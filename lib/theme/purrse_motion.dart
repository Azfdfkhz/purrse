import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Transisi halaman Purrse: fade + naik sedikit + membesar halus, seperti
/// kucing yang melongok dari dompet. iOS/macOS tetap memakai transisi native
/// (gestur geser-kembali tetap berfungsi).
class PurrsePageTransitions {
  PurrsePageTransitions._();

  static const PageTransitionsTheme theme = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: PurrsePageTransitionsBuilder(),
      TargetPlatform.fuchsia: PurrsePageTransitionsBuilder(),
      TargetPlatform.windows: PurrsePageTransitionsBuilder(),
      TargetPlatform.linux: PurrsePageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );
}

class PurrsePageTransitionsBuilder extends PageTransitionsBuilder {
  const PurrsePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;

    final enter = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final cover = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return ScaleTransition(
      // Halaman di bawah mengecil sedikit saat halaman baru menutupinya.
      scale: Tween<double>(begin: 1.0, end: 0.97).animate(cover),
      child: FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(enter),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1.0).animate(enter),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Kurva "membal" yang lembut untuk animasi lucu (tidak berlebihan).
class PurrseCurves {
  PurrseCurves._();
  static const Curve bounce = Curves.elasticOut;
  static const Curve pop = Curves.easeOutBack;
  static const Curve smooth = Curves.easeOutCubic;
}
