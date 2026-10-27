import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late Color _selected = ThemeController.instance.accentColor;

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
            Text('Warna aksen',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark)),
            SizedBox(height: 8),
            Text(
              'Pilih warna utama aplikasi. Warna ini akan menyesuaikan tombol, navbar, kartu utama, indikator, dan elemen UI lainnya.',
              style: TextStyle(color: AppColors.textGrey),
            ),
            SizedBox(height: 20),
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
                              ? Icon(Icons.check_rounded, color: AppColors.onPastel)
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
