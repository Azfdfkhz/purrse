import 'package:flutter/material.dart';
import '../expense/add_expense_modal.dart';
import '../profile/notification_settings_screen.dart';
import '../../widgets/ui_kit.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';
import '../../models/user_model.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../../utils/formatters.dart';

enum _ReportMode { hari, bulan }

enum _DisplayType { calendar, data }

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => LaporanScreenState();
}

class LaporanScreenState extends State<LaporanScreen> {
  _ReportMode _mode = _ReportMode.hari;
  _DisplayType _hariDisplay = _DisplayType.calendar;
  _DisplayType _bulanDisplay = _DisplayType.data;

  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  DateTime _selectedDay = ExpenseModel.dateOnly(DateTime.now());

  /// Hanya terisi jika pengguna sendiri mengetuk sebuah tanggal.
  /// Navigasi bulan menghapusnya, jadi tanggal transaksi tidak bergeser diam-diam.
  DateTime? _pickedDay;

  /// Tanggal awal untuk transaksi baru dari tombol (+): tanggal yang
  /// dipilih pengguna pada tampilan Hari, atau null (= hari ini).
  DateTime? get dateForNewExpense =>
      _mode == _ReportMode.hari ? _pickedDay : null;

  UserModel? _user;
  List<ExpenseModel> _allExpenses = [];
  List<CategoryModel> _categories = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> reload() => _load();

  Future<void> _addForSelectedDay() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (_) => AddExpenseModal(initialDate: _selectedDay),
    );
    if (added == true) await _load();
  }

  Future<void> _load() async {
    final user = await StorageService.instance.getCurrentUser();
    if (user == null) return;

    final expenses = await StorageService.instance.getExpenses(user.id);
    final categories = await StorageService.instance.getCategories(user.id);

    if (!mounted) return;

    setState(() {
      _user = user;
      _allExpenses = expenses;
      _categories = categories;
      _loading = false;
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      var newMonth = _month + delta;
      var newYear = _year;

      if (newMonth > 12) {
        newMonth = 1;
        newYear++;
      } else if (newMonth < 1) {
        newMonth = 12;
        newYear--;
      }

      _month = newMonth;
      _year = newYear;
      _selectedDay = DateTime(_year, _month, 1);
      _pickedDay = null;
    });
  }

  /// Pintasan: kembali ke bulan/hari ini tanpa menebak.
  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _month = now.month;
      _year = now.year;
      _selectedDay = ExpenseModel.dateOnly(now);
      _pickedDay = null;
    });
  }

  bool get _isCurrentPeriod {
    final now = DateTime.now();
    return _month == now.month && _year == now.year;
  }

  _DisplayType get _currentDisplay =>
      _mode == _ReportMode.hari ? _hariDisplay : _bulanDisplay;

  void _setCurrentDisplay(_DisplayType type) {
    setState(() {
      if (_mode == _ReportMode.hari) {
        _hariDisplay = type;
      } else {
        _bulanDisplay = type;
      }
    });
  }

  Future<void> _pickDisplayType() async {
    final selected = await showModalBottomSheet<_DisplayType>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Calendar'),
              subtitle: Text(
                _mode == _ReportMode.hari
                    ? 'Lihat kalender tanggal'
                    : 'Lihat grafik per bulan',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
              trailing: _currentDisplay == _DisplayType.calendar
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () => Navigator.pop(context, _DisplayType.calendar),
            ),
            ListTile(
              title: Text('Data'),
              subtitle: Text(
                _mode == _ReportMode.hari
                    ? 'Lihat daftar tanggal & totalnya'
                    : 'Lihat daftar bulan & totalnya',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
              trailing: _currentDisplay == _DisplayType.data
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () => Navigator.pop(context, _DisplayType.data),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      _setCurrentDisplay(selected);
    }
  }

  Future<void> _pickMode() async {
    final selected = await showModalBottomSheet<_ReportMode>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Hari'),
              trailing: _mode == _ReportMode.hari
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () => Navigator.pop(context, _ReportMode.hari),
            ),
            ListTile(
              title: Text('Bulan'),
              trailing: _mode == _ReportMode.bulan
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () => Navigator.pop(context, _ReportMode.bulan),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      setState(() => _mode = selected);
    }
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
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final themeColor = ThemeController.instance.accentColor;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Pill(
                    label: _mode == _ReportMode.hari ? 'Hari' : 'Bulan',
                    color: themeColor,
                    onTap: _pickMode,
                  ),
                  IconButton(
                    tooltip: 'Pengaturan notifikasi',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => NotificationSettingsScreen()),
                    ),
                    icon: Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.textDark,
                      size: 26,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Pill(
                    label: _currentDisplay == _DisplayType.calendar ? 'Calendar' : 'Data',
                    color: themeColor,
                    onTap: _pickDisplayType,
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Bulan sebelumnya',
                        onPressed: () => _shiftMonth(-1),
                        icon: Icon(Icons.chevron_left_rounded, color: AppColors.textDark),
                      ),
                      Text(
                        '${Formatters.monthNames[_month - 1]} $_year',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Bulan berikutnya',
                        onPressed: () => _shiftMonth(1),
                        icon: Icon(Icons.chevron_right_rounded, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ],
              ),
              if (!_isCurrentPeriod || (_mode == _ReportMode.hari && _pickedDay != null))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _goToday,
                    icon: Icon(Icons.today_rounded, size: 18),
                    label: Text(
                      _mode == _ReportMode.hari ? 'Hari ini' : 'Bulan ini',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              SizedBox(height: 14),
              if (_mode == _ReportMode.hari) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _addForSelectedDay,
                    icon: Icon(Icons.add_circle_outline_rounded, size: 20),
                    label: Text(
                      'Tambah di ${Formatters.date(_selectedDay)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
              if (_mode == _ReportMode.hari)
                _DayView(
                  month: _month,
                  year: _year,
                  selectedDay: _selectedDay,
                  displayType: _hariDisplay,
                  allExpenses: _allExpenses,
                  categoryOf: _categoryById,
                  themeColor: themeColor,
                  onDaySelected: (d) {
                    setState(() {
                      _selectedDay = ExpenseModel.dateOnly(d);
                      _pickedDay = _selectedDay;
                    });
                  },
                )
              else
                _MonthView(
                  month: _month,
                  year: _year,
                  displayType: _bulanDisplay,
                  allExpenses: _allExpenses,
                  categories: _categories,
                  themeColor: themeColor,
                  onMonthSelected: (m) {
                    setState(() => _month = m);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

// ✅ SUDAH DIPERBAIKI (Hapus 'const' pada Row)
class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.ink, width: 1.5),
        ),
        child: Row( // <-- Hilangkan 'const' di sini
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.onPastel,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.onPastel,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayView extends StatelessWidget {
  final int month;
  final int year;
  final DateTime selectedDay;
  final _DisplayType displayType;
  final List<ExpenseModel> allExpenses;
  final CategoryModel? Function(String id) categoryOf;
  final Color themeColor;
  final ValueChanged<DateTime> onDaySelected;

  const _DayView({
    required this.month,
    required this.year,
    required this.selectedDay,
    required this.displayType,
    required this.allExpenses,
    required this.categoryOf,
    required this.themeColor,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final expenseDays = allExpenses
        .where((e) => e.date.year == year && e.date.month == month)
        .map((e) => e.date.day)
        .toSet();

    final dayExpenses = StorageService.instance.filterByDate(allExpenses, selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (displayType == _DisplayType.calendar)
          _buildCalendarGrid(context, daysInMonth, expenseDays)
        else
          _buildDataList(context, expenseDays),
        SizedBox(height: 22),
        Text(
          'Berikut pengeluaran pada tanggal ${Formatters.date(selectedDay)}:',
          style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 12),
        if (dayExpenses.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Belum ada pengeluaran pada tanggal ini',
              style: TextStyle(color: AppColors.textGrey),
            ),
          )
        else
          Column(
            children: dayExpenses.map((e) {
              final cat = categoryOf(e.categoryId);

              return Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cat?.color ?? AppColors.softCoral,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          cat?.icon ?? Icons.category_rounded,
                          color: AppColors.onColor(cat?.color ?? AppColors.softCoral),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat?.name ?? 'Lainnya',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark),
                            ),
                            Text(
                              e.description.isEmpty ? '-' : e.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        Formatters.rupiah(e.amount),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildCalendarGrid(BuildContext context, int daysInMonth, Set<int> expenseDays) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.25),
        borderRadius: BorderRadius.circular(28),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: daysInMonth,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 10,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, i) {
          final day = i + 1;
          final date = DateTime(year, month, day);

          final isSelected = date.year == selectedDay.year &&
              date.month == selectedDay.month &&
              date.day == selectedDay.day;

          final hasExpense = expenseDays.contains(day);
          final now = DateTime.now();
          final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

          return GestureDetector(
            onTap: () => onDaySelected(date),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? themeColor : AppColors.surface,
                shape: BoxShape.circle,
                border: isToday ? Border.all(color: AppColors.ink, width: 2) : null,
                boxShadow: isSelected
                    ? [BoxShadow(color: themeColor.withOpacity(0.4), blurRadius: 4, offset: Offset(0, 2))]
                    : null,
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.onPastel : AppColors.textDark,
                    ),
                  ),
                  if (hasExpense && !isSelected)
                    Container(
                      margin: EdgeInsets.only(top: 2),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: themeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDataList(BuildContext context, Set<int> expenseDays) {
    final sortedDays = expenseDays.toList()..sort();

    if (sortedDays.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: themeColor.withOpacity(0.25),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Center(
          child: Text(
            'Belum ada tanggal dengan pengeluaran bulan ini',
            style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Column(
      children: sortedDays.map((day) {
        final date = DateTime(year, month, day);
        final isSelected = date.year == selectedDay.year &&
            date.month == selectedDay.month &&
            date.day == selectedDay.day;

        final total = StorageService.instance
            .filterByDate(allExpenses, date)
            .fold<double>(0, (sum, e) => sum + e.amount);

        return Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onDaySelected(date),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? themeColor : themeColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    Formatters.date(date),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.onPastel : AppColors.textDark,
                    ),
                  ),
                  Text(
                    Formatters.rupiah(total),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MonthView extends StatelessWidget {
  final int month;
  final int year;
  final _DisplayType displayType;
  final List<ExpenseModel> allExpenses;
  final List<CategoryModel> categories;
  final Color themeColor;
  final ValueChanged<int> onMonthSelected;

  const _MonthView({
    required this.month,
    required this.year,
    required this.displayType,
    required this.allExpenses,
    required this.categories,
    required this.themeColor,
    required this.onMonthSelected,
  });

  @override
  Widget build(BuildContext context) {
    final totals = StorageService.instance.monthlyTotals(allExpenses, year);
    final monthExpenses = StorageService.instance.filterByMonth(allExpenses, month, year);
    final catTotals = StorageService.instance.categoryTotals(monthExpenses);
    final catEntries = categories.where((c) => catTotals.containsKey(c.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (displayType == _DisplayType.calendar)
          _buildBarChart(context, totals)
        else
          _buildDataList(context, totals),
        SizedBox(height: 22),
        Text(
          'Pengeluaran sesuai kategori',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 12),
        if (catEntries.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Belum ada pengeluaran bulan ini',
              style: TextStyle(color: AppColors.textGrey),
            ),
          )
        else
          Column(
            children: catEntries.map((cat) {
              final value = catTotals[cat.id] ?? 0;

              return Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cat.color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(cat.icon, color: AppColors.onColor(cat.color), size: 20),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          cat.name,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark),
                        ),
                      ),
                      Text(
                        Formatters.rupiah(value),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildBarChart(BuildContext context, Map<int, double> totals) {
    final maxValue = totals.values.fold<double>(0, (m, v) => v > m ? v : m);

    return Container(
      width: double.infinity,
      height: 260,
      padding: EdgeInsets.fromLTRB(8, 20, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: maxValue == 0
          ? Center(
        child: Text(
          'Belum ada data pengeluaran tahun ini.\nCatat pengeluaran pertama dengan tombol +.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textGrey, fontSize: 14, height: 1.4),
        ),
      )
          : BarChart(
        BarChartData(
          maxY: maxValue * 1.2,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 66,
                getTitlesWidget: (value, meta) => Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    Formatters.rupiah(value),
                    style: TextStyle(fontSize: 12, color: AppColors.textDark),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 1 || idx > 12) return SizedBox.shrink();

                  return Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      Formatters.monthNames[idx - 1].substring(0, 3),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(12, (i) {
            final m = i + 1;
            final value = totals[m] ?? 0;
            final isSelected = m == month;

            return BarChartGroupData(
              x: m,
              barRods: [
                BarChartRodData(
                  toY: value,
                  width: 18,
                  borderRadius: BorderRadius.circular(9),
                  color: isSelected ? themeColor : themeColor.withOpacity(0.35),
                  borderSide: BorderSide(
                    color: AppColors.ink,
                    width: isSelected ? 2 : 1.2,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDataList(BuildContext context, Map<int, double> totals) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.25),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: List.generate(12, (i) {
          final m = i + 1;
          final value = totals[m] ?? 0;
          final isSelected = m == month;

          return Padding(
            padding: EdgeInsets.only(bottom: m == 12 ? 0 : 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onMonthSelected(m),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? themeColor : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Formatters.monthNames[i],
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.onPastel : AppColors.textDark,
                      ),
                    ),
                    Text(
                      Formatters.rupiah(value),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}