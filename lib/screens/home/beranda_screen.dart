import 'dart:io';
import 'package:flutter/material.dart';
import '../profile/category_management_screen.dart';
import '../profile/notification_settings_screen.dart';
import '../../models/expense_model.dart';
import '../../models/category_model.dart';
import '../../models/user_model.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/ui_kit.dart';

class BerandaScreen extends StatefulWidget {
  final VoidCallback? onNavigateToLaporan;
  final VoidCallback? onNavigateToTransaksi;
  final VoidCallback? onAddExpense;

  const BerandaScreen({
    super.key,
    this.onNavigateToLaporan,
    this.onNavigateToTransaksi,
    this.onAddExpense,
  });

  @override
  State<BerandaScreen> createState() => BerandaScreenState();
}

class BerandaScreenState extends State<BerandaScreen> {
  UserModel? _user;
  List<ExpenseModel> _all = [];
  List<ExpenseModel> _monthExpenses = [];
  List<CategoryModel> _categories = [];
  int _month = DateTime.now().month;
  final int _year = DateTime.now().year;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    // Spinner hanya saat pertama kali; muat ulang berikutnya tanpa berkedip.
    if (_user == null) setState(() => _loading = true);
    final user = await StorageService.instance.getCurrentUser();
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final all = await StorageService.instance.getExpenses(user.id);
    final cats = await StorageService.instance.getCategories(user.id);
    if (!mounted) return;
    setState(() {
      _user = user;
      _categories = cats;
      _all = all;
      _monthExpenses = StorageService.instance.filterByMonth(all, _month, _year);
      _loading = false;
    });
  }

  Future<void> _pickMonth() async {
    final themeColor = ThemeController.instance.accentColor;
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SizedBox(
        height: 360,
        child: ListView.builder(
          padding: EdgeInsets.symmetric(vertical: 12),
          itemCount: 12,
          itemBuilder: (_, i) => ListTile(
            title: Text(Formatters.monthNames[i]),
            trailing: _month == i + 1 ? Icon(Icons.check_rounded, color: themeColor) : null,
            onTap: () => Navigator.pop(context, i + 1),
          ),
        ),
      ),
    );
    if (selected != null) {
      setState(() => _month = selected);
      reload();
    }
  }

  double get _total => _monthExpenses.fold(0, (sum, e) => sum + e.amount);

  double get _prevTotal {
    final pm = _month == 1 ? 12 : _month - 1;
    final py = _month == 1 ? _year - 1 : _year;
    return StorageService.instance
        .filterByMonth(_all, pm, py)
        .fold<double>(0, (sum, e) => sum + e.amount);
  }

  Map<String, double> get _byCategory {
    final map = <String, double>{};
    for (final e in _monthExpenses) {
      map[e.categoryId] = (map[e.categoryId] ?? 0) + e.amount;
    }
    return map;
  }

  CategoryModel? _categoryById(String id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _openCategories() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryManagementScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _user == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 40, color: AppColors.textGrey),
              SizedBox(height: 12),
              Text(
                'Data akun tidak dapat dimuat.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              SizedBox(height: 16),
              FilledButton(onPressed: reload, child: Text('Coba lagi')),
            ],
          ),
        ),
      );
    }
    if (_loading || _user == null) {
      return AnimatedBuilder(
        animation: ThemeController.instance,
        builder: (context, _) => Center(
          child: CircularProgressIndicator(color: ThemeController.instance.accentColor),
        ),
      );
    }

    final byCategory = _byCategory;
    final recent = [..._monthExpenses]..sort((a, b) {
        final d = b.date.compareTo(a.date);
        return d != 0 ? d : b.createdAt.compareTo(a.createdAt);
      });

    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final themeColor = ThemeController.instance.accentColor;
        final hasAvatar = _user?.avatarPath != null &&
            _user!.avatarPath!.isNotEmpty &&
            File(_user!.avatarPath!).existsSync();

        return RefreshIndicator(
          onRefresh: reload,
          color: AppColors.ink,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: tombol bulat kiri, avatar kanan
                Row(
                  children: [
                    _RoundButton(
                      icon: Icons.notifications_none_rounded,
                      tooltip: 'Pengaturan notifikasi',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => NotificationSettingsScreen()),
                      ),
                    ),
                    Spacer(),
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: themeColor,
                      backgroundImage: hasAvatar ? FileImage(File(_user!.avatarPath!)) : null,
                      child: hasAvatar
                          ? null
                          : Icon(Icons.person_rounded, color: AppColors.onColor(themeColor)),
                    ),
                  ],
                ),
                SizedBox(height: 18),
                Text(
                  'Halo, ${_user!.username}!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Yuk, catat dan hemat uangmu.',
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
                SizedBox(height: 18),

                FadeSlideIn(
                  child: _CardStack(
                    count: _monthExpenses.length,
                    total: _total,
                    prevTotal: _prevTotal,
                    month: _month,
                    year: _year,
                    color: themeColor,
                    onMonthTap: _pickMonth,
                    onSummaryTap: () => widget.onNavigateToLaporan?.call(),
                  ),
                ),
                SizedBox(height: 16),

                FadeSlideIn(
                  index: 1,
                  child: _QuickActions(
                    items: [
                      _QuickItem(Icons.add_rounded, 'Tambah', () => widget.onAddExpense?.call()),
                      _QuickItem(Icons.receipt_long_rounded, 'Transaksi',
                          () => widget.onNavigateToTransaksi?.call()),
                      _QuickItem(Icons.bar_chart_rounded, 'Laporan',
                          () => widget.onNavigateToLaporan?.call()),
                      _QuickItem(Icons.category_rounded, 'Kategori', _openCategories),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                if (byCategory.isNotEmpty) ...[
                  FadeSlideIn(
                    index: 2,
                    child: _CategoryBreakdown(
                      byCategory: byCategory,
                      categories: _categories,
                      total: _total,
                    ),
                  ),
                  SizedBox(height: 16),
                ],

                FadeSlideIn(
                  index: 3,
                  child: _RecentCard(
                    expenses: recent.take(5).toList(),
                    categoryOf: _categoryById,
                    onViewAll: () => widget.onNavigateToTransaksi?.call(),
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

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: AppColors.softShadow,
          ),
          child: Icon(icon, color: AppColors.textDark, size: 22),
        ),
      ),
    );
  }
}

/// Dua kartu bertumpuk: kartu belakang (bulan lalu) mengintip di atas kartu
/// utama (bulan terpilih), dengan tombol "Lihat laporan" di lekukan kanan-bawah.
class _CardStack extends StatelessWidget {
  final int count;
  final double total;
  final double prevTotal;
  final int month;
  final int year;
  final Color color;
  final VoidCallback onMonthTap;
  final VoidCallback onSummaryTap;

  const _CardStack({
    required this.count,
    required this.total,
    required this.prevTotal,
    required this.month,
    required this.year,
    required this.color,
    required this.onMonthTap,
    required this.onSummaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.onColor(color);
    final fgSoft = fg.withOpacity(0.65);
    final back = AppColors.softOrange;
    final prevMonth = month == 1 ? 12 : month - 1;

    return SizedBox(
      height: 214,
      child: Stack(
        children: [
          // Kartu belakang: bulan lalu
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 110,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
              decoration: BoxDecoration(
                color: back,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.history_rounded, size: 18, color: AppColors.onPastel),
                  SizedBox(width: 6),
                  Text(
                    Formatters.monthNames[prevMonth - 1],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onPastel,
                    ),
                  ),
                  Spacer(),
                  Text(
                    Formatters.rupiah(prevTotal),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onPastel,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Kartu utama
          Positioned(
            left: 0,
            right: 0,
            top: 44,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: color)),
                  Padding(
                    padding: EdgeInsets.fromLTRB(22, 18, 22, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Total pengeluaran',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: fgSoft,
                                ),
                              ),
                            ),
                            Pressable(
                              onTap: onMonthTap,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: fg.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${Formatters.monthNames[month - 1]} $year',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: fg,
                                      ),
                                    ),
                                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: fg),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            Formatters.rupiah(total),
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              color: fg,
                            ),
                          ),
                        ),
                        Spacer(),
                        Text(
                          '$count transaksi',
                          style: TextStyle(fontSize: 12, color: fgSoft),
                        ),
                      ],
                    ),
                  ),
                  // Lekukan + tombol
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(8, 8, 0, 0),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(28)),
                      ),
                      child: Pressable(
                        onTap: onSummaryTap,
                        child: Container(
                          height: 46,
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(23),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Lihat laporan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _QuickItem(this.icon, this.label, this.onTap);
}

class _QuickActions extends StatelessWidget {
  final List<_QuickItem> items;
  const _QuickActions({required this.items});

  @override
  Widget build(BuildContext context) {
    return InkCard(
      radius: 28,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        children: [
          for (final it in items)
            Expanded(
              child: Semantics(
                button: true,
                label: it.label,
                child: Pressable(
                  onTap: it.onTap,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(it.icon, color: AppColors.textDark, size: 24),
                      ),
                      SizedBox(height: 8),
                      Text(
                        it.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ringkasan kategori: bilah bersegmen + 4 kategori teratas.
class _CategoryBreakdown extends StatelessWidget {
  final Map<String, double> byCategory;
  final List<CategoryModel> categories;
  final double total;

  const _CategoryBreakdown({
    required this.byCategory,
    required this.categories,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final rows = categories.where((c) => byCategory.containsKey(c.id)).toList()
      ..sort((a, b) => (byCategory[b.id] ?? 0).compareTo(byCategory[a.id] ?? 0));

    return InkCard(
      radius: 28,
      padding: EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Per kategori',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark),
          ),
          SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) SizedBox(width: 2),
                    Expanded(
                      flex: ((byCategory[rows[i].id] ?? 0) * 1000).round().clamp(1, 1 << 30).toInt(),
                      child: ColoredBox(color: rows[i].color),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 14),
          for (final c in rows.take(4))
            Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                  ),
                  Text(
                    Formatters.rupiah(byCategory[c.id] ?? 0),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  SizedBox(width: 8),
                  SizedBox(
                    width: 38,
                    child: Text(
                      total <= 0 ? '' : '${(((byCategory[c.id] ?? 0) / total) * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                  ),
                ],
              ),
            ),
          if (rows.length > 4)
            Text(
              '+${rows.length - 4} kategori lain',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final CategoryModel? Function(String id) categoryOf;
  final VoidCallback onViewAll;

  const _RecentCard({
    required this.expenses,
    required this.categoryOf,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return InkCard(
      radius: 28,
      padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pengeluaran terbaru',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark),
                ),
              ),
              Pressable(
                onTap: onViewAll,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Text(
                    'Lihat semua',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (expenses.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'Belum ada pengeluaran bulan ini.\nKetuk tombol + untuk mencatat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13, height: 1.5),
                ),
              ),
            )
          else
            for (final e in expenses) _ExpenseRow(expense: e, category: categoryOf(e.categoryId)),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final ExpenseModel expense;
  final CategoryModel? category;

  const _ExpenseRow({required this.expense, required this.category});

  @override
  Widget build(BuildContext context) {
    final color = category?.color ?? AppColors.softCoral;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(category?.icon ?? Icons.category_rounded, color: AppColors.onColor(color), size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description.isEmpty ? (category?.name ?? 'Lainnya') : expense.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark),
                ),
                SizedBox(height: 2),
                Text(
                  '${category?.name ?? 'Lainnya'} • ${Formatters.date(expense.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Text(
            Formatters.rupiah(expense.amount),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }
}
