import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _currency = NumberFormat.decimalPattern('id_ID');

  static String rupiah(num value) {
    return 'Rp. ${_currency.format(value.round())}';
  }

  static String currency(num value) => rupiah(value);

  /// 1250000 -> "1.250.000" (tanpa "Rp", untuk isi kolom input).
  static String digitsWithDots(num value) {
    final digits = value.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  static String date(DateTime date) {
    return DateFormat('dd/MM/yy').format(date);
  }

  /// "27 Oktober 2026"
  static String longDate(DateTime d) => '${d.day} ${monthNames[d.month - 1]} ${d.year}';

  /// "Hari ini" / "Kemarin" / "27 Oktober 2026"
  static String relativeDay(DateTime d, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    return longDate(d);
  }

  static const List<String> monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
}
