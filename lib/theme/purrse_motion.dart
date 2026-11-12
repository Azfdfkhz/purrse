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
    // Hanya fade + geser: murah di GPU, stabil di perangkat menengah.
    return FadeTransition(
      opacity: enter,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(enter),
        child: child,
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
