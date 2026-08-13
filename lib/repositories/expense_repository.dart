import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ExpenseRepository {
  static const String _key = 'user_expenses_data';

  // Simpan/Tambah List Transaksi ke JSON String
  Future<void> saveExpenses(List<Map<String, dynamic>> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    String encodedData = jsonEncode(expenses);
    await prefs.setString(_key, encodedData);
  }

  // Ambil Data Transaksi
  Future<List<Map<String, dynamic>>> getExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString(_key);

    if (jsonString == null) return [];

    List<dynamic> decodedList = jsonDecode(jsonString);
    return List<Map<String, dynamic>>.from(decodedList);
  }
}