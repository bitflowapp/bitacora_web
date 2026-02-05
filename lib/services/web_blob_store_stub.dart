import 'dart:typed_data';

import 'web_blob_store.dart';

class WebBlobStoreImpl implements WebBlobStore {
  final Map<String, WebBlobRecord> _mem = {};

  @override
  Future<void> delete(String key) async {
    _mem.remove(key);
  }

  @override
  Future<void> download(String key,
      {required String name, required String mime}) async {
    // No-op in stub.
  }

  @override
  Future<WebBlobRecord?> read(String key) async {
    return _mem[key];
  }

  @override
  Future<Uint8List?> readBytes(String key) async {
    return _mem[key]?.bytes;
  }

  @override
  Future<WebBlobRecord> save({
    required String key,
    required Object source,
    required String name,
    required String mime,
    required int size,
  }) async {
    Uint8List bytes;
    if (source is Uint8List) {
      bytes = source;
    } else {
      bytes = Uint8List(0);
    }
    final rec = WebBlobRecord(
      key: key,
      name: name,
      mime: mime,
      size: size,
      createdAt: DateTime.now(),
      bytes: bytes,
      storageMode: 'ram',
    );
    _mem[key] = rec;
    return rec;
  }
}
