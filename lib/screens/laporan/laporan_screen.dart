import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../expense/add_expense_modal.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';
import '../../models/user_model.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/ui_kit.dart';

enum _ReportMode { harian, bulanan }

const List<String> _weekdayShort = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

String _monthShort(int m) => Formatters.monthNames[m - 1].substring(0, 3);

/// 1.250.000 -> "1,3jt", 350.000 -> "350rb", 0 -> "–".
String _compact(double v) {
  if (v <= 0) return '–';
  String one(double x) {
    final s = x.toStringAsFixed(1);
    return (s.endsWith('.0') ? s.substring(0, s.length - 2) : s).replaceAll('.', ',');
  }

  if (v >= 1e9) return '${one(v / 1e9)}M';
  if (v >= 1e6) return '${one(v / 1e6)}jt';
  if (v >= 1e3) return '${(v / 1e3).round()}rb';
  return v.round().toString();
}

DateTime _weekStart(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => LaporanScreenState();
}

class LaporanScreenState extends State<LaporanScreen> {
  _ReportMode _mode = _ReportMode.harian;

  /// false = strip satu minggu (awal), true = kalender sebulan penuh.
  bool _expanded = false;

  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  DateTime _selectedDay = ExpenseModel.dateOnly(DateTime.now());

  /// Hanya terisi jika pengguna sendiri mengetuk sebuah tanggal.
  /// Navigasi minggu/bulan menghapusnya, jadi tanggal transaksi tidak bergeser diam-diam.
  DateTime? _pickedDay;

  /// Tanggal awal untuk transaksi baru dari tombol (+): tanggal yang
  /// dipilih pengguna pada tampilan Harian, atau null (= hari ini).
  DateTime? get dateForNewExpense => _mode == _ReportMode.harian ? _pickedDay : null;

  UserModel? _user;
  List<ExpenseModel> _allExpenses = [];
  List<CategoryModel> _categories = [];
  Map<String, List<ExpenseModel>> _byDay = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    final user = await StorageService.instance.getCurrentUser();
    if (user == null) return;

    final expenses = await StorageService.instance.getExpenses(user.id);
    final categories = await StorageService.instance.getCategories(user.id);

    if (!mounted) return;

    final byDay = <String, List<ExpenseModel>>{};
    for (final e in expenses) {
      (byDay[ExpenseModel.dateKey(e.date)] ??= []).add(e);
    }

    setState(() {
      _user = user;
      _allExpenses = expenses;
      _categories = categories;
      _byDay = byDay;
      _loading = false;
    });
  }

  List<ExpenseModel> _expensesOn(DateTime d) => _byDay[ExpenseModel.dateKey(d)] ?? const [];

  double _totalOn(DateTime d) => _expensesOn(d).fold<double>(0, (s, e) => s + e.amount);

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

  // ---------- Navigasi ----------

  void _selectDay(DateTime d) {
    setState(() {
      _selectedDay = ExpenseModel.dateOnly(d);
      _month = d.month;
      _year = d.year;
      _pickedDay = _selectedDay;
    });
  }

  void _shiftWeek(int delta) {
    final d = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day + 7 * delta);
    setState(() {
      _selectedDay = d;
      _month = d.month;
      _year = d.year;
      _pickedDay = null;
    });
  }

  void _shiftMonth(int delta) {
    var m = _month + delta;
    var y = _year;
    if (m > 12) {
      m = 1;
      y++;
    } else if (m < 1) {
      m = 12;
      y--;
    }
    final now = DateTime.now();
    setState(() {
      _month = m;
      _year = y;
      _selectedDay = (m == now.month && y == now.year) ? ExpenseModel.dateOnly(now) : DateTime(y, m, 1);
      _pickedDay = null;
    });
  }

  void _shiftYear(int delta) {
    setState(() {
      _year += delta;
      _pickedDay = null;
      _selectedDay = DateTime(_year, _month, 1);
    });
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _month = now.month;
      _year = now.year;
      _selectedDay = ExpenseModel.dateOnly(now);
      _pickedDay = null;
    });
  }

  bool get _isTodayContext {
    final now = DateTime.now();
    if (_mode == _ReportMode.harian) {
      return _expanded
          ? (_month == now.month && _year == now.year)
          : _sameDay(_weekStart(_selectedDay), _weekStart(now));
    }
    return _year == now.year && _month == now.month;
  }

  CategoryModel? _categoryById(String id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    if (_loading || _user == null) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
      );
    }

    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final themeColor = ThemeController.instance.accentColor;

        return RefreshIndicator(
          onRefresh: _load,
          color: AppColors.ink,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(themeColor),
                SizedBox(height: 16),
                _ModeSwitch(
                  harian: _mode == _ReportMode.harian,
                  onChanged: (h) => setState(() => _mode = h ? _ReportMode.harian : _ReportMode.bulanan),
                ),
                SizedBox(height: 18),
                if (_mode == _ReportMode.harian) ..._harian(themeColor) else ..._bulanan(themeColor),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(Color themeColor) {
    final harian = _mode == _ReportMode.harian;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Laporan',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: AppColors.textDark,
            ),
          ),
        ),
        // Chip bulan: mengetuk membuka/menutup kalender sebulan penuh.
        if (harian)
          Semantics(
            button: true,
            label: _expanded ? 'Tutup kalender bulan' : 'Buka kalender bulan',
            child: Pressable(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                height: 46,
                padding: EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: AppColors.softShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.textDark),
                    SizedBox(width: 8),
                    Text(
                      '${_monthShort(_month)} $_year',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: motion(context, 220),
                      child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textDark),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (harian) SizedBox(width: 10),
        if (harian)
          Semantics(
            button: true,
            label: 'Tambah pengeluaran di tanggal terpilih',
            child: Pressable(
              onTap: _addForSelectedDay,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: AppColors.inkInverse, shape: BoxShape.circle),
                child: Icon(Icons.edit_calendar_rounded, size: 20, color: AppColors.surface),
              ),
            ),
          ),
      ],
    );
  }

  // ---------- Harian ----------

  List<Widget> _harian(Color themeColor) {
    final dayExpenses = _expensesOn(_selectedDay);
    final dayTotal = dayExpenses.fold<double>(0, (s, e) => s + e.amount);

    return [
      _NavRow(
        label: _expanded
            ? '${Formatters.monthNames[_month - 1]} $_year'
            : _weekLabel(_weekStart(_selectedDay)),
        onPrev: () => _expanded ? _shiftMonth(-1) : _shiftWeek(-1),
        onNext: () => _expanded ? _shiftMonth(1) : _shiftWeek(1),
        onToday: _isTodayContext ? null : _goToday,
        todayLabel: _expanded ? 'Bulan ini' : 'Minggu ini',
      ),
      SizedBox(height: 10),
      AnimatedSize(
        duration: motion(context, 240),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: _expanded ? _monthCalendar(themeColor) : _weekStrip(themeColor),
      ),
      SizedBox(height: 22),
      Row(
        children: [
          Expanded(
            child: Text(
              _dayTitle(_selectedDay),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
          ),
          Text(
            Formatters.rupiah(dayTotal),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
        ],
      ),
      SizedBox(height: 12),
      for (final e in dayExpenses)
        Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: _ExpenseCard(expense: e, category: _categoryById(e.categoryId)),
        ),
      _AddSlot(
        label: dayExpenses.isEmpty
            ? 'Belum ada pengeluaran. Ketuk untuk menambah'
            : 'Tambah pengeluaran di ${_selectedDay.day} ${_monthShort(_selectedDay.month)}',
        onTap: _addForSelectedDay,
      ),
    ];
  }

  String _weekLabel(DateTime start) {
    final end = DateTime(start.year, start.month, start.day + 6);
    if (start.month == end.month) {
      return '${start.day} – ${end.day} ${_monthShort(end.month)} ${end.year}';
    }
    return '${start.day} ${_monthShort(start.month)} – ${end.day} ${_monthShort(end.month)} ${end.year}';
  }

  String _dayTitle(DateTime d) {
    final now = DateTime.now();
    if (_sameDay(d, now)) return 'Hari ini';
    if (_sameDay(d, DateTime(now.year, now.month, now.day - 1))) return 'Kemarin';
    return '${_weekdayShort[d.weekday - 1]}, ${d.day} ${Formatters.monthNames[d.month - 1]}';
  }

  Widget _weekStrip(Color themeColor) {
    final start = _weekStart(_selectedDay);
    final now = DateTime.now();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -250) _shiftWeek(1);
        if (v > 250) _shiftWeek(-1);
      },
      child: Row(
        key: ValueKey('week-${ExpenseModel.dateKey(start)}'),
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                child: _dayPill(DateTime(start.year, start.month, start.day + i), now, themeColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayPill(DateTime date, DateTime now, Color themeColor) {
    final selected = _sameDay(date, _selectedDay);
    final today = _sameDay(date, now);
    final count = _expensesOn(date).length;
    final fg = selected ? AppColors.surface : AppColors.textDark;
    final sub = selected ? AppColors.surface.withOpacity(0.75) : AppColors.textGrey;

    return Semantics(
      button: true,
      selected: selected,
      label: '${_weekdayShort[date.weekday - 1]} ${date.day}, $count transaksi',
      child: Pressable(
        onTap: () => _selectDay(date),
        child: AnimatedContainer(
          duration: motion(context, 200),
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.inkInverse : AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: selected ? const [] : AppColors.softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _weekdayShort[date.weekday - 1],
                style: TextStyle(fontSize: 11, color: sub, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 4),
              Text(
                '${date.day}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg),
              ),
              SizedBox(height: 4),
              // Penanda: hari ini (aksen) atau jumlah transaksi
              if (today && !selected)
                Container(
                  width: 14,
                  height: 4,
                  decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(2)),
                )
              else
                Text(
                  count == 0 ? '·' : '$count trx',
                  maxLines: 1,
                  style: TextStyle(fontSize: 10, color: count == 0 ? sub.withOpacity(0.5) : sub),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthCalendar(Color themeColor) {
    final first = DateTime(_year, _month, 1);
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final lead = first.weekday - 1; // Senin = 0
    final rows = ((lead + daysInMonth) / 7).ceil();
    final now = DateTime.now();

    return InkCard(
      radius: 28,
      padding: EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        key: ValueKey('month-$_year-$_month'),
        children: [
          Row(
            children: [
              for (final w in _weekdayShort)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: TextStyle(fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          for (var r = 0; r < rows; r++)
            Padding(
              padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : 6),
              child: Row(
                children: [
                  for (var c = 0; c < 7; c++)
                    Expanded(
                      child: () {
                        final day = r * 7 + c - lead + 1;
                        if (day < 1 || day > daysInMonth) return SizedBox(height: 46);
                        final date = DateTime(_year, _month, day);
                        final selected = _sameDay(date, _selectedDay);
                        final today = _sameDay(date, now);
                        final has = _expensesOn(date).isNotEmpty;
                        return Semantics(
                          button: true,
                          selected: selected,
                          label: '$day ${Formatters.monthNames[_month - 1]}',
                          child: Pressable(
                            onTap: () => _selectDay(date),
                            pressedScale: 0.9,
                            child: Container(
                              height: 46,
                              margin: EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.inkInverse
                                    : (today ? themeColor.withOpacity(0.35) : Colors.transparent),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$day',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: selected ? AppColors.surface : AppColors.textDark,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: has
                                          ? (selected ? AppColors.surface : AppColors.pinkAccent)
                                          : Colors.transparent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }(),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------- Bulanan ----------

  List<Widget> _bulanan(Color themeColor) {
    final totals = StorageService.instance.monthlyTotals(_allExpenses, _year);
    final monthExpenses = StorageService.instance.filterByMonth(_allExpenses, _month, _year);
    final monthTotal = totals[_month] ?? 0;
    final prevM = _month == 1 ? 12 : _month - 1;
    final prevTotal = _month == 1
        ? StorageService.instance
            .filterByMonth(_allExpenses, 12, _year - 1)
            .fold<double>(0, (s, e) => s + e.amount)
        : (totals[prevM] ?? 0);
    final catTotals = StorageService.instance.categoryTotals(monthExpenses);
    final catEntries = _categories.where((c) => catTotals.containsKey(c.id)).toList()
      ..sort((a, b) => (catTotals[b.id] ?? 0).compareTo(catTotals[a.id] ?? 0));
    final maxCat = catEntries.isEmpty ? 0.0 : (catTotals[catEntries.first.id] ?? 0);
    final yearMax = totals.values.fold<double>(0, (m, v) => v > m ? v : m);

    String? delta;
    if (prevTotal > 0) {
      final pct = ((monthTotal - prevTotal) / prevTotal * 100).round();
      delta = pct == 0 ? 'Sama dengan bulan lalu' : '${pct > 0 ? '+' : ''}$pct% dari bulan lalu';
    }

    return [
      _NavRow(
        label: '$_year',
        onPrev: () => _shiftYear(-1),
        onNext: () => _shiftYear(1),
        onToday: _isTodayContext ? null : _goToday,
        todayLabel: 'Bulan ini',
      ),
      SizedBox(height: 10),
      // 12 bulan: 2 baris x 6 pil
      for (var row = 0; row < 2; row++)
        Padding(
          padding: EdgeInsets.only(bottom: row == 0 ? 6 : 0),
          child: Row(
            children: [
              for (var i = 0; i < 6; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                    child: _monthPill(row * 6 + i + 1, totals[row * 6 + i + 1] ?? 0),
                  ),
                ),
            ],
          ),
        ),
      SizedBox(height: 18),
      InkCard(
        radius: 28,
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total ${Formatters.monthNames[_month - 1]} $_year',
              style: TextStyle(fontSize: 13, color: AppColors.textGrey, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Formatters.rupiah(monthTotal),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: AppColors.textDark,
                ),
              ),
            ),
            SizedBox(height: 4),
            Text(
              '${monthExpenses.length} transaksi${delta == null ? '' : '  •  $delta'}',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
            SizedBox(height: 18),
            SizedBox(
              height: 150,
              child: yearMax == 0
                  ? Center(
                      child: Text(
                        'Belum ada data pengeluaran tahun ini.',
                        style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                      ),
                    )
                  : _yearChart(totals, yearMax, themeColor),
            ),
          ],
        ),
      ),
      SizedBox(height: 22),
      Text(
        'Pengeluaran per kategori',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
      ),
      SizedBox(height: 12),
      if (catEntries.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Belum ada pengeluaran bulan ini', style: TextStyle(color: AppColors.textGrey)),
        )
      else
        for (final cat in catEntries)
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _CategoryCard(
              category: cat,
              value: catTotals[cat.id] ?? 0,
              share: maxCat <= 0 ? 0 : (catTotals[cat.id] ?? 0) / maxCat,
              percent: monthTotal <= 0 ? 0 : ((catTotals[cat.id] ?? 0) / monthTotal * 100).round(),
            ),
          ),
    ];
  }

  Widget _monthPill(int m, double value) {
    final selected = m == _month;
    final fg = selected ? AppColors.surface : AppColors.textDark;
    final sub = selected ? AppColors.surface.withOpacity(0.75) : AppColors.textGrey;
    return Semantics(
      button: true,
      selected: selected,
      label: Formatters.monthNames[m - 1],
      child: Pressable(
        onTap: () => setState(() {
          _month = m;
          _selectedDay = DateTime(_year, m, 1);
          _pickedDay = null;
        }),
        child: AnimatedContainer(
          duration: motion(context, 200),
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.inkInverse : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected ? const [] : AppColors.softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_monthShort(m), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
              SizedBox(height: 3),
              Text(
                _compact(value),
                maxLines: 1,
                style: TextStyle(fontSize: 10, color: sub),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _yearChart(Map<int, double> totals, double maxValue, Color themeColor) {
    return BarChart(
      BarChartData(
        maxY: maxValue * 1.15,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 1 || idx > 12) return SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    _monthShort(idx).substring(0, 1),
                    style: TextStyle(
                      fontSize: 11,
                      color: idx == _month ? AppColors.textDark : AppColors.textGrey,
                      fontWeight: idx == _month ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(12, (i) {
          final m = i + 1;
          return BarChartGroupData(
            x: m,
            barRods: [
              BarChartRodData(
                toY: totals[m] ?? 0,
                width: 14,
                borderRadius: BorderRadius.circular(7),
                color: m == _month ? AppColors.inkInverse : AppColors.border,
              ),
            ],
          );
        }),
      ),
    );
  }
}

// =====================================================================
// Komponen
// =====================================================================

class _ModeSwitch extends StatelessWidget {
  final bool harian;
  final ValueChanged<bool> onChanged;

  const _ModeSwitch({required this.harian, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool active, VoidCallback onTap) => Expanded(
          child: Semantics(
            button: true,
            selected: active,
            label: label,
            child: Pressable(
              onTap: onTap,
              pressedScale: 0.98,
              child: AnimatedContainer(
                duration: motion(context, 200),
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppColors.inkInverse : Colors.transparent,
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.surface : AppColors.textGrey,
                  ),
                ),
              ),
            ),
          ),
        );

    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(25),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          seg('Harian', harian, () => onChanged(true)),
          seg('Bulanan', !harian, () => onChanged(false)),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onToday;
  final String todayLabel;

  const _NavRow({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.todayLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Sebelumnya',
          onPressed: onPrev,
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.chevron_left_rounded, color: AppColors.textDark),
        ),
        Expanded(
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Berikutnya',
          onPressed: onNext,
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.chevron_right_rounded, color: AppColors.textDark),
        ),
        SizedBox(
          width: 84,
          child: onToday == null
              ? null
              : TextButton(
                  onPressed: onToday,
                  style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 4)),
                  child: Text(
                    todayLabel,
                    maxLines: 1,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final CategoryModel? category;

  const _ExpenseCard({required this.expense, required this.category});

  @override
  Widget build(BuildContext context) {
    final color = category?.color ?? AppColors.softCoral;
    final hasProof = expense.hasProof || expense.driveFileId != null;

    return InkCard(
      radius: 24,
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                    SizedBox(height: 2),
                    Text(
                      category?.name ?? 'Lainnya',
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
            ],
          ),
          if (hasProof) ...[
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_camera_outlined, size: 13, color: AppColors.textGrey),
                  SizedBox(width: 5),
                  Text(
                    'Ada foto bukti',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGrey),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final double value;
  final double share; // 0..1 relatif kategori terbesar
  final int percent;

  const _CategoryCard({
    required this.category,
    required this.value,
    required this.share,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return InkCard(
      radius: 24,
      padding: EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: category.color, shape: BoxShape.circle),
                child: Icon(category.icon, color: AppColors.onColor(category.color), size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.rupiah(value),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  Text('$percent%', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                ],
              ),
            ],
          ),
          SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 6, color: AppColors.surfaceVariant),
                FractionallySizedBox(
                  widthFactor: share.clamp(0.02, 1.0).toDouble(),
                  child: Container(height: 6, color: category.color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris putus-putus ("slot kosong") untuk menambah pengeluaran.
class _AddSlot extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddSlot({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.98,
        child: CustomPaint(
          painter: _DashedRRect(color: AppColors.textGrey.withOpacity(0.45), radius: 22),
          child: Container(
            height: 56,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 18, color: AppColors.textGrey),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: AppColors.textGrey, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRect extends CustomPainter {
  final Color color;
  final double radius;

  _DashedRRect({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRect old) => old.color != color || old.radius != radius;
}
