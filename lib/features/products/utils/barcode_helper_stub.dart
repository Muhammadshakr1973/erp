// platform stub for non-web environments
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

const MethodChannel _mediaChannel = MethodChannel('com.gardipos.app/media');

Future<bool> saveAndDownloadImage(Uint8List bytes, String fileName) async {
  if (!kIsWeb && Platform.isAndroid) {
    // 1. Primary method: Native Android MediaStore (saves directly to Pictures/GardiERP and updates Gallery)
    try {
      final bool? result = await _mediaChannel.invokeMethod<bool>(
        'saveImageToGallery',
        {
          'bytes': bytes,
          'fileName': fileName,
        },
      );
      if (result == true) {
        return true;
      }
    } catch (e) {
      debugPrint('Error saving image via MethodChannel: $e');
    }

    // 2. Fallback: Direct save to public directories on Android
    try {
      final candidateDirs = [
        Directory('/storage/emulated/0/Download'),
        Directory('/storage/emulated/0/Pictures/GardiERP'),
        Directory('/storage/emulated/0/Pictures'),
      ];
      for (final dir in candidateDirs) {
        bool exists = dir.existsSync();
        if (!exists) {
          try {
            dir.createSync(recursive: true);
            exists = true;
          } catch (_) {}
        }
        if (exists) {
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          return true;
        }
      }
    } catch (e) {
      debugPrint('Direct file save fallback error: $e');
    }
  }

  // Fallback for non-Android / desktop platforms
  try {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return true;
  } catch (e) {
    debugPrint('Temp file save fallback error: $e');
    return false;
  }
}

Future<void> shareImage(Uint8List bytes, String fileName, {String? text}) async {
  await Share.shareXFiles(
    [XFile.fromData(bytes, name: fileName, mimeType: 'image/png')],
    text: text,
  );
}

Future<void> printImage(Uint8List bytes) async {
  await Share.shareXFiles(
    [XFile.fromData(bytes, name: 'gardi_barcode.png', mimeType: 'image/png')],
  );
}

