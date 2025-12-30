// lib/services/att_store.dart
// Storage de adjuntos por (sheetId, row). Persistente con Hive (Web/IO).

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class Attachment {
  final String id;
  final String name;
  final String mime;
  final Uint8List bytes;
  final DateTime addedAt;

  const Attachment({
    required this.id,
    required this.name,
    required this.mime,
    required this.bytes,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mime': mime,
    'b64': base64Encode(bytes),
    'ts': addedAt.toIso8601String(),
  };

  static Attachment fromJson(Map<String, dynamic> m) => Attachment(
    id: m['id'] as String,
    name: m['name'] as String,
    mime: m['mime'] as String,
    bytes: Uint8List.fromList(base64Decode(m['b64'] as String)),
    addedAt: DateTime.tryParse(m['ts'] as String? ?? '') ?? DateTime.now(),
  );
}

class AttStore {
  AttStore._();
  static final AttStore I = AttStore._();

  static const _boxName = 'att_v1';
  Box<List>? _box;

  Future<void> _ensureBox() async {
    if (_box != null && _box!.isOpen) return;
    try {
      // idempotente; si ya está init, no falla
      await Hive.initFlutter();
    } catch (_) {}
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox<List>(_boxName);
    } else {
      _box = Hive.box<List>(_boxName);
    }
  }

  String _key(String sheetId, int row) => '$sheetId|$row';

  Future<List<Attachment>> list(String sheetId, int row) async {
    await _ensureBox();
    final raw = _box!.get(_key(sheetId, row));
    if (raw == null) return const [];
    return raw
        .cast<Map>()
        .map((e) => Attachment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<void> add(String sheetId, int row, Attachment a) async {
    await _ensureBox();
    final k = _key(sheetId, row);
    final current = await list(sheetId, row);
    final next = <Attachment>[...current, a];
    await _box!.put(k, next.map((e) => e.toJson()).toList(growable: false));
  }

  Future<void> remove(String sheetId, int row, String attId) async {
    await _ensureBox();
    final k = _key(sheetId, row);
    final current = await list(sheetId, row);
    final next = current.where((e) => e.id != attId).toList(growable: false);
    await _box!.put(k, next.map((e) => e.toJson()).toList(growable: false));
  }

  Future<void> clearRow(String sheetId, int row) async {
    await _ensureBox();
    await _box!.delete(_key(sheetId, row));
  }

  /// Para exportar todos los adjuntos de una fila (si querés armar un ZIP luego).
  Future<List<Attachment>> takeAll(String sheetId, int row) => list(sheetId, row);
}
