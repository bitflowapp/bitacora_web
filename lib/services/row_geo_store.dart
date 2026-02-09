// lib/services/row_geo_store.dart
import 'package:hive_flutter/hive_flutter.dart';

class RowGeo {
  final String sheetId;
  final int row;
  final double lat;
  final double lng;
  final double? accuracyM;

  /// Momento de captura (idealmente en UTC).
  final DateTime ts;

  const RowGeo({
    required this.sheetId,
    required this.row,
    required this.lat,
    required this.lng,
    required this.ts,
    this.accuracyM,
  });

  Map<String, dynamic> toMap() => {
        'sheetId': sheetId,
        'row': row,
        'lat': lat,
        'lng': lng,
        'acc': accuracyM,
        'ts': ts.toUtc().toIso8601String(),
      };

  static RowGeo? from(Object? raw) {
    if (raw is! Map) return null;
    try {
      final tsRaw = raw['ts'] as String?;
      final parsedTs = tsRaw != null ? DateTime.tryParse(tsRaw) : null;

      return RowGeo(
        sheetId: raw['sheetId'] as String,
        row: (raw['row'] as num).toInt(),
        lat: (raw['lat'] as num).toDouble(),
        lng: (raw['lng'] as num).toDouble(),
        accuracyM: (raw['acc'] as num?)?.toDouble(),
        ts: (parsedTs ?? DateTime.now()).toUtc(),
      );
    } catch (_) {
      return null;
    }
  }
}

class RowGeoStore {
  RowGeoStore._();
  static final RowGeoStore I = RowGeoStore._();

  static const _boxName = 'geo_box';
  Box<dynamic>? _box;

  /// Asegura que la box esté abierta y lista.
  Future<Box<dynamic>> _ensureBox() async {
    final existing = _box;
    if (existing != null && existing.isOpen) {
      return existing;
    }

    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<dynamic>(_boxName);
    } else {
      // Importante: Hive.initFlutter() debe llamarse una sola vez en main()
      _box = await Hive.openBox<dynamic>(_boxName);
    }
    return _box!;
  }

  String _key(String sheetId, int row) => '$sheetId::$row';

  Future<void> save(RowGeo g) async {
    final box = await _ensureBox();
    await box.put(_key(g.sheetId, g.row), g.toMap());
  }

  Future<RowGeo?> get(String sheetId, int row) async {
    final box = await _ensureBox();
    final raw = box.get(_key(sheetId, row));
    return RowGeo.from(raw);
  }

  Future<void> clear(String sheetId, int row) async {
    final box = await _ensureBox();
    await box.delete(_key(sheetId, row));
  }

  /// Devuelve todas las geos existentes para filas [0, rows).
  Future<List<RowGeo>> listForSheet(String sheetId, int rows) async {
    final box = await _ensureBox();
    final out = <RowGeo>[];

    for (var r = 0; r < rows; r++) {
      final raw = box.get(_key(sheetId, r));
      final g = RowGeo.from(raw);
      if (g != null) out.add(g);
    }

    return out;
  }

  /// Opcional: limpiar todas las geos de una hoja.
  Future<void> clearSheet(String sheetId, int rows) async {
    final box = await _ensureBox();
    final keys = <String>[];
    for (var r = 0; r < rows; r++) {
      keys.add(_key(sheetId, r));
    }
    await box.deleteAll(keys);
  }
}
