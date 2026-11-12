import 'package:flutter/material.dart';

/// Palet aplikasi Purrse.
///
/// Identitas brand (ungu Purrse, jingga kucing, krem) adalah titik awal.
/// Semua token "tema" (tombol, navbar, kartu utama, latar, garis, dsb.)
/// diturunkan dari satu warna pilihan pengguna ([seed]) yang diatur oleh
/// ThemeController. Jadi warna lain, termasuk Burgundy, hanya muncul bila
/// pengguna memilihnya di Pengaturan > Tampilan.
class AppColors {
  AppColors._();

  // ---- Identitas brand Purrse ----
  static const Color brandPrimary = Color(0xFF6A4FCF);
  static const Color brandAccent = Color(0xFFF79B4B);
  static const Color brandSecondary = Color(0xFFEADFFF);
  static const Color brandBackground = Color(0xFFFFF8F0);
  static const Color brandText = Color(0xFF2E1F3A);

  /// Diatur oleh ThemeController sebelum tema dibangun.
  static bool isDark = false;

  /// Warna pilihan pengguna. Bawaan: ungu Purrse.
  static Color seed = brandPrimary;

  // ---- Turunan warna (di-cache; dihitung ulang saat seed / mode berubah) ----
  static _Tokens? _tokens;
  static int _tokensKey = 0;

  static _Tokens get _t {
    final key = Object.hash(seed.value, isDark);
    if (_tokens == null || key != _tokensKey) {
      _tokens = _Tokens.derive(seed, isDark);
      _tokensKey = key;
    }
    return _tokens!;
  }

  // ---- Token yang mengikuti tema + warna pilihan ----
  static Color get background => _t.background;
  static Color get surface => _t.surface;
  static Color get surfaceVariant => _t.surfaceVariant;
  static Color get border => _t.border;
  static Color get cardBorder => border;

  /// Versi pastel dari warna pilihan (kartu hero, ikon, FAB). Untuk warna
  /// bawaan = Secondary Purrse (#EADFFF).
  static Color get soft => _t.soft;

  /// Garis halus untuk kartu/chip (pengganti outline hitam tebal).
  static Color get hairline => _p(const Color(0x14000000), const Color(0x1FFFFFFF));

  /// Bayangan lembut kartu (hanya di mode terang; di gelap cukup hairline).
  static List<BoxShadow> get softShadow => isDark
      ? const []
      : const [BoxShadow(color: Color(0x0F2E1F3A), blurRadius: 18, offset: Offset(0, 6))];

  /// Pil terpilih pada navbar / tombol tambah. Terang: versi lebih gelap dari
  /// warna pilihan; gelap: versi pastel agar kontras dengan latar.
  static Color get inkInverse => _t.inkInverse;

  /// Warna "tinta": tombol, navbar, kartu utama. Diturunkan dari warna pilihan
  /// dan selalu cukup gelap sehingga teks putih ([onInk]) tetap terbaca.
  static Color get ink => _t.ink;

  /// Teks utama dan teks sekunder (otomatis gelap di terang, terang di gelap).
  static Color get textDark => _p(brandText, const Color(0xFFF3EFF8));
  static Color get textGrey => _p(const Color(0xFF74687F), const Color(0xFFB4ADBF));

  static Color _p(Color light, Color dark) => isDark ? dark : light;

  // ---- Konstanta ----
  static const Color onInk = Colors.white; // teks/ikon di atas ink

  /// Teks/ikon di atas warna pastel (aksen, kategori): selalu gelap.
  static const Color onPastel = brandText;

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

/// Kumpulan token hasil turunan dari satu warna pilihan.
class _Tokens {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color border;
  final Color ink;
  final Color inkInverse;
  final Color soft;

  const _Tokens({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.ink,
    required this.inkInverse,
    required this.soft,
  });

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  /// Warna "tinta": dari seed, digelapkan secukupnya sampai teks putih terbaca.
  static Color _inkFrom(Color seed, bool dark) {
    final hsl = HSLColor.fromColor(seed);
    var l = hsl.lightness;
    if (dark && l < 0.30) l = 0.30; // jangan hilang di latar gelap
    var c = hsl.withLightness(l).toColor();
    var guard = 0;
    while (c.computeLuminance() > 0.20 && l > 0.18 && guard++ < 40) {
      l -= 0.02;
      c = hsl.withLightness(l).toColor();
    }
    return c;
  }

  static _Tokens derive(Color seed, bool dark) {
    final isBrand = seed.value == AppColors.brandPrimary.value;
    final hsl = HSLColor.fromColor(seed);

    final soft = isBrand
        ? AppColors.brandSecondary
        : HSLColor.fromAHSL(1, hsl.hue, hsl.saturation.clamp(0.35, 0.90).toDouble(), 0.90).toColor();

    final ink = _inkFrom(seed, dark);
    final inkHsl = HSLColor.fromColor(ink);

    if (dark) {
      return _Tokens(
        background: _mix(const Color(0xFF111014), seed, 0.07),
        surface: _mix(const Color(0xFF1C1B21), seed, 0.08),
        surfaceVariant: _mix(const Color(0xFF27252D), seed, 0.12),
        border: _mix(const Color(0xFF2F2D36), seed, 0.14),
        ink: ink,
        inkInverse: HSLColor.fromAHSL(1, hsl.hue, hsl.saturation.clamp(0.0, 0.75).toDouble(), 0.88).toColor(),
        soft: soft,
      );
    }

    final bg = isBrand ? AppColors.brandBackground : _mix(AppColors.brandBackground, soft, 0.28);
    return _Tokens(
      background: bg,
      surface: Colors.white,
      surfaceVariant: _mix(bg, soft, 0.60),
      border: _mix(bg, soft, 0.75),
      ink: ink,
      inkInverse: inkHsl.withLightness((inkHsl.lightness - 0.08).clamp(0.10, 1.0).toDouble()).toColor(),
      soft: soft,
    );
  }
}
