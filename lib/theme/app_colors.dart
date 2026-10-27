import 'package:flutter/material.dart';

/// Palet aplikasi. Token yang berubah antara Light dan Dark dibuat sebagai
/// getter (bukan const) dan mengikuti [isDark], yang diatur oleh
/// ThemeController. Warna pastel/semantik tetap const.
class AppColors {
  AppColors._();

  /// Diatur oleh ThemeController sebelum tema dibangun.
  static bool isDark = false;

  static Color _p(Color light, Color dark) => isDark ? dark : light;

  // ---- Token yang mengikuti tema ----
  static Color get background => _p(const Color(0xFFF2EFE8), const Color(0xFF111014));
  static Color get surface => _p(Colors.white, const Color(0xFF1C1B21));
  static Color get surfaceVariant => _p(const Color(0xFFEAE6DC), const Color(0xFF27252D));
  static Color get border => _p(const Color(0xFFE6E1D5), const Color(0xFF2F2D36));
  static Color get cardBorder => border;

  /// Garis halus untuk kartu/chip (pengganti outline hitam tebal).
  static Color get hairline => _p(const Color(0x14000000), const Color(0x1FFFFFFF));

  /// Bayangan lembut kartu (hanya di mode terang; di gelap cukup hairline).
  static List<BoxShadow> get softShadow => isDark
      ? const []
      : const [BoxShadow(color: Color(0x0F1F1B24), blurRadius: 18, offset: Offset(0, 6))];

  /// Kebalikan ink: pil terpilih pada navbar (putih di gelap, ink di terang).
  static Color get inkInverse => _p(const Color(0xFF141414), Colors.white);

  /// Warna "tinta": tombol, outline tebal, navbar, kartu utama.
  /// Selalu gelap sehingga teks putih (onInk) di atasnya tetap terbaca.
  static Color get ink => _p(const Color(0xFF141414), const Color(0xFF34313D));

  /// Teks utama dan teks sekunder (otomatis gelap di terang, terang di gelap).
  static Color get textDark => _p(const Color(0xFF1F1B24), const Color(0xFFF3EFF8));
  static Color get textGrey => _p(const Color(0xFF6B6573), const Color(0xFFB4ADBF));

  // ---- Konstanta ----
  static const Color onInk = Colors.white; // teks/ikon di atas ink
  /// Teks/ikon di atas warna pastel (aksen, kategori): selalu gelap.
  static const Color onPastel = Color(0xFF1F1B24);

  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFC62828);
  static const Color warning = Color(0xFF8A5A00);
  static const Color softPurple = Color(0xFFE3DEF6);
  static const Color softPurpleDark = Color(0xFFB9AEDD);
  static const Color softPink = Color(0xFFF3AECD);
  static const Color pinkAccent = Color(0xFFF07E9E);
  static const Color pinkStrong = Color(0xFFEC6D91);
  static const Color softBlue = Color(0xFF8FC1E8);
  static const Color softMint = Color(0xFF8FDCC9);
  static const Color softOrange = Color(0xFFF5C77E);
  static const Color softCoral = Color(0xFFF29C93);

  static const List<Color> categoryPalette = [
    softBlue,
    softOrange,
    softPurpleDark,
    softCoral,
    softMint,
  ];

  /// Warna teks/ikon yang aman di atas [bg]: gelap untuk latar terang,
  /// putih untuk latar gelap (dari luminance, bukan dipatok putih).
  static Color onColor(Color bg) =>
      bg.computeLuminance() > 0.5 ? onPastel : Colors.white;
}
