import 'package:flutter/material.dart';
import '../../models/category_model.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';

const List<IconData> _iconChoices = [
  Icons.restaurant_rounded,
  Icons.movie_filter_rounded,
  Icons.moped_rounded,
  Icons.category_rounded,
  Icons.shopping_bag_rounded,
  Icons.home_rounded,
  Icons.medical_services_rounded,
  Icons.school_rounded,
  Icons.pets_rounded,
  Icons.flight_rounded,
  Icons.sports_esports_rounded,
  Icons.local_cafe_rounded,
  Icons.fitness_center_rounded,
  Icons.card_giftcard_rounded,
  Icons.receipt_long_rounded,
  Icons.movie,
];

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  String? _userId;
  List<CategoryModel> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await StorageService.instance.getCurrentUser();
    if (user == null) return;
    final cats = await StorageService.instance.getCategories(user.id);
    setState(() {
      _userId = user.id;
      _categories = cats;
      _loading = false;
    });
  }

  Future<void> _openEditor({CategoryModel? existing}) async {
    if (_userId == null) return;
    final result = await showModalBottomSheet<_CategoryDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _CategoryEditorSheet(existing: existing),
    );
    if (result == null) return;

    if (existing == null) {
      final newCat = await StorageService.instance.addCategory(_userId!, result.name, result.color, result.icon);
      setState(() => _categories = [..._categories, newCat]);
    } else {
      final updated = CategoryModel(id: existing.id, name: result.name, color: result.color, icon: result.icon);
      await StorageService.instance.updateCategory(_userId!, updated);
      setState(() {
        _categories = _categories.map((c) => c.id == existing.id ? updated : c).toList();
      });
    }
  }

  Future<void> _delete(CategoryModel category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus kategori?'),
        content: Text('Kategori "${category.name}" akan dihapus. Pengeluaran lama tetap tersimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && _userId != null) {
      await StorageService.instance.deleteCategory(_userId!, category.id);
      setState(() => _categories = _categories.where((c) => c.id != category.id).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
        ),
        title: const Text('Kategori Pengeluaran', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle),
                        child: Icon(cat.icon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      IconButton(
                        onPressed: () => _openEditor(existing: cat),
                        icon: const Icon(Icons.edit_rounded, color: AppColors.textGrey, size: 20),
                      ),
                      IconButton(
                        onPressed: () => _delete(cat),
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _CategoryDraft {
  final String name;
  final Color color;
  final IconData icon;
  _CategoryDraft(this.name, this.color, this.icon);
}

class _CategoryEditorSheet extends StatefulWidget {
  final CategoryModel? existing;
  const _CategoryEditorSheet({this.existing});

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late Color _color = widget.existing?.color ?? AppColors.categoryPalette.first;
  late IconData _icon = widget.existing?.icon ?? _iconChoices.first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null ? 'Kategori baru' : 'Edit kategori',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Nama kategori',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Pilih ikon', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _iconChoices.map((icon) {
                final selected = icon == _icon;
                return GestureDetector(
                  onTap: () => setState(() => _icon = icon),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected ? _color : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? _color : AppColors.cardBorder),
                    ),
                    child: Icon(icon, color: selected ? Colors.white : AppColors.textGrey, size: 20),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            const Text('Pilih warna', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppColors.categoryPalette.map((color) {
                final selected = color.value == _color.value;
                return GestureDetector(
                  onTap: () => setState(() => _color = color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? AppColors.textDark : Colors.transparent, width: 2),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(context, _CategoryDraft(name, _color, _icon));
                },
                child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
