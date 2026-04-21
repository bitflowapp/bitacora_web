import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'audio_service.dart';
import 'audio_storage_service.dart';

class AudioStorageServiceImpl implements AudioStorageService {
  static const String _rootFolder = 'bitflow_audio';

  @override
  Future<StoredAudio?> saveRecording({
    required String sheetId,
    required String cellKey,
    required String attachmentId,
    required RecordedAudio recording,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeSheet = _sanitize(sheetId);
      final folder = Directory(p.join(dir.path, _rootFolder, safeSheet));
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }

      final ext = _extFor(recording.fileName, recording.mime);
      final safeCell = _sanitize(cellKey);
      final safeId = _sanitize(attachmentId);
      final fileName = 'audio_${safeCell}_$safeId$ext';
      final filePath = p.join(folder.path, fileName);

      if (recording.path != null && recording.path!.trim().isNotEmpty) {
        final src = File(recording.path!);
        if (src.existsSync()) {
          await src.copy(filePath);
        } else if (recording.bytes != null) {
          await File(filePath).writeAsBytes(recording.bytes!, flush: true);
        } else {
          return null;
        }
      } else if (recording.bytes != null) {
        await File(filePath).writeAsBytes(recording.bytes!, flush: true);
      } else {
        return null;
      }

      final saved = File(filePath);
      if (!await saved.exists()) {
        debugPrint('[AudioStorageService] save failed: missing $filePath');
        return null;
      }
      final size = await saved.length();
      if (size <= 0) {
        debugPrint('[AudioStorageService] save failed: empty $filePath');
        return null;
      }

      return StoredAudio(
        storageKey: filePath,
        fileName: recording.fileName,
        mime: recording.mime,
        bytesLength: size,
      );
    } catch (e, st) {
      debugPrint('[AudioStorageService] saveRecording failed: $e\n$st');
      return null;
    }
  }

  @override
  Future<Uint8List?> readAudioBytes(String storageKey) async {
    try {
      if (storageKey.trim().isEmpty) return null;
      final file = File(storageKey);
      if (!file.existsSync()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteAudio(String storageKey) async {
    try {
      if (storageKey.trim().isEmpty) return;
      final file = File(storageKey);
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  String _sanitize(String raw) {
    final t = raw.trim().isEmpty ? 'sheet' : raw.trim();
    return t.replaceAll(RegExp(r'[\\/:*?"<>|\\s]'), '_');
  }

  String _extFor(String name, String mime) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.wav')) return '.wav';
    if (lower.endsWith('.mp3')) return '.mp3';
    if (lower.endsWith('.m4a')) return '.m4a';
    if (lower.endsWith('.ogg')) return '.ogg';
    if (mime.contains('wav')) return '.wav';
    if (mime.contains('mpeg')) return '.mp3';
    if (mime.contains('m4a')) return '.m4a';
    if (mime.contains('ogg')) return '.ogg';
    return '.m4a';
  }
}
