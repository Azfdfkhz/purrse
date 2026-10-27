import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/ui_kit.dart';
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
    SyncService.instance.removeListener(_onSyncChanged);
    ProofUploadService.instance.stop();
    super.dispose();
  }

  late final List<Widget> _pages = [
    BerandaScreen(
      key: _berandaKey,
      onNavigateToLaporan: () => setState(() => _index = 2),
      onNavigateToTransaksi: () => setState(() => _index = 1),
      onAddExpense: _openAddExpense,
    ),
    TransaksiScreen(key: _transaksiKey),
    LaporanScreen(key: _laporanKey),
    ProfileScreen(),
  ];

  Future<void> _openAddExpense() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (_) => AddExpenseModal(
        // Dari tab Laporan (tampilan Hari): bawa tanggal yang dipilih pengguna.
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
        child: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _pages.length; i++)
              AnimatedOpacity(
                opacity: _index == i ? 1 : 0,
                duration: motion(context, 220),
                curve: Curves.easeOut,
                child: _pages[i],
              ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        onAdd: _openAddExpense,
      ),
    );
  }
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
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
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
