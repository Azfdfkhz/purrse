import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Durasi animasi yang menghormati pengaturan sistem "kurangi gerakan".
Duration motion(BuildContext context, [int ms = 200]) =>
    MediaQuery.of(context).disableAnimations ? Duration.zero : Duration(milliseconds: ms);

/// Efek tekan halus (skala kecil) untuk elemen yang bisa diketuk.
/// Tidak menunda aksi: onTap langsung dipanggil.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: motion(context, 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Muncul dengan fade + geser kecil. [index] memberi jeda bertahap antar item.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;

  const FadeSlideIn({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final d = motion(context, 220 + index.clamp(0, 5) * 50);
    if (d == Duration.zero) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: d,
      curve: Curves.easeOutCubic,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: c),
      ),
      child: child,
    );
  }
}

/// Kartu putih beroutline tinta tebal (gaya playful-minimalis).
class InkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final bool bold; // outline tebal (true) atau tipis lembut (false)

  const InkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = 24,
    this.bold = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: bold ? AppColors.ink : AppColors.cardBorder,
          width: bold ? 1.5 : 1,
        ),
      ),
      child: child,
    );
  }
}

/// Tombol utama: pil hitam, teks putih. Punya status loading & disabled.
class InkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool expand;

  const InkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Pressable(
        onTap: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: motion(context, 180),
          height: 54,
          padding: EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: enabled || loading ? AppColors.ink : AppColors.ink.withOpacity(0.35),
            borderRadius: BorderRadius.circular(30),
          ),
          child: content,
        ),
      ),
    );
  }
}
