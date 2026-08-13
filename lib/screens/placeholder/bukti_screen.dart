import 'package:flutter/material.dart';
import '../../widgets/coming_soon.dart';

class BuktiScreen extends StatelessWidget {
  const BuktiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoon(title: 'Bukti', icon: Icons.receipt_long_rounded);
  }
}
