import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth_scaffold.dart';
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
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: IntrinsicHeight(
          child: Column(
            children: [
              SizedBox(height: 32),
              Container(
                height: 240,
                width: double.infinity,
                alignment: Alignment.center,
                padding: EdgeInsets.all(16),
                child: Image.asset(
                  'assets/images/Kucingkucing.png',
                  semanticLabel: 'Ilustrasi kucing PurssApp',
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
              SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Catat pengeluaranmu dan kelola uangmu dengan lebih mudah.',
                  style: TextStyle(fontSize: 16, color: AppColors.textGrey, height: 1.4),
                ),
              ),
              Spacer(),
              SizedBox(height: 32),
              InkButton(
                label: 'Mulai Sekarang',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RegisterScreen()),
                ),
              ),
              SizedBox(height: 16),
              AuthFooterLink(
                prompt: 'Sudah memiliki akun?',
                action: 'Masuk',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LoginScreen())),
              ),
              SizedBox(height: 32),
            ],
          ),
          ),
          ),
          ),
        ),
      ),
    );
  }
}
