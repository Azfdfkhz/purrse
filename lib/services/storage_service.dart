import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auto_backup_service.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/expense_model.dart';
import '../models/category_model.dart';
import '../utils/password_hasher.dart';
import 'fcm_service.dart';
import 'supabase_service.dart';
import 'sync_service.dart';

/// Semua data disimpan secara lokal di memori HP menggunakan
/// SharedPreferences (tanpa server / internet).
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _kUsers = 'users';
  static const _kCurrentUser = 'current_user_id';
  static const _kExpensesPrefix = 'expenses_';
  static const _kCategoriesPrefix = 'categories_';

  final _uuid = const Uuid();

  // Antrean serial: semua operasi baca-ubah-tulis berjalan satu per satu
  // sehingga dua penyimpanan bersamaan tidak saling menimpa (lost update).
  Future<void> _tail = Future.value();
  Future<T> _serial<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  // ---------- Auth ----------
  Future<List<UserModel>> _loadUsers() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_kUsers);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  Future<void> _saveUsers(List<UserModel> users) async {
    final prefs = await _prefs;
    await prefs.setString(_kUsers, jsonEncode(users.map((e) => e.toJson()).toList()));
  }

  Future<UserModel?> findUserByEmail(String email) async {
    final users = await _loadUsers();
    final target = email.trim().toLowerCase();
    for (final u in users) {
      if (u.email.toLowerCase() == target) return u;
    }
    return null;
  }

  /// Membuat akun lokal. [id] diisi dengan auth.uid Supabase agar data lokal
  /// dan cloud memakai pemilik yang sama (syarat RLS). Tanpa [id] -> UUID lokal.
  Future<UserModel> createLocalUser({
    String? id,
    required String username,
    required String email,
    required String password,
    bool seedCategories = true,
  }) =>
      _serial(() async {
        final users = await _loadUsers();
        users.removeWhere((u) => u.email.toLowerCase() == email.toLowerCase());
        final salt = PasswordHasher.generateSalt();
        final user = UserModel(
          id: id ?? _uuid.v4(),
          username: username,
          email: email,
          passwordSalt: salt,
          passwordHash: PasswordHasher.hash(password, salt),
        );
        users.add(user);
        await _saveUsers(users);
        if (seedCategories) await _seedDefaultCategories(user.id);
        return user;
      });

  /// Memverifikasi password lokal (termasuk migrasi password teks biasa lama).
  /// Mengembalikan true jika cocok.
  Future<bool> verifyLocalPassword(UserModel user, String password) =>
      _serial(() async {
        if (user.passwordHash != null && user.passwordSalt != null) {
          return PasswordHasher.verify(password, user.passwordSalt!, user.passwordHash!);
        }
        if (user.legacyPassword != null && user.legacyPassword == password) {
          final users = await _loadUsers();
          final idx = users.indexWhere((u) => u.id == user.id);
          if (idx != -1) {
            final salt = PasswordHasher.generateSalt();
            users[idx] = users[idx].copyWith(
              passwordSalt: salt,
              passwordHash: PasswordHasher.hash(password, salt),
              clearLegacyPassword: true,
            );
            await _saveUsers(users);
          }
          return true;
        }
        return false;
      });

  /// Atur password lokal (dipakai setelah login cloud berhasil / ganti password).
  Future<void> setLocalPassword(String userId, String password) => _serial(() async {
        final users = await _loadUsers();
        final idx = users.indexWhere((u) => u.id == userId);
        if (idx == -1) return;
        final salt = PasswordHasher.generateSalt();
        users[idx] = users[idx].copyWith(
          passwordSalt: salt,
          passwordHash: PasswordHasher.hash(password, salt),
          clearLegacyPassword: true,
        );
        await _saveUsers(users);
      });

  Future<void> setCurrentUserId(String id) => _setCurrentUser(id);

  /// MIGRASI: pindahkan seluruh data akun lokal [oldId] ke pemilik baru [newId]
  /// (auth.uid Supabase). Transaksi dan kategori ditulis ulang dengan pemilik
  /// baru lalu ditandai belum tersinkron. Jika [newId] sudah punya data lokal
  /// (mis. login ulang), data digabung berdasarkan ID — tidak ada yang ditimpa
  /// kecuali versi yang lebih baru (updatedAt).
  Future<void> rekeyUser(String oldId, String newId) => _serial(() async {
        if (oldId == newId) return;
        final prefs = await _prefs;
        final users = await _loadUsers();
        final idx = users.indexWhere((u) => u.id == oldId);
        if (idx != -1) {
          users.removeWhere((u) => u.id == newId);
          users[idx] = users[idx].copyWithId(newId);
          await _saveUsers(users);
        }

        // Transaksi
        final oldExp = await _loadAllExpenses(oldId);
        final byId = {for (final e in await _loadAllExpenses(newId)) e.id: e};
        for (final e in oldExp) {
          final moved = e.copyWith(userId: newId, syncState: SyncState.pending);
          final cur = byId[e.id];
          if (cur == null || moved.updatedAt.isAfter(cur.updatedAt)) byId[e.id] = moved;
        }
        await _saveAllExpenses(newId, byId.values.toList());
        await prefs.remove('$_kExpensesPrefix$oldId');

        // Kategori
        final oldCats = await _loadAllCategories(oldId, seed: false);
        final catById = {for (final c in await _loadAllCategories(newId, seed: false)) c.id: c};
        final stamp = DateTime.now().toUtc();
        for (final c in oldCats) {
          final cur = catById[c.id];
          if (cur == null) catById[c.id] = c.copyWith(updatedAt: c.updatedAt ?? stamp);
        }
        if (catById.isNotEmpty) await _saveAllCategories(newId, catById.values.toList());
        await prefs.remove('$_kCategoriesPrefix$oldId');

        if (prefs.getString(_kCurrentUser) == oldId) {
          await prefs.setString(_kCurrentUser, newId);
        }
        await prefs.remove('sync_cursor_$oldId');
      });

  Future<void> _setCurrentUser(String id) async {
    final prefs = await _prefs;
    await prefs.setString(_kCurrentUser, id);
  }

  Future<void> logout() async {
    // Urutan penting: lepas token notifikasi selagi sesi cloud masih ada.
    await FcmService.instance.unregister();
    SyncService.instance.stop();
    await SupabaseService.instance.signOut();
    final prefs = await _prefs;
    await prefs.remove(_kCurrentUser);
  }

  Future<UserModel?> getCurrentUser() async {
    final prefs = await _prefs;
    final id = prefs.getString(_kCurrentUser);
    if (id == null) return null;
    final users = await _loadUsers();
    try {
      return users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  // ---------- Categories ----------
  Future<void> _seedDefaultCategories(String userId) async {
    final now = DateTime.now().toUtc();
    final defaults = [
      CategoryModel(id: _uuid.v4(), name: 'Makanan', color: Color(0xFF8FC1E8), icon: Icons.restaurant, updatedAt: now),
      CategoryModel(id: _uuid.v4(), name: 'Hiburan', color: Color(0xFF8FDCC9), icon: Icons.movie_filter, updatedAt: now),
      CategoryModel(id: _uuid.v4(), name: 'Transport', color: Color(0xFFF5C77E), icon: Icons.directions_car, updatedAt: now),
      CategoryModel(id: _uuid.v4(), name: 'Lainnya', color: Color(0xFFF29C93), icon: Icons.account_balance_wallet, updatedAt: now),
    ];
    await _saveAllCategories(userId, defaults);
  }

  /// Semua kategori termasuk yang sudah dihapus (tombstone).
  Future<List<CategoryModel>> _loadAllCategories(String userId, {bool seed = true}) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_kCategoriesPrefix$userId');
    if (raw == null) {
      if (!seed) return [];
      await _seedDefaultCategories(userId);
      return _loadAllCategories(userId, seed: false);
    }
    final out = <CategoryModel>[];
    for (final e in jsonDecode(raw) as List) {
      try {
        out.add(CategoryModel.fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (_) {}
    }
    return out;
  }

  Future<void> _saveAllCategories(String userId, List<CategoryModel> all) async {
    final prefs = await _prefs;
    await prefs.setString(
      '$_kCategoriesPrefix$userId',
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<CategoryModel>> getCategories(String userId) async {
    final prefs = await _prefs;
    if (prefs.getString('$_kCategoriesPrefix$userId') == null) {
      // Banyak layar memanggil ini bersamaan saat start: seed hanya sekali.
      await _serial(() async {
        if (prefs.getString('$_kCategoriesPrefix$userId') == null) {
          await _seedDefaultCategories(userId);
        }
      });
    }
    final all = await _loadAllCategories(userId, seed: false);
    return all.where((c) => !c.isDeleted).toList();
  }

  Future<CategoryModel> addCategory(String userId, String name, Color color, IconData icon) =>
      _serial(() async {
        final categories = await _loadAllCategories(userId);
        final newCat = CategoryModel(
          id: _uuid.v4(),
          name: name,
          color: color,
          icon: icon,
          updatedAt: DateTime.now().toUtc(),
        );
        categories.add(newCat);
        await _saveAllCategories(userId, categories);
        SyncService.instance.markDirty();
        return newCat;
      });

  // ---------- Expenses ----------
  Future<List<ExpenseModel>> _loadAllExpenses(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_kExpensesPrefix$userId');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    final out = <ExpenseModel>[];
    for (final e in list) {
      try {
        out.add(ExpenseModel.fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (_) {
        // Satu data rusak tidak boleh membuat seluruh daftar hilang.
      }
    }
    return out;
  }

  Future<void> _saveAllExpenses(String userId, List<ExpenseModel> all) async {
    final prefs = await _prefs;
    final ok = await prefs.setString(
      '$_kExpensesPrefix$userId',
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
    if (!ok) throw Exception('Gagal menyimpan data transaksi.');
  }

  /// Transaksi aktif (tanpa yang sudah dihapus), terbaru di atas.
  Future<List<ExpenseModel>> getExpenses(String userId) async {
    final all = await _loadAllExpenses(userId);
    final expenses = all.where((e) => !e.isDeleted).toList();
    expenses.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
    return expenses;
  }

  Future<void> addExpense(ExpenseModel expense) => _serial(() async {
        final all = await _loadAllExpenses(expense.userId);
        // Idempoten: ID yang sama tidak akan dobel.
        all.removeWhere((e) => e.id == expense.id);
        all.add(expense);
        await _saveAllExpenses(expense.userId, all);
        AutoBackupService.instance.markDirty();
        SyncService.instance.markDirty();
      });

  /// Ubah satu transaksi. [change] menerima data terbaru dan
  /// mengembalikan versi baru. Mengembalikan null jika tidak ditemukan.
  Future<ExpenseModel?> mutateExpense(
    String userId,
    String expenseId,
    ExpenseModel Function(ExpenseModel current) change,
  ) =>
      _serial(() async {
        final all = await _loadAllExpenses(userId);
        final idx = all.indexWhere((e) => e.id == expenseId);
        if (idx == -1) return null;
        final updated = change(all[idx]);
        all[idx] = updated;
        await _saveAllExpenses(userId, all);
        if (updated.syncState == SyncState.pending) SyncService.instance.markDirty();
        return updated;
      });

  /// Edit oleh pengguna: updatedAt diperbarui, perlu disinkronkan ulang.
  Future<void> updateExpense(ExpenseModel expense) async {
    await mutateExpense(
      expense.userId,
      expense.id,
      (_) => expense.copyWith(
        updatedAt: DateTime.now().toUtc(),
        syncState: SyncState.pending,
      ),
    );
    AutoBackupService.instance.markDirty();
  }

  /// Hapus lunak (tombstone) agar penghapusan dapat disinkronkan.
  Future<void> deleteExpense(String userId, String expenseId) async {
    await mutateExpense(
      userId,
      expenseId,
      (e) => e.copyWith(
        deletedAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        syncState: SyncState.pending,
      ),
    );
    AutoBackupService.instance.markDirty();
  }

  /// Transaksi yang foto buktinya belum terunggah.
  Future<List<ExpenseModel>> getUploadCandidates(String userId) async {
    final all = await getExpenses(userId);
    return all.where((e) {
      if (!e.hasProof) return false;
      return e.uploadStatus != UploadStatus.uploaded;
    }).toList();
  }

  List<ExpenseModel> filterByMonth(List<ExpenseModel> all, int month, int year) {
    return all.where((e) => e.date.month == month && e.date.year == year).toList();
  }

  List<ExpenseModel> filterByDate(List<ExpenseModel> all, DateTime date) {
    return all
        .where((e) => e.date.year == date.year && e.date.month == date.month && e.date.day == date.day)
        .toList();
  }

  /// Total pengeluaran per bulan (1-12) untuk tahun tertentu.
  Map<int, double> monthlyTotals(List<ExpenseModel> all, int year) {
    final map = <int, double>{for (var m = 1; m <= 12; m++) m: 0};
    for (final e in all) {
      if (e.date.year == year) {
        map[e.date.month] = (map[e.date.month] ?? 0) + e.amount;
      }
    }
    return map;
  }

  /// Total pengeluaran per kategori dari sekumpulan expense.
  Map<String, double> categoryTotals(List<ExpenseModel> expenses) {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.categoryId] = (map[e.categoryId] ?? 0) + e.amount;
    }
    return map;
  }

  // ---------- Profile ----------
  Future<String?> updateProfile({
    required String userId,
    String? username,
    String? avatarPath,
  }) async {
    final users = await _loadUsers();
    final idx = users.indexWhere((u) => u.id == userId);
    if (idx == -1) return 'User tidak ditemukan';
    users[idx] = users[idx].copyWith(username: username, avatarPath: avatarPath);
    await _saveUsers(users);
    return null;
  }

  Future<String?> changePassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final users = await _loadUsers();
    final idx = users.indexWhere((u) => u.id == userId);
    if (idx == -1) return 'User tidak ditemukan';
    final u = users[idx];
    final oldOk = (u.passwordHash != null && u.passwordSalt != null)
        ? PasswordHasher.verify(oldPassword, u.passwordSalt!, u.passwordHash!)
        : (u.legacyPassword != null && u.legacyPassword == oldPassword);
    if (!oldOk) return 'Password lama salah';
    final salt = PasswordHasher.generateSalt();
    users[idx] = u.copyWith(
      passwordSalt: salt,
      passwordHash: PasswordHasher.hash(newPassword, salt),
      clearLegacyPassword: true,
    );
    await _saveUsers(users);
    return null;
  }

  // ---------- Category management ----------
  Future<void> updateCategory(String userId, CategoryModel category) => _serial(() async {
        final categories = await _loadAllCategories(userId);
        final idx = categories.indexWhere((c) => c.id == category.id);
        if (idx == -1) return;
        categories[idx] = categories[idx].copyWith(
          name: category.name,
          color: category.color,
          icon: category.icon,
          updatedAt: DateTime.now().toUtc(),
        );
        await _saveAllCategories(userId, categories);
        SyncService.instance.markDirty();
      });

  /// Hapus lunak (tombstone) agar penghapusan ikut tersinkron.
  Future<void> deleteCategory(String userId, String categoryId) => _serial(() async {
        final categories = await _loadAllCategories(userId);
        final idx = categories.indexWhere((c) => c.id == categoryId);
        if (idx == -1) return;
        final now = DateTime.now().toUtc();
        categories[idx] = categories[idx].copyWith(deletedAt: now, updatedAt: now);
        await _saveAllCategories(userId, categories);
        SyncService.instance.markDirty();
      });

  // ---------- Tampilan (tema warna) ----------
  Future<void> setAccentColor(int colorValue) async {
    final prefs = await _prefs;
    await prefs.setInt('accent_color', colorValue);
  }

  Future<int?> getAccentColor() async {
    final prefs = await _prefs;
    return prefs.getInt('accent_color');
  }

  // ---------- Backup / Restore ----------

  /// Restore: isi backup menjadi kondisi baru. Agar konsisten dengan sinkronisasi,
  /// transaksi yang ada di perangkat tetapi tidak ada di backup diberi tombstone
  /// (bukan dihapus diam-diam), dan semua data hasil restore ditandai belum
  /// tersinkron dengan updatedAt baru sehingga menang atas versi cloud.
  Future<void> replaceExpensesFromBackup(
    String userId,
    List<Map<String, dynamic>> expenses,
  ) =>
      _serial(() async {
        final byId = <String, ExpenseModel>{};
        for (final json in expenses) {
          try {
            final e = ExpenseModel.fromJson(Map<String, dynamic>.from(json));
            byId[e.id] = e;
          } catch (_) {}
        }
        if (expenses.isNotEmpty && byId.isEmpty) {
          throw FormatException('Isi backup tidak valid, data tidak diubah.');
        }
        final now = DateTime.now().toUtc();
        final result = <String, ExpenseModel>{};
        for (final e in byId.values) {
          result[e.id] = e.copyWith(
            userId: userId,
            updatedAt: now,
            clearDeletedAt: true,
            syncState: SyncState.pending,
          );
        }
        for (final e in await _loadAllExpenses(userId)) {
          if (result.containsKey(e.id)) continue;
          result[e.id] = e.isDeleted
              ? e
              : e.copyWith(deletedAt: now, updatedAt: now, syncState: SyncState.pending);
        }
        await _saveAllExpenses(userId, result.values.toList());
        SyncService.instance.markDirty();
      });

  Future<void> replaceCategoriesFromBackup(
    String userId,
    List<Map<String, dynamic>> categories,
  ) =>
      _serial(() async {
        final now = DateTime.now().toUtc();
        final restored = <String, CategoryModel>{};
        for (final json in categories) {
          try {
            final c = CategoryModel.fromJson(Map<String, dynamic>.from(json));
            restored[c.id] = c.copyWith(updatedAt: now, clearDeletedAt: true);
          } catch (_) {}
        }
        for (final c in await _loadAllCategories(userId, seed: false)) {
          if (restored.containsKey(c.id)) continue;
          restored[c.id] = c.isDeleted ? c : c.copyWith(deletedAt: now, updatedAt: now);
        }
        await _saveAllCategories(userId, restored.values.toList());
        SyncService.instance.markDirty();
      });

  // ---------- Sinkronisasi (dipakai SyncService) ----------

  /// Semua transaksi termasuk tombstone.
  Future<List<ExpenseModel>> getAllExpensesRaw(String userId) => _loadAllExpenses(userId);

  Future<List<CategoryModel>> getAllCategoriesRaw(String userId) =>
      _loadAllCategories(userId, seed: false);

  /// Beri updatedAt pada kategori lama yang belum punya (data < 1.3.0).
  Future<void> stampLegacyCategories(String userId) => _serial(() async {
        final all = await _loadAllCategories(userId, seed: false);
        if (all.every((c) => c.updatedAt != null)) return;
        final now = DateTime.now().toUtc();
        await _saveAllCategories(
          userId,
          [for (final c in all) c.updatedAt == null ? c.copyWith(updatedAt: now) : c],
        );
      });

  /// Tandai tersinkron hanya bila transaksi tidak berubah sejak dikirim.
  Future<void> markExpensesSynced(String userId, Map<String, DateTime> pushed) =>
      _serial(() async {
        final all = await _loadAllExpenses(userId);
        var changed = false;
        for (var i = 0; i < all.length; i++) {
          final sentAt = pushed[all[i].id];
          if (sentAt != null &&
              all[i].syncState != SyncState.synced &&
              !all[i].updatedAt.isAfter(sentAt)) {
            all[i] = all[i].copyWith(syncState: SyncState.synced);
            changed = true;
          }
        }
        if (changed) await _saveAllExpenses(userId, all);
      });

  /// Gabungkan data cloud ke lokal (last-write-wins per updatedAt).
  /// Mengembalikan true bila ada data lokal yang berubah.
  Future<bool> mergeRemote(
    String userId, {
    required List<ExpenseModel> expenses,
    required List<CategoryModel> categories,
    required bool fullPull,
  }) =>
      _serial(() async {
        var changed = false;

        // ---- Kategori ----
        final cats = await _loadAllCategories(userId, seed: false);
        final catIdx = {for (var i = 0; i < cats.length; i++) cats[i].id: i};
        final remap = <String, String>{}; // id lokal -> id cloud (kategori kembar)

        if (fullPull) {
          // Perangkat baru / login pertama: kategori bawaan lokal (ID acak) yang
          // namanya sama dengan kategori cloud dianggap kembar, bukan data baru.
          final remoteIds = {for (final c in categories) c.id};
          String norm(String n) => n.trim().toLowerCase();
          final remoteByName = {
            for (final c in categories)
              if (!c.isDeleted) norm(c.name): c,
          };
          for (final c in List<CategoryModel>.from(cats)) {
            if (c.isDeleted || remoteIds.contains(c.id)) continue;
            final twin = remoteByName[norm(c.name)];
            if (twin != null) {
              remap[c.id] = twin.id;
              cats.remove(c);
              changed = true;
            }
          }
          catIdx
            ..clear()
            ..addAll({for (var i = 0; i < cats.length; i++) cats[i].id: i});
        }

        for (final r in categories) {
          final i = catIdx[r.id];
          if (i == null) {
            if (r.isDeleted) continue;
            cats.add(r);
            catIdx[r.id] = cats.length - 1;
            changed = true;
          } else {
            final l = cats[i];
            final lt = l.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
            if (r.updatedAt != null && r.updatedAt!.isAfter(lt)) {
              cats[i] = r;
              changed = true;
            }
          }
        }
        if (changed) await _saveAllCategories(userId, cats);

        // ---- Transaksi ----
        final all = await _loadAllExpenses(userId);
        final idx = {for (var i = 0; i < all.length; i++) all[i].id: i};
        var expChanged = false;

        if (remap.isNotEmpty) {
          for (var i = 0; i < all.length; i++) {
            final to = remap[all[i].categoryId];
            if (to != null) {
              all[i] = all[i].copyWith(
                categoryId: to,
                updatedAt: DateTime.now().toUtc(),
                syncState: SyncState.pending,
              );
              expChanged = true;
            }
          }
        }

        for (final r in expenses) {
          final i = idx[r.id];
          if (i == null) {
            if (r.isDeleted) continue;
            all.add(r);
            idx[r.id] = all.length - 1;
            expChanged = true;
            continue;
          }
          var l = all[i];
          if (r.updatedAt.isAfter(l.updatedAt)) {
            l = l.copyWith(
              categoryId: remap[r.categoryId] ?? r.categoryId,
              amount: r.amount,
              date: r.date,
              description: r.description,
              updatedAt: r.updatedAt,
              deletedAt: r.deletedAt,
              clearDeletedAt: r.deletedAt == null,
              syncState: SyncState.synced,
            );
            expChanged = true;
          }
          // Referensi foto di Drive selalu diadopsi bila perangkat ini belum punya.
          if (r.driveFileId != null && l.driveFileId == null) {
            l = l.copyWith(driveFileId: r.driveFileId, uploadStatus: UploadStatus.uploaded);
            expChanged = true;
          }
          all[i] = l;
        }
        if (expChanged) await _saveAllExpenses(userId, all);

        return changed || expChanged;
      });
}
