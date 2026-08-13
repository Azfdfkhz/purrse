import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../home/beranda_screen.dart';
import '../placeholder/transaksi_screen.dart';
import '../laporan/laporan_screen.dart';
import '../profile/profile_screen.dart';
import '../expense/add_expense_modal.dart';

class NavbarShell extends StatefulWidget {
  const NavbarShell({super.key});

  @override
  State<NavbarShell> createState() => _NavbarShellState();
}

class _NavbarShellState extends State<NavbarShell> {
  int _index = 0;
  final GlobalKey<BerandaScreenState> _berandaKey = GlobalKey<BerandaScreenState>();
  final GlobalKey<TransaksiScreenState> _transaksiKey = GlobalKey<TransaksiScreenState>();

  late final List<Widget> _pages = [
    BerandaScreen(
      key: _berandaKey,
      onNavigateToLaporan: () => setState(() => _index = 2), // Pindah ke tab Laporan
    ),
    TransaksiScreen(key: _transaksiKey),
    const LaporanScreen(),
    const ProfileScreen(),
  ];

  Future<void> _openAddExpense() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (_) => const AddExpenseModal(),
    );
    if (added == true) {
      _berandaKey.currentState?.reload();
      _transaksiKey.currentState?.reload();
      setState(() => _index = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: IndexedStack(index: _index, children: _pages)),
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
        final themeColor = ThemeController.instance.accentColor;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            height: 76, // Tinggi ideal agar tidak terlalu pendek/tinggi
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Background Card Navigasi
                Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: AppColors.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavIcon(
                        icon: Icons.home_rounded,
                        label: 'Beranda',
                        selected: currentIndex == 0,
                        activeColor: themeColor,
                        onTap: () => onTap(0),
                      ),
                      _NavIcon(
                        icon: Icons.receipt_long_rounded,
                        label: 'Transaksi',
                        selected: currentIndex == 1,
                        activeColor: themeColor,
                        onTap: () => onTap(1),
                      ),
                      const SizedBox(width: 48), // Spacer untuk tempat tombol (+)
                      _NavIcon(
                        icon: Icons.bar_chart_rounded,
                        label: 'Laporan',
                        selected: currentIndex == 2,
                        activeColor: themeColor,
                        onTap: () => onTap(2),
                      ),
                      _NavIcon(
                        icon: Icons.person_rounded,
                        label: 'Akun',
                        selected: currentIndex == 3,
                        activeColor: themeColor,
                        onTap: () => onTap(3),
                      ),
                    ],
                  ),
                ),

                // Floating Action Button (+) di tengah
                Positioned(
                  top: -14,
                  child: GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: themeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: themeColor.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add_rounded, color: AppColors.textDark, size: 32),
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

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : AppColors.textGrey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}