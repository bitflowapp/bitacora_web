// lib/services/json_worker.dart
// Parser JSON no bloqueante (web-safe). Evita colgar la UI al importar
// backups grandes o al preparar datos para exportar a XLSX.
//
// - JsonWorker.parseOnce(text) devuelve Future<Map<String, dynamic>>.
// - Sobre ese Map tenés extension getters: .headers y .rows
//   para armar la matriz estilo Excel en ExportXlsxService.

import 'dart:async' show Future, Completer, StreamSubscription;
import 'dart:convert' as convert;

/// Wrapper liviano para parsear JSON grande sin trabar el primer frame.
class JsonWorker {
  // Preparado para un posible uso con streams en el futuro.
  StreamSubscription<dynamic>? _sub;

  JsonWorker();

  /// Parseo único de un JSON grande sin bloquear el primer frame.
  ///
  /// Devuelve el objeto raíz decodificado como `Map<String, dynamic>`.
  /// Lanza [FormatException] si el JSON es inválido o si el root no es un Map.
  static Future<Map<String, dynamic>> parseOnce(String text) {
    final completer = Completer<Map<String, dynamic>>();

    // Dejamos que el event loop respire antes de parsear.
    Future<void>(() {
      try {
        final decoded = convert.jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          if (!completer.isCompleted) completer.complete(decoded);
        } else {
          if (!completer.isCompleted) {
            completer.completeError(
              const FormatException(
                'El JSON raíz debe ser un objeto (Map<String,dynamic>).',
              ),
            );
          }
        }
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });

    return completer.future;
  }

  /// Limpia recursos si se usan streams en el futuro.
  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

/// Record interno para armar matriz de exportación.
typedef _ExportMatrix = ({
  List<String> headers,
  List<List<String>> rows,
});

/// Extrae una matriz [headers, rows] desde el JSON decodificado.
///
/// Intenta varios formatos posibles:
/// - { "headers": [...], "rows": [ [...], ... ] }
/// - { "columns": [...], "rows" / "data": [...] } (grid más compleja)
/// Si no reconoce el formato, genera algo básico para no romper.
_ExportMatrix _extractExportMatrix(Map<String, dynamic> root) {
  // 1) Formato directo: headers + rows (ambos List).
  final directHeaders = root['headers'];
  final directRows = root['rows'];
  if (directHeaders is List && directRows is List) {
    final headers = directHeaders.map((e) => e?.toString() ?? '').toList();

    final rows = <List<String>>[];
    for (final r in directRows) {
      if (r is List) {
        rows.add(r.map((c) => c?.toString() ?? '').toList());
      } else {
        rows.add(<String>[r.toString()]);
      }
    }

    return (headers: headers, rows: rows);
  }

  // 2) Formato tipo columnas + data/rows (más parecido a una grilla avanzada).
  final cols = (root['columns'] ?? root['cols']) as List<dynamic>?;
  final data = (root['data'] ?? root['rows']) as List<dynamic>?;

  if (cols != null && data != null) {
    // Headers desde columns: usamos title/header/label/name si existen.
    final headers = <String>[];
    for (final col in cols) {
      if (col is Map<String, dynamic>) {
        final title =
            col['title'] ?? col['header'] ?? col['label'] ?? col['name'];
        headers.add((title ?? '').toString());
      } else {
        headers.add(col.toString());
      }
    }

    final rows = <List<String>>[];
    for (final row in data) {
      if (row is List) {
        rows.add(row.map((c) => c?.toString() ?? '').toList());
      } else if (row is Map<String, dynamic>) {
        // Intentamos campos típicos.
        final cells = row['cells'] ?? row['values'] ?? row['data'];
        if (cells is List) {
          rows.add(cells.map((c) => c?.toString() ?? '').toList());
        } else if (headers.isNotEmpty) {
          // Si hay headers, buscamos por clave con el mismo nombre.
          final line = <String>[];
          for (final h in headers) {
            line.add(row[h]?.toString() ?? '');
          }
          rows.add(line);
        } else {
          // Último recurso: todos los values del map.
          rows.add(row.values.map((v) => v?.toString() ?? '').toList());
        }
      } else {
        rows.add(<String>[row.toString()]);
      }
    }

    return (headers: headers, rows: rows);
  }

  // 3) Fallback muy básico: todo el JSON en una sola celda.
  final asString = root.toString();
  return (
    headers: <String>['JSON'],
    rows: <List<String>>[
      <String>[asString],
    ],
  );
}

/// Extensión para `Map<String, dynamic>` que devuelve headers/rows
/// listos para exportar a XLSX.
///
/// Uso típico:
/// final parsed = await JsonWorker.parseOnce(raw);
/// await ExportXlsxService.download(
///   fileName: 'algo.xlsx',
///   headers: parsed.headers,
///   rows: parsed.rows,
/// );
extension JsonExportMatrixExt on Map<String, dynamic> {
  List<String> get headers => _extractExportMatrix(this).headers;

  List<List<String>> get rows => _extractExportMatrix(this).rows;
}
