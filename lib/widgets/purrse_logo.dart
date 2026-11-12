import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Lokasi aset identitas Purrse.
class PurrseAssets {
  PurrseAssets._();
  static const mark = 'assets/images/brand/purrse_mark.png';
  static const wordmark = 'assets/images/brand/purrse_wordmark.png';
  static const sparkle = 'assets/images/brand/purrse_sparkle.png';
  static const dashPurpleA = 'assets/images/brand/purrse_dash_purple_a.png';
  static const dashPurpleB = 'assets/images/brand/purrse_dash_purple_b.png';
  static const dashOrangeA = 'assets/images/brand/purrse_dash_orange_a.png';
  static const dashOrangeB = 'assets/images/brand/purrse_dash_orange_b.png';
  static const appIcon = 'assets/images/brand/purrse_app_icon.png';
}

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Kucing-dompet Purrse yang hidup:
/// - masuk dengan memantul (jatuh lalu "boing"),
/// - bernapas + bergoyang pelan saat diam,
/// - kilau jingga berkedip, garis semangat ungu bergetar,
/// - diketuk: melompat, goyang, dan kilau meledak kecil.
/// Semua animasi mati otomatis bila pengguna mengaktifkan "kurangi gerakan".
class PurrseMark extends StatefulWidget {
  /// Lebar kucing-dompet (kilau & garis semangat boleh keluar sedikit dari kotak).
  final double size;

  /// Animasi masuk (memantul) saat pertama tampil.
  final bool intro;

  /// Animasi idle (napas, goyang, kedip kilau).
  final bool idle;

  /// Tampilkan kilau + garis semangat.
  final bool decorations;

  /// Bisa diketuk untuk bereaksi.
  final bool tappable;

  /// Jeda sebelum animasi masuk dimulai.
  final Duration introDelay;

  final String? semanticLabel;

  const PurrseMark({
    super.key,
    this.size = 120,
    this.intro = true,
    this.idle = true,
    this.decorations = true,
    this.tappable = true,
    this.introDelay = Duration.zero,
    this.semanticLabel = 'Logo Purrse: kucing di dalam dompet',
  });

  @override
  State<PurrseMark> createState() => _PurrseMarkState();
}

class _PurrseMarkState extends State<PurrseMark> with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _loop;
  late final AnimationController _tap;
  bool _started = false;

  // Proporsi aset (mark = 1.0 lebar). Diukur dari berkas branding.
  static const double _aspect = 578 / 560;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
    _tap = AnimationController(vsync: this, duration: const Duration(milliseconds: 760));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_reduceMotion(context)) {
      _intro.value = 1;
      return;
    }
    Future<void> start() async {
      if (widget.intro) {
        if (widget.introDelay > Duration.zero) await Future.delayed(widget.introDelay);
        if (!mounted) return;
        await _intro.forward();
      } else {
        _intro.value = 1;
      }
      if (mounted && widget.idle) _loop.repeat(count: 4);
    }

    start();
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    _tap.dispose();
    super.dispose();
  }

  void _onTap() {
    if (!widget.tappable || _reduceMotion(context)) return;
    HapticFeedback.lightImpact();
    _tap.forward(from: 0);
    if (widget.idle && !_loop.isAnimating) _loop.repeat(count: 2);
  }

  Widget _img(String asset, double width, {double? height}) => Image.asset(
        asset,
        width: width,
        height: height,
        fit: BoxFit.contain,
        // Decode sesuai ukuran tampil (hemat memori & raster ringan).
        cacheWidth: (width * 3).round(),
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      );

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    final h = w * _aspect;

    // Gambar dibuat SEKALI; animasi hanya mengubah matriks transform.
    final markImg = Semantics(
      label: widget.semanticLabel,
      image: true,
      child: ExcludeSemantics(child: _img(PurrseAssets.mark, w, height: h)),
    );
    final sparkleImg = _img(PurrseAssets.sparkle, w * 0.207);
    final dashA = _img(PurrseAssets.dashPurpleA, w * 0.114);
    final dashB = _img(PurrseAssets.dashPurpleB, w * 0.141);

    final body = AnimatedBuilder(
      animation: Listenable.merge([_intro, _loop, _tap]),
      child: markImg,
      builder: (context, markChild) {
        final i = _intro.value;
        final l = _loop.value * 2 * math.pi;
        final t = _tap.value;

        // Masuk: jatuh dari atas, memantul (elastic) + sedikit gepeng.
        final drop = Curves.elasticOut.transform(i.clamp(0.0, 1.0));
        double dy = (1 - drop) * -h * 0.55;
        final baseScale = 0.55 + 0.45 * drop;
        double squashX = 1, squashY = 1;
        final land = (i > 0.0 && i < 0.5) ? math.sin(i / 0.5 * math.pi) : 0.0;
        squashX += 0.05 * land;
        squashY -= 0.05 * land;

        // Idle: bernapas + melayang + miring pelan.
        final breathe = math.sin(l);
        squashY += 0.018 * breathe;
        squashX -= 0.010 * breathe;
        dy += -h * 0.012 * math.cos(l);
        double rot = 0.022 * math.sin(l * 0.5);

        // Ketuk: lompat, mendarat gepeng, lalu goyang meredam.
        if (t > 0) {
          dy += -h * 0.16 * math.sin(math.pi * math.min(t / 0.55, 1.0)).abs();
          if (t > 0.5) {
            final k = (t - 0.5) / 0.5;
            final sq = math.sin(math.min(k * 2, 1.0) * math.pi);
            rot += 0.16 * math.sin(k * 3 * math.pi) * (1 - k);
            squashY -= 0.07 * sq;
            squashX += 0.07 * sq;
          }
        }

        // Satu matriks (translate + rotate + scale) berporos di dasar gambar.
        final m = Matrix4.identity()
          ..translate(w / 2, h + dy)
          ..rotateZ(rot)
          ..scale(baseScale * squashX, baseScale * squashY, 1.0)
          ..translate(-w / 2, -h);
        final mark = Transform(transform: m, child: markChild);

        if (!widget.decorations) return mark;

        final popIn = Curves.easeOutBack.transform(((i - 0.45) / 0.45).clamp(0.0, 1.0));
        final twinkle = 0.5 + 0.5 * math.sin(l * 2 + 1.2);
        final burst = t > 0 ? math.sin(math.pi * t) : 0.0;
        final sparkleScale = popIn * (0.85 + 0.25 * twinkle + 0.35 * burst);
        final sparkleTurn = (0.08 * math.sin(l) + 0.6 * burst) * math.pi / 2;

        final dashIn = Curves.easeOut.transform(((i - 0.6) / 0.35).clamp(0.0, 1.0));
        final shake = math.sin(l * 4) * 0.02 * (idleOn ? 1 : 0) + burst * 0.1;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: 0, top: 0, child: mark),
            Positioned(
              left: w * 0.825,
              top: h * 0.049,
              child: Opacity(
                opacity: popIn.clamp(0.0, 1.0),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..rotateZ(sparkleTurn)
                    ..scale(sparkleScale, sparkleScale, 1.0),
                  child: sparkleImg,
                ),
              ),
            ),
            Positioned(
              left: -w * 0.092 - w * 0.04 * (1 - dashIn) + w * shake,
              top: h * 0.198,
              child: Opacity(opacity: dashIn, child: dashA),
            ),
            Positioned(
              left: -w * 0.166 - w * 0.04 * (1 - dashIn) - w * shake,
              top: h * 0.299,
              child: Opacity(opacity: dashIn, child: dashB),
            ),
          ],
        );
      },
    );

    // RepaintBoundary: animasi logo tidak ikut memicu repaint halaman.
    final sized = RepaintBoundary(child: SizedBox(width: w, height: h, child: body));
    if (!widget.tappable) return sized;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: sized,
    );
  }

  bool get idleOn => widget.idle && !_reduceMotion(context);
}

/// Logo lengkap: kucing-dompet + tulisan "Purrse". Tulisan meluncur masuk
/// setelah kucing mendarat; warnanya mengikuti tema (terang/gelap).
class PurrseLogo extends StatefulWidget {
  /// Lebar kucing-dompet; tulisan menyesuaikan.
  final double markSize;
  final Axis axis;
  final bool intro;
  final bool idle;

  const PurrseLogo({
    super.key,
    this.markSize = 120,
    this.axis = Axis.horizontal,
    this.intro = true,
    this.idle = true,
  });

  @override
  State<PurrseLogo> createState() => _PurrseLogoState();
}

class _PurrseLogoState extends State<PurrseLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _word;
  bool _started = false;

  // wordmark.png: 1710 x 475
  static const double _wordAspect = 211 / 760;

  @override
  void initState() {
    super.initState();
    _word = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.intro || _reduceMotion(context)) {
      _word.value = 1;
    } else {
      Future.delayed(const Duration(milliseconds: 520), () {
        if (mounted) _word.forward();
      });
    }
  }

  @override
  void dispose() {
    _word.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    final markW = widget.markSize;
    final wordH = markW * (horizontal ? 0.52 : 0.36) * 1.0;
    final wordW = wordH / _wordAspect;

    final word = AnimatedBuilder(
      animation: _word,
      builder: (context, child) {
        final t = Curves.easeOutBack.transform(_word.value.clamp(0.0, 1.0));
        final dx = horizontal ? (1 - t) * 26 : 0.0;
        final dy = horizontal ? 0.0 : (1 - t) * 14;
        return Opacity(
          opacity: _word.value.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(dx, dy), child: child),
        );
      },
      // Tulisan berwarna "tinta teks" tema agar terbaca di mode gelap.
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(AppColors.textDark, BlendMode.srcIn),
        child: Image.asset(
          PurrseAssets.wordmark,
          width: wordW,
          height: wordH,
          fit: BoxFit.contain,
          cacheWidth: (wordW * 3).round(),
          filterQuality: FilterQuality.medium,
          semanticLabel: 'Purrse',
        ),
      ),
    );

    final mark = PurrseMark(size: markW, intro: widget.intro, idle: widget.idle);

    if (horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [mark, SizedBox(width: markW * 0.14), word],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [mark, SizedBox(height: markW * 0.12), word],
    );
  }
}

/// Tiga titik memantul bergantian (indikator memuat yang lucu).
class PurrseDots extends StatefulWidget {
  final double size;
  final Color? color;
  const PurrseDots({super.key, this.size = 10, this.color});

  @override
  State<PurrseDots> createState() => _PurrseDotsState();
}

class _PurrseDotsState extends State<PurrseDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.ink;
    final still = _reduceMotion(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.size * 0.28),
                child: Transform.translate(
                  offset: Offset(0, still ? 0 : -widget.size * 0.9 * _bounce((_c.value - i * 0.16) % 1.0)),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: i == 1 ? AppColors.brandAccent : color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  double _bounce(double v) => v < 0.4 ? math.sin(v / 0.4 * math.pi) : 0.0;
}

/// Tampilan kosong yang ramah: kucing melayang pelan + judul + keterangan.
class PurrseEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final double markSize;
  final Widget? action;

  const PurrseEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.markSize = 96,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PurrseMark(size: markSize, semanticLabel: null),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textGrey, fontSize: 13, height: 1.5),
        ),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    );
  }
}

/// Snackbar lucu bertema kucing: logo kecil memantul di sebelah pesan.
void showPurrseSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const PurrseMark(size: 30, decorations: false, tappable: false, idle: false),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    ),
  );
}
