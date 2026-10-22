import 'dart:typed_data';

import 'receipt_file_service_stub.dart'
    if (dart.library.html) 'receipt_file_service_web.dart' as platform;

Future<void> downloadReceiptImage(Uint8List bytes, String fileName) =>
    platform.downloadReceiptImage(bytes, fileName);

Future<void> shareReceiptImage(Uint8List bytes, String fileName) =>
    platform.shareReceiptImage(bytes, fileName);
