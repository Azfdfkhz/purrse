import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
import '../widgets/purrse_logo.dart';
import 'auth/auth_choice_screen.dart';
import 'shell/navbar_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Beri waktu animasi masuk logo (kucing memantul + tulisan meluncur).
    await Future.delayed(Duration(milliseconds: 2100));
    await ThemeController.instance.load();
    UserModel? user;
    try {
      user = await StorageService.instance
          .getCurrentUser()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      user = null; // Timeout atau error → arahkan ke layar masuk
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => user != null ? NavbarShell() : AuthChoiceScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PurrseLogo(markSize: 96, axis: Axis.vertical),
            SizedBox(height: 28),
            PurrseDots(size: 9),
          ],
        ),
      ),
    );
  }
}
