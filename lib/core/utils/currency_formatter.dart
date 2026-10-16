import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Format rupiah integer: misal 150000 -> "Rp 150.000", -160000 -> "-Rp 160.000"
  static String format(int amount) {
    if (amount < 0) {
      return '-${_formatter.format(amount.abs())}';
    }
    return _formatter.format(amount);
  }

  /// Format compact: misal 150000 -> "150 rb"
  static String formatCompact(int amount) {
    if (amount >= 1000000) {
      final val = (amount / 1000000).toStringAsFixed(1).replaceAll('.0', '');
      return 'Rp ${val}jt';
    } else if (amount >= 1000) {
      final val = (amount / 1000).toStringAsFixed(0);
      return 'Rp ${val}rb';
    }
    return format(amount);
  }
}
