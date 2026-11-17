import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _currencyWholeFormat = NumberFormat('#,##0', 'en_US');
  static final NumberFormat _quantityFormat = NumberFormat('#,##0.####', 'en_US');
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormat = DateFormat('MMM dd, yyyy');
  static final DateFormat _fullDateTimeFormat = DateFormat('MMM dd, yyyy hh:mm a');

  /// Formats currency with LKR prefix
  static String currency(num amount, {bool forceDecimals = true}) {
    if (!forceDecimals && (amount % 1 == 0)) {
      return 'LKR ${_currencyWholeFormat.format(amount)}';
    }
    return 'LKR ${_currencyFormat.format(amount)}';
  }

  /// Formats decimal quantities cleanly
  static String quantity(num qty, [String? unit]) {
    final formatted = _quantityFormat.format(qty);
    if (unit != null && unit.isNotEmpty) {
      return '$formatted $unit';
    }
    return formatted;
  }

  /// Formats raw number cleanly
  static String number(num val) {
    return _quantityFormat.format(val);
  }

  /// Formats date to standard YYYY-MM-DD
  static String date(DateTime dt) {
    return _dateFormat.format(dt);
  }

  /// Formats date to readable display format
  static String displayDate(String yyyyMmDd) {
    try {
      final parsed = DateTime.parse(yyyyMmDd);
      return _displayDateFormat.format(parsed);
    } catch (_) {
      return yyyyMmDd;
    }
  }

  /// Formats ISO datetime string to readable display
  static String displayDateTime(String isoString) {
    try {
      final parsed = DateTime.parse(isoString);
      return _fullDateTimeFormat.format(parsed);
    } catch (_) {
      return isoString;
    }
  }

  /// Safe double parse
  static double parseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value.toString().replaceAll(',', ''));
    return parsed ?? defaultValue;
  }

  /// Safe int parse
  static int parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value.toString().replaceAll(',', ''));
    return parsed ?? defaultValue;
  }
}
