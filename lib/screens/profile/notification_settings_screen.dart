import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui_kit.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  final _svc = NotificationService.instance;
  final Map<ReminderKind, ReminderPref> _prefs = {};
  bool _permission = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Pengguna mungkin mengubah izin di pengaturan sistem lalu kembali.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final perm = await _svc.hasPermission();
    for (final k in ReminderKind.values) {
      _prefs[k] = await _svc.getPref(k);
    }
    if (!mounted) return;
    setState(() {
      _permission = perm;
      _loading = false;
    });
  }

  Future<void> _toggle(ReminderKind k, bool on) async {
    if (on && !_permission) {
      final ok = await _svc.requestPermission();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Izin notifikasi ditolak. Aktifkan lewat pengaturan sistem untuk memakai pengingat.'),
        ));
        return;
      }
      _permission = true;
    }
    final next = _prefs[k]!.copyWith(enabled: on);
    await _svc.savePref(k, next);
    if (!mounted) return;
    setState(() => _prefs[k] = next);
  }

  Future<void> _pickTime(ReminderKind k) async {
    final cur = _prefs[k]!;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur.hour, minute: cur.minute),
    );
    if (t == null) return;
    final next = cur.copyWith(hour: t.hour, minute: t.minute);
    await _svc.savePref(k, next);
    if (!mounted) return;
    setState(() => _prefs[k] = next);
  }

  String _fmt(ReminderPref p) =>
      '${p.hour.toString().padLeft(2, '0')}.${p.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
        ),
        title: Text('Notifikasi',
            style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(20),
              children: [
                Text(
                  'Pengingat berjalan di perangkat ini dan mengikuti zona waktu HP. '
                  'Isi notifikasi tidak menampilkan nominal uang.',
                  style: TextStyle(color: AppColors.textGrey, height: 1.4),
                ),
                SizedBox(height: 16),
                if (!_permission)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: InkCard(
                      bold: false,
                      child: Row(
                        children: [
                          Icon(Icons.notifications_off_outlined, color: AppColors.textDark),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Izin notifikasi belum aktif. Izin diminta saat kamu menyalakan pengingat.',
                              style: TextStyle(color: AppColors.textDark, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final k in ReminderKind.values) ...[
                  _ReminderCard(
                    title: NotificationService.title(k),
                    description: NotificationService.description(k),
                    pref: _prefs[k]!,
                    timeLabel: _fmt(_prefs[k]!),
                    onToggle: (v) => _toggle(k, v),
                    onTime: () => _pickTime(k),
                  ),
                  SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final String title;
  final String description;
  final ReminderPref pref;
  final String timeLabel;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTime;

  const _ReminderCard({
    required this.title,
    required this.description,
    required this.pref,
    required this.timeLabel,
    required this.onToggle,
    required this.onTime,
  });

  @override
  Widget build(BuildContext context) {
    return InkCard(
      bold: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark)),
              ),
              Switch(value: pref.enabled, onChanged: onToggle),
            ],
          ),
          Text(description, style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
          if (pref.enabled) ...[
            SizedBox(height: 8),
            TextButton.icon(
              onPressed: onTime,
              icon: Icon(Icons.schedule_rounded, size: 18),
              label: Text('Pukul $timeLabel'),
            ),
          ],
        ],
      ),
    );
  }
}
