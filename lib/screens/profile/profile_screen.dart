import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../auth/auth_choice_screen.dart';
import 'appearance_screen.dart';
import 'category_management_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import '../settings/backup_restore_page.dart';

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
    if (!mounted) return;
    setState(() => _user = user);
  }

  Future<void> _quickChangePhoto() async {
    if (_user == null) return;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (file == null) return;
      await StorageService.instance.updateProfile(userId: _user!.id, avatarPath: file.path);
      await _load();
    } catch (_) {}
  }

  Future<void> _goEditProfile() async {
    if (_user == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user!)),
    );
    if (changed == true) _load();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar dari akun?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Kamu perlu masuk kembali untuk mengakses data pengeluaranmu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await StorageService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthChoiceScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
    }

    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final themeColor = ThemeController.instance.accentColor;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              _Header(
                user: _user!,
                themeColor: themeColor,
                onCameraTap: _quickChangePhoto,
              ),
              const SizedBox(height: 14),
              Text(
                _user!.username,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              Text(
                '@${_usernameHandle(_user!.username)}',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _goEditProfile,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textDark,
                  side: BorderSide(color: themeColor, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                icon: Icon(Icons.edit_note_rounded, size: 20, color: themeColor),
                label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.palette_rounded,
                      iconBg: themeColor.withOpacity(0.2),
                      iconColor: AppColors.textDark,
                      title: 'Tampilan',
                      subtitle: 'Atur warna dan tampilan aplikasi',
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AppearanceScreen()),
                        );
                        _load();
                      },
                    ),
                    const SizedBox(height: 14),
                    _MenuTile(
                      icon: Icons.bookmark_rounded,
                      iconBg: themeColor.withOpacity(0.2),
                      iconColor: AppColors.textDark,
                      title: 'Kategori Pengeluaran',
                      subtitle: 'Kelola kategori pengeluaran',
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
                        );
                        _load();
                      },
                    ),
                    const SizedBox(height: 14),

                    _MenuTile(
                      icon: Icons.cloud_sync_rounded,
                      iconBg: themeColor.withOpacity(0.2),
                      iconColor: AppColors.textDark,
                      title: 'Backup & Restore',
                      subtitle: 'Simpan dan pulihkan data dengan Google Drive',
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BackupRestorePage(),
                          ),
                        );
                        _load();
                      },
                    ),
                    const SizedBox(height: 14),
                    _MenuTile(
                      icon: Icons.lock_rounded,
                      iconBg: const Color(0xFFD9F3E7),
                      iconColor: const Color(0xFF2E7D32),
                      title: 'Keamanan',
                      subtitle: 'Ubah password akun',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Divider(color: AppColors.cardBorder),
                    const SizedBox(height: 4),
                    _MenuTile(
                      icon: Icons.logout_rounded,
                      iconBg: const Color(0xFFFBDDD4),
                      iconColor: const Color(0xFFE0573F),
                      title: 'Keluar',
                      subtitle: 'Logout dari akun ini',
                      onTap: _logout,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _usernameHandle(String username) {
    return username.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }
}

class _Header extends StatelessWidget {
  final UserModel user;
  final Color themeColor;
  final VoidCallback onCameraTap;

  const _Header({
    required this.user,
    required this.themeColor,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          height: 230,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeColor.withOpacity(0.85),
                themeColor.withOpacity(0.35),
              ],
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(46)),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 40,
                left: 24,
                child: Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white.withOpacity(0.8)),
              ),
              Positioned(
                top: 90,
                right: 70,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), shape: BoxShape.circle),
                ),
              ),
              Positioned(
                top: 60,
                right: 28,
                child: Icon(Icons.favorite_rounded, size: 12, color: Colors.white.withOpacity(0.8)),
              ),
              Positioned(
                top: 18,
                right: 20,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none_rounded, color: AppColors.textDark, size: 26),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppColors.textDark, shape: BoxShape.circle),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 130,
          child: GestureDetector(
            onTap: onCameraTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: themeColor.withOpacity(0.3),
                    backgroundImage: (user.avatarPath != null && user.avatarPath!.isNotEmpty)
                        ? FileImage(File(user.avatarPath!))
                        : null,
                    child: (user.avatarPath == null || user.avatarPath!.isEmpty)
                        ? const Icon(Icons.person, size: 54, color: AppColors.textDark)
                        : null,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6),
                      ],
                    ),
                    child: Icon(Icons.camera_alt_rounded, color: themeColor, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}