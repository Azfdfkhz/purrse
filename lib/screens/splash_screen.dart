import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
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
    await Future.delayed(Duration(milliseconds: 1400));
    await ThemeController.instance.load();
    final user = await StorageService.instance.getCurrentUser();
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
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1),
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : Duration(milliseconds: 700),
          curve: Curves.easeOutBack,
          builder: (_, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(scale: t, child: child),
          ),
          child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: ThemeController.instance.accentColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Image.asset(
            'assets/images/favicon.png',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
          ),
        ),
        ),
    );
  }
}
