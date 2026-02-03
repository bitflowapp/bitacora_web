import 'dart:math';
import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';

import 'photo_storage_service.dart';

class PhotoStorageServiceImpl implements PhotoStorageService {
  static const String _boxName = 'photo_store_v2';
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

  String _genId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final r = Random();
    final tail = List.generate(6, (_) => r.nextInt(36))
        .map((n) => 'abcdefghijklmnopqrstuvwxyz0123456789'[n])
        .join();
    return 'ph_$now$tail';
  }

  @override
  Future<StoredPhoto?> savePhoto({
    required String sheetId,
    required Uint8List bytes,
    required String originalName,
    required String mime,
  }) async {
    try {
      await _ensureBox();
      final id = _genId();
      await _box!.put(id, <String, dynamic>{
        'name': originalName,
        'mime': mime,
        'bytes': bytes,
      });
      return StoredPhoto(path: 'key:$id', fileName: originalName, mime: mime);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Uint8List?> readPhotoBytes(String path) async {
    try {
      final key = _normalizeKey(path);
      if (key.isEmpty) return null;
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
      await _ensureBox();
      await _box!.delete(key);
    } catch (_) {}
  }

  String _normalizeKey(String raw) {
    final t = raw.trim();
    if (t.startsWith('key:')) return t.substring(4);
    return t;
  }
}
