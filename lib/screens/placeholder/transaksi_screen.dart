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
      selectedColor: AppColors.ink,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textDark,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(color: AppColors.ink, width: selected ? 1.5 : 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
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
        return ('Tersimpan di Drive', const Color(0xFF2E7D32), Icons.cloud_done_rounded);
      case UploadStatus.uploading:
        return ('Mengunggah…', const Color(0xFF1565C0), Icons.cloud_upload_rounded);
      case UploadStatus.failed:
        return ('Upload gagal', const Color(0xFFC62828), Icons.cloud_off_rounded);
      case UploadStatus.needsAuth:
        return ('Hubungkan Drive', const Color(0xFFEF6C00), Icons.link_off_rounded);
      default:
        return ('Menunggu upload', AppColors.textGrey, Icons.cloud_queue_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: GestureDetector(
              onTap: () => _showImage(context),
              child: _image(height: 210, fit: BoxFit.cover),
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
                      Text(Formatters.currency(expense.amount), style: TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(height: 8),
                      Builder(builder: (_) {
                        final (label, color, icon) = _uploadInfo();
                        final canRetry = expense.uploadStatus == UploadStatus.failed ||
                            expense.uploadStatus == UploadStatus.needsAuth;
                        return Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Icon(icon, size: 16, color: color),
                            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
                            if (canRetry)
                              InkWell(
                                onTap: onRetry,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                  child: Text('Coba lagi', style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w800)),
                                ),
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Menu transaksi',
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textGrey),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
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
        insetPadding: const EdgeInsets.all(18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: InteractiveViewer(child: _image(height: 520, fit: BoxFit.contain)),
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
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _future = GoogleDriveService.instance.downloadProof(widget.fileId);
                }),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Foto belum bisa dimuat. Ketuk untuk coba lagi'),
              ),
            );
          }
          return Image.memory(snap.data!, fit: widget.fit, width: double.infinity);
        },
      ),
    );
  }
}
