// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<void> downloadReceiptImage(Uint8List bytes, String fileName) async {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  try {
    final body = html.document.body;
    if (body == null) {
      throw StateError('بەشی پەڕەی وێب بۆ دابەزاندن ئامادە نییە.');
    }
    body.children.add(anchor);
    anchor.click();
  } catch (_) {
    html.Url.revokeObjectUrl(url);
    rethrow;
  } finally {
    anchor.remove();
  }
  Timer(const Duration(seconds: 2), () => html.Url.revokeObjectUrl(url));
}

Future<void> shareReceiptImage(Uint8List bytes, String fileName) async {
  final result = await Share.shareXFiles(
    [XFile.fromData(bytes, name: fileName, mimeType: 'image/png')],
    text: 'پسوڵەی GARDI ERP',
  );
  if (result.status == ShareResultStatus.unavailable) {
    throw UnsupportedError('شیتی هاوبەشکردنی وێنە لە وێبگەڕەکەدا بەردەست نییە.');
  }
  if (result.status == ShareResultStatus.dismissed) {
    throw StateError('هاوبەشکردنی وێنەکە هەڵوەشێنرایەوە.');
  }
}
