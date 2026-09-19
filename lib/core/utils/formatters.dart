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
}
