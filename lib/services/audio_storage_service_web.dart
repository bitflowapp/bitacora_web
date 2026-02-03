import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';

import 'audio_service.dart';
import 'audio_storage_service.dart';

class AudioStorageServiceImpl implements AudioStorageService {
  static const String _boxName = 'audio_store_v1';
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
  Future<StoredAudio?> saveRecording({
    required String sheetId,
    required String cellKey,
    required String attachmentId,
    required RecordedAudio recording,
  }) async {
    final bytes = recording.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    await _ensureBox();

    final key = _makeKey(sheetId, cellKey, attachmentId);
    await _box!.put(key, <String, dynamic>{
      'name': recording.fileName,
      'mime': recording.mime,
      'bytes': bytes,
    });

    return StoredAudio(
      storageKey: key,
      fileName: recording.fileName,
      mime: recording.mime,
      bytesLength: bytes.lengthInBytes,
    );
  }

  @override
  Future<Uint8List?> readAudioBytes(String storageKey) async {
    await _ensureBox();
    final raw = _box!.get(storageKey);
    if (raw is Map) {
      final bytes = raw['bytes'];
      if (bytes is Uint8List) return bytes;
    }
    return null;
  }

  @override
  Future<void> deleteAudio(String storageKey) async {
    await _ensureBox();
    await _box!.delete(storageKey);
  }

  String _sanitize(String raw) {
    final t = raw.trim().isEmpty ? 'x' : raw.trim();
    return t.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
  }
}

