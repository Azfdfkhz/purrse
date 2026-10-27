import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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

  const BerandaScreen({super.key, this.onNavigateToLaporan});

  @override
  State<BerandaScreen> createState() => BerandaScreenState();
}

class BerandaScreenState extends State<BerandaScreen> {
  UserModel? _user;
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
    setState(() => _loading = true);
    final user = await StorageService.instance.getCurrentUser();
    if (user == null) return;
    final all = await StorageService.instance.getExpenses(user.id);
    final cats = await StorageService.instance.getCategories(user.id);
    if (!mounted) return;
    setState(() {
      _user = user;
      _categories = cats;
      _monthExpenses = StorageService.instance.filterByMonth(all, _month, _year);
      _loading = false;
    });
  }

  Future<void> _pickMonth() async {
    final themeColor = ThemeController.instance.accentColor;
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SizedBox(
        height: 320,
        child: ListView.builder(
          itemCount: 12,
          itemBuilder: (_, i) => ListTile(
            title: Text(Formatters.monthNames[i]),
            trailing: _month == i + 1
                ? Icon(Icons.check_rounded, color: themeColor)
                : null,
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

  Map<String, double> get _byCategory {
    final map = <String, double>{};
    for (final e in _monthExpenses) {
      map[e.categoryId] = (map[e.categoryId] ?? 0) + e.amount;
    }
    return map;
  }

  CategoryModel? _categoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _user == null) {
      return AnimatedBuilder(
        animation: ThemeController.instance,
        builder: (context, _) => Center(
          child: CircularProgressIndicator(
            color: ThemeController.instance.accentColor,
          ),
        ),
      );
    }

    final byCategory = _byCategory;

    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final themeColor = ThemeController.instance.accentColor;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Halo, ${_user!.username} 👋',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    tooltip: 'Notifikasi',
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.textDark,
                      size: 26,
                    ),
                  ),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.ink,
                    child: CircleAvatar(
                    radius: 22,
                    backgroundColor: themeColor,
                    backgroundImage: (_user?.avatarPath != null && _user!.avatarPath!.isNotEmpty)
                        ? FileImage(File(_user!.avatarPath!))
                        : null,
                    child: (_user?.avatarPath == null || _user!.avatarPath!.isEmpty)
                        ? const Icon(Icons.person, color: AppColors.textDark)
                        : null,
                  ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Card Saldo/Pengeluaran
              FadeSlideIn(child: _BalanceCard(
                count: _monthExpenses.length,
                total: _total,
                month: _month,
                color: themeColor,
                onMonthTap: _pickMonth,
                onSummaryTap: () {
                  if (widget.onNavigateToLaporan != null) {
                    widget.onNavigateToLaporan!();
                  }
                },
              )),
              const SizedBox(height: 14),

              // Donut Chart & Legenda
              SizedBox(
                height: 170,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _DonutCard(
                        total: _total,
                        month: _month,
                        year: _year,
                        byCategory: byCategory,
                        categories: _categories,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LegendCard(
                        byCategory: byCategory,
                        categories: _categories,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // List Pengeluaran Terbaru
              Expanded(
                child: _RecentExpensesCard(
                  expenses: _monthExpenses,
                  categoryOf: _categoryById,
                  themeColor: themeColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double total;
  final int month;
  final int count;
  final Color color;
  final VoidCallback onMonthTap;
  final VoidCallback onSummaryTap;

  const _BalanceCard({
    required this.total,
    required this.month,
    required this.count,
    required this.color,
    required this.onMonthTap,
    required this.onSummaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            color: AppColors.ink,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Pengeluaran bulan ini',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Pressable(
                      onTap: onMonthTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Formatters.monthNames[month - 1],
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.ink),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Formatters.rupiah(total),
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Pressable(
                      onTap: onSummaryTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Lihat ringkasan',
                              style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, color: AppColors.ink, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '$count transaksi',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Dekorasi lembut berwarna aksen (mengikuti pilihan warna pengguna)
          Positioned(
            right: -34,
            top: -34,
            child: IgnorePointer(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(color: color.withOpacity(0.18), shape: BoxShape.circle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutCard extends StatelessWidget {
  final double total;
  final int month;
  final int year;
  final Map<String, double> byCategory;
  final List<CategoryModel> categories;

  const _DonutCard({
    required this.total,
    required this.month,
    required this.year,
    required this.byCategory,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final sections = <PieChartSectionData>[];
    if (byCategory.isEmpty) {
      sections.add(
        PieChartSectionData(
          color: AppColors.cardBorder,
          value: 1,
          radius: 22,
          showTitle: false,
        ),
      );
    } else {
      for (final entry in byCategory.entries) {
        final cat = categories.where((c) => c.id == entry.key).toList();
        final color = cat.isNotEmpty ? cat.first.color : AppColors.softCoral;
        sections.add(
          PieChartSectionData(
            color: color,
            value: entry.value,
            radius: 22,
            showTitle: false,
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 42,
              sectionsSpace: 3,
              startDegreeOffset: -90,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Formatters.monthNames[month - 1],
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
              const SizedBox(height: 2),
              Text(
                Formatters.rupiah(total),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              Text(
                '$year',
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendCard extends StatelessWidget {
  final Map<String, double> byCategory;
  final List<CategoryModel> categories;

  const _LegendCard({required this.byCategory, required this.categories});

  @override
  Widget build(BuildContext context) {
    final entries = categories.where((c) => byCategory.containsKey(c.id)).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: entries.isEmpty
          ? const Center(
        child: Text(
          'Belum ada data',
          style: TextStyle(color: AppColors.textGrey, fontSize: 12),
        ),
      )
          : ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final cat = entries[i];
          final value = byCategory[cat.id] ?? 0;
          return Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: cat.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      Formatters.rupiah(value),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecentExpensesCard extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final CategoryModel? Function(String id) categoryOf;
  final Color themeColor;

  const _RecentExpensesCard({
    required this.expenses,
    required this.categoryOf,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengeluaran terbaru',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: expenses.isEmpty
                ? const Center(
              child: Text(
                'Belum ada pengeluaran bulan ini.\nKetuk tombol + untuk mencatat.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGrey, fontSize: 14, height: 1.4),
              ),
            )
                : ListView.separated(
              itemCount: expenses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final e = expenses[i];
                final cat = categoryOf(e.categoryId);
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (cat?.color ?? AppColors.softCoral),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.ink, width: 1.5),
                        ),
                        child: Icon(
                          cat?.icon ?? Icons.category_rounded,
                          color: AppColors.ink,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat?.name ?? 'Lainnya',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              e.description.isEmpty ? '-' : e.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Formatters.date(e.date),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Formatters.rupiah(e.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}