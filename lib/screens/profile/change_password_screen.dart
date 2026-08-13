import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_text_field.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_old.text.isEmpty || _new.text.isEmpty || _confirm.text.isEmpty) {
      setState(() => _error = 'Semua kolom wajib diisi');
      return;
    }
    if (_new.text.length < 6) {
      setState(() => _error = 'Password baru minimal 6 karakter');
      return;
    }
    if (_new.text != _confirm.text) {
      setState(() => _error = 'Konfirmasi password tidak sama');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final user = await StorageService.instance.getCurrentUser();
    if (user == null) return;
    final err = await StorageService.instance.changePassword(
      userId: user.id,
      oldPassword: _old.text,
      newPassword: _new.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password berhasil diubah')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
        ),
        title: const Text('Ubah Password', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(label: 'Password lama', controller: _old, obscureText: true, hint: '********'),
            const SizedBox(height: 18),
            AppTextField(label: 'Password baru', controller: _new, obscureText: true, hint: 'minimal 6 karakter'),
            const SizedBox(height: 18),
            AppTextField(label: 'Konfirmasi password baru', controller: _confirm, obscureText: true, hint: '********'),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan Password', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
