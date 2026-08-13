import 'dart:convert';

import '../models/backup_model.dart';
import 'storage_service.dart';
import 'google_drive_service.dart';

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
    String appVersion = '1.0.0',
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
        throw const FormatException(
          'Format backup tidak valid.',
        );
      }

      final backup =
      BackupModel.fromJson(decoded);

      // Pastikan backup berasal dari Purrse
      if (backup.app != appName) {
        throw const FormatException(
          'File bukan backup Purrse.',
        );
      }

      // Backup dibuat menggunakan versi
      // aplikasi yang lebih baru
      if (backup.backupVersion >
          currentBackupVersion) {
        throw const FormatException(
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
    String appVersion = '1.0.0',
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