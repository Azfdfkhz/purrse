import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import '../screens/expense/add_expense_modal.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'purrse_logo.dart';
import 'ui_kit.dart';

enum _ExpenseAction { edit, delete }

/// Popup saat sebuah pengeluaran diketuk: pilih Edit atau Hapus.
/// Mengembalikan true bila data berubah (diedit atau dihapus) sehingga
/// pemanggil perlu memuat ulang daftar.
Future<bool> showExpenseActions(BuildContext context, ExpenseModel expense) async {
  final action = await showModalBottomSheet<_ExpenseAction>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              expense.description.isEmpty ? 'Pengeluaran' : expense.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
            const SizedBox(height: 2),
            Text(
              '${Formatters.rupiah(expense.amount)} • ${Formatters.date(expense.date)}',
              style: TextStyle(fontSize: 13, color: AppColors.textGrey),
            ),
            const SizedBox(height: 16),
            _ActionTile(
              icon: Icons.edit_rounded,
              label: 'Edit',
              hint: 'Perbaiki nominal, kategori, atau catatan',
              color: AppColors.textDark,
              onTap: () => Navigator.pop(sheetContext, _ExpenseAction.edit),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Hapus',
              hint: 'Salah memasukkan? Hapus dari riwayat',
              color: AppColors.isDark ? const Color(0xFFFF8A80) : AppColors.danger,
              onTap: () => Navigator.pop(sheetContext, _ExpenseAction.delete),
            ),
          ],
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) return false;

  if (action == _ExpenseAction.edit) {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (_) => AddExpenseModal(expense: expense),
    );
    return saved == true;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Hapus pengeluaran?'),
      content: const Text('Pengeluaran ini akan dihapus dari riwayat.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Hapus')),
      ],
    ),
  );
  if (confirmed != true) return false;
  await StorageService.instance.deleteExpense(expense.userId, expense.id);
  if (context.mounted) showPurrseSnack(context, 'Sudah dihapus 🐾');
  return true;
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
                  Text(hint, style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
