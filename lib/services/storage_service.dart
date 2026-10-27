import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/expense_model.dart';
import '../models/category_model.dart';
import '../utils/password_hasher.dart';

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

  /// Mengembalikan null jika berhasil, atau pesan error jika gagal.
  Future<String?> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final users = await _loadUsers();
    final exists = users.any((u) => u.email.toLowerCase() == email.toLowerCase());
    if (exists) return 'Email sudah terdaftar';

    final salt = PasswordHasher.generateSalt();
    final newUser = UserModel(
      id: _uuid.v4(),
      username: username,
      email: email,
      passwordSalt: salt,
      passwordHash: PasswordHasher.hash(password, salt),
    );
    users.add(newUser);
    await _saveUsers(users);
    await _seedDefaultCategories(newUser.id);
    await _setCurrentUser(newUser.id);
    return null;
  }

  Future<String?> login({required String email, required String password}) async {
    final users = await _loadUsers();
    final idx = users.indexWhere((u) => u.email.toLowerCase() == email.toLowerCase());
    if (idx == -1) return 'Email atau password salah';
    final user = users[idx];

    var ok = false;
    if (user.passwordHash != null && user.passwordSalt != null) {
      ok = PasswordHasher.verify(password, user.passwordSalt!, user.passwordHash!);
    } else if (user.legacyPassword != null && user.legacyPassword == password) {
      // Migrasi otomatis dari password teks biasa (<= 1.1.0) ke hash.
      final salt = PasswordHasher.generateSalt();
      users[idx] = user.copyWith(
        passwordSalt: salt,
        passwordHash: PasswordHasher.hash(password, salt),
        clearLegacyPassword: true,
      );
      await _saveUsers(users);
      ok = true;
    }
    if (!ok) return 'Email atau password salah';
    await _setCurrentUser(user.id);
    return null;
  }

  Future<void> _setCurrentUser(String id) async {
    final prefs = await _prefs;
    await prefs.setString(_kCurrentUser, id);
  }

  Future<void> logout() async {
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
    final defaults = [
      CategoryModel(id: _uuid.v4(), name: 'Makanan', color: const Color(0xFF8FC1E8), icon: Icons.restaurant),
      CategoryModel(id: _uuid.v4(), name: 'Hiburan', color: const Color(0xFF8FDCC9), icon: Icons.movie_filter),
      CategoryModel(id: _uuid.v4(), name: 'Transport', color: const Color(0xFFF5C77E), icon: Icons.directions_car),
      CategoryModel(id: _uuid.v4(), name: 'Lainnya', color: const Color(0xFFF29C93), icon: Icons.account_balance_wallet),
    ];
    final prefs = await _prefs;
    await prefs.setString(
      '$_kCategoriesPrefix$userId',
      jsonEncode(defaults.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<CategoryModel>> getCategories(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_kCategoriesPrefix$userId');
    if (raw == null) {
      await _seedDefaultCategories(userId);
      return getCategories(userId);
    }
    final list = jsonDecode(raw) as List;
    return list.map((e) => CategoryModel.fromJson(e)).toList();
  }

  Future<CategoryModel> addCategory(String userId, String name, Color color, IconData icon) async {
    final categories = await getCategories(userId);
    final newCat = CategoryModel(id: _uuid.v4(), name: name, color: color, icon: icon);
    categories.add(newCat);
    final prefs = await _prefs;
    await prefs.setString(
      '$_kCategoriesPrefix$userId',
      jsonEncode(categories.map((e) => e.toJson()).toList()),
    );
    return newCat;
  }

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
  Future<void> updateCategory(String userId, CategoryModel category) async {
    final categories = await getCategories(userId);
    final idx = categories.indexWhere((c) => c.id == category.id);
    if (idx == -1) return;
    categories[idx] = category;
    final prefs = await _prefs;
    await prefs.setString(
      '$_kCategoriesPrefix$userId',
      jsonEncode(categories.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteCategory(String userId, String categoryId) async {
    final categories = await getCategories(userId);
    categories.removeWhere((c) => c.id == categoryId);
    final prefs = await _prefs;
    await prefs.setString(
      '$_kCategoriesPrefix$userId',
      jsonEncode(categories.map((e) => e.toJson()).toList()),
    );
  }

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

  Future<void> replaceExpensesFromBackup(
    String userId,
    List<Map<String, dynamic>> expenses,
  ) =>
      _serial(() async {
        // Validasi & normalisasi sebelum menimpa data lama. ID unik,
        // jadi file backup yang berisi duplikat tidak membuat transaksi ganda.
        final byId = <String, ExpenseModel>{};
        for (final json in expenses) {
          try {
            final e = ExpenseModel.fromJson(Map<String, dynamic>.from(json));
            byId[e.id] = e;
          } catch (_) {}
        }
        if (expenses.isNotEmpty && byId.isEmpty) {
          throw const FormatException('Isi backup tidak valid, data tidak diubah.');
        }
        await _saveAllExpenses(userId, byId.values.toList());
      });

  Future<void> replaceCategoriesFromBackup(
      String userId,
      List<Map<String, dynamic>> categories,
      ) async {
    final prefs = await _prefs;

    await prefs.setString(
      '$_kCategoriesPrefix$userId',
      jsonEncode(categories),
    );
  }
}


