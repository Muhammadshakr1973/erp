import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

const _mediaChannel = MethodChannel('com.gardipos.app/media');

Future<void> downloadReceiptImage(Uint8List bytes, String fileName) async {
  if (!kIsWeb && Platform.isAndroid) {
    final saved = await _mediaChannel.invokeMethod<bool>(
      'saveImageToGallery',
      {'bytes': bytes, 'fileName': fileName},
    );
    if (saved != true) {
      throw StateError('وێنەکە لە وێنەکانی ئامێر پاشەکەوت نەکرا.');
    }
    return;
  }

  if (!kIsWeb && Platform.isIOS) {
    final temporaryFile = await _writeTemporaryPng(bytes, fileName);
    try {
      final result = await Share.shareXFiles(
        [XFile(temporaryFile.path, mimeType: 'image/png')],
        text: 'پاشەکەوتکردنی وێنەی پسوڵە',
      );
      if (result.status == ShareResultStatus.unavailable) {
        throw UnsupportedError('شیتی پاشەکەوتکردن لەم ئامێرەدا بەردەست نییە.');
      }
      if (result.status == ShareResultStatus.dismissed) {
        throw StateError('پاشەکەوتکردنی وێنەکە هەڵوەشێنرایەوە.');
      }
    } finally {
      await temporaryFile.parent.delete(recursive: true);
    }
    return;
  }

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    final home =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home == null || home.trim().isEmpty) {
      throw StateError('شوێنی پاشەکەوتکردن لە ئامێرەکەدا نەدۆزرایەوە.');
    }
    final downloads = Directory('$home${Platform.pathSeparator}Downloads');
    await downloads.create(recursive: true);
    final file = File('${downloads.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return;
  }

  throw UnsupportedError('دابەزاندنی وێنە لەم پلاتفۆرمەدا پشتگیری ناکرێت.');
}

Future<void> shareReceiptImage(Uint8List bytes, String fileName) async {
  final temporaryFile = await _writeTemporaryPng(bytes, fileName);
  try {
    final result = await Share.shareXFiles(
      [XFile(temporaryFile.path, mimeType: 'image/png')],
      text: 'پسوڵەی GARDI ERP',
    );
    if (result.status == ShareResultStatus.unavailable) {
      throw UnsupportedError('شیتی هاوبەشکردن لەم ئامێرەدا بەردەست نییە.');
    }
    if (result.status == ShareResultStatus.dismissed) {
      throw StateError('هاوبەشکردنی وێنەکە هەڵوەشێنرایەوە.');
    }
  } finally {
    await temporaryFile.parent.delete(recursive: true);
  }
}

Future<File> _writeTemporaryPng(Uint8List bytes, String fileName) async {
  final temporaryDirectory =
      await Directory.systemTemp.createTemp('gardi_receipt_');
  final file = File(
    '${temporaryDirectory.path}${Platform.pathSeparator}$fileName',
  );
  try {
    await file.writeAsBytes(bytes, flush: true);
    return file;
  } catch (_) {
    await temporaryDirectory.delete(recursive: true);
    rethrow;
  }
}
