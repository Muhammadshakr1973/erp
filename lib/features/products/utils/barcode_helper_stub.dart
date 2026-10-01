// platform stub for non-web environments
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

void saveAndDownloadImage(Uint8List bytes, String fileName) {
  Share.shareXFiles(
    [XFile.fromData(bytes, name: fileName, mimeType: 'image/png')],
  );
}

void shareImage(Uint8List bytes, String fileName, {String? text}) {
  Share.shareXFiles(
    [XFile.fromData(bytes, name: fileName, mimeType: 'image/png')],
    text: text,
  );
}

void printImage(Uint8List bytes) {
  Share.shareXFiles(
    [XFile.fromData(bytes, name: fileName, mimeType: 'image/png')],
  );
}
