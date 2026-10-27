import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'tour_keys.dart';

// ─────────────────────────────────────────────
// Model satu langkah panduan
// ─────────────────────────────────────────────

class _Step {
  final String title;
  final String body;
  final GlobalKey? key;   // null = tidak ada spotlight (langkah pengantar)
  final double padding;   // ruang ekstra di sekitar target

  const _Step({
    required this.title,
    required this.body,
    this.key,
    this.padding = 16,
  });
}

// ─────────────────────────────────────────────
// Daftar langkah — sesuai elemen nyata di UI
// ─────────────────────────────────────────────

final _steps = [
  _Step(
    title: 'Hai, selamat datang di Purrse! 👋',
    body: 'Yuk kenali fitur-fitur utama aplikasi ini satu per satu. '
        'Ketuk Lanjut untuk mulai.',
  ),
  _Step(
    title: '① Beranda',
    body: 'Halaman utama kamu. Berisi kartu total pengeluaran bulan ini, '
        'perbandingan dengan bulan lalu, dan ringkasan per kategori.',
    key: TourKeys.home,
    padding: 14,
  ),
  _Step(
    title: '② Tombol + (Tambah)',
    body: 'Tombol ini untuk mencatat pengeluaran baru. '
        'Isi nominal, pilih kategori, tanggal, dan catatan opsional — '
        'lalu simpan.',
    key: TourKeys.add,
    padding: 10,
  ),
  _Step(
    title: '③ Transaksi',
    body: 'Lihat semua catatan pengeluaran yang sudah tersimpan. '
        'Bisa dicari berdasarkan nama atau diurutkan berdasarkan tanggal.',
    key: TourKeys.transaksi,
    padding: 14,
  ),
  _Step(
    title: '④ Laporan',
    body: 'Analisis pengeluaranmu lewat grafik. '
        'Tersedia tampilan harian dan bulanan agar kamu bisa melacak '
        'pola belanja dengan mudah.',
    key: TourKeys.laporan,
    padding: 14,
  ),
  _Step(
    title: '⑤ Akun & Pengaturan',
    body: 'Tempat untuk mengubah profil, mengganti tema warna, '
        'mengelola kategori, mengaktifkan notifikasi, '
        'dan backup data ke Google Drive.',
    key: TourKeys.akun,
    padding: 14,
  ),
];

// ─────────────────────────────────────────────
// Widget utama
// ─────────────────────────────────────────────

/// Panduan interaktif dengan spotlight yang menunjuk elemen UI nyata.
/// Panggil [TourGuide.show] dari mana saja.
class TourGuide extends StatefulWidget {
  const TourGuide({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, _, __) => const TourGuide(),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 260),
    );
  }

  @override
  State<TourGuide> createState() => _TourGuideState();
}

class _TourGuideState extends State<TourGuide> {
  int _idx = 0;
  bool _vis = true; // untuk fade antar-langkah

  bool get _isFirst => _idx == 0;
  bool get _isLast  => _idx == _steps.length - 1;

  // Hitung posisi elemen yang di-spotlight dari GlobalKey-nya
  Rect? _rectOf(GlobalKey? key) {
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  Future<void> _go(int next) async {
    setState(() => _vis = false);
    await Future.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    setState(() {
      _idx = next.clamp(0, _steps.length - 1);
      _vis = true;
    });
  }

  void _done() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final step   = _steps[_idx];
    final screen = MediaQuery.of(context).size;
    final pad    = MediaQuery.of(context).padding;

    final targetRect  = _rectOf(step.key);
    final paddedRect  = targetRect?.inflate(step.padding);

    // Callout di atas target jika target ada di bawah setengah layar
    final bool above = targetRect != null &&
        targetRect.center.dy > screen.height * 0.55;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedOpacity(
        opacity: _vis ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 160),
        child: Stack(
          children: [
            // ── Overlay gelap + spotlight cutout ──
            CustomPaint(
              size: screen,
              painter: _SpotlightPainter(spot: paddedRect, radius: 20),
            ),

            // ── Tombol Lewati ──
            if (!_isLast)
              Positioned(
                top: pad.top + 12,
                right: 16,
                child: TextButton(
                  onPressed: _done,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black26,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(
                    'Lewati',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

            // ── Nomor langkah ──
            if (_idx > 0)
              Positioned(
                top: pad.top + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_idx / ${_steps.length - 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Callout utama ──
            paddedRect != null
                ? _TargetCallout(
                    step: step,
                    screen: screen,
                    pad: pad,
                    paddedRect: paddedRect,
                    above: above,
                    isFirst: _isFirst,
                    isLast: _isLast,
                    onBack: () => _go(_idx - 1),
                    onNext: () => _go(_idx + 1),
                    onDone: _done,
                  )
                : _CenterCard(
                    step: step,
                    isFirst: _isFirst,
                    isLast: _isLast,
                    onBack: () => _go(_idx - 1),
                    onNext: () => _go(_idx + 1),
                    onDone: _done,
                  ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Spotlight painter
// ─────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final Rect? spot;
  final double radius;
  const _SpotlightPainter({this.spot, this.radius = 16});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = Colors.black.withOpacity(0.74);
    if (spot == null) {
      canvas.drawRect(Offset.zero & size, fillPaint);
      return;
    }
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, fillPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(spot!, Radius.circular(radius)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.spot != spot;
}

// ─────────────────────────────────────────────
// Callout yang menunjuk ke target
// ─────────────────────────────────────────────

class _TargetCallout extends StatelessWidget {
  final _Step step;
  final Size screen;
  final EdgeInsets pad;
  final Rect paddedRect;
  final bool above;
  final bool isFirst, isLast;
  final VoidCallback onBack, onNext, onDone;

  const _TargetCallout({
    required this.step,
    required this.screen,
    required this.pad,
    required this.paddedRect,
    required this.above,
    required this.isFirst,
    required this.isLast,
    required this.onBack,
    required this.onNext,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    const hPad    = 20.0;
    const arrowH  = 12.0;
    const cardGap = 8.0;
    final cardW   = screen.width - hPad * 2;

    // Posisi vertikal kartu
    double top;
    if (above) {
      // Kartu di atas spotlight
      top = paddedRect.top - arrowH - cardGap - 220;
    } else {
      // Kartu di bawah spotlight
      top = paddedRect.bottom + arrowH + cardGap;
    }
    top = top.clamp(
      pad.top + 8.0,
      screen.height - 240.0 - pad.bottom,
    );

    // Posisi horizontal panah (menunjuk ke pusat target)
    final targetCx  = paddedRect.center.dx;
    final arrowLeft = (targetCx - hPad).clamp(20.0, cardW - 20.0);

    return Positioned(
      top: top,
      left: hPad,
      width: cardW,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panah di atas kartu (menuju target di bawahnya)
          if (!above)
            _Triangle(left: arrowLeft, pointUp: true),

          // Kartu konten
          _Card(
            step: step,
            isFirst: isFirst,
            isLast: isLast,
            onBack: onBack,
            onNext: onNext,
            onDone: onDone,
          ),

          // Panah di bawah kartu (menuju target di bawahnya)
          if (above)
            _Triangle(left: arrowLeft, pointUp: false),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Kartu untuk langkah tanpa spotlight (pengantar)
// ─────────────────────────────────────────────

class _CenterCard extends StatelessWidget {
  final _Step step;
  final bool isFirst, isLast;
  final VoidCallback onBack, onNext, onDone;

  const _CenterCard({
    required this.step,
    required this.isFirst,
    required this.isLast,
    required this.onBack,
    required this.onNext,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _Card(
          step: step,
          isFirst: isFirst,
          isLast: isLast,
          onBack: onBack,
          onNext: onNext,
          onDone: onDone,
          centered: true,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Kartu konten (dibagi pakai)
// ─────────────────────────────────────────────

class _Card extends StatelessWidget {
  final _Step step;
  final bool isFirst, isLast, centered;
  final VoidCallback onBack, onNext, onDone;

  const _Card({
    required this.step,
    required this.isFirst,
    required this.isLast,
    required this.onBack,
    required this.onNext,
    required this.onDone,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.ink;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          // Judul
          Text(
            step.title,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.3,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),

          // Isi deskripsi
          Text(
            step.body,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: AppColors.textDark.withOpacity(0.82),
            ),
          ),
          const SizedBox(height: 20),

          // Tombol navigasi
          Row(
            children: [
              if (!isFirst)
                OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textDark,
                    side: BorderSide(color: AppColors.border),
                    minimumSize: const Size(48, 42),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text(
                    '← Kembali',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              const Spacer(),
              FilledButton(
                onPressed: isLast ? onDone : onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 42),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                ),
                child: Text(
                  isLast ? 'Selesai 🎉' : 'Lanjut →',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Segitiga panah
// ─────────────────────────────────────────────

class _Triangle extends StatelessWidget {
  final double left;   // posisi x ujung panah relatif terhadap kartu
  final bool pointUp;

  const _Triangle({required this.left, required this.pointUp});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      width: double.infinity,
      child: CustomPaint(
        painter: _TrianglePainter(cx: left, pointUp: pointUp, color: AppColors.surface),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final double cx;
  final bool pointUp;
  final Color color;

  const _TrianglePainter({required this.cx, required this.pointUp, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final path = Path();
    final x = cx.clamp(12.0, size.width - 12.0);
    if (pointUp) {
      path.moveTo(x - 11, size.height);
      path.lineTo(x + 11, size.height);
      path.lineTo(x, 0);
    } else {
      path.moveTo(x - 11, 0);
      path.lineTo(x + 11, 0);
      path.lineTo(x, size.height);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_TrianglePainter o) =>
      o.cx != cx || o.pointUp != pointUp || o.color != color;
}
