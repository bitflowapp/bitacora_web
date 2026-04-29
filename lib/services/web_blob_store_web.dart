// ignore: avoid_web_libraries_in_flutter
import 'package:bitacora_web/web/html_compat.dart' as html;
import 'dart:typed_data';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:bitacora_web/web/js_interop_compat.dart' as js_util;

import 'web_blob_store.dart';

class WebBlobStoreImpl implements WebBlobStore {
  static const _dbName = 'bf_blob_store_v1';
  static const _storeName = 'attachments';
  static const _cacheName = 'bf_blob_store_cache_v1';
  static const _cachePathPrefix = '/_bitflow_blob_cache/';

  dynamic _db;
  final Map<String, WebBlobRecord> _mem = {};
  String? _lastSaveReason;
  String? _lastSaveStore;

  @override
  String? get lastSaveReason => _lastSaveReason;
  String? get lastSaveStore => _lastSaveStore;

  Future<dynamic> _ensureDb() async {
    if (_db != null) return _db;
    try {
      _db = await html.window.indexedDB!.open(
        _dbName,
        version: 1,
        onUpgradeNeeded: (e) {
          final db = (e.target as dynamic).result;
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
    _lastSaveReason = null;
    _lastSaveStore = null;
    html.Blob blob;
    if (source is html.Blob) {
      blob = source;
    } else if (source is Uint8List) {
      blob = html.Blob([source], mime);
    } else {
      blob = html.Blob(<Object>[], mime);
    }
    final now = DateTime.now();
    void debugLogSaveDecision(String store, String? reasonCode) {
      assert(() {
        final reason =
            (reasonCode ?? '').trim().isEmpty ? 'none' : reasonCode!.trim();
        developer.log(
          '[web-blob] save bytes=$size store=$store reason=$reason',
          name: 'bitflow.web_blob',
        );
        return true;
      }());
    }

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
        _lastSaveStore = 'indexeddb';
        debugLogSaveDecision('indexeddb', null);
        return WebBlobRecord(
          key: key,
          name: name,
          mime: mime,
          size: size,
          createdAt: now,
          blob: blob,
          storageMode: 'indexeddb',
          sessionOnly: false,
          storageReason: null,
        );
      } catch (e) {
        _lastSaveReason = _classifyStorageReason(e);
        // fallthrough to Cache API
      }
    } else {
      _lastSaveReason = 'storage_blocked';
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
      final finalReasonCode = (_lastSaveReason ?? '').trim().isEmpty
          ? 'unknown_storage_error'
          : _lastSaveReason!;
      _lastSaveReason = finalReasonCode;
      _lastSaveStore = 'cache';
      debugLogSaveDecision('cache', finalReasonCode);
      return WebBlobRecord(
        key: key,
        name: name,
        mime: mime,
        size: size,
        createdAt: now,
        blob: blob,
        storageMode: 'cache',
        sessionOnly: false,
        storageReason: finalReasonCode,
      );
    }

    // Fallback RAM
    final finalReasonCode = (_lastSaveReason ?? '').trim().isEmpty
        ? 'unknown_storage_error'
        : _lastSaveReason!;
    _lastSaveReason = finalReasonCode;
    _lastSaveStore = 'ram';
    debugLogSaveDecision('ram', finalReasonCode);
    final rec = WebBlobRecord(
      key: key,
      name: name,
      mime: mime,
      size: size,
      createdAt: now,
      blob: blob,
      storageMode: 'ram',
      sessionOnly: true,
      storageReason: finalReasonCode,
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
            storageReason: null,
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
      if (caches == null) {
        _lastSaveReason ??= 'storage_blocked';
        return false;
      }
      final cache = _requireJsObject(await caches.open(_cacheName));
      final responseCtor =
          js_util.getProperty<Object?>(js_util.globalThis, 'Response');
      if (responseCtor == null) {
        _lastSaveReason ??= 'storage_blocked';
        return false;
      }
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
    } catch (e) {
      _lastSaveReason = _classifyStorageReason(e);
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
        storageReason: null,
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

  String _classifyStorageReason(Object error) {
    final lower = error.toString().toLowerCase();
    if (lower.contains('quota') ||
        lower.contains('quotaexceeded') ||
        lower.contains('insufficient storage')) {
      return 'quota_exceeded';
    }
    if (lower.contains('private') ||
        lower.contains('incognito') ||
        lower.contains('session') ||
        lower.contains('notallowederror') ||
        lower.contains('securityerror')) {
      return 'storage_session_only';
    }
    if (lower.contains('indexeddb') ||
        lower.contains('blocked') ||
        lower.contains('invalidstateerror') ||
        lower.contains('null_js_value')) {
      return 'storage_blocked';
    }
    return 'unknown_storage_error';
  }
}
