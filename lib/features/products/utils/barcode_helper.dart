// master barcode helper using conditional imports
import 'dart:typed_data';

import 'barcode_helper_stub.dart'
    if (dart.library.html) 'barcode_helper_web.dart' as helper;

Future<bool> downloadBarcode(Uint8List bytes, String fileName) async {
  return await helper.saveAndDownloadImage(bytes, fileName);
}

Future<void> shareBarcode(Uint8List bytes, String fileName, {String? text}) async {
  await helper.shareImage(bytes, fileName, text: text);
}

Future<void> printBarcode(Uint8List bytes) async {
  await helper.printImage(bytes);
}
