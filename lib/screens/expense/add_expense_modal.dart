import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';
import '../../services/proof_upload_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/ui_kit.dart';

/// Memformat angka dengan pemisah ribuan titik (1.250.000) saat mengetik.
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final buf = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i > 0 && (trimmed.length - i) % 3 == 0) buf.write('.');
      buf.write(trimmed[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class AddExpenseModal extends StatefulWidget {
  /// Tanggal awal formulir (mis. tanggal yang dipilih di kalender).
  /// Jika null, memakai hari ini.
  final DateTime? initialDate;

  /// Jika diisi, formulir berada dalam mode edit.
  final ExpenseModel? expense;

  const AddExpenseModal({super.key, this.initialDate, this.expense});

  @override
  State<AddExpenseModal> createState() => _AddExpenseModalState();
}

class _AddExpenseModalState extends State<AddExpenseModal> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  late DateTime _date;
  bool get _isEdit => widget.expense != null;
  static const double _maxAmount = 9999999999999;
  String? _selectedCategoryId;
  String? _proofPath;
  List<CategoryModel> _categories = [];
  bool _loading = true;
  bool _saving = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    final edit = widget.expense;
    _date = ExpenseModel.dateOnly(
      edit?.date ?? widget.initialDate ?? DateTime.now(),
    );
    if (edit != null) {
      _amountController.text = Formatters.digitsWithDots(edit.amount);
      _descController.text = edit.description;
      _proofPath = edit.proofPath;
    }
    _load();
  }

  Future<void> _load() async {
    final user = await StorageService.instance.getCurrentUser();
    if (user == null) return;
    final cats = await StorageService.instance.getCategories(user.id);
    setState(() {
      _userId = user.id;
      _categories = cats;
      final editCat = widget.expense?.categoryId;
      _selectedCategoryId = (editCat != null && cats.any((c) => c.id == editCat))
          ? editCat
          : (cats.isNotEmpty ? cats.first.id : null);
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = ExpenseModel.dateOnly(picked));
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (file != null) setState(() => _proofPath = file.path);
    } catch (_) {
    }
  }

  Future<void> _addCategoryDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kategori baru'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Nama kategori')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Tambah')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && _userId != null) {
      final palette = AppColors.categoryPalette;
      final color = palette[_categories.length % palette.length];
      final newCat = await StorageService.instance.addCategory(_userId!, result, color, Icons.category_rounded);
      setState(() {
        _categories.add(newCat);
        _selectedCategoryId = newCat.id;
      });
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    if (_saving) return;
    // Rupiah tidak memakai desimal: hanya digit yang diterima.
    final digits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = digits.isEmpty ? null : double.tryParse(digits);
    if (amount == null || amount <= 0) {
      _toast('Jumlah harus lebih dari 0');
      return;
    }
    if (amount > _maxAmount) {
      _toast('Jumlah terlalu besar');
      return;
    }
    if (_selectedCategoryId == null || _userId == null) {
      _toast('Pilih kategori terlebih dahulu');
      return;
    }
    setState(() => _saving = true);
    try {
      final old = widget.expense;
      final proofChanged = old == null || old.proofPath != _proofPath;
      final String savedId;
      if (old == null) {
        final expense = ExpenseModel(
          id: const Uuid().v4(),
          userId: _userId!,
          categoryId: _selectedCategoryId!,
          amount: amount,
          date: _date,
          description: _descController.text.trim(),
          proofPath: _proofPath,
        );
        await StorageService.instance.addExpense(expense);
        savedId = expense.id;
      } else {
        await StorageService.instance.updateExpense(
          old.copyWith(
            categoryId: _selectedCategoryId,
            amount: amount,
            date: _date,
            description: _descController.text.trim(),
            proofPath: _proofPath,
            clearProof: _proofPath == null,
            // Foto diganti -> upload ulang; foto sama -> status dipertahankan.
            clearDriveFileId: proofChanged,
          ),
        );
        savedId = old.id;
      }
      // Transaksi sudah tersimpan. Upload foto berjalan terpisah:
      // kegagalan upload tidak membatalkan penyimpanan transaksi.
      if (_proofPath != null && proofChanged) {
        await ProofUploadService.instance.enqueue(_userId!, savedId);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Gagal menyimpan transaksi. Coba lagi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Kembali', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(top: BorderSide(color: AppColors.ink, width: 2)),
            ),
            child: _loading
                ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isEdit ? 'Edit Pengeluaran' : 'Jumlah Pengeluaran:', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [_ThousandsFormatter()],
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                          decoration: InputDecoration(
                            prefixText: 'Rp ',
                            hintText: '0',
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ..._categories.map((c) {
                              final selected = c.id == _selectedCategoryId;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedCategoryId = c.id),
                                child: Column(
                                  children: [
                                    AnimatedContainer(
                                      duration: motion(context, 180),
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: c.color,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: AppColors.ink,
                                          width: selected ? 2.5 : 1,
                                        ),
                                      ),
                                      child: Icon(c.icon, color: AppColors.ink, size: 22),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(c.name, style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              );
                            }),
                            GestureDetector(
                              onTap: _addCategoryDialog,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppColors.cardBorder),
                                ),
                                child: const Icon(Icons.add_rounded, color: AppColors.textGrey),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Tanggal:', style: TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: _pickDate,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.cardBorder),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(Formatters.date(_date), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                          const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textGrey),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Deskripsi:', style: TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _descController,
                                    decoration: InputDecoration(
                                      hintText: 'Catatan',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: AppColors.cardBorder),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text('Bukti (opsional)', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: Text(
                                    _proofPath == null ? 'upload foto' : 'Foto dipilih (ketuk untuk ganti)',
                                    style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.ink,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size(110, 54),
                                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(_isEdit ? 'Perbarui' : 'Simpan', style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ],
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
