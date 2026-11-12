import 'dart:io';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'storage_service.dart';

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

/// Satu pesan notifikasi.
class _Msg {
  final String title;
  final String body;
  const _Msg(this.title, this.body);
}

/// Notifikasi LOKAL terjadwal (tanpa server). Isi notifikasi sengaja tidak
/// memuat nominal atau detail keuangan agar aman tampil di lock-screen.
///
/// Pengingat harian itu PINTAR: hanya dijadwalkan untuk hari yang belum ada
/// pengeluaran tercatat, dan nadanya makin "manja" kalau sudah lama tidak
/// mencatat. Jadwal disegarkan setiap kali aplikasi dibuka dan setiap kali
/// pengeluaran ditambah / diubah / dihapus.
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

  /// Pengingat harian dijadwalkan per hari (bukan berulang) agar bisa dilewati
  /// pada hari yang sudah ada catatan. Slot: 1100 .. 1100 + _dailyHorizon - 1.
  static const _dailySlotBase = 1100;
  static const _dailyHorizon = 7;

  static const _defaults = {
    ReminderKind.daily: ReminderPref(enabled: false, hour: 20, minute: 0),
    ReminderKind.weekly: ReminderPref(enabled: false, hour: 19, minute: 0),
    ReminderKind.backup: ReminderPref(enabled: false, hour: 9, minute: 0),
  };

  static String title(ReminderKind k) => switch (k) {
        ReminderKind.daily => 'Pengingat catat pengeluaran',
        ReminderKind.weekly => 'Pengingat tinjau pengeluaran',
        ReminderKind.backup => 'Pengingat backup data',
      };

  static String description(ReminderKind k) => switch (k) {
        ReminderKind.daily =>
          'Kucingmu mengingatkan setiap hari, tapi hanya kalau kamu belum mencatat pengeluaran hari itu.',
        ReminderKind.weekly => 'Setiap Minggu, untuk meninjau pengeluaran minggu ini.',
        ReminderKind.backup => 'Setiap Senin, untuk mengingatkan mengecek backup.',
      };

  static const _weeklyMsgs = [
    _Msg('Waktunya intip dompet 👀', 'Yuk lihat ke mana saja uangmu jalan-jalan minggu ini.'),
    _Msg('Rapor mingguan datang! 📊', 'Tinjau pengeluaranmu minggu ini, cuma sebentar kok.'),
  ];

  static const _backupMsgs = [
    _Msg('Amankan datamu 🛡️', 'Cek backup-mu supaya catatan tetap aman.'),
    _Msg('Dompetku mau dijaga 💜', 'Yuk pastikan backup datamu masih terbaru.'),
  ];

  // Belum pernah mencatat sama sekali.
  static const _firstMsgs = [
    _Msg('Dompetku masih kosong 🐾', 'Yuk catat pengeluaran pertamamu, cuma sebentar kok.'),
    _Msg('Halo, aku Purrse 😺', 'Ayo mulai catat jajan hari ini. Aku temani!'),
  ];

  // Hari ini belum mencatat (terakhir mencatat kemarin / hari ini).
  static const _gentleMsgs = [
    _Msg('Sudah jajan hari ini? 🐱', 'Belum ada catatan pengeluaran nih. Yuk dicatat sebelum lupa!'),
    _Msg('Dompetku nanya nih 👀', 'Hari ini belum ada pengeluaran tercatat. Ada yang terlewat?'),
    _Msg('Purr purr… catat dulu yuk 🐾', 'Satu ketukan, satu catatan. Kucingmu menunggu!'),
    _Msg('Psst, ada yang lupa dicatat? 😸', 'Kasih tahu aku pengeluaranmu hari ini ya.'),
    _Msg('Tik tok, jam catat-catat! ⏰', 'Pengeluaran hari ini belum masuk buku nih.'),
  ];

  // 2-3 hari tanpa catatan. {n} = jumlah hari.
  static const _cheekyMsgs = [
    _Msg('Sudah {n} hari kamu menghilang 🙀', 'Dompetku mulai penasaran. Yuk catat pengeluaran terbaru!'),
    _Msg('Ke mana aja nih? 😿', 'Belum ada catatan sejak {n} hari lalu. Mampir sebentar yuk!'),
    _Msg('Cakar-cakarku mulai gatal 🐾', 'Ayo catat pengeluaran biar bukunya nggak bolong-bolong.'),
  ];

  // 4 hari atau lebih. {n} = jumlah hari.
  static const _missYouMsgs = [
    _Msg('Aku kangen kamu 😽', 'Sudah {n} hari tanpa catatan. Satu pengeluaran saja sudah bikin aku senang!'),
    _Msg('Dompetku sepi banget 🥺', 'Yuk mulai lagi pelan-pelan, dari pengeluaran hari ini.'),
    _Msg('Purrse nungguin di sini 💜', 'Kapan pun kamu siap, kita lanjut catat bareng ya.'),
  ];

  /// Pesan pengingat harian. [daysSince] = hari sejak catatan terakhir
  /// (null = belum pernah mencatat). [variant] memutar pilihan kalimat.
  static _Msg dailyMessage(int? daysSince, int variant) {
    final _Msg m;
    if (daysSince == null) {
      m = _firstMsgs[variant % _firstMsgs.length];
    } else if (daysSince <= 1) {
      m = _gentleMsgs[variant % _gentleMsgs.length];
    } else if (daysSince <= 3) {
      m = _cheekyMsgs[variant % _cheekyMsgs.length];
    } else {
      m = _missYouMsgs[variant % _missYouMsgs.length];
    }
    final n = '${daysSince ?? 0}';
    return _Msg(m.title.replaceAll('{n}', n), m.body.replaceAll('{n}', n));
  }

  static _Msg _staticMessage(ReminderKind k) {
    final day = DateTime.now().day;
    return switch (k) {
      ReminderKind.weekly => _weeklyMsgs[day % _weeklyMsgs.length],
      ReminderKind.backup => _backupMsgs[day % _backupMsgs.length],
      ReminderKind.daily => dailyMessage(1, day),
    };
  }

  static String _payload(ReminderKind k) => switch (k) {
        ReminderKind.backup => 'backup',
        _ => 'home',
      };

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        // Zona waktu tidak terbaca: pakai UTC bawaan paket timezone.
      }
      final android = AndroidInitializationSettings('ic_stat_purrse');
      final ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
      );
      // Kanal untuk notifikasi push (FCM). Id harus sama dengan meta-data
      // default_notification_channel_id di AndroidManifest.
      if (!kIsWeb && Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(const AndroidNotificationChannel(
              pushChannelId,
              'Info Purrse',
              description: 'Pemberitahuan dari Purrse',
              importance: Importance.defaultImportance,
            ));
      }
      _ready = true;
    } catch (e) {
      debugPrint('Notifikasi gagal diinisialisasi: $e');
    }
  }

  static const pushChannelId = 'purssapp_push';

  /// Tampilkan notifikasi sekarang (dipakai untuk pesan push saat aplikasi terbuka).
  Future<void> showNow({required String title, required String body, String? payload}) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000 + 2000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            pushChannelId,
            'Info Purrse',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: 'ic_stat_purrse',
            color: Color(0xFF6A4FCF),
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi: $e');
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

  /// Detail notifikasi bertema Purrse: ikon siluet kucing, warna ungu, ikon besar.
  NotificationDetails _details(String body) => NotificationDetails(
        android: AndroidNotificationDetails(
          'purssapp_reminders',
          'Pengingat Purrse',
          channelDescription: 'Pengingat pencatatan, tinjauan, dan backup',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          visibility: NotificationVisibility.private,
          icon: 'ic_stat_purrse',
          color: const Color(0xFF6A4FCF),
          largeIcon: const DrawableResourceAndroidBitmap('ic_notif_large'),
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(),
      );

  Future<void> _apply(ReminderKind k, ReminderPref pref) async {
    if (!_ready) return;
    if (k == ReminderKind.daily) {
      await refreshDailyReminder();
      return;
    }
    final id = _ids[k]!;
    try {
      await _plugin.cancel(id);
      if (!pref.enabled) return;
      if (!await hasPermission()) return;
      final m = _staticMessage(k);
      await _plugin.zonedSchedule(
        id,
        m.title,
        m.body,
        _next(k, pref),
        _details(m.body),
        // Inexact: tidak memerlukan izin alarm presisi; cukup untuk pengingat.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: _payload(k),
      );
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi: $e');
    }
  }

  // ---------- Pengingat harian pintar ----------

  Future<void> _dailyChain = Future.value();

  /// Susun ulang jadwal harian: lewati hari yang sudah ada catatan, dan pilih
  /// nada pesan sesuai berapa lama user tidak mencatat. Aman dipanggil
  /// berulang (diserialkan agar tidak saling menimpa).
  Future<void> refreshDailyReminder() {
    _dailyChain = _dailyChain.catchError((_) {}).then((_) => _refreshDaily());
    return _dailyChain;
  }

  Future<void> _cancelDailySlots() async {
    await _plugin.cancel(_ids[ReminderKind.daily]!); // jadwal berulang versi lama
    for (var i = 0; i < _dailyHorizon; i++) {
      await _plugin.cancel(_dailySlotBase + i);
    }
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Hari terakhir user mencatat (tanggal transaksi ATAU waktu input), maksimal
  /// hari ini. null = belum pernah mencatat.
  Future<DateTime?> _lastEntryDay(String userId) async {
    final list = await StorageService.instance.getExpenses(userId);
    final today = _dayOnly(DateTime.now());
    DateTime? last;
    for (final e in list) {
      for (final d in [_dayOnly(e.date), _dayOnly(e.createdAt.toLocal())]) {
        if (d.isAfter(today)) continue;
        if (last == null || d.isAfter(last)) last = d;
      }
    }
    return last;
  }

  Future<void> _refreshDaily() async {
    if (!_ready) return;
    try {
      await _cancelDailySlots();
      final pref = await getPref(ReminderKind.daily);
      if (!pref.enabled) return;
      if (!await hasPermission()) return;
      final user = await StorageService.instance.getCurrentUser();
      if (user == null) return;
      final last = await _lastEntryDay(user.id);

      final now = tz.TZDateTime.now(tz.local);
      final today = DateTime(now.year, now.month, now.day);
      for (var i = 0; i < _dailyHorizon; i++) {
        final at = tz.TZDateTime(tz.local, now.year, now.month, now.day + i, pref.hour, pref.minute);
        if (!at.isAfter(now)) continue;
        final day = today.add(Duration(days: i));
        // Hari ini sudah mencatat: tidak perlu mengingatkan.
        if (last != null && !day.isAfter(last)) continue;
        final daysSince = last == null ? null : day.difference(last).inDays;
        final m = dailyMessage(daysSince, day.day + i);
        await _plugin.zonedSchedule(
          _dailySlotBase + i,
          m.title,
          m.body,
          at,
          _details(m.body),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: _payload(ReminderKind.daily),
        );
      }
    } catch (e) {
      debugPrint('Gagal menjadwalkan pengingat harian: $e');
    }
  }

  /// Tampilkan contoh notifikasi lucu sekarang (tombol "Coba notifikasi").
  /// Mengembalikan false bila izin belum diberikan.
  Future<bool> showPreview() async {
    if (!_ready) return false;
    if (!await hasPermission() && !await requestPermission()) return false;
    final m = dailyMessage(2 + DateTime.now().second % 4, DateTime.now().second);
    try {
      await _plugin.show(1999, m.title, m.body, _details(m.body), payload: 'home');
      return true;
    } catch (e) {
      debugPrint('Gagal menampilkan contoh notifikasi: $e');
      return false;
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
