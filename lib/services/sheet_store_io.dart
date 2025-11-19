// lib/services/sheet_store_io.dart
// Store de planillas en disco (Android / iOS / desktop) usando SharedPreferences.
// - Maneja índice de hojas por id.
// - Cada hoja se guarda como JSON de TableState.
// - Soporta plantillas básicas (resistividades, inventario, checklist).

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

/// Plantillas opcionales.
enum TemplateKind {
  resistividades,
  inventario,
  checklist,
}

class SheetStore {
  static const String _indexKey = 'sheets:index'; // JSON: {"ids": [...]}
  static SharedPreferences? _prefs;

  /// Llamar una vez al inicio (ver main()).
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Devuelve el JSON raw guardado para una hoja, o null.
  static String? loadRaw(String id) {
    final prefs = _prefs;
    if (prefs == null) return null;
    return prefs.getString('sheet:$id');
  }

  /// Devuelve el TableState ya parseado, o null si no existe / está corrupto.
  static TableState? load(String id) {
    final raw = loadRaw(id);
    if (raw == null || raw.isEmpty) return null;
    return TableState.fromJsonString(raw);
  }

  /// Guarda estado y garantiza presencia en el índice.
  static void saveState(String id, TableState state) {
    final prefs = _prefs;
    if (prefs == null) return;

    // Normalizamos el estado y actualizamos el timestamp.
    final fixed = TableState(
      headers: state.headers,
      rows: state.rows,
      savedAt: DateTime.now(),
    );

    final json = fixed.toJsonString();
    prefs.setString('sheet:$id', json);

    final ids = _getIndex();
    if (!ids.contains(id)) {
      ids.insert(0, id);
      _saveIndex(ids);
    }
  }

  /// Renombra una hoja (sin tocar el contenido de la planilla).
  static void rename(String id, String newTitle) {
    final prefs = _prefs;
    if (prefs == null) return;
    prefs.setString('sheet:$id:title', newTitle.trim());
  }

  static String? _readTitle(String id) {
    final prefs = _prefs;
    if (prefs == null) return null;
    return prefs.getString('sheet:$id:title');
  }

  /// Crea hoja en blanco y retorna su id.
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

  /// Elimina hoja y la saca del índice (también el título).
  static void delete(String id) {
    final prefs = _prefs;
    if (prefs == null) return;

    prefs
      ..remove('sheet:$id')
      ..remove('sheet:$id:title');

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

      final ts = TableState.fromJsonString(raw);
      if (ts == null) {
        // Si el JSON está roto, no la mostramos en el listado.
        continue;
      }

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
    }

    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  // ----------------- Helpers internos -----------------

  static List<String> _getIndex() {
    final prefs = _prefs;
    if (prefs == null) return <String>[];

    final raw = prefs.getString(_indexKey);
    if (raw == null || raw.isEmpty) return <String>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return <String>[];
      final idsRaw = decoded['ids'];
      if (idsRaw is! List) return <String>[];
      return idsRaw.map((e) => e.toString()).toList(growable: true);
    } catch (_) {
      // Si el índice está corrupto, empezamos de cero.
      return <String>[];
    }
  }

  static void _saveIndex(List<String> ids) {
    final prefs = _prefs;
    if (prefs == null) return;
    prefs.setString(_indexKey, jsonEncode({'ids': ids}));
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
