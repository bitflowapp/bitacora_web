// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:indexed_db' as idb;
import 'dart:typed_data';
import 'dart:async';

import 'web_blob_store.dart';

class WebBlobStoreImpl implements WebBlobStore {
  static const _dbName = 'bf_blob_store_v1';
  static const _storeName = 'attachments';

  idb.Database? _db;
  final Map<String, WebBlobRecord> _mem = {};

  Future<idb.Database?> _ensureDb() async {
    if (_db != null) return _db;
    try {
      _db = await html.window.indexedDB!.open(
        _dbName,
        version: 1,
        onUpgradeNeeded: (e) {
          final db = (e.target as idb.Request).result as idb.Database;
          db.createObjectStore(_storeName);
        },
      );
    } catch (_) {
      _db = null;
    }
    return _db;
  }

  @override
  Future<WebBlobRecord> save({
    required String key,
    required Object source,
    required String name,
    required String mime,
    required int size,
  }) async {
    html.Blob blob;
    if (source is html.Blob) {
      blob = source;
    } else if (source is Uint8List) {
      blob = html.Blob([source], mime);
    } else {
      blob = html.Blob([], mime);
    }
    final now = DateTime.now();
    final recordMap = {
      'blob': blob,
      'name': name,
      'mime': mime,
      'size': size,
      'createdAt': now.toIso8601String(),
    };

    final db = await _ensureDb();
    if (db != null) {
      try {
        final tx = db.transaction(_storeName, 'readwrite');
        final store = tx.objectStore(_storeName);
        await store.put(recordMap, key);
        await tx.completed;
        return WebBlobRecord(
          key: key,
          name: name,
          mime: mime,
          size: size,
          createdAt: now,
          blob: blob,
          storageMode: 'indexeddb',
        );
      } catch (_) {
        // fallthrough to mem
      }
    }

    // Fallback RAM
    final rec = WebBlobRecord(
      key: key,
      name: name,
      mime: mime,
      size: size,
      createdAt: now,
      blob: blob,
      storageMode: 'ram',
    );
    _mem[key] = rec;
    return rec;
  }

  @override
  Future<WebBlobRecord?> read(String key) async {
    if (_mem.containsKey(key)) return _mem[key];

    final db = await _ensureDb();
    if (db == null) return null;
    try {
      final tx = db.transaction(_storeName, 'readonly');
      final store = tx.objectStore(_storeName);
      final map = await store.getObject(key) as Map?;
      await tx.completed;
      if (map == null) return null;
      final blob = map['blob'] as html.Blob?;
      final name = (map['name'] ?? '') as String;
      final mime = (map['mime'] ?? 'application/octet-stream') as String;
      final size = (map['size'] as num?)?.toInt() ?? blob?.size ?? 0;
      final createdAt = DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now();
      return WebBlobRecord(
        key: key,
        name: name,
        mime: mime,
        size: size,
        createdAt: createdAt,
        blob: blob,
        storageMode: 'indexeddb',
      );
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _blobToBytes(html.Blob? blob) async {
    if (blob == null) return null;
    final reader = html.FileReader();
    final completer = Completer<Uint8List?>();
    reader.onError.first.then((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
    reader.onLoadEnd.first.then((_) {
      if (completer.isCompleted) return;
      final res = reader.result;
      if (res is ByteBuffer) {
        completer.complete(Uint8List.view(res));
      } else {
        completer.complete(null);
      }
    });
    reader.readAsArrayBuffer(blob);
    return completer.future;
  }

  @override
  Future<Uint8List?> readBytes(String key) async {
    final rec = await read(key);
    if (rec == null) return null;
    if (rec.bytes != null) return rec.bytes;
    return _blobToBytes(rec.blob as html.Blob?);
  }

  @override
  Future<void> delete(String key) async {
    _mem.remove(key);
    final db = await _ensureDb();
    if (db == null) return;
    try {
      final tx = db.transaction(_storeName, 'readwrite');
      final store = tx.objectStore(_storeName);
      await store.delete(key);
      await tx.completed;
    } catch (_) {}
  }

  @override
  Future<void> download(String key,
      {required String name, required String mime}) async {
    final rec = await read(key);
    final blob = rec?.blob as html.Blob?;
    if (blob == null) return;
    final url = html.Url.createObjectUrlFromBlob(blob);
    final a = html.AnchorElement()
      ..href = url
      ..download = name.isEmpty ? 'archivo' : name
      ..style.position = 'fixed'
      ..style.left = '-1000px'
      ..style.top = '-1000px';
    html.document.body?.append(a);
    a.click();
    a.remove();
    Future.delayed(const Duration(seconds: 1), () {
      html.Url.revokeObjectUrl(url);
    });
  }
}
