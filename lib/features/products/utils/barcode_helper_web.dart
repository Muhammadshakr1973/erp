// web implementation of barcode helper using dart:html
import 'dart:html' as html;
import 'dart:typed_data';

void saveAndDownloadImage(Uint8List bytes, String fileName) {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

void printImage(Uint8List bytes) {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final newWindow = html.window.open('', '_blank');
  newWindow?.document.write('''
    <!DOCTYPE html>
    <html>
    <head>
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
      </style>
    </head>
    <body>
      <div class="container">
        <img src="$url" onload="window.print();" />
      </div>
    </body>
    </html>
  ''');
  newWindow?.document.close();
}
