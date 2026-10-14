import 'dart:typed_data';

import 'package:universal_html/html.dart' as html;

/// Descarga [bytes] como archivo en el navegador. Solo para Flutter Web:
/// en Android/iOS se comparte o guarda el archivo con otros mecanismos.
void downloadBytesInBrowser(Uint8List bytes, String filename, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..download = filename;
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
