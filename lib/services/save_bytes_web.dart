import 'package:bitacora_web/web/html_compat.dart' as html;
import 'dart:typed_data';

class SaveBytes {
  static Future<bool> save({
    required Uint8List bytes,
    required String filename,
    String mime = 'application/octet-stream',
  }) async {
    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);

    final a = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';

    html.document.body?.children.add(a);
    a.click();
    a.remove();

    html.Url.revokeObjectUrl(url);
    return true;
  }
}
