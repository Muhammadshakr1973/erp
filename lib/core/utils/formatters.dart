import 'package:intl/intl.dart';
import '../network/api_constants.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en_US');
  static final NumberFormat _unitFormat = NumberFormat('#,##0.##', 'en_US');

  /// Safely parses any value (int, double, num, or String e.g. "2.000") to int without throwing TypeError.
  static int parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final str = value.trim();
      if (str.isEmpty) return defaultValue;
      final d = double.tryParse(str);
      if (d != null) return d.toInt();
      final i = int.tryParse(str);
      if (i != null) return i;
    }
    return defaultValue;
  }

  /// Safely parses any value (int, double, num, or String e.g. "2.000") to double without throwing TypeError.
  static double parseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final str = value.trim();
      if (str.isEmpty) return defaultValue;
      final d = double.tryParse(str);
      if (d != null) return d;
    }
    return defaultValue;
  }

  /// Safely parses any value (int, double, num, or String e.g. "2.000") to num without throwing TypeError.
  static num parseNum(dynamic value, [num defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is num) return value;
    if (value is String) {
      final str = value.trim();
      if (str.isEmpty) return defaultValue;
      final n = num.tryParse(str);
      if (n != null) return n;
    }
    return defaultValue;
  }

  static String currency(num amount) {
    return '${_currencyFormat.format(amount)} د.ع';
  }

  static String units(num amount) {
    final unitValue = amount / 1000.0;
    return '${_unitFormat.format(unitValue)} یەکە';
  }

  static String number(num value) {
    return _currencyFormat.format(value);
  }

  /// Cleans a number or string representation of a number to display cleanly without trailing .0:
  /// e.g. 10000.0 -> "10000", 12500.50 -> "12500.5", 24.0 -> "24"
  static String cleanNumberString(dynamic value) {
    if (value == null) return '';
    final strVal = value.toString().trim();
    if (strVal.isEmpty) return '';
    final num? n = num.tryParse(strVal);
    if (n == null) return strVal;
    if (n % 1 == 0) {
      return n.toInt().toString();
    }
    String s = n.toString();
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  static String date(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }

  static String kurdishDayAndDate(String dateStr) {
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return dateStr;
    
    String dayName;
    switch (parsed.weekday) {
      case DateTime.monday:
        dayName = 'دووشەممە';
        break;
      case DateTime.tuesday:
        dayName = 'سێشەممە';
        break;
      case DateTime.wednesday:
        dayName = 'چوارشەممە';
        break;
      case DateTime.thursday:
        dayName = 'پێنجشەممە';
        break;
      case DateTime.friday:
        dayName = 'هەینی';
        break;
      case DateTime.saturday:
        dayName = 'شەممە';
        break;
      case DateTime.sunday:
        dayName = 'یەکشەممە';
        break;
      default:
        dayName = '';
    }

    final dateFormatted = DateFormat('yyyy/MM/dd').format(parsed);
    if (dayName.isNotEmpty) {
      return '$dayName • $dateFormatted';
    }
    return dateFormatted;
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

  static String directImageUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';

    // Handle Google Drive and Google Share links
    if (trimmed.contains('drive.google.com') || trimmed.contains('google.') || trimmed.contains('share.google')) {
      final fileDRegExp = RegExp(r'/(?:file/d/|d/)([a-zA-Z0-9_-]+)');
      final fileDMatch = fileDRegExp.firstMatch(trimmed);
      if (fileDMatch != null && fileDMatch.groupCount >= 1) {
        final fileId = fileDMatch.group(1);
        return 'https://lh3.googleusercontent.com/d/$fileId';
      }

      final idRegExp = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)');
      final idMatch = idRegExp.firstMatch(trimmed);
      if (idMatch != null && idMatch.groupCount >= 1) {
        final fileId = idMatch.group(1);
        return 'https://lh3.googleusercontent.com/d/$fileId';
      }
    }

    // Handle Dropbox links
    if (trimmed.contains('dropbox.com')) {
      if (trimmed.endsWith('?dl=0')) {
        return trimmed.replaceAll('?dl=0', '?raw=1');
      } else if (!trimmed.contains('?')) {
        return '$trimmed?raw=1';
      }
    }

    return trimmed;
  }

  static String proxyImageUrl(String url) {
    final direct = directImageUrl(url);
    if (direct.isEmpty) return '';
    return '${ApiConstants.baseUrl}/proxy-image?url=${Uri.encodeComponent(direct)}';
  }
}
