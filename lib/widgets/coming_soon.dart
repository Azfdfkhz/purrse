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
            decoration: BoxDecoration(color: AppColors.softPurple, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
          ),
          SizedBox(height: 16),
          Text('Halaman $title', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          SizedBox(height: 6),
          Text('Segera hadir', style: TextStyle(color: AppColors.textGrey)),
        ],
      ),
    );
  }
}
