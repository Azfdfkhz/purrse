import 'package:flutter/material.dart';
import '../../widgets/coming_soon.dart';

class LaporanScreen extends StatelessWidget {
  const LaporanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoon(title: 'Laporan', icon: Icons.bar_chart_rounded);
  }
}
