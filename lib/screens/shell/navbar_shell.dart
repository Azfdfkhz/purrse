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
import '../../services/storage_service.dart';

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

  @override
  void initState() {
    super.initState();
    _startUploads();
  }

  Future<void> _startUploads() async {
    final user = await StorageService.instance.getCurrentUser();
    if (user != null) ProofUploadService.instance.startPeriodic(user.id);
  }

  @override
  void dispose() {
    ProofUploadService.instance.stop();
    super.dispose();
  }

  late final List<Widget> _pages = [
    BerandaScreen(
      key: _berandaKey,
      onNavigateToLaporan: () => setState(() => _index = 2), // Pindah ke tab Laporan
    ),
    TransaksiScreen(key: _transaksiKey),
    LaporanScreen(key: _laporanKey),
    const ProfileScreen(),
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
          ..showSnackBar(const SnackBar(content: Text('Pengeluaran tersimpan ✓')));
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

class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  const _BottomBar({
    required this.currentIndex,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final accent = ThemeController.instance.accentColor;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: SizedBox(
            height: 82,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Pil hitam melayang
                Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.22),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _NavItem(icon: Icons.home_rounded, label: 'Beranda', selected: currentIndex == 0, onTap: () => onTap(0)),
                      _NavItem(icon: Icons.receipt_long_rounded, label: 'Transaksi', selected: currentIndex == 1, onTap: () => onTap(1)),
                      const SizedBox(width: 64), // ruang tombol (+)
                      _NavItem(icon: Icons.bar_chart_rounded, label: 'Laporan', selected: currentIndex == 2, onTap: () => onTap(2)),
                      _NavItem(icon: Icons.person_rounded, label: 'Akun', selected: currentIndex == 3, onTap: () => onTap(3)),
                    ],
                  ),
                ),

                // Tombol tambah (+)
                Positioned(
                  top: 0,
                  child: Semantics(
                    button: true,
                    label: 'Tambah pengeluaran',
                    child: Pressable(
                      onTap: onAdd,
                      pressedScale: 0.9,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.ink, width: 3),
                        ),
                        child: const Icon(Icons.add_rounded, color: AppColors.ink, size: 32),
                      ),
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
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Pressable(
          onTap: onTap,
          child: Center(
            child: AnimatedContainer(
              duration: motion(context, 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 24, color: selected ? AppColors.ink : Colors.white70),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? AppColors.ink : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
