// lib/models/table_state.dart
// Estado inmutable de la hoja tipo Excel.
// - Headers inmutables
// - Filas normalizadas al ancho de columnas
// - Helpers funcionales: withHeaders, withAppendedRows, withCell, withNewEmptyRow
// - Serialización JSON compacta con versión de esquema

import 'dart:collection' show UnmodifiableListView;
import 'dart:convert';

/// Tamaño inicial por defecto de una hoja nueva.
/// La idea es arrancar liviano (12x12) y que el usuario agregue más si quiere.
const int kInitialCols = 12;
const int kInitialRows = 12;

class TableState {
  /// Versión de esquema para futuras migraciones.
  static const int schemaVersion = 1;

  /// Encabezados de columnas (longitud = colCount).
  ///
  /// Internamente es un [UnmodifiableListView], pero se expone como [List]
  /// para mantener la API simple.
  final List<String> headers;

  /// Filas de datos (cada fila tiene exactamente [colCount] celdas).
  ///
  /// También se almacena internamente como listas inmutables.
  final List<List<String>> rows;

  /// Momento en que este estado fue persistido / generado (UTC).
  final DateTime savedAt;

  // ------------------------------------------------------------
  // Constructores
  // ------------------------------------------------------------

  /// Constructor principal: crea un estado inmutable y normaliza filas
  /// al ancho de [headers].
  factory TableState({
    required List<String> headers,
    required List<List<String>> rows,
    required DateTime savedAt,
  }) {
    // Copia defensiva + envoltorio inmutable.
    final h = UnmodifiableListView<String>(
      headers.map((e) => e.toString()).toList(growable: false),
    );

    final r = UnmodifiableListView<List<String>>(
      rows
          .map(
            (row) => UnmodifiableListView<String>(
              row.map((e) => e.toString()).toList(growable: false),
            ),
          )
          .toList(growable: false),
    );

    final t = _toUtc(savedAt);
    final normalizedRows = _normalizeRows(h, r);
    return TableState._internal(h, normalizedRows, t);
  }

  const TableState._internal(this.headers, this.rows, this.savedAt);

  /// Estado vacío con [cols] columnas y [rows] filas iniciales.
  ///
  /// Por defecto arranca en 12x12 para no hacer pesada la planilla.
  factory TableState.empty({int cols = kInitialCols, int rows = kInitialRows}) {
    final headers = UnmodifiableListView(
      List<String>.filled(cols, '', growable: false),
    );

    final data = UnmodifiableListView<List<String>>(
      List.generate(
        rows,
        (_) => UnmodifiableListView(
          List<String>.filled(cols, '', growable: false),
        ),
        growable: false,
      ),
    );

    return TableState._internal(headers, data, _nowUtc());
  }

  int get colCount => headers.length;
  int get rowCount => rows.length;

  // ------------------------------------------------------------
  // Serialización
  // ------------------------------------------------------------

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': schemaVersion,
        'headers': headers,
        'rows': rows,
        'savedAt': savedAt.toIso8601String(),
      };

  String toJsonString({bool pretty = false}) {
    final obj = toJson();
    if (!pretty) return jsonEncode(obj);
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(obj);
  }

  static TableState? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      // Versión (por si en el futuro querés migrar esquemas).
      final dynamic vRaw = json['v'];
      final int v = vRaw is int ? vRaw : schemaVersion;

      // Headers
      final rawHeaders = json['headers'];
      final headers = (rawHeaders is List ? rawHeaders : const [])
          .map((e) => e.toString())
          .toList(growable: false);

      // Filas
      final rawRows = json['rows'];
      final rows = (rawRows is List ? rawRows : const []).map((r) {
        final rr = (r is List ? r : const []);
        return rr.map((e) => e.toString()).toList(growable: false);
      }).toList(growable: false);

      // Fecha
      final savedAtRaw = json['savedAt']?.toString() ?? '';
      final savedAt = DateTime.tryParse(savedAtRaw)?.toUtc() ?? _nowUtc();

      // En el futuro, si v != schemaVersion, acá se migraría.
      switch (v) {
        case 1:
        default:
          return TableState(headers: headers, rows: rows, savedAt: savedAt);
      }
    } catch (_) {
      return null;
    }
  }

  static TableState? fromJsonString(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final m = jsonDecode(s);
      return m is Map<String, dynamic> ? fromJson(m) : null;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------
  // Helpers funcionales
  // ------------------------------------------------------------

  /// Reemplaza headers y re-normaliza filas a la nueva cantidad de columnas.
  TableState withHeaders(List<String> newHeaders) {
    final n = newHeaders.length;
    final adjustedRows =
        rows.map((src) => _normalizeRowToLen(src, n)).toList(growable: false);

    return TableState(
      headers: newHeaders,
      rows: adjustedRows,
      savedAt: _nowUtc(),
    );
  }

  /// Agrega filas al final (normaliza cada fila al ancho actual).
  ///
  /// Si [chunk] está vacío no se modifica el estado.
  TableState withAppendedRows(List<List<String>> chunk) {
    if (chunk.isEmpty) {
      return this;
    }

    final normalizedChunk = chunk
        .map((r) => _normalizeRowToLen(r, colCount))
        .toList(growable: false);

    final merged = <List<String>>[
      ...rows.map((r) => List<String>.from(r)),
      ...normalizedChunk,
    ];

    return TableState(
      headers: headers,
      rows: merged,
      savedAt: _nowUtc(),
    );
  }

  /// Actualiza una celda (row, col).
  ///
  /// Si el índice es inválido o el valor es igual al anterior, devuelve el mismo estado.
  TableState withCell(int row, int col, String value) {
    if (row < 0 || row >= rowCount || col < 0 || col >= colCount) {
      return this;
    }
    if (rows[row][col] == value) {
      return this;
    }

    final newRows =
        rows.map((r) => List<String>.from(r)).toList(growable: false);
    newRows[row][col] = value;

    return TableState(
      headers: headers,
      rows: newRows,
      savedAt: _nowUtc(),
    );
  }

  /// Inserta una nueva fila vacía al final (mismo número de columnas).
  TableState withNewEmptyRow() {
    final newRows = List<List<String>>.from(rows, growable: true)
      ..add(List<String>.filled(colCount, ''));

    return TableState(
      headers: headers,
      rows: newRows,
      savedAt: _nowUtc(),
    );
  }

  /// Copia con cambios crudos. Re-normaliza filas para respetar el ancho.
  TableState copyWith({
    List<String>? headers,
    List<List<String>>? rows,
    DateTime? savedAt,
  }) {
    final newHeaders = headers ?? this.headers;
    final newRows = rows ?? this.rows;
    final newSaved = _toUtc(savedAt ?? this.savedAt);

    return TableState(
      headers: newHeaders,
      rows: newRows,
      savedAt: newSaved,
    );
  }

  // ------------------------------------------------------------
  // Utilidades
  // ------------------------------------------------------------

  /// Devuelve una matriz mutable profunda (para operaciones temporales).
  List<List<String>> toMutableMatrix() =>
      rows.map((r) => List<String>.from(r)).toList(growable: true);

  /// Indica si todos los encabezados y celdas están vacíos.
  bool get isAllEmpty {
    if (headers.any((h) => h.isNotEmpty)) return false;
    for (final r in rows) {
      if (r.any((c) => c.isNotEmpty)) return false;
    }
    return true;
  }

  /// Devuelve una copia con textos `trim()` en headers y/o celdas.
  TableState trim({bool headersToo = true, bool cells = true}) {
    if (!headersToo && !cells) return this;

    var changed = false;

    final List<String> newHeaders;
    if (headersToo) {
      newHeaders = List<String>.generate(
        headers.length,
        (i) {
          final old = headers[i];
          final trimmed = old.trim();
          if (!changed && trimmed != old) changed = true;
          return trimmed;
        },
        growable: false,
      );
    } else {
      newHeaders = headers;
    }

    final List<List<String>> newRows;
    if (cells) {
      newRows = List<List<String>>.generate(
        rows.length,
        (r) {
          final row = rows[r];
          return List<String>.generate(
            row.length,
            (c) {
              final old = row[c];
              final trimmed = old.trim();
              if (!changed && trimmed != old) changed = true;
              return trimmed;
            },
            growable: false,
          );
        },
        growable: false,
      );
    } else {
      newRows = rows;
    }

    if (!changed) return this;

    return TableState(
      headers: newHeaders,
      rows: newRows,
      savedAt: _nowUtc(),
    );
  }

  /// Elimina columnas vacías al final (encabezado vacío y todas las celdas vacías).
  TableState pruneTrailingEmptyColumns() {
    int lastKeep = colCount - 1;
    for (; lastKeep >= 0; lastKeep--) {
      final headerEmpty = headers[lastKeep].isEmpty;
      final allEmpty = rows.every((r) => r[lastKeep].isEmpty);
      if (!(headerEmpty && allEmpty)) break;
    }

    final keep = lastKeep + 1;
    if (keep == colCount) return this;

    if (keep <= 0) {
      // Nos quedamos sin columnas: respetamos la cantidad de filas.
      return TableState.empty(cols: 0, rows: rowCount);
    }

    final newHeaders = List<String>.from(headers.take(keep));
    final newRows = rows
        .map((r) => List<String>.from(r.take(keep)))
        .toList(growable: false);

    return TableState(
      headers: newHeaders,
      rows: newRows,
      savedAt: _nowUtc(),
    );
  }

  // ------------------------------------------------------------
  // Igualdad / hash
  // ------------------------------------------------------------

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TableState) return false;

    if (headers.length != other.headers.length) return false;
    for (var i = 0; i < headers.length; i++) {
      if (headers[i] != other.headers[i]) return false;
    }

    if (rows.length != other.rows.length) return false;
    for (var r = 0; r < rows.length; r++) {
      final a = rows[r], b = other.rows[r];
      if (a.length != b.length) return false;
      for (var c = 0; c < a.length; c++) {
        if (a[c] != b[c]) return false;
      }
    }

    // Incluimos savedAt en la igualdad, ya que representa una "versión" del estado.
    return savedAt.toIso8601String() == other.savedAt.toIso8601String();
  }

  @override
  int get hashCode {
    var h = 17;
    for (final e in headers) {
      h = _hashCombine(h, e.hashCode);
    }
    for (final row in rows) {
      var rh = 17;
      for (final e in row) {
        rh = _hashCombine(rh, e.hashCode);
      }
      h = _hashCombine(h, rh);
    }
    h = _hashCombine(h, savedAt.toIso8601String().hashCode);
    return _hashFinish(h);
  }

  // ------------------------------------------------------------
  // Privados
  // ------------------------------------------------------------

  static DateTime _nowUtc() => DateTime.now().toUtc();

  static DateTime _toUtc(DateTime d) => d.isUtc ? d : d.toUtc();

  static List<List<String>> _normalizeRows(
    List<String> headers,
    List<List<String>> rows,
  ) {
    final n = headers.length;
    if (n == 0) {
      return UnmodifiableListView<List<String>>(
        rows
            .map(
              (_) => UnmodifiableListView<String>(const <String>[]),
            )
            .toList(growable: false),
      );
    }

    return UnmodifiableListView<List<String>>(
      rows
          .map(
            (src) => UnmodifiableListView<String>(
              _normalizeRowToLen(src, n),
            ),
          )
          .toList(growable: false),
    );
  }

  static List<String> _normalizeRowToLen(List<String> src, int n) {
    if (src.length == n) {
      return List<String>.from(src, growable: false);
    }
    if (src.length < n) {
      final out = List<String>.from(src, growable: true)
        ..addAll(List.filled(n - src.length, ''));
      return List<String>.from(out, growable: false);
    }
    return List<String>.from(src.take(n), growable: false);
  }

  static int _hashCombine(int hash, int value) {
    hash = 0x1fffffff & (hash + value);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int _hashFinish(int hash) {
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}
