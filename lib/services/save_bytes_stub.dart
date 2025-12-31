import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

class SaveBytes {
  static Future<bool> save({
    required Uint8List bytes,
    required String filename,
    String mime = 'application/octet-stream',
  }) async {
    final loc = await getSaveLocation(suggestedName: filename);
    if (loc == null) return false;

    final x = XFile.fromData(bytes, mimeType: mime, name: filename);
    await x.saveTo(loc.path);
    return true;
  }
}
