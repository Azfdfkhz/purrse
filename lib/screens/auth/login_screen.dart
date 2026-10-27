import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/ui_kit.dart';
import '../shell/navbar_shell.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Email dan password wajib diisi');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await AuthService.instance.login(email: _email.text, password: _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!res.ok) {
      setState(() => _error = res.error ?? res.info);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => NavbarShell()), (route) => false);
    if (res.notice != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(res.notice!), duration: Duration(seconds: 8)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Selamat Datang',
      subtitle: 'Masuk untuk melanjutkan',
      footer: AuthFooterLink(
        prompt: 'Belum memiliki akun?',
        action: 'Daftar',
        onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RegisterScreen())),
      ),
      children: [
        AppTextField(
          label: 'Email',
          controller: _email,
          hint: 'contoh@email.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: [AutofillHints.email],
          onSubmitted: (_) => _passwordFocus.requestFocus(),
          enabled: !_loading,
        ),
        SizedBox(height: 18),
        AppTextField(
          label: 'Password',
          controller: _password,
          focusNode: _passwordFocus,
          hint: 'Masukkan password',
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          autofillHints: [AutofillHints.password],
          onSubmitted: (_) => _submit(),
          enabled: !_loading,
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
            icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _loading
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ForgotPasswordScreen())),
            child: Text('Lupa password?'),
          ),
        ),
        if (_error != null) ...[
          SizedBox(height: 4),
          StatusBanner(_error!),
        ],
        SizedBox(height: 20),
        InkButton(label: 'Masuk', loading: _loading, onPressed: _submit),
      ],
    );
  }
}
