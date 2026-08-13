import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'app_colors.dart';

/// Mengatur warna aksen aplikasi (dipakai di card Beranda, tombol tambah,
/// dan ikon navbar yang aktif) supaya bisa diganti sesuai selera user lewat
/// halaman Tampilan, lalu disimpan lokal di memori HP.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  Color accentColor = AppColors.softPurple;

  Future<void> load() async {
    final saved = await StorageService.instance.getAccentColor();
    if (saved != null) {
      accentColor = Color(saved);
      notifyListeners();
    }
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
