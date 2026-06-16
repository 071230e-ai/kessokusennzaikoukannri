import 'package:intl/intl.dart';

class DateFormatter {
  static final _dateFormat = DateFormat('yyyy/MM/dd');
  static final _shortFormat = DateFormat('MM/dd');

  static String format(DateTime? date) {
    if (date == null) return '-';
    return _dateFormat.format(date);
  }

  static String formatShort(DateTime? date) {
    if (date == null) return '-';
    return _shortFormat.format(date);
  }

  static String formatQuantity(double qty, String unit) {
    if (qty == qty.roundToDouble()) {
      return '${qty.toInt()} $unit';
    }
    return '${qty.toStringAsFixed(1)} $unit';
  }

  static String quantityStr(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(1);
  }
}
