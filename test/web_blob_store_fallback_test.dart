import 'dart:typed_data';

import 'package:bitacora_web/services/web_blob_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web blob store fallback keeps bytes in session memory', () async {
    final key = 'test-key-fallback';
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

    final record = await WebBlobStore.I.save(
      key: key,
      source: bytes,
      name: 'demo.bin',
      mime: 'application/octet-stream',
      size: bytes.lengthInBytes,
    );

    expect(record.key, key);
    expect(record.storageMode, isNotEmpty);
    expect(record.sessionOnly, isTrue);

    final read = await WebBlobStore.I.readBytes(key);
    expect(read, isNotNull);
    expect(read, bytes);
  });
}
