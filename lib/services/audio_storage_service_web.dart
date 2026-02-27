import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'audio_service.dart';
import 'audio_storage_service.dart';

class AudioStorageServiceImpl implements AudioStorageService {
  static const String _boxName = 'audio_store_v1';
  static final Map<String, Map<String, dynamic>> _memStore =
      <String, Map<String, dynamic>>{};
  Box<dynamic>? _box;
  String? _lastSaveStore;
  String? _lastSaveReason;

  String? get lastSaveStore => _lastSaveStore;
  String? get lastSaveReason => _lastSaveReason;

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
    _lastSaveStore = null;
    _lastSaveReason = null;
    final bytesLength = recording.bytes?.lengthInBytes ?? 0;

    try {
      final bytes = recording.bytes;
      if (bytes == null || bytes.isEmpty) return null;
      await _ensureBox();

      final key = _makeKey(sheetId, cellKey, attachmentId);
      await _box!.put(key, <String, dynamic>{
        'name': recording.fileName,
        'mime': recording.mime,
        'bytes': bytes,
      });

      _lastSaveStore = 'indexeddb';
      _lastSaveReason = null;
      _debugLogSave(
        bytesLength: bytesLength,
        store: _lastSaveStore!,
        reasonCode: _lastSaveReason,
      );

      return StoredAudio(
        storageKey: key,
        fileName: recording.fileName,
        mime: recording.mime,
        bytesLength: bytes.lengthInBytes,
      );
    } catch (e) {
      final bytes = recording.bytes;
      if (bytes == null || bytes.isEmpty) return null;
      final key = _makeKey(sheetId, cellKey, attachmentId);
      _memStore[key] = <String, dynamic>{
        'name': recording.fileName,
        'mime': recording.mime,
        'bytes': bytes,
      };
      _lastSaveStore = 'mem';
      _lastSaveReason = _classifyStorageReason(e);
      _debugLogSave(
        bytesLength: bytesLength,
        store: _lastSaveStore!,
        reasonCode: _lastSaveReason,
      );
      return StoredAudio(
        storageKey: 'mem:$key',
        fileName: recording.fileName,
        mime: recording.mime,
        bytesLength: bytes.lengthInBytes,
      );
    }
  }

  @override
  Future<Uint8List?> readAudioBytes(String storageKey) async {
    if (storageKey.startsWith('mem:')) {
      final key = storageKey.substring(4);
      final raw = _memStore[key];
      final bytes = raw?['bytes'];
      return bytes is Uint8List ? bytes : null;
    }
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
    if (storageKey.startsWith('mem:')) {
      _memStore.remove(storageKey.substring(4));
      return;
    }
    await _ensureBox();
    await _box!.delete(storageKey);
  }

  String _sanitize(String raw) {
    final t = raw.trim().isEmpty ? 'x' : raw.trim();
    return t.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
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
        lower.contains('invalidstateerror')) {
      return 'storage_blocked';
    }
    return 'unknown_storage_error';
  }

  void _debugLogSave({
    required int bytesLength,
    required String store,
    required String? reasonCode,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[audio-store-web] save bytes=$bytesLength '
      'store=$store reason=${reasonCode ?? 'none'}',
    );
  }
}
