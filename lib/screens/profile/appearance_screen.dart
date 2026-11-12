import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/ui_kit.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late Color _selected = ThemeController.instance.seedColor;

  Future<void> _apply(Color color) async {
    setState(() => _selected = color);
    await ThemeController.instance.setAccent(color);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
        ),
        title: Text('Tampilan', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w800)),
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mode tampilan',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark)),
            SizedBox(height: 10),
            SegmentedButton<AppThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: AppThemeMode.system, label: Text('Sistem'), icon: Icon(Icons.brightness_auto_rounded)),
                ButtonSegment(value: AppThemeMode.light, label: Text('Terang'), icon: Icon(Icons.light_mode_rounded)),
                ButtonSegment(value: AppThemeMode.dark, label: Text('Gelap'), icon: Icon(Icons.dark_mode_rounded)),
              ],
              selected: {ThemeController.instance.mode},
              onSelectionChanged: (v) async {
                await ThemeController.instance.setMode(v.first);
                if (mounted) setState(() {});
              },
            ),
            SizedBox(height: 22),
            Text('Warna tema',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark)),
            SizedBox(height: 8),
            Text(
              'Semua warna aplikasi (tombol, navbar, kartu, latar, dan garis) mengikuti warna yang kamu pilih. Warna bawaan Purrse adalah ungu; warna lain seperti Burgundy hanya dipakai kalau kamu memilihnya.',
              style: TextStyle(color: AppColors.textGrey),
            ),
            SizedBox(height: 14),
            InkCard(
              bold: false,
              child: Row(
                children: [
                  Expanded(
                    child: InkButton(label: 'Contoh tombol', onPressed: () {}, expand: true),
                  ),
                  SizedBox(width: 12),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(color: AppColors.soft, shape: BoxShape.circle),
                    child: Icon(Icons.pets_rounded, color: AppColors.onColor(AppColors.soft)),
                  ),
                ],
              ),
            ),
            SizedBox(height: 18),
            Expanded(
              child: GridView.builder(
                itemCount: ThemeController.presets.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 18,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (context, i) {
                  final option = ThemeController.presets[i];
                  final isSelected = option.color.value == _selected.value;
                  return GestureDetector(
                    onTap: () => _apply(option.color),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: option.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.textDark : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: isSelected
                              ? Icon(Icons.check_rounded, color: AppColors.onColor(option.color))
                              : null,
                        ),
                        SizedBox(height: 8),
                        Text(
                          option.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
