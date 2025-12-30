// lib/services/attachments_saver_io.dart
// En móviles/escritorio: comparte el archivo con Share Plus.

import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import 'attachments_saver_stub.dart';

AttachmentSaver getAttachmentSaver() => _IOSaver();

class _IOSaver implements AttachmentSaver {
  @override
  Future<void> save(String name, Uint8List bytes, String mime) async {
    final xf = XFile.fromData(bytes, name: name, mimeType: mime);
    await Share.shareXFiles([xf]);
  }
}
