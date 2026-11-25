import 'package:intl/intl.dart';

/// Utility formatters for Dominican Peso (DOP) currency and dates.
class AppFormatters {
  AppFormatters._();

  static final NumberFormat _numberFormat = NumberFormat('#,##0.00', 'en_US');
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  static String money(double value, {String symbol = 'RD\$'}) {
    return '$symbol ${_numberFormat.format(value)}';
  }

  static String date(DateTime dt) => _dateFormat.format(dt);

  static String dateTime(DateTime dt) => _dateTimeFormat.format(dt);
}
