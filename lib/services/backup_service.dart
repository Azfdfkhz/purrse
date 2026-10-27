import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/backup_model.dart';
import 'storage_service.dart';
import 'google_drive_service.dart';

/// Hasil unduh + validasi backup, ditampilkan ke pengguna SEBELUM restore.
class BackupPreview {
  final String json;
  final int transactionCount;
  final int categoryCount;
  final DateTime? createdAt;

  const BackupPreview({
    required this.json,
    required this.transactionCount,
    required this.categoryCount,
    required this.createdAt,
  });
}

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  static const String appName = 'Purrse';

  /// Naikkan angka ini jika struktur backup berubah
  /// di masa depan.
  static const int currentBackupVersion = 1;

  final StorageService _storage =
      StorageService.instance;

  final GoogleDriveService _drive =
      GoogleDriveService.instance;

  // ============================================================
  // CREATE BACKUP
  // ============================================================

  Future<String> createBackup({
    String appVersion = '1.2.2',
  }) async {
    final currentUser =
    await _storage.getCurrentUser();

    if (currentUser == null) {
      throw Exception(
        'Tidak ada pengguna yang sedang login.',
      );
    }

    // Ambil semua transaksi
    final expenses =
    await _storage.getExpenses(
      currentUser.id,
    );

    // Ambil semua kategori
    final categories =
    await _storage.getCategories(
      currentUser.id,
    );

    // Ambil setting warna
    final accentColor =
    await _storage.getAccentColor();

    final backup = BackupModel(
      app: appName,
      backupVersion: currentBackupVersion,
      appVersion: appVersion,
      createdAt:
      DateTime.now().toUtc().toIso8601String(),

      // Password TIDAK disimpan.
      user: {
        'id': currentUser.id,
        'username': currentUser.username,
        'email': currentUser.email,
        'avatarPath': currentUser.avatarPath,
      },

      transactions: expenses
          .map(
            (expense) => expense.toJson(),
      )
          .toList(),

      categories: categories
          .map(
            (category) => category.toJson(),
      )
          .toList(),

      settings: {
        if (accentColor != null)
          'accentColor': accentColor,
      },
    );

    return jsonEncode(
      backup.toJson(),
    );
  }

  // ============================================================
  // VALIDATE BACKUP
  // ============================================================

  BackupModel validateBackup(
      String backupJson,
      ) {
    try {
      final decoded = jsonDecode(
        backupJson,
      );

      if (decoded is! Map<String, dynamic>) {
        throw FormatException(
          'Format backup tidak valid.',
        );
      }

      final backup =
      BackupModel.fromJson(decoded);

      // Pastikan backup berasal dari Purrse
      if (backup.app != appName) {
        throw FormatException(
          'File bukan backup Purrse.',
        );
      }

      // Backup dibuat menggunakan versi
      // aplikasi yang lebih baru
      if (backup.backupVersion >
          currentBackupVersion) {
        throw FormatException(
          'Backup dibuat menggunakan versi aplikasi yang lebih baru.',
        );
      }

      // Backup versi lama
      if (backup.backupVersion <
          currentBackupVersion) {
        return migrateBackup(backup);
      }

      return backup;
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException(
        'Backup rusak atau tidak dapat dibaca: $e',
      );
    }
  }

  // ============================================================
  // MIGRATION
  // ============================================================

  BackupModel migrateBackup(
      BackupModel backup,
      ) {
    var result = backup;

    // ----------------------------------------------------------
    // Contoh migration untuk masa depan:
    //
    // if (result.backupVersion == 1) {
    //   result = _migrateV1ToV2(result);
    // }
    //
    // Untuk sekarang baru ada version 1.
    // ----------------------------------------------------------

    return result;
  }

  // ============================================================
  // RESTORE LOCAL BACKUP
  // ============================================================

  Future<void> restoreBackup(
      String backupJson,
      ) async {
    final backup =
    validateBackup(backupJson);

    final currentUser =
    await _storage.getCurrentUser();

    if (currentUser == null) {
      throw Exception(
        'Tidak ada pengguna yang sedang login.',
      );
    }

    /*
     * PENTING:
     *
     * User ID dari HP lama TIDAK digunakan.
     *
     * Semua transaksi akan menggunakan
     * user ID dari HP sekarang.
     */

    final restoredExpenses =
    backup.transactions.map((json) {
      final data =
      Map<String, dynamic>.from(json);

      data['userId'] =
          currentUser.id;

      return data;
    }).toList();

    final restoredCategories =
    backup.categories.map((json) {
      return Map<String, dynamic>.from(json);
    }).toList();

    // Simpan transaksi
    await _storage
        .replaceExpensesFromBackup(
      currentUser.id,
      restoredExpenses,
    );

    // Simpan kategori
    await _storage
        .replaceCategoriesFromBackup(
      currentUser.id,
      restoredCategories,
    );

    // Restore setting warna
    final accentColor =
    backup.settings['accentColor'];

    if (accentColor is int) {
      await _storage.setAccentColor(
        accentColor,
      );
    }
  }

  // ============================================================
  // BACKUP TO GOOGLE DRIVE
  // ============================================================

  Future<void> backupToGoogleDrive({
    String appVersion = '1.2.2',
  }) async {
    // Pastikan Google Drive terhubung
    if (!_drive.isSignedIn) {
      await _drive.signIn();
    }

    // Buat backup dari data lokal
    final backupJson =
    await createBackup(
      appVersion: appVersion,
    );

    // Upload atau update file backup
    await _drive.uploadOrUpdateBackup(
      backupJson,
    );

    // Dicatat HANYA setelah upload berhasil (tidak melapor sukses lebih awal).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kLastBackup,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  // ============================================================
  // STATUS, PREVIEW, DAN RESTORE AMAN
  // ============================================================

  static const String _kLastBackup = 'last_drive_backup_at';
  static const String _kSafetyJson = 'safety_backup_json';
  static const String _kSafetyAt = 'safety_backup_at';

  /// Waktu backup Drive terakhir yang berhasil dari perangkat ini.
  Future<DateTime?> lastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLastBackup);
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  /// Unduh dan validasi backup tanpa mengubah data lokal.
  Future<BackupPreview> previewGoogleDriveBackup() async {
    if (!_drive.isSignedIn) {
      await _drive.signIn();
    }
    if (!await _drive.hasBackup()) {
      throw Exception(
        'Belum ada file backup di Google Drive akun ini. Pastikan akun Google '
        'yang dipilih sama dengan yang dipakai saat backup, atau buat backup '
        'dulu dari perangkat lama.',
      );
    }
    final json = await _drive.downloadBackup();
    final backup = validateBackup(json);
    return BackupPreview(
      json: json,
      transactionCount: backup.transactions.length,
      categoryCount: backup.categories.length,
      createdAt: DateTime.tryParse(backup.createdAt)?.toLocal(),
    );
  }

  /// Simpan salinan pengaman data lokal saat ini, lalu restore dari [preview].
  /// Jika restore gagal, data lokal dikembalikan dari salinan pengaman.
  Future<void> restoreWithSafety(BackupPreview preview) async {
    final prefs = await SharedPreferences.getInstance();
    final before = await createBackup();
    await prefs.setString(_kSafetyJson, before);
    await prefs.setString(_kSafetyAt, DateTime.now().toUtc().toIso8601String());
    try {
      await restoreBackup(preview.json);
    } catch (e) {
      await restoreBackup(before);
      rethrow;
    }
  }

  Future<DateTime?> safetyBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kSafetyJson) == null) return null;
    final raw = prefs.getString(_kSafetyAt);
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  /// Batalkan restore terakhir: kembalikan data sebelum restore.
  Future<void> undoLastRestore() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kSafetyJson);
    if (json == null) {
      throw Exception('Tidak ada salinan pengaman untuk dikembalikan.');
    }
    await restoreBackup(json);
    await prefs.remove(_kSafetyJson);
    await prefs.remove(_kSafetyAt);
  }

  // ============================================================
  // RESTORE FROM GOOGLE DRIVE
  // ============================================================

  Future<void> restoreFromGoogleDrive() async {
    // Pastikan Google Drive terhubung
    if (!_drive.isSignedIn) {
      await _drive.signIn();
    }

    // Download backup dari Google Drive
    final backupJson =
    await _drive.downloadBackup();

    // Validasi dan restore ke storage lokal
    await restoreBackup(
      backupJson,
    );
  }

  // ============================================================
  // CHECK GOOGLE DRIVE BACKUP
  // ============================================================

  Future<bool> hasGoogleDriveBackup() async {
    if (!_drive.isSignedIn) {
      return false;
    }

    return await _drive.hasBackup();
  }
}