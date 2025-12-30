import 'dart:async';
import 'dart:convert' as convert;

import '../models/table_state.dart';

/// Fallback sin Web Worker: parsea y emite en bloques sin congelar el frame.
class JsonWorker {
  JsonWorker({
    required this.onMeta,
    required this.onRowsChunk,
    required this.onError,
    this.chunkSize = 800,
  });

  final void Function(List<String> headers, int totalRows) onMeta;
  final void Function(List<List<String>> rowsChunk, bool done) onRowsChunk;
  final void Function(Object error) onError;
  final int chunkSize;

  void start(String rawJson) {
    // Microtask para evitar bloquear el frame actual.
    scheduleMicrotask(() {
      try {
        final obj = convert.jsonDecode(rawJson);
        if (obj is! Map) throw 'JSON inválido (no es objeto)';
        final map = obj as Map<String, dynamic>;

        final headers = ((map['headers'] as List?) ?? const [])
            .map((e) => e?.toString() ?? '')
            .toList();

        final rows = ((map['rows'] as List?) ?? const [])
            .map((r) => (r is List ? r : const [])
                .map((e) => e?.toString() ?? '')
                .toList())
            .toList();

        onMeta(headers, rows.length);

        final ch = chunkSize;
        for (var i = 0; i < rows.length; i += ch) {
          final end = (i + ch < rows.length) ? i + ch : rows.length;
          final slice = rows.sublist(i, end);
          final done = end >= rows.length;
          onRowsChunk(slice, done);
        }
      } catch (e) {
        onError(e);
      }
    });
  }

  void dispose() {}

  /// Parseo one-shot directo (sin Worker).
  static Future<TableState> parseOnce(String rawJson,
      {int chunkSize = 800}) async {
    try {
      final obj = convert.jsonDecode(rawJson);
      if (obj is! Map) throw 'JSON inválido (no es objeto)';
      final map = obj as Map<String, dynamic>;

      final headers = ((map['headers'] as List?) ?? const [])
          .map((e) => e?.toString() ?? '')
          .toList();

      final rows = ((map['rows'] as List?) ?? const [])
          .map((r) => (r is List ? r : const [])
              .map((e) => e?.toString() ?? '')
              .toList())
          .toList();

      return TableState(headers: headers, rows: rows, savedAt: DateTime.now());
    } catch (e) {
      return Future<TableState>.error(e);
    }
  }
}
