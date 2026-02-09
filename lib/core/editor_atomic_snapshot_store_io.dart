import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'atomic_file_writer.dart';

class EditorAtomicSnapshotStore {
  EditorAtomicSnapshotStore({AtomicFileWriter? writer})
      : _writer = writer ?? const AtomicFileWriter();

  final AtomicFileWriter _writer;

  bool get isSupported => _writer.isSupported;

  Future<bool> writeSnapshot({
    required String sheetId,
    required String payload,
    bool simulateSwapFailure = false,
  }) async {
    final file = await _resolveFile(sheetId);
    if (file == null) return false;
    await _writer.writeStringAtomic(
      file.path,
      payload,
      simulateSwapFailure: simulateSwapFailure,
    );
    return true;
  }

  Future<String?> readSnapshot(String sheetId) async {
    final file = await _resolveFile(sheetId);
    if (file == null || !await file.exists()) return null;
    final raw = await file.readAsString();
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<File?> _resolveFile(String sheetId) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final safeId = _safeId(sheetId);
      final folder = Directory(p.join(dir.path, 'bitflow_editor', 'atomic'));
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }
      return File(p.join(folder.path, '$safeId.json'));
    } catch (_) {
      return null;
    }
  }

  String _safeId(String raw) {
    final trimmed = raw.trim().isEmpty ? 'sheet' : raw.trim();
    return trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }
}
