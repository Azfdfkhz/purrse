import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';
import 'app_colors.dart';

enum AppThemeMode { system, light, dark }

/// Mengatur warna aksen dan mode tema (Sistem/Terang/Gelap). Keduanya
/// disimpan lokal. [AppColors.isDark] selalu disinkronkan di sini sebelum
/// listener (MaterialApp) membangun ulang tema.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _kMode = 'theme_mode';

  Color accentColor = AppColors.softPurple;
  AppThemeMode mode = AppThemeMode.system;

  bool get isDark => switch (mode) {
        AppThemeMode.dark => true,
        AppThemeMode.light => false,
        AppThemeMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
      };

  /// Sinkronkan flag palet dengan mode saat ini (tanpa notifikasi).
  void syncPalette() => AppColors.isDark = isDark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final m = prefs.getString(_kMode);
    mode = AppThemeMode.values.firstWhere(
      (e) => e.name == m,
      orElse: () => AppThemeMode.system,
    );
    final saved = await StorageService.instance.getAccentColor();
    if (saved != null) accentColor = Color(saved);
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

  Future<void> setAccent(Color color) async {
    accentColor = color;
    notifyListeners();
    await StorageService.instance.setAccentColor(color.value);
  }

  static const List<_AccentOption> presets = [
    _AccentOption('Ungu Lembut', AppColors.softPurple),
    _AccentOption('Pink Lembut', Color(0xFFF6D9E6)),
    _AccentOption('Biru Lembut', Color(0xFFDCEBF8)),
    _AccentOption('Mint Lembut', Color(0xFFDBF3EC)),
    _AccentOption('Peach Lembut', Color(0xFFFBE6D4)),
    _AccentOption('Kuning Lembut', Color(0xFFFBF1D2)),
    _AccentOption('Lavender Abu', Color(0xFFE7E4F0)),
    _AccentOption('Coral Lembut', Color(0xFFFAE1DE)),
  ];
}

class _AccentOption {
  final String name;
  final Color color;
  const _AccentOption(this.name, this.color);
}
