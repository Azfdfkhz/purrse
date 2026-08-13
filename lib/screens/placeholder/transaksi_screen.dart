import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';

class TransaksiScreen extends StatefulWidget {
  const TransaksiScreen({super.key});

  @override
  State<TransaksiScreen> createState() => TransaksiScreenState();
}

class TransaksiScreenState extends State<TransaksiScreen> {
  List<ExpenseModel> _expenses = [];
  List<CategoryModel> _categories = [];
  String? _userId;
  String? _categoryId;
  DateTime? _selectedDate;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final user = await StorageService.instance.getCurrentUser();
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final results = await Future.wait([
      StorageService.instance.getExpenses(user.id),
      StorageService.instance.getCategories(user.id),
    ]);

    if (!mounted) return;
    setState(() {
      _userId = user.id;
      _expenses = results[0] as List<ExpenseModel>;
      _categories = results[1] as List<CategoryModel>;
      _loading = false;
    });
  }

  CategoryModel? _categoryFor(String id) {
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  List<ExpenseModel> get _photoExpenses {
    return _expenses.where((expense) => expense.proofPath != null && File(expense.proofPath!).existsSync()).toList();
  }

  List<ExpenseModel> get _filteredExpenses {
    return _photoExpenses.where((expense) {
      final categoryMatch = _categoryId == null || expense.categoryId == _categoryId;
      final dateMatch = _selectedDate == null ||
          (expense.date.year == _selectedDate!.year &&
              expense.date.month == _selectedDate!.month &&
              expense.date.day == _selectedDate!.day);
      return categoryMatch && dateMatch;
    }).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _clearDate() => setState(() => _selectedDate = null);

  Future<void> _deleteExpense(ExpenseModel expense) async {
    if (_userId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: const Text('Transaksi ini akan dihapus dari riwayat pengeluaran.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true) return;
    await StorageService.instance.deleteExpense(_userId!, expense.id);
    await reload();
  }

  String _dateLabel(DateTime date) => Formatters.date(date);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return RefreshIndicator(
      color: primary,
      onRefresh: reload,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            title: const Text('Transaksi', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
            actions: [
              IconButton(
                onPressed: _pickDate,
                tooltip: 'Filter tanggal',
                icon: Icon(Icons.calendar_month_rounded, color: _selectedDate == null ? AppColors.textDark : primary),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Foto transaksi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  const Text('Lihat bukti pengeluaran berdasarkan kategori dan tanggal.', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChip(
                          label: 'Semua',
                          selected: _categoryId == null,
                          onTap: () => setState(() => _categoryId = null),
                          color: primary,
                        ),
                        ..._categories.map((category) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _FilterChip(
                                label: category.name,
                                selected: _categoryId == category.id,
                                onTap: () => setState(() => _categoryId = category.id),
                                color: primary,
                              ),
                            )),
                      ],
                    ),
                  ),
                  if (_selectedDate != null) ...[
                    const SizedBox(height: 10),
                    InputChip(
                      label: Text(_dateLabel(_selectedDate!)),
                      avatar: Icon(Icons.event_rounded, size: 17, color: primary),
                      onDeleted: _clearDate,
                      deleteIconColor: primary,
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_filteredExpenses.isEmpty)
            const SliverFillRemaining(child: _EmptyTransactions())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              sliver: SliverList.builder(
                itemCount: _filteredExpenses.length,
                itemBuilder: (context, index) {
                  final expense = _filteredExpenses[index];
                  final category = _categoryFor(expense.categoryId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _TransactionCard(
                      expense: expense,
                      category: category,
                      onDelete: () => _deleteExpense(expense),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({required this.label, required this.selected, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color,
      labelStyle: TextStyle(
        color: selected ? (color.computeLuminance() > 0.55 ? AppColors.textDark : Colors.white) : AppColors.textDark,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? color : AppColors.cardBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final ExpenseModel expense;
  final CategoryModel? category;
  final VoidCallback onDelete;

  const _TransactionCard({required this.expense, required this.category, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: GestureDetector(
              onTap: () => _showImage(context),
              child: Image.file(File(expense.proofPath!), height: 210, width: double.infinity, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: (category?.color ?? primary).withOpacity(0.18), borderRadius: BorderRadius.circular(13)),
                  child: Icon(category?.icon ?? Icons.category_rounded, color: category?.color ?? primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(expense.description.isEmpty ? 'Pengeluaran' : expense.description, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('${category?.name ?? 'Tanpa kategori'} · ${Formatters.date(expense.date)}', style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(Formatters.currency(expense.amount), style: TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 15)),
                    ],
                  ),
                ),
                IconButton(onPressed: onDelete, tooltip: 'Hapus', icon: const Icon(Icons.more_vert_rounded, color: AppColors.textGrey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showImage(BuildContext context) {
    if (expense.proofPath == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: InteractiveViewer(child: Image.file(File(expense.proofPath!), fit: BoxFit.contain)),
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(color: primary.withOpacity(0.18), shape: BoxShape.circle),
              child: Icon(Icons.photo_library_outlined, color: primary, size: 38),
            ),
            const SizedBox(height: 16),
            const Text('Belum ada foto transaksi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 6),
            const Text('Upload foto bukti saat mencatat pengeluaran agar foto muncul di sini.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
