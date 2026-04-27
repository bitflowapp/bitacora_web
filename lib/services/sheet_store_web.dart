// lib/services/sheet_store_web.dart
// SheetStore - IndexedDB (Hive) primary storage, SharedPreferences read-fallback.
// Primary key: bitflow:sheet:<id> (JSON compatible with EditorScreen _SheetModel).
// Legacy fallback: sheet:<id> (TableState) + sheet:<id>:title.

import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/table_state.dart';

/// Common KV interface shared by the Hive-backed store and the in-memory
/// fallback so [SheetStore] can swap between them without branching.
abstract class _Kv {
  String? getString(String key);
  void setString(String key, String value);
  void remove(String key);
  Set<String> getKeys();
  Object? get lastWriteError;
  Future<void> flushPendingWrites();
}

/// In-memory fallback used when IndexedDB is unavailable (Safari Private
/// Browsing, storage-restricted contexts, first-install quota issues, etc.).
/// Data is NOT persisted across page reloads, but the app remains fully
/// usable for demo and single-session workflows.
class _MemoryKv implements _Kv {
  final Map<String, String> _data = <String, String>{};

  @override
  String? getString(String key) => _data[key];

  @override
  void setString(String key, String value) {
    _data[key] = value;
  }

  @override
  void remove(String key) {
    _data.remove(key);
  }

  @override
  Set<String> getKeys() => _data.keys.toSet();

  @override
  Object? get lastWriteError => null;

  @override
  Future<void> flushPendingWrites() async {}
}

/// Synchronous key-value store backed by a Hive Box (IndexedDB on web).
/// On init it migrates any SharedPreferences sheet keys to Hive once.
class _HiveKv implements _Kv {
  _HiveKv(this._box, this._sp);

  final Box<dynamic> _box;
  final SharedPreferences _sp;
  final Set<Future<void>> _pendingWrites = <Future<void>>{};
  Object? _lastWriteError;

  static const String _boxName = 'bitflow_sheets';
  static const String _migratedKey = '__sp_migrated_v1';
  static const String _sheetPrefix = 'bitflow:sheet:';
  static const String _legacyPrefix = 'sheet:';
  static const String _legacyIndexKey = 'sheets:index';

  static Future<_HiveKv> open(SharedPreferences sp) async {
    try {
      await Hive.initFlutter();
    } catch (_) {
      // Hive init is process-wide; repeated calls can throw on some platforms.
    }
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<dynamic>(_boxName);
    }
    final box = Hive.box<dynamic>(_boxName);
    final kv = _HiveKv(box, sp);
    if (box.get(_migratedKey) != true) {
      await kv._migrateFrom(sp);
      await box.put(_migratedKey, true);
    }
    return kv;
  }

  Future<void> _migrateFrom(SharedPreferences sp) async {
    for (final key in sp.getKeys()) {
      if (key.startsWith('bitflow:sheet:') ||
          key.startsWith('sheet:') ||
          key == 'sheets:index') {
        final v = sp.getString(key);
        if (v != null) await _box.put(key, v);
      }
    }
  }

  @override
  String? getString(String key) {
    final v = _box.get(key);
    final hiveValue = v is String ? v : null;
    final prefsValue = _sp.getString(key);
    if (_isSheetPayloadKey(key)) {
      return _freshestSheetPayload(hiveValue, prefsValue);
    }
    return hiveValue ?? prefsValue;
  }

  @override
  void setString(String key, String value) {
    _track(
      Future.wait<void>([
        _box.put(key, value),
        _sp.setString(key, value).then((ok) {
          if (!ok) throw StateError('SharedPreferences write failed: $key');
        }),
      ]),
    );
  }

  @override
  void remove(String key) {
    _track(
      Future.wait<void>([
        _box.delete(key),
        _sp.remove(key).then((ok) {
          if (!ok) throw StateError('SharedPreferences remove failed: $key');
        }),
      ]),
    );
  }

  @override
  Set<String> getKeys() {
    final keys = _box.keys.whereType<String>().toSet();
    keys.addAll(_sp.getKeys().where(_isStoreKey));
    return keys;
  }

  @override
  Object? get lastWriteError => _lastWriteError;

  @override
  Future<void> flushPendingWrites() async {
    while (_pendingWrites.isNotEmpty) {
      final pending = List<Future<void>>.of(_pendingWrites);
      await Future.wait(pending);
    }
    final error = _lastWriteError;
    if (error != null) {
      _lastWriteError = null;
      throw StateError('SheetStore write failed: $error');
    }
  }

  void _track(Future<void> write) {
    _pendingWrites.add(write);
    unawaited(
      write.catchError((Object error, StackTrace stackTrace) {
        _lastWriteError = error;
      }).whenComplete(() {
        _pendingWrites.remove(write);
      }),
    );
  }

  static bool _isStoreKey(String key) {
    return key.startsWith(_sheetPrefix) ||
        key.startsWith(_legacyPrefix) ||
        key == _legacyIndexKey;
  }

  static bool _isSheetPayloadKey(String key) {
    if (!key.startsWith(_sheetPrefix)) return false;
    final id = key.substring(_sheetPrefix.length);
    return id.isNotEmpty && !id.contains(':');
  }

  static String? _freshestSheetPayload(String? a, String? b) {
    if (a == null || a.trim().isEmpty) return b;
    if (b == null || b.trim().isEmpty) return a;
    final aSavedAt = _savedAtMs(a);
    final bSavedAt = _savedAtMs(b);
    if (bSavedAt > aSavedAt) return b;
    return a;
  }

  static int _savedAtMs(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return 0;
      final parsed = DateTime.tryParse((decoded['savedAt'] ?? '').toString());
      return parsed?.millisecondsSinceEpoch ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

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
  proteccionCatodica,
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
    this.rows = const <List<String>>[],
  });

  final String name;
  final List<_TemplateColumn> columns;
  final List<List<String>> rows;

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
    if (rows.isNotEmpty) {
      return rows.map((source) {
        final row = List<String>.filled(headersLen, '');
        for (int i = 0; i < headersLen && i < source.length; i++) {
          row[i] = source[i];
        }
        return row;
      }).toList(growable: false);
    }
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
  static _Kv? _kv;

  /// True when the active store is backed by IndexedDB (Hive).
  /// False means we are running from a transient in-memory store — data will
  /// not survive a page reload.  Callers may read this to show a warning UI.
  static bool _isPersistent = false;
  static bool get isPersistent => _isPersistent;

  /// The error that caused the persistent store to be unavailable, if any.
  static Object? _storeInitError;
  static Object? get storeInitError => _storeInitError;

  static const String _sheetPrefix = 'bitflow:sheet:';
  static const String _backupMarker = ':bk:';

  // Legacy keys
  static const String _legacyPrefix = 'sheet:';
  static const String _legacyTitleSuffix = ':title';
  static const String _legacyIndexKey = 'sheets:index';

  static const String _photosHeader = 'Photos';
  static const String _photosColId = 'col_photos';
  static int _sheetIdSeed = 0;

  /// Initialises the store.  Never throws.
  ///
  /// Tries IndexedDB (Hive) first with an internal 5-second guard so Safari
  /// hangs don't propagate to the boot splash.  On any failure (private
  /// browsing, quota, ITP restrictions) falls back to an in-memory store so
  /// the app remains fully usable for the current session.
  static Future<void> init() async {
    try {
      final sp = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 4));
      _kv = await _HiveKv.open(sp).timeout(const Duration(seconds: 4));
      _isPersistent = true;
      _storeInitError = null;
    } catch (e) {
      _kv ??= _MemoryKv();
      _isPersistent = false;
      _storeInitError = e;
    }
  }

  static Object? get lastWriteError => _kv?.lastWriteError;

  static Future<void> flushPendingWrites() async {
    await _kv?.flushPendingWrites();
  }

  static String _sheetKey(String id) => '$_sheetPrefix$id';

  static String? loadRaw(String id) {
    final kv = _kv;
    if (kv == null) return null;
    final raw = kv.getString(_sheetKey(id));
    if (raw != null && raw.trim().isNotEmpty) return raw;
    return kv.getString('$_legacyPrefix$id');
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
    final kv = _kv;
    if (kv == null) return;

    final fixed = TableState(
      headers: state.headers,
      rows: state.rows,
      savedAt: DateTime.now(),
    );

    final existingRaw = kv.getString(_sheetKey(id));
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

    kv.setString(_sheetKey(id), jsonEncode(model));
  }

  /// Guarda un modelo completo (BitFlow JSON) ya normalizado.
  static void saveModel(String id, Map<String, dynamic> model) {
    final kv = _kv;
    if (kv == null) return;
    kv.setString(_sheetKey(id), jsonEncode(model));
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
        final review = rowRaw['review'];
        if (review is Map && review.isNotEmpty) next['review'] = review;
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
    final kv = _kv;
    if (kv == null) return;
    final key = _sheetKey(id);
    final raw = kv.getString(key);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          decoded['name'] = newTitle.trim();
          kv.setString(key, jsonEncode(decoded));
          return;
        }
      } catch (_) {}
    }

    // Legacy fallback
    kv.setString('$_legacyPrefix$id$_legacyTitleSuffix', newTitle.trim());
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

    _kv?.setString(_sheetKey(id), jsonEncode(model));
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
    final kv = _kv;
    if (kv == null) return;
    kv.remove(_sheetKey(id));

    for (final key in kv.getKeys()) {
      if (key.startsWith('$_sheetPrefix$id$_backupMarker')) {
        kv.remove(key);
      }
    }

    // Legacy cleanup
    kv
      ..remove('$_legacyPrefix$id')
      ..remove('$_legacyPrefix$id$_legacyTitleSuffix');
  }

  static List<SheetMeta> list() {
    final kv = _kv;
    if (kv == null) return <SheetMeta>[];

    final ids = _collectIds();
    final out = <SheetMeta>[];
    for (final id in ids) {
      final raw = kv.getString(_sheetKey(id));
      if (raw != null && raw.trim().isNotEmpty) {
        final meta = _metaFromNewJson(id, raw);
        if (meta != null) out.add(meta);
        continue;
      }

      // Legacy
      final legacyRaw = kv.getString('$_legacyPrefix$id');
      if (legacyRaw == null || legacyRaw.trim().isEmpty) continue;
      final legacyTitle = kv.getString('$_legacyPrefix$id$_legacyTitleSuffix');
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
    final kv = _kv;
    if (kv == null) return <String>[];

    final keys = kv.getKeys();
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
          name: 'Relevamiento técnico con evidencias',
          columns: <_TemplateColumn>[
            _TemplateColumn(label: 'Fecha', type: 'date'),
            _TemplateColumn(label: 'Cliente / Obra', type: 'text'),
            _TemplateColumn(label: 'Sector', type: 'text'),
            _TemplateColumn(label: 'Hallazgo', type: 'text'),
            _TemplateColumn(
              label: 'Criticidad',
              type: 'status',
              defaultValue: 'Media',
              options: <String>['Baja', 'Media', 'Alta'],
            ),
            _TemplateColumn(label: 'Accion recomendada', type: 'text'),
            _TemplateColumn(label: 'Responsable', type: 'text'),
          ],
          rows: <List<String>>[
            <String>[
              '2026-04-20',
              'Operadora Norte',
              'Manifold 3',
              'Etiqueta ilegible en valvula bypass',
              'Media',
              'Reponer identificacion y fotografiar cierre.',
              'S. Perez',
              '',
            ],
            <String>[
              '2026-04-20',
              'Operadora Norte',
              'Linea 6"',
              'Soporte con corrosion superficial',
              'Media',
              'Lijar, pintar y registrar evidencia final.',
              'S. Perez',
              '',
            ],
          ],
        );
      case TemplateKind.resistividades:
        return const _TemplateDefinition(
          name: 'Puesta a tierra - mediciones',
          columns: <_TemplateColumn>[
            _TemplateColumn(label: 'Fecha', type: 'date'),
            _TemplateColumn(label: 'Sector', type: 'text'),
            _TemplateColumn(label: 'Punto PAT', type: 'text'),
            _TemplateColumn(label: 'Resistencia (Ohm)', type: 'number'),
            _TemplateColumn(
              label: 'Continuidad',
              type: 'status',
              defaultValue: 'OK',
              options: <String>['OK', 'Obs', 'Urgente'],
            ),
            _TemplateColumn(
              label: 'Estado',
              type: 'status',
              defaultValue: 'OK',
              options: <String>['OK', 'Obs', 'Urgente'],
            ),
            _TemplateColumn(label: 'Observaciones', type: 'text'),
            _TemplateColumn(label: 'Responsable', type: 'text'),
          ],
          rows: <List<String>>[
            <String>[
              '2026-04-21',
              'Tablero bombas',
              'PAT-TB-01',
              '2.8',
              'OK',
              'OK',
              'Bornes limpios. Se adjunta foto de jabalina.',
              'L. Vega',
              '',
            ],
            <String>[
              '2026-04-21',
              'Sala MCC',
              'PAT-MCC-02',
              '4.6',
              'OK',
              'Obs',
              'Valor alto para criterio interno. Repetir.',
              'L. Vega',
              '',
            ],
          ],
        );
      case TemplateKind.proteccionCatodica:
        return const _TemplateDefinition(
          name: 'Relevamiento Proteccion Catodica',
          columns: <_TemplateColumn>[
            _TemplateColumn(label: 'Fecha', type: 'date'),
            _TemplateColumn(label: 'Progresiva', type: 'number'),
            _TemplateColumn(label: 'Punto de medición', type: 'text'),
            _TemplateColumn(label: 'Potencial ON (V)', type: 'number'),
            _TemplateColumn(label: 'Potencial OFF (V)', type: 'number'),
            _TemplateColumn(label: 'IR drop (V)', type: 'number'),
            _TemplateColumn(
              label: 'Cupon',
              type: 'status',
              defaultValue: 'Polarizado',
              options: <String>['Polarizado', 'Despolarizado', 'N/A'],
            ),
            _TemplateColumn(
              label: 'Estado',
              type: 'status',
              defaultValue: 'OK',
              options: <String>['OK', 'Obs', 'Urgente'],
            ),
            _TemplateColumn(label: 'Observaciones', type: 'text'),
            _TemplateColumn(label: 'Responsable', type: 'text'),
          ],
          rows: <List<String>>[
            <String>[
              '2026-04-22',
              '12+000',
              'CMP-120',
              '-1.12',
              '-0.92',
              '0.20',
              'Polarizado',
              'OK',
              'Caja limpia. Referencia Cu/CuSO4 estable.',
              'M. Luna',
              '',
            ],
            <String>[
              '2026-04-22',
              '12+050',
              'CMP-122',
              '-0.82',
              '-0.61',
              '0.21',
              'Despolarizado',
              'Obs',
              'Revisar continuidad y repetir medición.',
              'A. Rojas',
              '',
            ],
          ],
        );
      case TemplateKind.inventario:
        return const _TemplateDefinition(
          name: 'Control operativo simple',
          columns: <_TemplateColumn>[
            _TemplateColumn(label: 'Fecha', type: 'date'),
            _TemplateColumn(label: 'Equipo / Area', type: 'text'),
            _TemplateColumn(label: 'Control', type: 'text'),
            _TemplateColumn(label: 'Valor', type: 'text'),
            _TemplateColumn(
              label: 'Estado',
              type: 'status',
              defaultValue: 'OK',
              options: <String>['OK', 'Obs', 'Urgente'],
            ),
            _TemplateColumn(label: 'Accion', type: 'text'),
            _TemplateColumn(label: 'Responsable', type: 'text'),
          ],
          rows: <List<String>>[
            <String>[
              '2026-04-18',
              'Bomba P-101',
              'Presion descarga',
              '8.4 bar',
              'OK',
              'Sin acción',
              'G. Molina',
              '',
            ],
            <String>[
              '2026-04-18',
              'Compresor C-02',
              'Nivel aceite',
              'Bajo',
              'Obs',
              'Completar nivel y registrar foto.',
              'G. Molina',
              '',
            ],
          ],
        );
      case TemplateKind.checklist:
        return const _TemplateDefinition(
          name: 'Inspección operativa de campo',
          columns: <_TemplateColumn>[
            _TemplateColumn(label: 'Fecha', type: 'date'),
            _TemplateColumn(label: 'Frente', type: 'text'),
            _TemplateColumn(label: 'Actividad', type: 'text'),
            _TemplateColumn(
              label: 'Estado',
              type: 'status',
              defaultValue: 'OK',
              options: <String>['OK', 'Obs', 'Urgente'],
            ),
            _TemplateColumn(label: 'Observaciones', type: 'text'),
            _TemplateColumn(label: 'Responsable', type: 'text'),
          ],
          rows: <List<String>>[
            <String>[
              '2026-04-19',
              'Norte',
              'Replanteo de traza',
              'OK',
              'Puntos marcados y fotografiados.',
              'J. Soto',
              '',
            ],
            <String>[
              '2026-04-19',
              'Sur',
              'Verificacion de tapada',
              'OK',
              'Cota verificada contra plano IFC.',
              'A. Rojas',
              '',
            ],
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

    _kv?.setString(_sheetKey(id), jsonEncode(model));
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
      final review = existing?['review'];
      if (review is Map && review.isNotEmpty) {
        next['review'] = review;
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
    final kv = _kv;
    for (int attempt = 0; attempt < 64; attempt++) {
      final id = _sheetIdCandidate();
      if (kv == null) return id;
      final hasNew = kv.getString(_sheetKey(id)) != null;
      final hasLegacy = kv.getString('$_legacyPrefix$id') != null;
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
