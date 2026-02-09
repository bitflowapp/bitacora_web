// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: uri_does_not_exist
import 'dart:indexed_db' as idb;
import 'dart:typed_data';
import 'dart:async';
// ignore: uri_does_not_exist
import 'dart:js_util' as js_util;

import 'web_blob_store.dart';

class WebBlobStoreImpl implements WebBlobStore {
  static const _dbName = 'bf_blob_store_v1';
  static const _storeName = 'attachments';
  static const _cacheName = 'bf_blob_store_cache_v1';
  static const _cachePathPrefix = '/_bitflow_blob_cache/';

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
      blob = html.Blob(<Object>[], mime);
    }
    final now = DateTime.now();
    final recordMap = <String, dynamic>{
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
          sessionOnly: false,
        );
      } catch (_) {
        // fallthrough to Cache API
      }
    }

    final cacheSaved = await _saveToCache(
      key: key,
      blob: blob,
      mime: mime,
      name: name,
      size: size,
      createdAtIso: now.toIso8601String(),
    );
    if (cacheSaved) {
      return WebBlobRecord(
        key: key,
        name: name,
        mime: mime,
        size: size,
        createdAt: now,
        blob: blob,
        storageMode: 'cache',
        sessionOnly: false,
      );
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
      sessionOnly: true,
    );
    _mem[key] = rec;
    return rec;
  }

  @override
  Future<WebBlobRecord?> read(String key) async {
    if (_mem.containsKey(key)) return _mem[key];

    final db = await _ensureDb();
    if (db != null) {
      try {
        final tx = db.transaction(_storeName, 'readonly');
        final store = tx.objectStore(_storeName);
        final map = await store.getObject(key) as Map?;
        await tx.completed;
        if (map != null) {
          final blob = map['blob'] as html.Blob?;
          final name = (map['name'] ?? '') as String;
          final mime = (map['mime'] ?? 'application/octet-stream') as String;
          final size = (map['size'] as num?)?.toInt() ?? blob?.size ?? 0;
          final createdAt =
              DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                  DateTime.now();
          return WebBlobRecord(
            key: key,
            name: name,
            mime: mime,
            size: size,
            createdAt: createdAt,
            blob: blob,
            storageMode: 'indexeddb',
            sessionOnly: false,
          );
        }
      } catch (_) {
        // fallthrough
      }
    }

    final cacheRec = await _readFromCache(key);
    if (cacheRec != null) return cacheRec;
    return null;
  }

  Future<bool> _saveToCache({
    required String key,
    required html.Blob blob,
    required String mime,
    required String name,
    required int size,
    required String createdAtIso,
  }) async {
    try {
      final caches = html.window.caches;
      if (caches == null) return false;
      final cache = _requireJsObject(await caches.open(_cacheName));
      final responseCtor =
          js_util.getProperty<Object?>(js_util.globalThis, 'Response');
      if (responseCtor == null) return false;
      final response = js_util.callConstructor<Object>(
        responseCtor,
        <Object?>[blob],
      );
      await js_util.promiseToFuture<Object?>(
        js_util.callMethod<Object>(
          cache,
          'put',
          <Object?>[_cachePathForKey(key), response],
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<WebBlobRecord?> _readFromCache(String key) async {
    try {
      final caches = html.window.caches;
      if (caches == null) return null;
      final cache = _requireJsObject(await caches.open(_cacheName));
      final response = await js_util.promiseToFuture<Object?>(
        js_util.callMethod<Object>(
          cache,
          'match',
          <Object?>[_cachePathForKey(key)],
        ),
      );
      if (response == null) return null;
      final responseObj = _requireJsObject(response);
      final blob = await js_util.promiseToFuture<html.Blob>(
        js_util.callMethod<Object>(
          responseObj,
          'blob',
          const <Object?>[],
        ),
      );
      final blobMime = blob.type.trim();
      return WebBlobRecord(
        key: key,
        name: 'adjunto',
        mime: blobMime.isEmpty ? 'application/octet-stream' : blobMime,
        size: blob.size,
        createdAt: DateTime.now(),
        blob: blob,
        storageMode: 'cache',
        sessionOnly: false,
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

    try {
      final caches = html.window.caches;
      if (caches != null) {
        final cache = _requireJsObject(await caches.open(_cacheName));
        await js_util.promiseToFuture<Object?>(
          js_util.callMethod<Object>(
            cache,
            'delete',
            <Object?>[_cachePathForKey(key)],
          ),
        );
      }
    } catch (_) {}

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

  String _cachePathForKey(String key) => '$_cachePathPrefix$key';

  Object _requireJsObject(Object? value) {
    if (value == null) {
      throw StateError('null_js_value');
    }
    return value;
  }
}
