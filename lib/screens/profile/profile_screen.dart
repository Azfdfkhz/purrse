import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/auto_backup_service.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../auth/auth_choice_screen.dart';
import '../settings/backup_restore_page.dart';
import 'appearance_screen.dart';
import 'category_management_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  bool _linked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await StorageService.instance.getCurrentUser();
    final linked = user == null ? false : await AuthService.instance.isCloudLinked(user.id);
    if (!mounted) return;
    setState(() {
      _user = user;
      _linked = linked;
    });
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

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    _load();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Keluar dari akun?'),
        content: Text(_linked
            ? 'Datamu tetap aman di cloud. Masuk kembali untuk melanjutkan di perangkat ini.'
            : 'Kamu perlu masuk kembali untuk mengakses data pengeluaranmu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Keluar', style: TextStyle(color: AppColors.isDark ? Color(0xFFFF8A80) : AppColors.danger, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    // Kirim perubahan terakhir sebelum sesi cloud diakhiri.
    if (_linked) await SyncService.instance.syncNow();
    await NotificationService.instance.cancelAll();
    AutoBackupService.instance.cancel();
    await StorageService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AuthChoiceScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Center(child: CircularProgressIndicator());
    }
    final user = _user!;

    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final accent = ThemeController.instance.accentColor;
        final iconBg = accent;
        final iconFg = AppColors.onColor(accent);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 120),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(4, 8, 4, 16),
                    child: Semantics(
                      header: true,
                      child: Text('Akun', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: AppColors.textDark)),
                    ),
                  ),
                  _AccountCard(
                    user: user,
                    accent: accent,
                    linked: _linked,
                    onPhotoTap: _quickChangePhoto,
                    onEdit: _goEditProfile,
                  ),
                  SizedBox(height: 24),
                  _SectionLabel('Preferensi'),
                  _MenuGroup(children: [
                    _MenuRow(icon: Icons.palette_rounded, iconBg: iconBg, iconFg: iconFg, title: 'Tampilan', subtitle: 'Warna dan mode terang/gelap', onTap: () => _push(AppearanceScreen())),
                    _MenuRow(icon: Icons.notifications_active_rounded, iconBg: iconBg, iconFg: iconFg, title: 'Notifikasi', subtitle: 'Pengingat catat, tinjau, dan backup', onTap: () => _push(NotificationSettingsScreen())),
                    _MenuRow(icon: Icons.bookmark_rounded, iconBg: iconBg, iconFg: iconFg, title: 'Kategori pengeluaran', subtitle: 'Tambah, ubah, atau hapus kategori', onTap: () => _push(CategoryManagementScreen())),
                  ]),
                  SizedBox(height: 24),
                  _SectionLabel('Data'),
                  _MenuGroup(children: [
                    _SyncRow(iconBg: iconBg, iconFg: iconFg, linked: _linked),
                    _MenuRow(icon: Icons.cloud_sync_rounded, iconBg: iconBg, iconFg: iconFg, title: 'Backup & Restore', subtitle: 'Simpan dan pulihkan lewat Google Drive', onTap: () => _push(BackupRestorePage())),
                  ]),
                  SizedBox(height: 24),
                  _SectionLabel('Keamanan'),
                  _MenuGroup(children: [
                    _MenuRow(icon: Icons.lock_rounded, iconBg: iconBg, iconFg: iconFg, title: 'Ubah password', subtitle: _linked ? 'Berlaku di semua perangkat' : 'Ubah password akun', onTap: () => _push(ChangePasswordScreen())),
                  ]),
                  SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.isDark ? Color(0xFFFF8A80) : AppColors.danger,
                        side: BorderSide(color: AppColors.isDark ? Color(0xFFFF8A80) : AppColors.danger, width: 1.5),
                        minimumSize: Size(48, 52),
                      ),
                      icon: Icon(Icons.logout_rounded),
                      label: Text('Keluar', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.4, color: AppColors.textGrey),
        ),
      ),
    );
  }
}

/// Kartu identitas: foto, nama, email, status cloud, dan tombol edit.
class _AccountCard extends StatelessWidget {
  final UserModel user;
  final Color accent;
  final bool linked;
  final VoidCallback onPhotoTap;
  final VoidCallback onEdit;

  const _AccountCard({
    required this.user,
    required this.accent,
    required this.linked,
    required this.onPhotoTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = user.avatarPath != null && user.avatarPath!.isNotEmpty && File(user.avatarPath!).existsSync();
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Ganti foto profil',
                child: GestureDetector(
                  onTap: onPhotoTap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: accent,
                        backgroundImage: hasAvatar ? FileImage(File(user.avatarPath!)) : null,
                        child: hasAvatar ? null : Icon(Icons.person_rounded, size: 38, color: AppColors.onColor(accent)),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surface, width: 2),
                          ),
                          child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.textDark),
                    ),
                    SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textGrey, fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(linked ? Icons.cloud_done_rounded : Icons.phone_android_rounded, size: 16, color: AppColors.textGrey),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            linked ? 'Terhubung ke cloud' : 'Hanya di perangkat ini',
                            style: TextStyle(color: AppColors.textGrey, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: Icon(Icons.edit_rounded, size: 18),
              label: Text('Edit profil', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Beberapa baris menu dalam satu kartu, dipisah garis tipis.
class _MenuGroup extends StatelessWidget {
  final List<Widget> children;
  const _MenuGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(Divider(height: 1, indent: 72, color: AppColors.cardBorder));
      items.add(children[i]);
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Material(color: Colors.transparent, child: Column(children: items)),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _MenuRow({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 64),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconFg, size: 21),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark)),
                    SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12.5, color: AppColors.textGrey, height: 1.25)),
                  ],
                ),
              ),
              trailing ?? (onTap != null ? Icon(Icons.chevron_right_rounded, color: AppColors.textGrey) : SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status sinkronisasi cloud + tombol "Sinkronkan sekarang".
class _SyncRow extends StatelessWidget {
  final Color iconBg;
  final Color iconFg;
  final bool linked;
  const _SyncRow({required this.iconBg, required this.iconFg, required this.linked});

  String _label(SyncService s) {
    if (!linked || !SupabaseService.instance.isSignedIn) {
      return 'Belum aktif. Masuk dengan akun cloud untuk menyinkronkan antar perangkat.';
    }
    switch (s.status) {
      case SyncStatus.syncing:
        return 'Menyinkronkan…';
      case SyncStatus.offline:
        return 'Offline. Akan dicoba lagi otomatis.';
      case SyncStatus.error:
        return 'Gagal menyinkronkan. Ketuk untuk coba lagi.';
      case SyncStatus.notLinked:
        return 'Akun belum terhubung ke cloud.';
      case SyncStatus.idle:
        final t = s.lastSyncedAt;
        if (t == null) return 'Siap. Ketuk untuk sinkronkan sekarang.';
        final hh = t.hour.toString().padLeft(2, '0');
        final mm = t.minute.toString().padLeft(2, '0');
        return 'Terakhir sinkron $hh:$mm. Ketuk untuk sinkronkan.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SyncService.instance,
      builder: (context, _) {
        final s = SyncService.instance;
        final active = linked && SupabaseService.instance.isSignedIn;
        return _MenuRow(
          icon: Icons.sync_rounded,
          iconBg: iconBg,
          iconFg: iconFg,
          title: 'Sinkronisasi cloud',
          subtitle: _label(s),
          onTap: active && s.status != SyncStatus.syncing ? () => s.syncNow() : null,
          trailing: s.status == SyncStatus.syncing && active
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
              : null,
        );
      },
    );
  }
}
