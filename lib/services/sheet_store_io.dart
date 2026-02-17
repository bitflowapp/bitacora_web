// lib/services/sheet_store_io.dart
// Unified SheetStore (no server) using SharedPreferences and the BitFlow model.
// Primary key: bitflow:sheet:<id> (JSON compatible with EditorScreen _SheetModel).
// Legacy fallback: sheet:<id> (TableState) + sheet:<id>:title.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitacora_web/core/i18n/app_strings.dart';

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

/// Plantillas opcionales (mismas que en legacy).
enum TemplateKind {
  plantilla,
  resistividades,
  inventario,
  checklist,
}

class _TemplateColumn {
  const _TemplateColumn({
    required this.label,
    required this.type,
    this.defaultValue = '',
    this.options = const <String>[],
  });

  final String label;
  final String type;
  final String defaultValue;
  final List<String> options;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'label': label,
        'type': type,
        'default': defaultValue,
        if (options.isNotEmpty) 'options': options,
      };
}

class _TemplateDefinition {
  const _TemplateDefinition({
    required this.name,
    required this.columns,
  });

  final String name;
  final List<_TemplateColumn> columns;

  List<String> headersWithPhotos(String photosHeader) {
    return <String>[
      ...columns.map((c) => c.label),
      photosHeader,
    ];
  }

  List<Map<String, dynamic>> columnSpecsWithPhotos(String photosHeader) {
    return <Map<String, dynamic>>[
      ...columns.map((c) => c.toJson()),
      <String, dynamic>{
        'label': photosHeader,
        'type': 'photos',
      },
    ];
  }

  List<List<String>> initialRows(int count) {
    final headersLen = columns.length + 1; // +Photos
    return List<List<String>>.generate(count, (_) {
      final row = List<String>.filled(headersLen, '');
      for (int i = 0; i < columns.length; i++) {
        row[i] = columns[i].defaultValue;
      }
      return row;
    });
  }
}

class SheetStore {
  static SharedPreferences? _prefs;

  static const String _sheetPrefix = 'bitflow:sheet:';
  static const String _backupMarker = ':bk:';

  // Legacy keys
  static const String _legacyPrefix = 'sheet:';
  static const String _legacyTitleSuffix = ':title';
  static const String _legacyIndexKey = 'sheets:index';

  static const String _photosHeader = AppStrings.photos;
  static const String _photosColId = 'col_photos';
  static int _sheetIdSeed = 0;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String _sheetKey(String id) => '$_sheetPrefix$id';

  static String? loadRaw(String id) {
    final prefs = _prefs;
    if (prefs == null) return null;
    final raw = prefs.getString(_sheetKey(id));
    if (raw != null && raw.trim().isNotEmpty) return raw;
    return prefs.getString('$_legacyPrefix$id');
  }

  /// Intenta devolver un TableState (desde nuevo JSON o legacy).
  static TableState? load(String id) {
    final raw = loadRaw(id);
    if (raw == null || raw.trim().isEmpty) return null;

    final legacy = TableState.fromJsonString(raw);
    if (legacy != null) return legacy;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final headers = (decoded['headers'] as List?)
              ?.map((e) => (e ?? '').toString())
              .toList() ??
          const <String>[];
      final rowsRaw = (decoded['rows'] as List?) ?? const [];
      final rows = <List<String>>[];
      for (final r in rowsRaw) {
        if (r is Map) {
          final cells = (r['cells'] as List?)
                  ?.map((e) => (e ?? '').toString())
                  .toList() ??
              const <String>[];
          rows.add(cells);
        } else if (r is List) {
          rows.add(r.map((e) => (e ?? '').toString()).toList());
        }
      }
      final savedAt =
          DateTime.tryParse((decoded['savedAt'] ?? '').toString()) ??
              DateTime.now();
      return TableState(headers: headers, rows: rows, savedAt: savedAt);
    } catch (_) {
      return null;
    }
  }

  /// Guarda estado simple (sin adjuntos) en el store nuevo.
  /// Preserva ids/metadata si ya existe un modelo previo.
  static void saveState(String id, TableState state) {
    final prefs = _prefs;
    if (prefs == null) return;

    final fixed = TableState(
      headers: state.headers,
      rows: state.rows,
      savedAt: DateTime.now(),
    );

    final existingRaw = prefs.getString(_sheetKey(id));
    Map<String, dynamic>? existingMap;
    if (existingRaw != null && existingRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(existingRaw);
        if (decoded is Map<String, dynamic>) existingMap = decoded;
      } catch (_) {}
    }

    final name = (existingMap?['name'] ?? '').toString();
    final colIds = _normalizeColIds(
      fixed.headers,
      (existingMap?['colIds'] as List?)
          ?.map((e) => (e ?? '').toString())
          .toList(),
    );

    final existingRows = existingMap?['rows'] as List?;
    final rows = _buildRowMaps(fixed.rows, existingRows: existingRows);

    final model = <String, dynamic>{
      'name': name,
      'savedAt': fixed.savedAt.toIso8601String(),
      'headers': fixed.headers,
      'colIds': colIds,
      'rows': rows,
    };

    final cellMeta = existingMap?['cellMeta'];
    if (cellMeta is Map && cellMeta.isNotEmpty) {
      model['cellMeta'] = cellMeta;
    }
    final columnSpecs = existingMap?['columnSpecs'];
    if (columnSpecs is List && columnSpecs.isNotEmpty) {
      model['columnSpecs'] = columnSpecs;
    }
    final columnPrefs = existingMap?['columnPrefs'];
    if (columnPrefs is Map && columnPrefs.isNotEmpty) {
      model['columnPrefs'] = columnPrefs;
    }
    final columnOrder = existingMap?['columnOrder'];
    if (columnOrder is List && columnOrder.isNotEmpty) {
      model['columnOrder'] = columnOrder;
    }
    final frozenColId = (existingMap?['frozenColId'] ?? '').toString().trim();
    if (frozenColId.isNotEmpty) {
      model['frozenColId'] = frozenColId;
    }
    final templateKind = (existingMap?['templateKind'] ?? '').toString().trim();
    if (templateKind.isNotEmpty) {
      model['templateKind'] = templateKind;
    }

    prefs.setString(_sheetKey(id), jsonEncode(model));
  }

  /// Guarda un modelo completo (BitFlow JSON) ya normalizado.
  static void saveModel(String id, Map<String, dynamic> model) {
    final prefs = _prefs;
    if (prefs == null) return;
    prefs.setString(_sheetKey(id), jsonEncode(model));
  }

  /// Crea una planilla a partir de un modelo completo (BitFlow JSON).
  /// Normaliza headers/colIds/rows y conserva cellMeta si existe.
  static String createFromModel(Map<String, dynamic> model) {
    final id = _nextSheetId();
    final normalized = normalizeModel(model);
    saveModel(id, normalized);
    return id;
  }

  /// Normaliza un modelo completo para guardarlo.
  static Map<String, dynamic> normalizeModel(Map<String, dynamic> raw) {
    final headers =
        (raw['headers'] as List?)?.map((e) => (e ?? '').toString()).toList() ??
            const <String>[];
    final colIds = _normalizeColIds(
      headers,
      (raw['colIds'] as List?)?.map((e) => (e ?? '').toString()).toList(),
    );

    final rowsRaw = (raw['rows'] as List?) ?? const [];
    final rows = <Map<String, dynamic>>[];
    for (int i = 0; i < rowsRaw.length; i++) {
      final rowRaw = rowsRaw[i];
      if (rowRaw is Map) {
        final idRaw = (rowRaw['id'] ?? '').toString().trim();
        final rowId = idRaw.isNotEmpty ? idRaw : _genRowId(i);
        final cellsRaw = rowRaw['cells'];
        var cells = (cellsRaw is List)
            ? cellsRaw.map((e) => (e ?? '').toString()).toList()
            : const <String>[];
        if (cells.length < headers.length) {
          cells = List<String>.from(cells)
            ..addAll(List<String>.filled(headers.length - cells.length, ''));
        }
        if (cells.length > headers.length) {
          cells = cells.sublist(0, headers.length);
        }
        final next = <String, dynamic>{
          'id': rowId,
          'cells': cells,
        };
        final photos = rowRaw['photos'];
        if (photos is List && photos.isNotEmpty) next['photos'] = photos;
        final gps = rowRaw['gps'];
        if (gps is Map && gps.isNotEmpty) next['gps'] = gps;
        rows.add(next);
        continue;
      }
      if (rowRaw is List) {
        var cells = rowRaw.map((e) => (e ?? '').toString()).toList();
        if (cells.length < headers.length) {
          cells = List<String>.from(cells)
            ..addAll(List<String>.filled(headers.length - cells.length, ''));
        }
        if (cells.length > headers.length) {
          cells = cells.sublist(0, headers.length);
        }
        rows.add(<String, dynamic>{
          'id': _genRowId(i),
          'cells': cells,
        });
      }
    }

    final normalized = <String, dynamic>{
      'name': (raw['name'] ?? '').toString(),
      'savedAt':
          (raw['savedAt'] ?? DateTime.now().toIso8601String()).toString(),
      'headers': headers,
      'colIds': colIds,
      'rows': rows,
    };

    final cellMeta = raw['cellMeta'];
    if (cellMeta is Map && cellMeta.isNotEmpty) {
      normalized['cellMeta'] = cellMeta;
    }
    final columnSpecs = raw['columnSpecs'];
    if (columnSpecs is List && columnSpecs.isNotEmpty) {
      normalized['columnSpecs'] = columnSpecs;
    }
    final columnPrefs = raw['columnPrefs'];
    if (columnPrefs is Map && columnPrefs.isNotEmpty) {
      normalized['columnPrefs'] = columnPrefs;
    }
    final columnOrder = raw['columnOrder'];
    if (columnOrder is List && columnOrder.isNotEmpty) {
      normalized['columnOrder'] = columnOrder;
    }
    final frozenColId = (raw['frozenColId'] ?? '').toString().trim();
    if (frozenColId.isNotEmpty) {
      normalized['frozenColId'] = frozenColId;
    }
    final templateKind = (raw['templateKind'] ?? '').toString().trim();
    if (templateKind.isNotEmpty) {
      normalized['templateKind'] = templateKind;
    }

    return normalized;
  }

  static void rename(String id, String newTitle) {
    final prefs = _prefs;
    if (prefs == null) return;
    final key = _sheetKey(id);
    final raw = prefs.getString(key);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          decoded['name'] = newTitle.trim();
          prefs.setString(key, jsonEncode(decoded));
          return;
        }
      } catch (_) {}
    }

    // Legacy fallback
    prefs.setString('$_legacyPrefix$id$_legacyTitleSuffix', newTitle.trim());
  }

  static String createNew() {
    final id = _nextSheetId();
    final headers = _defaultHeaders();
    final colIds = _defaultColIds(headers.length);
    final rows = _buildRowMaps(
      List.generate(3, (_) => List<String>.filled(headers.length, '')),
    );

    final model = <String, dynamic>{
      'name': '',
      'savedAt': DateTime.now().toIso8601String(),
      'headers': headers,
      'colIds': colIds,
      'rows': rows,
    };

    _prefs?.setString(_sheetKey(id), jsonEncode(model));
    return id;
  }

  static String createFromTemplate(TemplateKind kind) {
    final spec = _templateDefinitionOf(kind);
    final headers = spec.headersWithPhotos(_photosHeader);
    final rows = spec.initialRows(3);
    final columnSpecs = spec.columnSpecsWithPhotos(_photosHeader);
    return _createWith(
      name: spec.name,
      headers: headers,
      rows: rows,
      columnSpecs: columnSpecs,
      templateKind: kind.name,
    );
  }

  static Future<String> ensureDefault() async {
    final ids = _collectIds();
    if (ids.isEmpty) return createNew();
    return ids.first;
  }

  static void delete(String id) {
    final prefs = _prefs;
    if (prefs == null) return;
    prefs.remove(_sheetKey(id));

    for (final key in prefs.getKeys()) {
      if (key.startsWith('$_sheetPrefix$id$_backupMarker')) {
        prefs.remove(key);
      }
    }

    // Legacy cleanup
    prefs
      ..remove('$_legacyPrefix$id')
      ..remove('$_legacyPrefix$id$_legacyTitleSuffix');
  }

  static List<SheetMeta> list() {
    final prefs = _prefs;
    if (prefs == null) return <SheetMeta>[];

    final ids = _collectIds();
    final out = <SheetMeta>[];
    for (final id in ids) {
      final raw = prefs.getString(_sheetKey(id));
      if (raw != null && raw.trim().isNotEmpty) {
        final meta = _metaFromNewJson(id, raw);
        if (meta != null) out.add(meta);
        continue;
      }

      // Legacy
      final legacyRaw = prefs.getString('$_legacyPrefix$id');
      if (legacyRaw == null || legacyRaw.trim().isEmpty) continue;
      final legacyTitle =
          prefs.getString('$_legacyPrefix$id$_legacyTitleSuffix');
      final legacyMeta = _metaFromLegacy(
        id,
        legacyRaw,
        customTitle: legacyTitle,
      );
      if (legacyMeta != null) out.add(legacyMeta);
    }

    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  // ----------------- Helpers internos -----------------

  static List<String> _collectIds() {
    final prefs = _prefs;
    if (prefs == null) return <String>[];

    final keys = prefs.getKeys();
    final ids = <String, bool>{};

    for (final key in keys) {
      if (key.startsWith(_sheetPrefix)) {
        if (key.contains(_backupMarker)) continue;
        final id = key.substring(_sheetPrefix.length);
        // Ignore per-sheet metadata keys (e.g. "<id>:backup", "<id>:bk:list").
        if (id.contains(':')) continue;
        if (id.isEmpty) continue;
        ids[id] = true;
      }
    }

    for (final key in keys) {
      if (!key.startsWith(_legacyPrefix)) continue;
      if (key == _legacyIndexKey) continue;
      if (key.endsWith(_legacyTitleSuffix)) continue;
      final id = key.substring(_legacyPrefix.length);
      if (id.isEmpty) continue;
      ids.putIfAbsent(id, () => false);
    }

    return ids.keys.toList(growable: false);
  }

  static SheetMeta? _metaFromNewJson(String id, String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final name = (decoded['name'] ?? '').toString().trim();
      final headers = (decoded['headers'] as List?)
              ?.map((e) => (e ?? '').toString())
              .toList() ??
          const <String>[];
      final rowsRaw = (decoded['rows'] as List?) ?? const [];
      final savedAt =
          DateTime.tryParse((decoded['savedAt'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);

      final title = name.isNotEmpty ? name : (_firstNonEmpty(headers) ?? '');
      return SheetMeta(
        id: id,
        updatedAt: savedAt,
        title: title,
        rows: rowsRaw.length,
      );
    } catch (_) {
      return null;
    }
  }

  static SheetMeta? _metaFromLegacy(
    String id,
    String raw, {
    String? customTitle,
  }) {
    final ts = TableState.fromJsonString(raw);
    if (ts == null) return null;
    final trimmed = (customTitle ?? '').trim();
    final title =
        trimmed.isNotEmpty ? trimmed : (_firstNonEmpty(ts.headers) ?? '');
    return SheetMeta(
      id: id,
      updatedAt: ts.savedAt,
      title: title,
      rows: ts.rows.length,
    );
  }

  static _TemplateDefinition _templateDefinitionOf(TemplateKind kind) {
    switch (kind) {
      case TemplateKind.plantilla:
        return const _TemplateDefinition(
          name: 'Plantilla base',
          columns: <_TemplateColumn>[
            _TemplateColumn(label: 'Actividad', type: 'text'),
            _TemplateColumn(label: 'Detalle', type: 'text'),
            _TemplateColumn(
              label: 'Estado',
              type: 'status',
              defaultValue: 'OK',
              options: <String>['OK', 'Obs', 'Urgente'],
            ),
            _TemplateColumn(label: 'Responsable', type: 'text'),
            _TemplateColumn(label: 'Fecha', type: 'date'),
          ],
        );
      case TemplateKind.resistividades:
        return const _TemplateDefinition(
          name: 'Relevamiento resistividades',
          columns: <_TemplateColumn>[
            _TemplateColumn(label: 'Fecha', type: 'date'),
            _TemplateColumn(label: 'Progresiva', type: 'number'),
            _TemplateColumn(label: '1 m (Ohm)', type: 'number'),
            _TemplateColumn(label: '3 m (Ohm)', type: 'number'),
            _TemplateColumn(label: '5 m (Ohm)', type: 'number'),
            _TemplateColumn(label: 'Observaciones', type: 'text'),
          ],
        );
      case TemplateKind.inventario:
        return const _TemplateDefinition(
          name: 'Inventario simple',
          columns: <_TemplateColumn>[
            _TemplateColumn(label: 'Item', type: 'text'),
            _TemplateColumn(
                label: 'Cantidad', type: 'number', defaultValue: '1'),
            _TemplateColumn(label: 'Unidad', type: 'text', defaultValue: 'u'),
            _TemplateColumn(label: 'Ubicacion', type: 'text'),
            _TemplateColumn(label: 'Nota', type: 'text'),
          ],
        );
      case TemplateKind.checklist:
        return const _TemplateDefinition(
          name: 'Checklist diario',
          columns: <_TemplateColumn>[
            _TemplateColumn(label: 'Tarea', type: 'text'),
            _TemplateColumn(label: 'Responsable', type: 'text'),
            _TemplateColumn(
              label: 'Estado',
              type: 'status',
              defaultValue: 'OK',
              options: <String>['OK', 'Obs', 'Urgente'],
            ),
            _TemplateColumn(label: 'Fecha', type: 'date'),
            _TemplateColumn(label: 'Comentario', type: 'text'),
          ],
        );
    }
  }

  static String _createWith({
    required List<String> headers,
    String name = '',
    List<List<String>>? rows,
    List<Map<String, dynamic>>? columnSpecs,
    String? templateKind,
  }) {
    final id = _nextSheetId();
    final initialRows = rows ??
        List.generate(3, (_) => List<String>.filled(headers.length, ''));
    final colIds = _normalizeColIds(headers, null);

    final model = <String, dynamic>{
      'name': name,
      'savedAt': DateTime.now().toIso8601String(),
      'headers': headers,
      'colIds': colIds,
      'rows': _buildRowMaps(initialRows),
      'columnPrefs': _columnPrefsFromSpecs(columnSpecs, colIds),
      if (columnSpecs != null && columnSpecs.isNotEmpty)
        'columnSpecs': columnSpecs,
      if (templateKind != null && templateKind.trim().isNotEmpty)
        'templateKind': templateKind.trim(),
    };

    _prefs?.setString(_sheetKey(id), jsonEncode(model));
    return id;
  }

  static List<Map<String, dynamic>> _buildRowMaps(
    List<List<String>> rows, {
    List<dynamic>? existingRows,
  }) {
    final out = <Map<String, dynamic>>[];
    for (int i = 0; i < rows.length; i++) {
      final existing = (existingRows != null &&
              i < existingRows.length &&
              existingRows[i] is Map)
          ? existingRows[i] as Map
          : null;
      final existingId = (existing?['id'] ?? '').toString().trim();
      final rowId = existingId.isNotEmpty ? existingId : _genRowId(i);
      final next = <String, dynamic>{
        'id': rowId,
        'cells': rows[i],
      };
      final photos = existing?['photos'];
      if (photos is List && photos.isNotEmpty) {
        next['photos'] = photos;
      }
      final gps = existing?['gps'];
      if (gps is Map && gps.isNotEmpty) {
        next['gps'] = gps;
      }
      out.add(next);
    }
    return out;
  }

  static List<String> _defaultHeaders() {
    const cols = 15;
    final h = List<String>.filled(cols, '');
    if (h.isNotEmpty) h[h.length - 1] = _photosHeader;
    return h;
  }

  static Map<String, Map<String, dynamic>> _columnPrefsFromSpecs(
    List<Map<String, dynamic>>? specs,
    List<String> colIds,
  ) {
    if (specs == null || specs.isEmpty) return <String, Map<String, dynamic>>{};
    final out = <String, Map<String, dynamic>>{};
    for (int i = 0; i < specs.length && i < colIds.length; i++) {
      final colId = colIds[i];
      if (colId == _photosColId) continue;
      final spec = specs[i];
      final typeRaw = (spec['type'] ?? '').toString().trim().toLowerCase();
      if (typeRaw.isEmpty || typeRaw == 'photos') continue;
      final pref = <String, dynamic>{
        'type': typeRaw == 'enum' ? 'status' : typeRaw,
      };
      final options = spec['options'];
      if (options is List && options.isNotEmpty) {
        pref['enumValues'] = options.map((e) => e.toString()).toList();
      }
      out[colId] = pref;
    }
    return out;
  }

  static List<String> _defaultColIds(int len) {
    final out = <String>[];
    for (int i = 0; i < len; i++) {
      out.add(i == len - 1 ? _photosColId : '');
    }
    return out;
  }

  static List<String> _normalizeColIds(
    List<String> headers,
    List<String>? incoming,
  ) {
    final len = headers.length;
    final out = <String>[];
    for (int i = 0; i < len; i++) {
      final raw = (incoming != null && i < incoming.length) ? incoming[i] : '';
      final trimmed = raw.trim();
      out.add(trimmed.isEmpty ? _genColId(i) : trimmed);
    }
    if (len > 0) out[len - 1] = _photosColId;
    return out;
  }

  static String _genRowId(int salt) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    return 'r_${ts}_$salt';
  }

  static String _genColId(int salt) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    return 'c_${ts}_$salt';
  }

  static String _nextSheetId() {
    final prefs = _prefs;
    for (int attempt = 0; attempt < 64; attempt++) {
      final id = _sheetIdCandidate();
      if (prefs == null) return id;
      final hasNew = prefs.getString(_sheetKey(id)) != null;
      final hasLegacy = prefs.getString('$_legacyPrefix$id') != null;
      if (!hasNew && !hasLegacy) return id;
    }
    return _sheetIdCandidate();
  }

  static String _sheetIdCandidate() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final seed = (_sheetIdSeed++ & 0x7fffffff).toRadixString(36);
    return '${ts}_$seed';
  }

  static String? _firstNonEmpty(List<String> xs) {
    for (final x in xs) {
      final t = x.trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }
}
