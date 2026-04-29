import 'dart:typed_data';

import 'web_blob_store_stub.dart'
    if (dart.library.html) 'web_blob_store_web.dart';

class WebBlobRecord {
  WebBlobRecord({
    required this.key,
    required this.name,
    required this.mime,
    required this.size,
    required this.createdAt,
    this.bytes,
    this.blob,
    this.storageMode = 'ram',
    this.sessionOnly = false,
    this.storageReason,
  });

  final String key;
  final String name;
  final String mime;
  final int size;
  final DateTime createdAt;
  final Uint8List? bytes;
  final Object? blob; // html.Blob en web
  final String storageMode; // indexeddb | cache | ram
  final bool sessionOnly;
  final String? storageReason; // quota_exceeded | storage_session_only | ...
}

abstract class WebBlobStore {
  static final WebBlobStore _instance = WebBlobStoreImpl();
  static WebBlobStore get I => _instance;

  /// Guarda un Blob/File sin convertirlo a bytes.
  /// [source] debe ser html.Blob o html.File en Web; en stub puede ser Uint8List.
  Future<WebBlobRecord> save({
    required String key,
    required Object source,
    required String name,
    required String mime,
    required int size,
  });

  Future<WebBlobRecord?> read(String key);

  Future<Uint8List?> readBytes(String key);

  Future<void> delete(String key);

  Future<void> download(String key,
      {required String name, required String mime});

  /// Último motivo clasificado de fallback/error de guardado (best effort).
  String? get lastSaveReason => null;
}
