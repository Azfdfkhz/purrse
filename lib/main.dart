import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'screens/splash_screen.dart';
import 'services/auto_backup_service.dart';
import 'services/google_drive_service.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'services/sync_service.dart';
import 'services/storage_service.dart';
import 'screens/settings/backup_restore_page.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sesi Supabase dipulihkan dari penyimpanan lokal (tidak butuh internet).
  await SupabaseService.instance.initialize();

  await GoogleDriveService.instance.initialize();
  // Pulihkan sesi Drive secara senyap (tanpa memilih akun lagi).
  GoogleDriveService.instance.restoreSession();

  AutoBackupService.instance.resumePending();

  await NotificationService.instance.init();
  NotificationService.instance.onTap = _handleNotificationTap;
  NotificationService.instance.rescheduleAll();

  // Push (FCM): aman bila Firebase belum dikonfigurasi (fitur nonaktif).
  await FcmService.instance.init();
  FcmService.instance.onOpen = _handleNotificationTap;

  runApp(FinanceApp());

  // Notifikasi mengetuk saat aplikasi tertutup: tunggu splash selesai, lalu buka layar tujuan.
  Future<String?> launch() async =>
      await NotificationService.instance.launchPayload() ?? await FcmService.instance.launchPayload();
  launch().then((payload) async {
    if (payload == null) return;
    await Future.delayed(Duration(milliseconds: 2600));
    await _handleNotificationTap(payload);
  });
}

/// Ketuk notifikasi: pengingat backup membuka halaman Backup (jika sudah login);
/// lainnya cukup membuka aplikasi di layar terakhir.
Future<void> _handleNotificationTap(String? payload) async {
  if (payload != 'backup') return;
  final user = await StorageService.instance.getCurrentUser();
  if (user == null) return;
  appNavigatorKey.currentState?.push(
    MaterialPageRoute(builder: (_) => BackupRestorePage()),
  );
}

class FinanceApp extends StatefulWidget {
  const FinanceApp({super.key});

  @override
  State<FinanceApp> createState() => _FinanceAppState();
}

/// Membangun ulang seluruh pohon widget (menjaga state & navigasi) agar
/// token warna dinamis dibaca ulang setelah mode tema berubah.
void _rebuildAll(BuildContext context) {
  void rebuild(Element el) {
    el.markNeedsBuild();
    el.visitChildren(rebuild);
  }

  (context as Element).visitChildren(rebuild);
}

class _FinanceAppState extends State<FinanceApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ThemeController.instance.syncPalette();
    ThemeController.instance.load();
    ThemeController.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) SyncService.instance.syncNow();
  }

  @override
  void didChangePlatformBrightness() {
    ThemeController.instance.onPlatformBrightnessChanged();
  }

  void _onThemeChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rebuildAll(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        ThemeController.instance.syncPalette();
        return MaterialApp(
          title: 'PurssApp',
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          theme: AppTheme.build(accent: ThemeController.instance.accentColor),
          home: const SplashScreen(),
        );
      },
    );
  }
}
