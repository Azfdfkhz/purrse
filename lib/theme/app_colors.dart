import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFFFBF7F0); // krem hangat
  static const Color ink = Color(0xFF1F1B24); // hitam tinta: tombol, outline, navbar
  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFC62828);
  static const Color softPurple = Color(0xFFE3DEF6);
  static const Color softPurpleDark = Color(0xFFB9AEDD);
  static const Color softPink = Color(0xFFF3AECD);
  static const Color pinkAccent = Color(0xFFF07E9E);
  static const Color pinkStrong = Color(0xFFEC6D91);
  static const Color softBlue = Color(0xFF8FC1E8);
  static const Color softMint = Color(0xFF8FDCC9);
  static const Color softOrange = Color(0xFFF5C77E);
  static const Color softCoral = Color(0xFFF29C93);
  static const Color textDark = Color(0xFF1F1B24);
  static const Color textGrey = Color(0xFF6B6573); // kontras >= 4.5:1 di atas putih
  static const Color cardBorder = Color(0xFFE9E2D6);

  static const List<Color> categoryPalette = [
    softBlue,
    softOrange,
    softPurpleDark,
    softCoral,
    softMint,
  ];
}
