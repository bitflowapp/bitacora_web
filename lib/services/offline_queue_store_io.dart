import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/atomic_file_writer.dart';

class OfflineQueueStore {
  OfflineQueueStore({AtomicFileWriter? writer})
      : _writer = writer ?? const AtomicFileWriter();

  final AtomicFileWriter _writer;

  bool get isPersistent => _writer.isSupported;

  Future<String?> read(String sheetId) async {
    final file = await _resolveFile(sheetId);
    if (file == null || !await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      return null;
    }
  }

  Future<void> write({
    required String sheetId,
    required String payload,
  }) async {
    final file = await _resolveFile(sheetId);
    if (file == null) return;
    if (payload.trim().isEmpty) {
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      return;
    }
    await _writer.writeStringAtomic(file.path, payload);
  }

  Future<void> delete(String sheetId) async {
    final file = await _resolveFile(sheetId);
    if (file == null || !await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {}
  }

  Future<File?> _resolveFile(String sheetId) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final folder = Directory(
        p.join(dir.path, 'bitflow_editor', 'offline_queue'),
      );
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }
      return File(p.join(folder.path, '${_safeId(sheetId)}.json'));
    } catch (_) {
      return null;
    }
  }

  String _safeId(String raw) {
    final trimmed = raw.trim().isEmpty ? 'sheet' : raw.trim();
    return trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }
}
