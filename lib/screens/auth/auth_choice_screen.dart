import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/google_sign_in_button.dart';
import '../../widgets/ui_kit.dart';
import '../shell/navbar_shell.dart';
import 'register_screen.dart';
import 'login_screen.dart';

class AuthChoiceScreen extends StatefulWidget {
  const AuthChoiceScreen({super.key});

  @override
  State<AuthChoiceScreen> createState() => _AuthChoiceScreenState();
}

class _AuthChoiceScreenState extends State<AuthChoiceScreen> {
  bool _loading = false;

  Future<void> _loginGoogle() async {
    if (_loading) return;
    setState(() => _loading = true);
    final res = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);

    if (res.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error!)),
      );
      return;
    }

    if (res.ok) {
      AuthService.instance.afterLogin();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const NavbarShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    Container(
                      height: 240,
                      width: double.infinity,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(16),
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
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontSize: 30),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Catat pengeluaranmu dan kelola uangmu dengan lebih mudah.',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textGrey,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 32),
                    GoogleSignInButton(
                      label: 'Lanjut dengan Google',
                      isLoading: _loading,
                      onPressed: _loginGoogle,
                    ),
                    const SizedBox(height: 12),
                    InkButton(
                      label: 'Mulai dengan Email',
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const RegisterScreen()),
                              ),
                    ),
                    const SizedBox(height: 16),
                    AuthFooterLink(
                      prompt: 'Sudah memiliki akun?',
                      action: 'Masuk',
                      onTap: () {
                        if (_loading) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
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
