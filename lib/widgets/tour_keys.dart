import 'package:flutter/widgets.dart';

/// Kunci global yang digunakan [TourGuide] untuk menemukan posisi
/// elemen UI di navbar. [NavbarShell] memasang kunci ini ke widget-nya.
class TourKeys {
  TourKeys._();
  static final GlobalKey home      = GlobalKey(debugLabel: 'tour_home');
  static final GlobalKey add       = GlobalKey(debugLabel: 'tour_add');
  static final GlobalKey transaksi = GlobalKey(debugLabel: 'tour_transaksi');
  static final GlobalKey laporan   = GlobalKey(debugLabel: 'tour_laporan');
  static final GlobalKey akun      = GlobalKey(debugLabel: 'tour_akun');
}
