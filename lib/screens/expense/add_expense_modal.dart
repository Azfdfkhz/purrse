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
    if (digits.isEmpty) return TextEditingValue();
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
  String? _amountError;
  String? _categoryError;
  bool _loadFailed = false;

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
    if (user == null) {
      if (mounted) setState(() { _loading = false; _loadFailed = true; });
      return;
    }
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
        title: Text('Kategori baru'),
        content: TextField(controller: controller, decoration: InputDecoration(hintText: 'Nama kategori')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text('Tambah')),
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
    String? amountError;
    if (amount == null || amount <= 0) {
      amountError = 'Jumlah harus lebih dari 0';
    } else if (amount > _maxAmount) {
      amountError = 'Jumlah terlalu besar';
    }
    final categoryError = (_selectedCategoryId == null || _userId == null)
        ? 'Pilih satu kategori'
        : null;
    if (amountError != null || categoryError != null) {
      setState(() {
        _amountError = amountError;
        _categoryError = categoryError;
      });
      return;
    }
    setState(() => _saving = true);
    try {
      final old = widget.expense;
      final proofChanged = old == null || old.proofPath != _proofPath;
      final String savedId;
      if (old == null) {
        final expense = ExpenseModel(
          id: Uuid().v4(),
          userId: _userId!,
          categoryId: _selectedCategoryId!,
          amount: amount!,
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
            amount: amount!,
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

  Widget _label(String text) => Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textDark)),
      );

  Widget _errorText(String? msg) => msg == null
      ? SizedBox.shrink()
      : Padding(
          padding: EdgeInsets.only(top: 6, left: 4),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
              SizedBox(width: 6),
              Expanded(
                child: Text(msg,
                    style: TextStyle(
                        color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Tinggi sheet mengikuti ruang yang tersisa di atas keyboard.
    final maxSheet = (mq.size.height - mq.viewInsets.bottom) * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: AppColors.onInk,
                  shape: StadiumBorder(),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: Icon(Icons.arrow_back_rounded, size: 18),
                label: Text('Kembali', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            constraints: BoxConstraints(maxHeight: maxSheet),
            padding: EdgeInsets.fromLTRB(22, 22, 22, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              
            ),
            child: _loading
                ? Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _loadFailed
                    ? Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Data akun tidak dapat dimuat. Tutup lalu coba lagi.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEdit ? 'Edit Pengeluaran' : 'Tambah Pengeluaran',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
                          ),
                          SizedBox(height: 14),
                          Flexible(
                            child: SingleChildScrollView(
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Jumlah'),
                                  TextField(
                                    controller: _amountController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [_ThousandsFormatter()],
                                    onChanged: (_) {
                                      if (_amountError != null) setState(() => _amountError = null);
                                    },
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                                    decoration: InputDecoration(
                                      prefixText: 'Rp ',
                                      hintText: '0',
                                      filled: true,
                                      fillColor: AppColors.surfaceVariant,
                                      contentPadding:
                                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: _amountError == null ? AppColors.border : AppColors.danger,
                                          width: 1,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: _amountError == null ? AppColors.border : AppColors.danger,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _errorText(_amountError),
                                  SizedBox(height: 20),
                                  _label('Kategori'),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      ..._categories.map((c) {
                                        final selected = c.id == _selectedCategoryId;
                                        return Semantics(
                                          button: true,
                                          selected: selected,
                                          label: 'Kategori ${c.name}',
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => setState(() {
                                              _selectedCategoryId = c.id;
                                              _categoryError = null;
                                            }),
                                            child: SizedBox(
                                              width: 64,
                                              child: Column(
                                                children: [
                                                  AnimatedContainer(
                                                    duration: motion(context, 180),
                                                    width: 52,
                                                    height: 52,
                                                    decoration: BoxDecoration(
                                                      color: c.color,
                                                      borderRadius: BorderRadius.circular(18),
                                                      border: selected
                                                          ? Border.all(color: AppColors.ink, width: 2)
                                                          : null,
                                                    ),
                                                    child: Icon(
                                                      selected ? Icons.check_rounded : c.icon,
                                                      color: AppColors.ink,
                                                      size: 22,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    c.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          selected ? FontWeight.w800 : FontWeight.w500,
                                                      color: AppColors.textDark,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                      Semantics(
                                        button: true,
                                        label: 'Tambah kategori',
                                        child: GestureDetector(
                                          onTap: _addCategoryDialog,
                                          child: Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceVariant,
                                              borderRadius: BorderRadius.circular(18),
                                              border: Border.all(color: AppColors.border),
                                            ),
                                            child: Icon(Icons.add_rounded, color: AppColors.textGrey),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  _errorText(_categoryError),
                                  SizedBox(height: 20),
                                  _label('Tanggal'),
                                  InkWell(
                                    onTap: _pickDate,
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      constraints: BoxConstraints(minHeight: 52),
                                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_today_rounded,
                                              size: 18, color: AppColors.textGrey),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              Formatters.date(_date),
                                              style: TextStyle(
                                                  fontSize: 15, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                          Text('Ubah',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.textGrey)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  _label('Deskripsi (opsional)'),
                                  TextField(
                                    controller: _descController,
                                    textCapitalization: TextCapitalization.sentences,
                                    decoration: InputDecoration(
                                      hintText: 'Contoh: makan siang',
                                      contentPadding:
                                          EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: AppColors.border),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  _label('Bukti (opsional)'),
                                  InkWell(
                                    onTap: _pickImage,
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      constraints: BoxConstraints(minHeight: 52),
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _proofPath == null
                                                ? Icons.add_photo_alternate_outlined
                                                : Icons.check_circle_rounded,
                                            size: 20,
                                            color: _proofPath == null
                                                ? AppColors.textGrey
                                                : AppColors.success,
                                          ),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _proofPath == null
                                                  ? 'Unggah foto bukti'
                                                  : 'Foto dipilih (ketuk untuk ganti)',
                                              style: TextStyle(
                                                  fontSize: 14, color: AppColors.textDark),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          // Tombol simpan di luar area scroll: tidak tertutup keyboard.
                          InkButton(
                            label: _isEdit ? 'Perbarui' : 'Simpan',
                            loading: _saving,
                            onPressed: _saving ? null : _save,
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
