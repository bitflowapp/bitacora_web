// lib/services/sheet_store_web.dart
// Store de planillas en Web usando localStorage.
// - Índice de hojas por id.
// - Cada hoja se guarda como JSON de TableState.
// - Plantillas (resistividades, inventario, checklist).
// - API alineada con sheet_store_io.dart (TemplateKind, createFromTemplate, etc).

import 'dart:convert';
import 'dart:html' as html;

import '../models/table_state.dart';

/// Metadata para listar planillas.
class SheetMeta {
  final String id;
  final DateTime updatedAt;
  final String title;
  final int rows;

  const SheetMeta({
    required this.id,
    required this.updatedAt,
    required this.title,
    required this.rows,
  });
}

/// Plantillas opcionales (mismas que en IO).
enum TemplateKind {
  resistividades,
  inventario,
  checklist,
}

class SheetStore {
  static const String _indexKey = 'sheets:index'; // {"ids":[...]}

  /// En Web no necesitamos init real, pero mantenemos la firma por simetría.
  static Future<void> init() async {
    // no-op
  }

  /// JSON raw guardado, o null.
  static String? loadRaw(String id) {
    return html.window.localStorage['sheet:$id'];
  }

  /// Guarda estado y garantiza presencia en el índice.
  static void saveState(String id, TableState state) {
    // Normalizamos para asegurar consistencia (UTC, dimensiones, etc.).
    final fixed = TableState(
      headers: state.headers,
      rows: state.rows,
      savedAt: DateTime.now(),
    );

    html.window.localStorage['sheet:$id'] = fixed.toJsonString();

    final ids = _getIndex();
    if (!ids.contains(id)) {
      ids.insert(0, id);
      _saveIndex(ids);
    }
  }

  /// Renombrar (se guarda separado para no tocar el JSON de la hoja).
  static void rename(String id, String newTitle) {
    html.window.localStorage['sheet:$id:title'] = newTitle.trim();
  }

  static String? _readTitle(String id) {
    return html.window.localStorage['sheet:$id:title'];
  }

  /// Crea hoja en blanco (5x3) y retorna id.
  static String createNew() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final state = TableState.empty(cols: 5, rows: 3);
    saveState(id, state);
    return id;
  }

  /// Crea hoja desde plantilla y retorna id.
  static String createFromTemplate(TemplateKind kind) {
    switch (kind) {
      case TemplateKind.resistividades:
        return _createWith(
          headers: const [
            'Fecha',
            'Progresiva',
            '1 m (Ω)',
            '3 m (Ω)',
            '5 m (Ω)',
            'Observaciones',
          ],
        );
      case TemplateKind.inventario:
        return _createWith(
          headers: const [
            'Item',
            'Cantidad',
            'Unidad',
            'Ubicación',
            'Nota',
          ],
        );
      case TemplateKind.checklist:
        return _createWith(
          headers: const [
            'Tarea',
            'Responsable',
            'Estado',
            'Hora',
            'Comentario',
          ],
        );
    }
  }

  /// Garantiza que exista al menos una hoja y devuelve el id por defecto.
  static Future<String> ensureDefault() async {
    final ids = _getIndex();
    if (ids.isEmpty) {
      return createNew();
    }
    return ids.first;
  }

  /// Elimina hoja y la saca del índice (también su título).
  static void delete(String id) {
    html.window.localStorage.remove('sheet:$id');
    html.window.localStorage.remove('sheet:$id:title');

    final ids = _getIndex()..remove(id);
    _saveIndex(ids);
  }

  /// Lista planillas ordenadas por fecha desc.
  static List<SheetMeta> list() {
    final ids = _getIndex();
    final out = <SheetMeta>[];

    for (final id in ids) {
      final raw = loadRaw(id);
      if (raw == null || raw.isEmpty) continue;

      try {
        final ts = TableState.fromJsonString(raw);
        if (ts == null) continue;

        final custom = _readTitle(id);
        final derived = _firstNonEmpty(ts.headers) ?? '';
        final title = (custom != null && custom.trim().isNotEmpty)
            ? custom.trim()
            : derived;

        out.add(
          SheetMeta(
            id: id,
            updatedAt: ts.savedAt,
            title: title,
            rows: ts.rows.length,
          ),
        );
      } catch (_) {
        // Si la hoja está corrupta, la salteamos silenciosamente.
      }
    }

    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  // ----------------- Helpers internos -----------------

  static List<String> _getIndex() {
    final raw = html.window.localStorage[_indexKey];
    if (raw == null || raw.isEmpty) return <String>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return <String>[];
      final idsRaw = decoded['ids'];
      if (idsRaw is! List) return <String>[];
      return idsRaw.map((e) => e.toString()).toList(growable: true);
    } catch (_) {
      // Índice roto => arrancamos de cero.
      return <String>[];
    }
  }

  static void _saveIndex(List<String> ids) {
    html.window.localStorage[_indexKey] = jsonEncode({'ids': ids});
  }

  static String _createWith({required List<String> headers}) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final state = TableState(
      headers: headers,
      rows: List.generate(
        3,
            (_) => List<String>.filled(headers.length, ''),
      ),
      savedAt: DateTime.now(),
    );
    saveState(id, state);
    return id;
  }

  static String? _firstNonEmpty(List<String> xs) {
    for (final x in xs) {
      final t = x.trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }
}
