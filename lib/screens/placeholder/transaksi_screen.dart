import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';
import '../../services/google_drive_service.dart';
import '../../services/proof_upload_service.dart';
import '../../services/storage_service.dart';
import '../expense/add_expense_modal.dart';
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

  StreamSubscription<void>? _uploadSub;

  @override
  void initState() {
    super.initState();
    reload();
    _uploadSub = ProofUploadService.instance.changes.listen((_) => reload());
  }

  @override
  void dispose() {
    _uploadSub?.cancel();
    super.dispose();
  }

  Future<void> _edit(ExpenseModel expense) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (_) => AddExpenseModal(expense: expense),
    );
    if (saved == true) await reload();
  }

  Future<void> _retryUpload(ExpenseModel expense) async {
    if (_userId == null) return;
    await ProofUploadService.instance.retry(_userId!, expense.id);
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
    return _expenses.where((expense) {
      final localOk = expense.proofPath != null && File(expense.proofPath!).existsSync();
      return localOk || expense.driveFileId != null;
    }).toList();
  }

  List<ExpenseModel> get _filteredExpenses {
    return _photoExpenses.where((expense) {
      final categoryMatch = _categoryId == null || expense.categoryId == _categoryId;
      final dateMatch = _selectedDate == null ||
          ExpenseModel.dateKey(expense.date) == ExpenseModel.dateKey(_selectedDate!);
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
        title: Text('Hapus transaksi?'),
        content: Text('Transaksi ini akan dihapus dari riwayat pengeluaran.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true) return;
    await StorageService.instance.deleteExpense(_userId!, expense.id);
    await reload();
  }

  bool get _hasFilter => _categoryId != null || _selectedDate != null;

  void _resetFilters() => setState(() {
        _categoryId = null;
        _selectedDate = null;
      });

  /// Daftar bergrup per tanggal: header hari (+ total hari) lalu kartu transaksi.
  List<Object> _buildRows(List<ExpenseModel> items) {
    final totals = <String, double>{};
    for (final e in items) {
      final k = ExpenseModel.dateKey(e.date);
      totals[k] = (totals[k] ?? 0) + e.amount;
    }
    final rows = <Object>[];
    String? current;
    for (final e in items) {
      final k = ExpenseModel.dateKey(e.date);
      if (k != current) {
        current = k;
        rows.add(_DayHeader(e.date, totals[k] ?? 0));
      }
      rows.add(e);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredExpenses;
    final rows = _buildRows(items);
    final total = items.fold<double>(0, (sum, e) => sum + e.amount);

    return RefreshIndicator(
      color: AppColors.textDark,
      onRefresh: reload,
      child: CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            title: Text('Transaksi', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter: tanggal + kategori dalam satu baris yang bisa digeser.
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _DateChip(
                          label: _selectedDate == null ? 'Tanggal' : Formatters.date(_selectedDate!),
                          active: _selectedDate != null,
                          onTap: _pickDate,
                          onClear: _clearDate,
                        ),
                        SizedBox(width: 8),
                        _FilterChip(
                          label: 'Semua',
                          selected: _categoryId == null,
                          onTap: () => setState(() => _categoryId = null),
                        ),
                        ..._categories.map((category) => Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: _FilterChip(
                                label: category.name,
                                selected: _categoryId == category.id,
                                onTap: () => setState(() => _categoryId = category.id),
                              ),
                            )),
                      ],
                    ),
                  ),
                  if (!_loading && items.isNotEmpty) ...[
                    SizedBox(height: 6),
                    Text(
                      '${items.length} foto bukti · ${Formatters.rupiah(total)}',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                  SizedBox(height: 8),
                ],
              ),
            ),
          ),
          if (_loading)
            SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
          else if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyTransactions(filtered: _hasFilter, onReset: _resetFilters),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 120), // ruang agar tidak tertutup navbar
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  if (row is _DayHeader) {
                    return Padding(
                      padding: EdgeInsets.only(top: index == 0 ? 4 : 18, bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                Formatters.relativeDay(row.date),
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark),
                              ),
                            ),
                          ),
                          Text(
                            Formatters.rupiah(row.total),
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    );
                  }
                  final expense = row as ExpenseModel;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: _TransactionCard(
                      key: ValueKey(expense.id),
                      expense: expense,
                      category: _categoryFor(expense.categoryId),
                      onDelete: () => _deleteExpense(expense),
                      onEdit: () => _edit(expense),
                      onRetry: () => _retryUpload(expense),
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

class _DayHeader {
  final DateTime date;
  final double total;
  const _DayHeader(this.date, this.total);
}

class _DateChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateChip({required this.label, required this.active, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: active ? 'Filter tanggal $label, ketuk untuk ubah' : 'Filter tanggal',
        child: InputChip(
          avatar: Icon(Icons.calendar_month_rounded, size: 18, color: active ? Colors.white : AppColors.textDark),
          label: Text(label),
          onPressed: onTap,
          onDeleted: active ? onClear : null,
          deleteIconColor: Colors.white,
          deleteButtonTooltipMessage: 'Hapus filter tanggal',
          backgroundColor: active ? AppColors.ink : AppColors.surface,
          labelStyle: TextStyle(
            color: active ? Colors.white : AppColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          side: BorderSide(color: active ? AppColors.ink : AppColors.border, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.ink,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textDark,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        backgroundColor: AppColors.surface,
        side: BorderSide(color: selected ? AppColors.ink : AppColors.border, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final ExpenseModel expense;
  final CategoryModel? category;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onRetry;

  const _TransactionCard({
    super.key,
    required this.expense,
    required this.category,
    required this.onDelete,
    required this.onEdit,
    required this.onRetry,
  });

  bool get _localExists => expense.proofPath != null && File(expense.proofPath!).existsSync();

  Widget _image({required double height, required BoxFit fit}) {
    if (_localExists) {
      return Image.file(File(expense.proofPath!), height: height, width: double.infinity, fit: fit);
    }
    return _DriveImage(fileId: expense.driveFileId!, height: height, fit: fit);
  }

  (String, Color, IconData) _uploadInfo() {
    switch (expense.uploadStatus) {
      case UploadStatus.uploaded:
        return ('Tersimpan di Drive', AppColors.isDark ? Color(0xFF81C995) : Color(0xFF2E7D32), Icons.cloud_done_rounded);
      case UploadStatus.uploading:
        return ('Mengunggah…', AppColors.isDark ? Color(0xFF90CAF9) : Color(0xFF1565C0), Icons.cloud_upload_rounded);
      case UploadStatus.failed:
        return ('Upload gagal', AppColors.isDark ? Color(0xFFEF9A9A) : Color(0xFFC62828), Icons.cloud_off_rounded);
      case UploadStatus.needsAuth:
        return ('Hubungkan Drive', AppColors.isDark ? Color(0xFFFFB74D) : Color(0xFFB45309), Icons.link_off_rounded);
      default:
        return ('Menunggu upload', AppColors.textGrey, Icons.cloud_queue_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = category?.color ?? Theme.of(context).colorScheme.primary;
    final title = expense.description.isEmpty ? 'Pengeluaran' : expense.description;
    final (statusLabel, statusColor, statusIcon) = _uploadInfo();
    final canRetry = expense.uploadStatus == UploadStatus.failed ||
        expense.uploadStatus == UploadStatus.needsAuth;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.hairline, width: 1),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Foto di atas, rasio tetap agar kartu konsisten di semua lebar layar.
          Semantics(
            button: true,
            label: 'Lihat foto bukti $title',
            child: GestureDetector(
              onTap: () => _showImage(context),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: _image(height: double.infinity, fit: BoxFit.cover),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: catColor, borderRadius: BorderRadius.circular(12)),
                  child: Icon(category?.icon ?? Icons.category_rounded, color: AppColors.onColor(catColor), size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark, fontSize: 15),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${category?.name ?? 'Tanpa kategori'} · ${Formatters.date(expense.date)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    Formatters.currency(expense.amount),
                    style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Menu transaksi',
                  icon: Icon(Icons.more_vert_rounded, color: AppColors.textGrey),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.cardBorder),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 2, 8, 2),
            child: Row(
              children: [
                Icon(statusIcon, size: 18, color: statusColor),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w700),
                  ),
                ),
                if (canRetry) TextButton(onPressed: onRetry, child: Text('Coba lagi')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showImage(BuildContext context) {
    if (!_localExists && expense.driveFileId == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: InteractiveViewer(child: _image(height: 520, fit: BoxFit.contain)),
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  final bool filtered;
  final VoidCallback onReset;
  const _EmptyTransactions({required this.filtered, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(28, 28, 28, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
              child: Icon(
                filtered ? Icons.filter_alt_off_rounded : Icons.photo_library_outlined,
                color: AppColors.onColor(primary),
                size: 38,
              ),
            ),
            SizedBox(height: 16),
            Text(
              filtered ? 'Tidak ada foto yang cocok' : 'Belum ada foto transaksi',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textDark),
            ),
            SizedBox(height: 6),
            Text(
              filtered
                  ? 'Coba ganti kategori atau tanggal, atau tampilkan semua foto.'
                  : 'Upload foto bukti saat mencatat pengeluaran agar foto muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey, fontSize: 14, height: 1.35),
            ),
            if (filtered) ...[
              SizedBox(height: 16),
              OutlinedButton(onPressed: onReset, child: Text('Tampilkan semua')),
            ],
          ],
        ),
      ),
    );
  }
}


/// Foto dari Google Drive (saat file lokal tidak ada, mis. perangkat lain).
class _DriveImage extends StatefulWidget {
  final String fileId;
  final double height;
  final BoxFit fit;
  const _DriveImage({required this.fileId, required this.height, required this.fit});

  @override
  State<_DriveImage> createState() => _DriveImageState();
}

class _DriveImageState extends State<_DriveImage> {
  late Future<Uint8List> _future = GoogleDriveService.instance.downloadProof(widget.fileId);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: FutureBuilder<Uint8List>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _future = GoogleDriveService.instance.downloadProof(widget.fileId);
                }),
                icon: Icon(Icons.refresh_rounded),
                label: Text('Foto belum bisa dimuat. Ketuk untuk coba lagi'),
              ),
            );
          }
          return Image.memory(snap.data!, fit: widget.fit, width: double.infinity);
        },
      ),
    );
  }
}
