import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'screens/splash_screen.dart';
import 'services/google_drive_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GoogleDriveService.instance.initialize();

  runApp(const FinanceApp());
}

class FinanceApp extends StatefulWidget {
  const FinanceApp({super.key});

  @override
  State<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends State<FinanceApp> {
  @override
  void initState() {
    super.initState();
    ThemeController.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Kukukuk',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(accent: ThemeController.instance.accentColor),
          home: const SplashScreen(),
        );
      },
    );
  }
}
