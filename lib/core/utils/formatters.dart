import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');

  static String currency(num amount) {
    return '${_currencyFormat.format(amount)} د.ع';
  }

  static String number(num value) {
    return _currencyFormat.format(value);
  }

  static String date(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }

  static String dateTime(DateTime date) {
    return DateFormat('yyyy/MM/dd HH:mm').format(date);
  }
}
