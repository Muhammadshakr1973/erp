// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// web implementation of barcode helper using dart:html
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

void saveAndDownloadImage(Uint8List bytes, String fileName) {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

void printImage(Uint8List bytes) {
  final imageBlob = html.Blob([bytes], 'image/png');
  final imageUrl = html.Url.createObjectUrlFromBlob(imageBlob);

  final htmlContent = '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>چاپکردنی بارکۆد</title>
      <style>
        body {
          margin: 0;
          display: flex;
          justify-content: center;
          align-items: center;
          height: 100vh;
          font-family: 'Rudaw', sans-serif;
          background-color: white;
        }
        .container {
          text-align: center;
          border: 1px dashed #ccc;
          padding: 20px;
          border-radius: 8px;
        }
        img {
          max-width: 100%;
          height: auto;
          display: block;
          margin: 0 auto 10px auto;
        }
        p {
          margin: 0;
          font-size: 16px;
          font-weight: bold;
          color: #333;
        }
        @page {
          size: 50mm 30mm;
          margin: 0;
        }
        @media print {
          html, body {
            width: 50mm;
            height: 30mm;
            margin: 0;
            padding: 0;
          }
          .container {
            border: none;
            padding: 0;
            margin: 0;
            width: 50mm;
            height: 30mm;
          }
          img {
            width: 50mm;
            height: auto;
            max-height: 30mm;
            margin: 0;
            display: block;
          }
        }
      </style>
    </head>
    <body>
      <div class="container">
        <img src="$imageUrl" onload="window.print();" />
      </div>
    </body>
    </html>
  ''';

  final htmlBlob = html.Blob([htmlContent], 'text/html');
  final htmlUrl = html.Url.createObjectUrlFromBlob(htmlBlob);
  html.window.open(htmlUrl, '_blank');

  // Revoke object URLs after delay to allow rendering and printing
  Timer(const Duration(minutes: 2), () {
    html.Url.revokeObjectUrl(htmlUrl);
    html.Url.revokeObjectUrl(imageUrl);
  });
}

