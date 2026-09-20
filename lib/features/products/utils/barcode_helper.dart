// master barcode helper using conditional imports
import 'dart:typed_data';

import 'barcode_helper_stub.dart'
    if (dart.library.html) 'barcode_helper_web.dart' as helper;

void downloadBarcode(Uint8List bytes, String fileName) {
  helper.saveAndDownloadImage(bytes, fileName);
}

void printBarcode(Uint8List bytes) {
  helper.printImage(bytes);
}
