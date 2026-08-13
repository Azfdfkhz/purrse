import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ComingSoon extends StatelessWidget {
  final String title;
  final IconData icon;

  const ComingSoon({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(color: AppColors.softPurple, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text('Halaman $title', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Segera hadir', style: TextStyle(color: AppColors.textGrey)),
        ],
      ),
    );
  }
}
