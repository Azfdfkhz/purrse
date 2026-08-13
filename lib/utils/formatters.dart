import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _currency = NumberFormat.decimalPattern('id_ID');

  static String rupiah(num value) {
    return 'Rp. ${_currency.format(value)}';
  }

  static String currency(num value) => rupiah(value);

  static String date(DateTime date) {
    return DateFormat('dd/MM/yy').format(date);
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
