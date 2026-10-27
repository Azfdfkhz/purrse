import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Pengaturan satu kategori pengingat.
class ReminderPref {
  final bool enabled;
  final int hour;
  final int minute;
  const ReminderPref({required this.enabled, required this.hour, required this.minute});

  ReminderPref copyWith({bool? enabled, int? hour, int? minute}) => ReminderPref(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );
}

enum ReminderKind { daily, weekly, backup }

/// Notifikasi LOKAL terjadwal (tanpa server). Isi notifikasi sengaja tidak
/// memuat nominal atau detail keuangan agar aman tampil di lock-screen.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Dipanggil saat notifikasi diketuk; diisi dari main.dart.
  void Function(String? payload)? onTap;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _ids = {
    ReminderKind.daily: 1001,
    ReminderKind.weekly: 1002,
    ReminderKind.backup: 1003,
  };

  static const _defaults = {
    ReminderKind.daily: ReminderPref(enabled: false, hour: 20, minute: 0),
    ReminderKind.weekly: ReminderPref(enabled: false, hour: 19, minute: 0),
    ReminderKind.backup: ReminderPref(enabled: false, hour: 9, minute: 0),
  };

  static String title(ReminderKind k) => switch (k) {
        ReminderKind.daily => 'Pengingat catat transaksi',
        ReminderKind.weekly => 'Pengingat tinjau pengeluaran',
        ReminderKind.backup => 'Pengingat backup data',
      };

  static String description(ReminderKind k) => switch (k) {
        ReminderKind.daily => 'Setiap hari, supaya pengeluaran tidak terlewat dicatat.',
        ReminderKind.weekly => 'Setiap Minggu, untuk meninjau pengeluaran minggu ini.',
        ReminderKind.backup => 'Setiap Senin, untuk mengingatkan mengecek backup.',
      };

  static String _body(ReminderKind k) => switch (k) {
        ReminderKind.daily => 'Sudah mencatat transaksi hari ini?',
        ReminderKind.weekly => 'Yuk tinjau pengeluaranmu minggu ini.',
        ReminderKind.backup => 'Cek backup datamu agar tetap aman.',
      };

  static String _payload(ReminderKind k) => switch (k) {
        ReminderKind.backup => 'backup',
        _ => 'home',
      };

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        // Zona waktu tidak terbaca: pakai UTC bawaan paket timezone.
      }
      android = AndroidInitializationSettings('@mipmap/ic_launcher');
      ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifikasi gagal diinisialisasi: $e');
    }
  }

  /// Payload notifikasi yang membuka aplikasi dari kondisi tertutup.
  Future<String?> launchPayload() async {
    if (!_ready) return null;
    final d = await _plugin.getNotificationAppLaunchDetails();
    return (d?.didNotificationLaunchApp ?? false) ? d?.notificationResponse?.payload : null;
  }

  /// Meminta izin. Mengembalikan true jika diberikan.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      if (Platform.isAndroid) {
        final a = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await a?.requestNotificationsPermission() ?? false;
      }
      if (Platform.isIOS) {
        final i = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        return await i?.requestPermissions(alert: true, badge: false, sound: true) ?? false;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> hasPermission() async {
    if (!_ready) return false;
    try {
      if (Platform.isAndroid) {
        final a = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await a?.areNotificationsEnabled() ?? false;
      }
      if (Platform.isIOS) {
        final i = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final p = await i?.checkPermissions();
        return p?.isEnabled ?? false;
      }
    } catch (_) {}
    return false;
  }

  // ---------- Preferensi ----------

  Future<ReminderPref> getPref(ReminderKind k) async {
    final p = await SharedPreferences.getInstance();
    final d = _defaults[k]!;
    return ReminderPref(
      enabled: p.getBool('notif_${k.name}_on') ?? d.enabled,
      hour: p.getInt('notif_${k.name}_h') ?? d.hour,
      minute: p.getInt('notif_${k.name}_m') ?? d.minute,
    );
  }

  Future<void> savePref(ReminderKind k, ReminderPref pref) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('notif_${k.name}_on', pref.enabled);
    await p.setInt('notif_${k.name}_h', pref.hour);
    await p.setInt('notif_${k.name}_m', pref.minute);
    await _apply(k, pref);
  }

  /// Jadwalkan ulang semua sesuai preferensi tersimpan (panggil saat app start).
  Future<void> rescheduleAll() async {
    if (!_ready) return;
    for (final k in ReminderKind.values) {
      await _apply(k, await getPref(k));
    }
  }

  /// Batalkan semua jadwal (dipakai saat logout).
  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  Future<void> _apply(ReminderKind k, ReminderPref pref) async {
    if (!_ready) return;
    final id = _ids[k]!;
    try {
      await _plugin.cancel(id);
      if (!pref.enabled) return;
      if (!await hasPermission()) return;
      await _plugin.zonedSchedule(
        id,
        title(k),
        _body(k),
        _next(k, pref),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'purssapp_reminders',
            'Pengingat PurssApp',
            channelDescription: 'Pengingat pencatatan, tinjauan, dan backup',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            visibility: NotificationVisibility.private,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // Inexact: tidak memerlukan izin alarm presisi; cukup untuk pengingat.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: k == ReminderKind.daily
            ? DateTimeComponents.time
            : DateTimeComponents.dayOfWeekAndTime,
        payload: _payload(k),
      );
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi: $e');
    }
  }

  tz.TZDateTime _next(ReminderKind k, ReminderPref pref) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, pref.hour, pref.minute);
    final weekday = switch (k) {
      ReminderKind.weekly => DateTime.sunday,
      ReminderKind.backup => DateTime.monday,
      ReminderKind.daily => null,
    };
    while (t.isBefore(now) || (weekday != null && t.weekday != weekday)) {
      t = t.add(Duration(days: 1));
    }
    return t;
  }
}
