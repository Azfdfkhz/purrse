import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/ui_kit.dart';
import '../../widgets/tour_guide.dart';
import '../../widgets/tour_keys.dart';
import '../home/beranda_screen.dart';
import '../placeholder/transaksi_screen.dart';
import '../laporan/laporan_screen.dart';
import '../profile/profile_screen.dart';
import '../expense/add_expense_modal.dart';
import '../../services/proof_upload_service.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../services/sync_service.dart';

class NavbarShell extends StatefulWidget {
  const NavbarShell({super.key});

  @override
  State<NavbarShell> createState() => _NavbarShellState();
}

class _NavbarShellState extends State<NavbarShell> {
  int _index = 0;
  final GlobalKey<BerandaScreenState> _berandaKey = GlobalKey<BerandaScreenState>();
  final GlobalKey<TransaksiScreenState> _transaksiKey = GlobalKey<TransaksiScreenState>();
  final GlobalKey<LaporanScreenState> _laporanKey = GlobalKey<LaporanScreenState>();

  int _seenRevision = SyncService.instance.dataRevision;

  @override
  void initState() {
    super.initState();
    _startUploads();
    SyncService.instance.start();
    SyncService.instance.addListener(_onSyncChanged);
    AuthService.instance.afterLogin();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstRunGuide());
  }

  static const String _tourKey = 'purrse_tour_done_124';

  Future<void> _showFirstRunGuide() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_tourKey) ?? false) return;
    if (!mounted) return;
    await TourGuide.show(context);
    await prefs.setBool(_tourKey, true);
  }


  /// Data baru dari cloud: muat ulang layar yang menampilkan data.
  void _onSyncChanged() {
    final rev = SyncService.instance.dataRevision;
    if (rev == _seenRevision) return;
    _seenRevision = rev;
    _berandaKey.currentState?.reload();
    _transaksiKey.currentState?.reload();
    _laporanKey.currentState?.reload();
  }

  Future<void> _startUploads() async {
    final user = await StorageService.instance.getCurrentUser();
    if (user != null) ProofUploadService.instance.startPeriodic(user.id);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    SyncService.instance.removeListener(_onSyncChanged);
    ProofUploadService.instance.stop();
    super.dispose();
  }

  late final PageController _pageCtrl = PageController(initialPage: _index);

  late final List<Widget> _pages = [
    _KeepAlive(child: BerandaScreen(
      key: _berandaKey,
      onNavigateToLaporan: () => _jumpTo(2),
      onNavigateToTransaksi: () => _jumpTo(1),
      onAddExpense: _openAddExpense,
    )),
    _KeepAlive(child: TransaksiScreen(key: _transaksiKey)),
    _KeepAlive(child: LaporanScreen(key: _laporanKey)),
    _KeepAlive(child: ProfileScreen()),
  ];

  /// Pindah tab — sinkronkan PageView dan navbar sekaligus.
  void _jumpTo(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _pageCtrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _openAddExpense() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (_) => AddExpenseModal(
        initialDate: _index == 2 ? _laporanKey.currentState?.dateForNewExpense : null,
      ),
    );
    if (added == true) {
      _berandaKey.currentState?.reload();
      _transaksiKey.currentState?.reload();
      _laporanKey.currentState?.reload();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Pengeluaran tersimpan ✓')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: PageView(
          controller: _pageCtrl,
          // Izinkan swipe antar halaman dengan sensitivitas normal.
          // Flutter otomatis membedakan scroll vertikal (konten) vs
          // swipe horizontal (ganti halaman).
          physics: const _SnapPagePhysics(),
          onPageChanged: (i) {
            if (_index != i) setState(() => _index = i);
          },
          children: _pages,
        ),
      ),
      bottomNavigationBar: _BottomBar(
        currentIndex: _index,
        onTap: _jumpTo,
        onAdd: _openAddExpense,
      ),
    );
  }
}

/// Jaga state halaman tetap hidup walau PageView geser ke halaman lain.
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Physics kustom: tetap bisa swipe antar halaman, tapi threshold
/// lebih tinggi (26%) sehingga tidak mudah salah geser.
class _SnapPagePhysics extends PageScrollPhysics {
  const _SnapPagePhysics({super.parent});

  @override
  _SnapPagePhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapPagePhysics(parent: buildParent(ancestor));

  @override
  double get dragStartDistanceMotionThreshold => 3.5;
}

/// Navbar melayang: pil putih (gelap di Dark Mode) berisi 4 tab; tab aktif
/// berupa pil hitam dengan ikon + label. Tombol (+) terpisah di sisi kanan.
class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  const _BottomBar({
    required this.currentIndex,
    required this.onTap,
    required this.onAdd,
  });

  static const _items = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, 'Beranda'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Transaksi'),
    (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Laporan'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Akun'),
  ];

  // Key tour untuk setiap tab — urutan sesuai _items
  static final _tourNavKeys = [
    TourKeys.home,
    TourKeys.transaksi,
    TourKeys.laporan,
    TourKeys.akun,
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final dark = AppColors.isDark;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 64,
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: AppColors.hairline, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(dark ? 0.35 : 0.10),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < _items.length; i++)
                          _NavItem(
                            tourKey: _tourNavKeys[i],
                            icon: currentIndex == i ? _items[i].$2 : _items[i].$1,
                            label: _items[i].$3,
                            selected: currentIndex == i,
                            onTap: () => onTap(i),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Semantics(
                  button: true,
                  label: 'Tambah pengeluaran',
                  child: Pressable(
                    onTap: onAdd,
                    pressedScale: 0.92,
                    child: Container(
                      key: TourKeys.add,
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.inkInverse,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(dark ? 0.35 : 0.16),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(Icons.add_rounded, color: AppColors.surface, size: 30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final GlobalKey? tourKey;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    this.tourKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.surface : AppColors.textGrey;
    // Tab aktif lebih lebar (memuat label); tab lain berbagi sisa ruang.
    return Expanded(
      flex: selected ? 5 : 2,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            key: tourKey,
            duration: motion(context, 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.inkInverse : Colors.transparent,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: fg),
                if (selected) ...[
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

