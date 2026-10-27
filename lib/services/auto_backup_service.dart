import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_service.dart';
import 'google_drive_service.dart';

enum AutoBackupState { idle, waiting, running, failed, needsDrive }

/// Backup otomatis ke Google Drive setelah perubahan data.
/// - Debounce 30 detik: banyak perubahan beruntun = satu backup.
/// - Antrean tahan restart: penanda "ada perubahan belum dibackup" disimpan.
/// - Gagal -> coba lagi dengan jeda bertahap (1, 5, 15, 30, 60 menit).
/// - Tidak pernah melaporkan sukses sebelum upload benar-benar berhasil.
/// - Tidak memunculkan dialog login: bila Drive belum terhubung, menunggu.
class AutoBackupService extends ChangeNotifier {
  AutoBackupService._();
  static final AutoBackupService instance = AutoBackupService._();

  static const _kEnabled = 'auto_backup_enabled';
  static const _kDirty = 'auto_backup_dirty';
  static const _backoff = [1, 5, 15, 30, 60]; // menit

  AutoBackupState state = AutoBackupState.idle;
  Timer? _timer;
  int _attempt = 0;
  int _version = 0;
  bool _running = false;

  Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kEnabled) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, value);
    if (!value) {
      cancel();
      return;
    }
    // Saat dinyalakan, cadangkan kondisi data saat ini.
    await markDirty(delay: const Duration(seconds: 3));
  }

  /// Tandai ada perubahan yang perlu dibackup.
  Future<void> markDirty({Duration delay = const Duration(seconds: 30)}) async {
    _version++;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDirty, true);
    if (!(p.getBool(_kEnabled) ?? false)) return;
    _schedule(delay);
  }

  /// Dipanggil saat aplikasi dibuka: lanjutkan backup yang tertunda.
  Future<void> resumePending() async {
    final p = await SharedPreferences.getInstance();
    if ((p.getBool(_kEnabled) ?? false) && (p.getBool(_kDirty) ?? false)) {
      _schedule(const Duration(seconds: 8));
    }
  }

  /// Coba lagi sekarang (tombol manual setelah gagal).
  Future<void> retryNow() async {
    _attempt = 0;
    _schedule(const Duration(seconds: 1));
  }

  /// Batalkan jadwal (logout / dimatikan).
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _set(AutoBackupState.idle);
  }

  void _schedule(Duration d) {
    _timer?.cancel();
    _timer = Timer(d, _run);
    _set(AutoBackupState.waiting);
  }

  void _set(AutoBackupState s) {
    state = s;
    notifyListeners();
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    final startVersion = _version;
    _set(AutoBackupState.running);
    try {
      final drive = GoogleDriveService.instance;
      if (!drive.isSignedIn) {
        _set(AutoBackupState.needsDrive);
        return;
      }
      await BackupService.instance.backupToGoogleDrive();
      _attempt = 0;
      if (_version == startVersion) {
        final p = await SharedPreferences.getInstance();
        await p.setBool(_kDirty, false);
        _set(AutoBackupState.idle);
      } else {
        // Ada perubahan baru selama backup berjalan.
        _schedule(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint('Backup otomatis gagal: $e');
      final minutes = _backoff[_attempt.clamp(0, _backoff.length - 1)];
      _attempt++;
      _set(AutoBackupState.failed);
      if (_attempt <= _backoff.length) {
        _timer?.cancel();
        _timer = Timer(Duration(minutes: minutes), _run);
      }
    } finally {
      _running = false;
    }
  }
}
