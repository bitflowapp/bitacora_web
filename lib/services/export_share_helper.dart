import 'dart:typed_data';

import 'export_share_file_stub.dart'
    if (dart.library.io) 'export_share_file_io.dart' as impl;

Future<String?> persistShareTempFile({
  required String fileName,
  required Uint8List bytes,
}) {
  return impl.persistShareTempFile(fileName: fileName, bytes: bytes);
}
