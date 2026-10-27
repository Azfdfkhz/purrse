import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../auth/auth_choice_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await StorageService.instance.getCurrentUser();
    setState(() => _user = user);
  }

  Future<void> _logout() async {
    await StorageService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AuthChoiceScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                CircleAvatar(radius: 44, backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.35), child: Icon(Icons.person, size: 40, color: Colors.white)),
                SizedBox(height: 12),
                Text(_user!.username, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(_user!.email, style: TextStyle(color: AppColors.textGrey)),
              ],
            ),
          ),
          Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _logout,
              child: Text('Keluar', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
