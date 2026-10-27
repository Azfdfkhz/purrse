import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui_kit.dart';
import 'register_screen.dart';
import 'login_screen.dart';

class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                height: 260,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Image.asset(
                  'assets/images/Kucingkucing.png',
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Buat akun dan mulai perjalanan keuanganmu.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 30),
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Catat pengeluaranmu dan kelola uangmu dengan lebih mudah.',
                  style: TextStyle(fontSize: 16, color: AppColors.textGrey, height: 1.4),
                ),
              ),
              const Spacer(),
              const SizedBox(height: 32),
              InkButton(
                label: 'Mulai Sekarang',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Sudah memiliki akun? ', style: TextStyle(color: AppColors.textDark)),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: Text(
                      'Masuk',
                      style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
