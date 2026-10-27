import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/google_sign_in_button.dart';
import '../../widgets/ui_kit.dart';
import '../shell/navbar_shell.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;
  String? _message;
  bool _isInfo = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || _googleLoading) return;
    if (_username.text.trim().isEmpty || _email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() {
        _message = 'Semua kolom wajib diisi';
        _isInfo = false;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _message = null;
    });
    final res = await AuthService.instance.register(
      username: _username.text.trim(),
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!res.ok) {
      setState(() {
        _message = res.error ?? res.info;
        _isInfo = res.info != null;
      });
      return;
    }
    AuthService.instance.afterLogin();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const NavbarShell()),
      (route) => false,
    );
  }

  Future<void> _submitGoogle() async {
    if (_loading || _googleLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _googleLoading = true;
      _message = null;
    });
    final res = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _googleLoading = false);

    if (res.error != null) {
      setState(() {
        _message = res.error;
        _isInfo = false;
      });
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
    return AuthScaffold(
      title: 'Buat Akun Baru',
      subtitle: 'Daftar untuk mulai mengelola keuangan',
      footer: AuthFooterLink(
        prompt: 'Sudah memiliki akun?',
        action: 'Masuk',
        onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())),
      ),
      children: [
        AppTextField(
          label: 'Username',
          controller: _username,
          hint: 'Masukkan nama pengguna',
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username],
          onSubmitted: (_) => _emailFocus.requestFocus(),
          enabled: !_loading && !_googleLoading,
        ),
        const SizedBox(height: 18),
        AppTextField(
          label: 'Email',
          controller: _email,
          focusNode: _emailFocus,
          hint: 'contoh@email.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _passwordFocus.requestFocus(),
          enabled: !_loading && !_googleLoading,
        ),
        const SizedBox(height: 18),
        AppTextField(
          label: 'Password',
          controller: _password,
          focusNode: _passwordFocus,
          hint: 'Minimal 6 karakter',
          helperText: 'Minimal 6 karakter',
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _submit(),
          enabled: !_loading && !_googleLoading,
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
            icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 16),
          StatusBanner(_message!, kind: _isInfo ? BannerKind.info : BannerKind.error),
        ],
        const SizedBox(height: 24),
        InkButton(label: 'Daftar', loading: _loading, onPressed: _googleLoading ? null : _submit),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.border, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'atau',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Divider(color: AppColors.border, thickness: 1)),
          ],
        ),
        const SizedBox(height: 18),
        GoogleSignInButton(
          label: 'Daftar dengan Google',
          isLoading: _googleLoading,
          onPressed: _loading ? null : _submitGoogle,
        ),
      ],
    );
  }
}
