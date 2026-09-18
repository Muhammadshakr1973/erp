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

  static String cleanError(dynamic error) {
    if (error == null) return 'هەڵەیەکی نادیار ڕوویدا';
    var msg = error.toString().trim();
    while (msg.startsWith('Exception: ')) {
      msg = msg.substring(11).trim();
    }
    if (msg.startsWith('FormatException: ')) {
      msg = msg.substring(17).trim();
    }
    return msg;
  }
}
