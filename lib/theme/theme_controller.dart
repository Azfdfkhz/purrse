import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';
import 'app_colors.dart';

enum AppThemeMode { system, light, dark }

/// Mengatur warna pilihan dan mode tema (Sistem/Terang/Gelap). Keduanya
/// disimpan lokal. [AppColors.isDark] dan [AppColors.seed] selalu
/// disinkronkan di sini sebelum listener (MaterialApp) membangun ulang tema.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _kMode = 'theme_mode';

  /// Warna pilihan pengguna. Semua warna UI diturunkan dari sini.
  Color seedColor = AppColors.brandPrimary;
  AppThemeMode mode = AppThemeMode.system;

  /// Versi pastel dari warna pilihan (dipakai kartu hero, ikon, FAB).
  /// Nama dipertahankan agar layar lama tetap valid.
  Color get accentColor => AppColors.soft;

  bool get isDark => switch (mode) {
        AppThemeMode.dark => true,
        AppThemeMode.light => false,
        AppThemeMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
      };

  /// Sinkronkan flag palet dengan mode & warna saat ini (tanpa notifikasi).
  void syncPalette() {
    AppColors.isDark = isDark;
    AppColors.seed = seedColor;
  }

  /// Warna pastel lama (sebelum identitas Purrse) -> padanannya sekarang.
  /// Pengguna lama dan backup lama tetap mendapat warna dengan rona serupa.
  static const Map<int, Color> _legacy = {
    0xFFE3DEF6: AppColors.brandPrimary,
    0xFFF6D9E6: Color(0xFFD9578A),
    0xFFDCEBF8: Color(0xFF3B82C4),
    0xFFDBF3EC: Color(0xFF2E9E85),
    0xFFFBE6D4: Color(0xFFF79B4B),
    0xFFFBF1D2: Color(0xFFD39B1E),
    0xFFE7E4F0: Color(0xFF7C7694),
    0xFFFAE1DE: Color(0xFFE06B5E),
  };

  static Color _migrate(Color c) => _legacy[c.value] ?? c;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final m = prefs.getString(_kMode);
    mode = AppThemeMode.values.firstWhere(
      (e) => e.name == m,
      orElse: () => AppThemeMode.system,
    );
    final saved = await StorageService.instance.getAccentColor();
    seedColor = saved != null ? _migrate(Color(saved)) : AppColors.brandPrimary;
    syncPalette();
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode value) async {
    mode = value;
    syncPalette();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMode, value.name);
  }

  /// Dipanggil saat tema sistem berubah (hanya berpengaruh pada mode Sistem).
  void onPlatformBrightnessChanged() {
    if (mode != AppThemeMode.system) return;
    syncPalette();
    notifyListeners();
  }

  /// Simpan warna pilihan. Nama [setAccent] dipertahankan (dipakai juga oleh
  /// restore backup).
  Future<void> setAccent(Color color) async {
    seedColor = _migrate(color);
    syncPalette();
    notifyListeners();
    await StorageService.instance.setAccentColor(seedColor.value);
  }

  /// Pilihan warna. Warna pertama = bawaan Purrse. Burgundy hanya aktif bila
  /// pengguna memilihnya sendiri.
  static const List<AccentOption> presets = [
    AccentOption('Ungu Purrse', AppColors.brandPrimary),
    AccentOption('Burgundy', Color(0xFF98677F)),
    AccentOption('Jingga Kucing', AppColors.brandAccent),
    AccentOption('Pink Permen', Color(0xFFD9578A)),
    AccentOption('Biru Langit', Color(0xFF3B82C4)),
    AccentOption('Mint Segar', Color(0xFF2E9E85)),
    AccentOption('Kuning Madu', Color(0xFFD39B1E)),
    AccentOption('Coral', Color(0xFFE06B5E)),
    AccentOption('Abu Lavender', Color(0xFF7C7694)),
  ];
}

class AccentOption {
  final String name;
  final Color color;
  const AccentOption(this.name, this.color);
}
