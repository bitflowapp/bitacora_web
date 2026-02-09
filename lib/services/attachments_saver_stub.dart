// lib/services/attachments_saver_stub.dart
// Fachada de guardado/descarga multiplataforma.

import 'dart:typed_data';

AttachmentSaver getAttachmentSaver() => _StubSaver();

abstract class AttachmentSaver {
  Future<void> save(String name, Uint8List bytes, String mime);
}

class _StubSaver implements AttachmentSaver {
  @override
  Future<void> save(String name, Uint8List bytes, String mime) async {
    // No-op en plataformas no soportadas.
  }
}
