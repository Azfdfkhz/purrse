import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

/// Handler pesan saat aplikasi di latar belakang / tertutup. Harus top-level.
/// Pesan bertipe "notification" ditampilkan sendiri oleh sistem; tidak ada
/// yang perlu dilakukan di sini.
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

/// Push notification (FCM), sisi aplikasi. Mengirim pesan butuh backend
/// (lihat docs/FCM_SETUP.md); aplikasi hanya meminta izin, mendaftarkan token
/// perangkat ke Supabase (tabel device_tokens), dan menangani pesan masuk.
///
/// Aman bila Firebase belum dikonfigurasi: init() gagal secara senyap dan
/// seluruh fitur push nonaktif tanpa mengganggu aplikasi.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const _kAsked = 'fcm_permission_asked';

  bool _ready = false;
  bool get isReady => _ready;
  String? _token;

  /// Diisi dari main.dart: dipanggil dengan payload saat notifikasi diketuk.
  void Function(String? payload)? onOpen;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpen?.call(_payloadOf(m)));
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _token = t;
        unawaited(registerToken());
      });
      _ready = true;
    } catch (e) {
      debugPrint('FCM nonaktif (Firebase belum dikonfigurasi): $e');
    }
  }

  static String? _payloadOf(RemoteMessage m) => m.data['payload']?.toString();

  /// Payload dari notifikasi push yang membuka aplikasi dari kondisi tertutup.
  Future<String?> launchPayload() async {
    if (!_ready) return null;
    try {
      final m = await FirebaseMessaging.instance.getInitialMessage();
      return m == null ? null : _payloadOf(m);
    } catch (_) {
      return null;
    }
  }

  /// Di latar depan Android tidak menampilkan notifikasi sendiri: tampilkan lokal.
  void _onForeground(RemoteMessage m) {
    final n = m.notification;
    if (n == null) return;
    NotificationService.instance.showNow(
      title: n.title ?? 'PurssApp',
      body: n.body ?? '',
      payload: _payloadOf(m),
    );
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final s = await FirebaseMessaging.instance.requestPermission();
      return s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// Setelah pengguna masuk: minta izin (sekali) lalu daftarkan token.
  Future<void> onLogin() async {
    if (!_ready) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_kAsked) ?? false)) {
      await prefs.setBool(_kAsked, true);
      if (!await requestPermission()) return;
    }
    await registerToken();
  }

  /// Simpan token perangkat ke Supabase (RPC memindahkan kepemilikan token
  /// bila perangkat dipakai akun lain).
  Future<void> registerToken() async {
    if (!_ready) return;
    final client = SupabaseService.instance.client;
    if (client == null || !SupabaseService.instance.isSignedIn) return;
    try {
      _token ??= await FirebaseMessaging.instance.getToken();
      if (_token == null) return;
      await client.rpc('register_device_token', params: {
        'p_token': _token,
        'p_platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      debugPrint('Gagal mendaftarkan token FCM: $e');
    }
  }

  /// Dipanggil saat logout (sebelum sesi Supabase diakhiri).
  Future<void> unregister() async {
    if (!_ready) return;
    final client = SupabaseService.instance.client;
    try {
      if (_token != null && client != null && SupabaseService.instance.isSignedIn) {
        await client.from('device_tokens').delete().eq('token', _token!);
      }
    } catch (e) {
      debugPrint('Gagal melepas token FCM: $e');
    }
  }
}
