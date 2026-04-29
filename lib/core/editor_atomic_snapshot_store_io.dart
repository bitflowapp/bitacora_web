import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/widgets.dart';

import 'atomic_file_writer.dart';

class EditorAtomicSnapshotStore {
  EditorAtomicSnapshotStore({AtomicFileWriter? writer})
      : _writer = writer ?? const AtomicFileWriter();

  final AtomicFileWriter _writer;
  static const Duration _ioTimeout = Duration(seconds: 2);

  bool get isSupported => _writer.isSupported;

  Future<bool> writeSnapshot({
    required String sheetId,
    required String payload,
    bool simulateSwapFailure = false,
  }) async {
    final file = await _resolveFile(sheetId);
    if (file == null) return false;
    try {
      await _writer
          .writeStringAtomic(
            file.path,
            payload,
            simulateSwapFailure: simulateSwapFailure,
          )
          .timeout(_ioTimeout);
      return true;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> readSnapshot(String sheetId) async {
    final file = await _resolveFile(sheetId);
    if (file == null) return null;
    try {
      if (!await file.exists().timeout(_ioTimeout)) return null;
      final raw = await file.readAsString().timeout(_ioTimeout);
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<File?> _resolveFile(String sheetId) async {
    if (_isWidgetTestEnv) return null;
    try {
      final dir = await getApplicationSupportDirectory().timeout(_ioTimeout);
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

  bool get _isWidgetTestEnv {
    try {
      final bindingType = WidgetsBinding.instance.runtimeType.toString();
      return bindingType.contains('TestWidgetsFlutterBinding');
    } catch (_) {
      return false;
    }
  }

  String _safeId(String raw) {
    final trimmed = raw.trim().isEmpty ? 'sheet' : raw.trim();
    return trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }
}
