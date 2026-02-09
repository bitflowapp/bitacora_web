import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';

import 'photo_storage_service.dart';

class PhotoStorageServiceImpl implements PhotoStorageService {
  static const String _boxName = 'photo_store_v2';
  static final Map<String, Map<String, dynamic>> _memStore =
      <String, Map<String, dynamic>>{};
  Box<dynamic>? _box;

  Future<void> _ensureBox() async {
    if (_box != null && _box!.isOpen) return;
    try {
      await Hive.initFlutter();
    } catch (_) {}
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<dynamic>(_boxName);
    } else {
      _box = await Hive.openBox<dynamic>(_boxName);
    }
  }

  String _makeKey(String sheetId, String cellKey, String attachmentId) {
    final safeSheet = _sanitize(sheetId);
    final safeCell = _sanitize(cellKey);
    final safeId = _sanitize(attachmentId);
    return '$safeSheet:$safeCell:$safeId';
  }

  @override
  Future<StoredPhoto?> savePhoto({
    required String sheetId,
    required String cellKey,
    required String attachmentId,
    required Uint8List bytes,
    required String originalName,
    required String mime,
  }) async {
    final key = _makeKey(sheetId, cellKey, attachmentId);
    try {
      await _ensureBox();
      await _box!.put(key, <String, dynamic>{
        'name': originalName,
        'mime': mime,
        'bytes': bytes,
      });
      return StoredPhoto(path: 'key:$key', fileName: originalName, mime: mime);
    } catch (_) {
      _memStore[key] = <String, dynamic>{
        'name': originalName,
        'mime': mime,
        'bytes': bytes,
      };
      return StoredPhoto(path: 'mem:$key', fileName: originalName, mime: mime);
    }
  }

  @override
  Future<Uint8List?> readPhotoBytes(String path) async {
    try {
      final key = _normalizeKey(path);
      if (key.isEmpty) return null;
      if (path.startsWith('mem:')) {
        final raw = _memStore[key];
        final bytes = raw?['bytes'];
        return bytes is Uint8List ? bytes : null;
      }
      await _ensureBox();
      final raw = _box!.get(key);
      if (raw is Map) {
        final bytes = raw['bytes'];
        if (bytes is Uint8List) return bytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deletePhoto(String path) async {
    try {
      final key = _normalizeKey(path);
      if (key.isEmpty) return;
      if (path.startsWith('mem:')) {
        _memStore.remove(key);
        return;
      }
      await _ensureBox();
      await _box!.delete(key);
    } catch (_) {}
  }

  String _normalizeKey(String raw) {
    final t = raw.trim();
    if (t.startsWith('key:')) return t.substring(4);
    if (t.startsWith('mem:')) return t.substring(4);
    return t;
  }

  String _sanitize(String raw) {
    final t = raw.trim().isEmpty ? 'x' : raw.trim();
    return t.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
  }
}
