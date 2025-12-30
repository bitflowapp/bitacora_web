import 'dart:async';
import 'dart:convert' as convert;
import 'dart:html' as html;

import '../models/table_state.dart';

/// Wrapper para el worker JS en web/workers/json_parser_worker.js
class JsonWorker {
  JsonWorker({
    required this.onMeta,
    required this.onRowsChunk,
    required this.onError,
    this.chunkSize = 800,
    this.scriptUrl = 'workers/json_parser_worker.js',
  });

  final void Function(List<String> headers, int totalRows) onMeta;
  final void Function(List<List<String>> rowsChunk, bool done) onRowsChunk;
  final void Function(Object error) onError;

  final int chunkSize;
  final String scriptUrl;

  html.Worker? _worker;
  StreamSubscription<html.MessageEvent>? _sub;
  bool _closed = false;

  void start(String rawJson) {
    try {
      _worker = html.Worker(scriptUrl);
    } catch (e) {
      onError("No se pudo inicializar Worker: ");
      return;
    }

    _sub = _worker!.onMessage.listen((evt) {
      if (_closed) return;
      _handleRaw(evt.data);
    });

    // Inicia el worker
    _worker!.postMessage({
      'type': 'start',
      'raw': rawJson,
      'chunkSize': chunkSize,
    });
  }

  void _handleRaw(dynamic data) {
    try {
      Map<String, dynamic> m;
      if (data is String) {
        m = convert.jsonDecode(data) as Map<String, dynamic>;
      } else if (data is Map) {
        m = data.map((k, v) => MapEntry(k.toString(), v));
      } else {
        return;
      }
      _handleMap(m);
    } catch (e) {
      onError(e);
      dispose();
    }
  }

  void _handleMap(Map<String, dynamic> m) {
    final type = m['type'];
    if (type == 'meta') {
      final headers =
          (m['headers'] as List?)?.map((e) => e.toString()).toList() ??
              const <String>[];
      final total = (m['total'] as num?)?.toInt() ?? 0;
      onMeta(headers, total);
    } else if (type == 'chunk') {
      final rows = (m['rows'] as List?)
              ?.map((r) => (r as List).map((e) => e.toString()).toList())
              .toList() ??
          const <List<String>>[];
      final done = m['done'] == true;
      onRowsChunk(rows, done);
      if (done) dispose();
    } else if (type == 'error') {
      onError(m['message'] ?? 'worker error');
      dispose();
    }
  }

  void dispose() {
    _closed = true;
    try {
      _sub?.cancel();
    } catch (_) {}
    _sub = null;
    try {
      _worker?.terminate();
    } catch (_) {}
    _worker = null;
  }

  /// Versión one-shot opcional (no la usamos más abajo, pero la dejo OK).
  static Future<TableState> parseOnce(
    String rawJson, {
    int chunkSize = 800,
    String scriptUrl = 'workers/json_parser_worker.js',
  }) async {
    final c = Completer<TableState>();
    final headers = <String>[];
    final rows = <List<String>>[];

    final w = JsonWorker(
      onMeta: (h, _) {
        headers
          ..clear()
          ..addAll(h);
      },
      onRowsChunk: (chunk, done) {
        rows.addAll(chunk);
        if (done && !c.isCompleted) {
          c.complete(TableState(
              headers: headers, rows: rows, savedAt: DateTime.now()));
        }
      },
      onError: (err) {
        if (!c.isCompleted) c.completeError(err);
      },
      chunkSize: chunkSize,
      scriptUrl: scriptUrl,
    );

    w.start(rawJson);
    return c.future;
  }
}
