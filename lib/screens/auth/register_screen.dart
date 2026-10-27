import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
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
    if (_loading) return;
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
        _isInfo = res.error == null;
      });
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => NavbarShell()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Buat Akun',
      subtitle: 'Daftar untuk mulai mengatur keuanganmu',
      footer: AuthFooterLink(
        prompt: 'Sudah memiliki akun?',
        action: 'Masuk',
        onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen())),
      ),
      children: [
        AppTextField(
          label: 'Username',
          controller: _username,
          hint: 'Nama kamu',
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          autofillHints: [AutofillHints.nickname],
          onSubmitted: (_) => _emailFocus.requestFocus(),
          enabled: !_loading,
        ),
        SizedBox(height: 18),
        AppTextField(
          label: 'Email',
          controller: _email,
          focusNode: _emailFocus,
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
          hint: 'Minimal 6 karakter',
          helperText: 'Minimal 6 karakter',
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          autofillHints: [AutofillHints.newPassword],
          onSubmitted: (_) => _submit(),
          enabled: !_loading,
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
            icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        if (_message != null) ...[
          SizedBox(height: 16),
          StatusBanner(_message!, kind: _isInfo ? BannerKind.info : BannerKind.error),
        ],
        SizedBox(height: 24),
        InkButton(label: 'Daftar', loading: _loading, onPressed: _submit),
      ],
    );
  }
}
