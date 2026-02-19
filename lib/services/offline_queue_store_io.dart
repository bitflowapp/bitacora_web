import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/atomic_file_writer.dart';

class OfflineQueueStore {
  OfflineQueueStore({AtomicFileWriter? writer})
      : _writer = writer ?? const AtomicFileWriter();

  final AtomicFileWriter _writer;
  static const Duration _ioTimeout = Duration(seconds: 2);

  bool get isPersistent => _writer.isSupported;

  Future<String?> read(String sheetId) async {
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

  Future<void> write({
    required String sheetId,
    required String payload,
  }) async {
    final file = await _resolveFile(sheetId);
    if (file == null) return;
    if (payload.trim().isEmpty) {
      if (await file.exists().timeout(_ioTimeout)) {
        try {
          await file.delete().timeout(_ioTimeout);
        } catch (_) {}
      }
      return;
    }
    try {
      await _writer.writeStringAtomic(file.path, payload).timeout(_ioTimeout);
    } catch (_) {}
  }

  Future<void> delete(String sheetId) async {
    final file = await _resolveFile(sheetId);
    if (file == null) return;
    if (!await file.exists().timeout(_ioTimeout)) return;
    try {
      await file.delete().timeout(_ioTimeout);
    } catch (_) {}
  }

  Future<File?> _resolveFile(String sheetId) async {
    if (_isWidgetTestEnv) return null;
    try {
      final dir = await getApplicationSupportDirectory().timeout(_ioTimeout);
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
