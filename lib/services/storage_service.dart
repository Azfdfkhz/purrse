import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/expense_model.dart';
import '../models/category_model.dart';

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

    final newUser = UserModel(
      id: _uuid.v4(),
      username: username,
      email: email,
      password: password,
    );
    users.add(newUser);
    await _saveUsers(users);
    await _seedDefaultCategories(newUser.id);
    await _setCurrentUser(newUser.id);
    return null;
  }

  Future<String?> login({required String email, required String password}) async {
    final users = await _loadUsers();
    final match = users.where(
      (u) => u.email.toLowerCase() == email.toLowerCase() && u.password == password,
    );
    if (match.isEmpty) return 'Email atau password salah';
    await _setCurrentUser(match.first.id);
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
  Future<List<ExpenseModel>> getExpenses(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_kExpensesPrefix$userId');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    final expenses = list.map((e) => ExpenseModel.fromJson(e)).toList();
    expenses.sort((a, b) => b.date.compareTo(a.date));
    return expenses;
  }

  Future<void> addExpense(ExpenseModel expense) async {
    final expenses = await getExpenses(expense.userId);
    expenses.add(expense);
    final prefs = await _prefs;
    await prefs.setString(
      '$_kExpensesPrefix${expense.userId}',
      jsonEncode(expenses.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteExpense(String userId, String expenseId) async {
    final expenses = await getExpenses(userId);
    expenses.removeWhere((e) => e.id == expenseId);
    final prefs = await _prefs;
    await prefs.setString(
      '$_kExpensesPrefix$userId',
      jsonEncode(expenses.map((e) => e.toJson()).toList()),
    );
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
    final current = users[idx];
    users[idx] = UserModel(
      id: current.id,
      username: username ?? current.username,
      email: current.email,
      password: current.password,
      avatarPath: avatarPath ?? current.avatarPath,
    );
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
    if (users[idx].password != oldPassword) return 'Password lama salah';
    final current = users[idx];
    users[idx] = UserModel(
      id: current.id,
      username: current.username,
      email: current.email,
      password: newPassword,
      avatarPath: current.avatarPath,
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
      ) async {
    final prefs = await _prefs;

    await prefs.setString(
      '$_kExpensesPrefix$userId',
      jsonEncode(expenses),
    );
  }

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


