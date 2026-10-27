import 'dart:async';
import 'dart:io';

import '../models/expense_model.dart';
import 'google_drive_service.dart';
import 'storage_service.dart';

/// Antrean upload foto bukti -> Google Drive.
///
/// Antrean disimpan di data transaksi itu sendiri (uploadStatus,
/// uploadAttempts, nextRetryAt), sehingga bertahan walau aplikasi ditutup.
/// - Gagal jaringan  -> retry dengan jeda bertahap (backoff).
/// - Drive belum terhubung / izin habis -> status needsAuth, tidak dihitung
///   sebagai percobaan; lanjut otomatis setelah pengguna menghubungkan ulang.
/// - Retry tidak membuat file ganda (Drive dicek lewat ID transaksi).
class ProofUploadService {
  ProofUploadService._();
  static final ProofUploadService instance = ProofUploadService._();

  static const int maxAttempts = 8;
  static const List<Duration> _backoff = [
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 10),
    Duration(minutes: 30),
    Duration(hours: 2),
  ];

  final _changes = StreamController<void>.broadcast();

  /// Dipancarkan setiap status upload berubah (untuk refresh UI).
  Stream<void> get changes => _changes.stream;

  bool _running = false;
  Timer? _timer;

  /// Mulai pemeriksaan berkala selama aplikasi terbuka.
  void startPeriodic(String userId) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => processPending(userId));
    processPending(userId);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Masukkan transaksi ke antrean (dipanggil setelah simpan/edit foto).
  Future<void> enqueue(String userId, String expenseId) async {
    await StorageService.instance.mutateExpense(
      userId,
      expenseId,
      (e) => e.copyWith(
        uploadStatus: e.hasProof ? UploadStatus.pending : UploadStatus.none,
        uploadAttempts: 0,
        clearNextRetry: true,
        clearUploadError: true,
      ),
    );
    _changes.add(null);
    unawaited(processPending(userId));
  }

  /// Coba ulang manual (mengabaikan jeda backoff).
  Future<void> retry(String userId, String expenseId) async {
    await StorageService.instance.mutateExpense(
      userId,
      expenseId,
      (e) => e.copyWith(
        uploadStatus: UploadStatus.pending,
        uploadAttempts: 0,
        clearNextRetry: true,
        clearUploadError: true,
      ),
    );
    _changes.add(null);
    await processPending(userId);
  }

  Future<void> processPending(String userId) async {
    if (_running) return;
    _running = true;
    try {
      final drive = GoogleDriveService.instance;
      final candidates = await StorageService.instance.getUploadCandidates(userId);
      if (candidates.isEmpty) return;

      final connected = await drive.restoreSession();
      final now = DateTime.now().toUtc();

      for (final e in candidates) {
        if (e.uploadAttempts >= maxAttempts &&
            e.uploadStatus == UploadStatus.failed) {
          continue; // menunggu retry manual
        }
        if (e.nextRetryAt != null && e.nextRetryAt!.isAfter(now)) continue;

        if (!connected) {
          await _setStatus(userId, e.id, UploadStatus.needsAuth,
              error: 'Google Drive belum terhubung.');
          continue;
        }
        await _uploadOne(userId, e);
      }
    } finally {
      _running = false;
      _changes.add(null);
    }
  }

  Future<void> _uploadOne(String userId, ExpenseModel e) async {
    final path = e.proofPath;
    if (path == null || !File(path).existsSync()) {
      await StorageService.instance.mutateExpense(
        userId,
        e.id,
        (c) => c.copyWith(
          uploadStatus: UploadStatus.failed,
          uploadAttempts: maxAttempts,
          uploadError: 'File foto tidak ditemukan di perangkat ini.',
        ),
      );
      return;
    }

    await _setStatus(userId, e.id, UploadStatus.uploading);
    try {
      final bytes = await File(path).readAsBytes();
      final fileId = await GoogleDriveService.instance.uploadProof(
        expenseId: e.id,
        bytes: bytes,
        localPath: path,
      );
      // Dianggap berhasil hanya setelah Drive mengembalikan ID file.
      await StorageService.instance.mutateExpense(
        userId,
        e.id,
        (c) => c.copyWith(
          driveFileId: fileId,
          uploadStatus: UploadStatus.uploaded,
          clearNextRetry: true,
          clearUploadError: true,
          syncState: SyncState.pending, // metadata berubah -> perlu sinkron
        ),
      );
    } on DriveAuthRequired catch (err) {
      await _setStatus(userId, e.id, UploadStatus.needsAuth, error: err.message);
    } catch (err) {
      final attempts = e.uploadAttempts + 1;
      final delay = _backoff[(attempts - 1).clamp(0, _backoff.length - 1)];
      await StorageService.instance.mutateExpense(
        userId,
        e.id,
        (c) => c.copyWith(
          uploadStatus: UploadStatus.failed,
          uploadAttempts: attempts,
          nextRetryAt: DateTime.now().toUtc().add(delay),
          uploadError: 'Upload gagal, akan dicoba lagi otomatis.',
        ),
      );
    }
    _changes.add(null);
  }

  Future<void> _setStatus(String userId, String id, String status,
      {String? error}) async {
    await StorageService.instance.mutateExpense(
      userId,
      id,
      (c) => c.copyWith(
        uploadStatus: status,
        uploadError: error,
        clearUploadError: error == null,
      ),
    );
    _changes.add(null);
  }
}
