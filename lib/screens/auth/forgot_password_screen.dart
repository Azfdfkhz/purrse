import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _message;
  bool _isError = false;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _message = 'Email wajib diisi';
        _isError = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    final err = await SupabaseService.instance.sendPasswordResetEmail(email);

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (err != null) {
        _message = err;
        _isError = true;
      } else {
        _message = 'Link reset password telah dikirim ke email $email. Silakan periksa kotak masuk/spam email Anda.';
        _isError = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.arrow_back_ios_new_rounded),
              ),
              SizedBox(height: 8),
              Text(
                'Lupa Password',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 6),
              Text(
                'Masukkan email yang terdaftar untuk menerima instruksi reset password.',
                style: TextStyle(color: AppColors.textGrey, fontSize: 14),
              ),
              SizedBox(height: 28),
              AppTextField(
                label: 'Email',
                controller: _emailController,
                hint: 'contoh@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
              if (_message != null) ...[
                SizedBox(height: 14),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isError ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isError ? Colors.red : Colors.green,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                        color: _isError ? Colors.red : Colors.green,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: _isError ? Colors.red.shade800 : Colors.green.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Kirim Link Reset Password',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
