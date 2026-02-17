import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'outbox_op.dart';

class OutboxStore {
  OutboxStore._();

  static final OutboxStore instance = OutboxStore._();

  static const String _boxName = 'bitflow_outbox_v1';

  Box<String>? _box;

  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;

    try {
      await Hive.initFlutter();
    } catch (_) {
      // Hive can already be initialized by other services.
    }

    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<String>(_boxName);
      return;
    }

    _box = await Hive.openBox<String>(_boxName);
  }

  Future<void> enqueue(OutboxOp op) async {
    final box = await _ensureBox();
    final value = jsonEncode(op.toJson());
    await box.put(op.id, value);
  }

  Future<bool> ensureQueuedKind(String kind) async {
    final normalizedKind = kind.trim();
    if (normalizedKind.isEmpty) return false;

    final box = await _ensureBox();
    for (final value in box.values) {
      final op = _parse(value);
      if (op == null) continue;
      if (op.kind != normalizedKind) continue;
      if (op.status == OutboxOp.statusQueued ||
          op.status == OutboxOp.statusInFlight) {
        return false;
      }
    }

    final op = OutboxOp.create(
      kind: normalizedKind,
      payload: <String, dynamic>{'hint': 'cell_meta_dirty'},
    );
    await enqueue(op);
    return true;
  }

  Future<List<OutboxOp>> listReady({
    DateTime? now,
    int limit = 25,
  }) async {
    final when = (now ?? DateTime.now()).toUtc();
    final all = await _listAll();

    final ready = all.where((op) {
      if (op.status == OutboxOp.statusQueued) return true;
      if (op.status != OutboxOp.statusError) return false;
      final next = op.nextAttemptAt;
      if (next == null) return true;
      return !next.toUtc().isAfter(when);
    }).toList(growable: false)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (limit <= 0 || ready.length <= limit) return ready;
    return ready.take(limit).toList(growable: false);
  }

  Future<void> markInFlight(String id) async {
    final op = await _readById(id);
    if (op == null) return;
    await enqueue(
      op.copyWith(
        status: OutboxOp.statusInFlight,
        clearLastError: true,
      ),
    );
  }

  Future<void> markDone(String id) async {
    final op = await _readById(id);
    if (op == null) return;
    await enqueue(
      op.copyWith(
        status: OutboxOp.statusDone,
        clearNextAttemptAt: true,
        clearLastError: true,
      ),
    );
  }

  Future<void> markError(
    String id,
    String error,
    DateTime nextAttemptAt,
  ) async {
    final op = await _readById(id);
    if (op == null) return;

    await enqueue(
      op.copyWith(
        status: OutboxOp.statusError,
        attempts: op.attempts + 1,
        nextAttemptAt: nextAttemptAt.toUtc(),
        lastError: error.trim().isEmpty ? 'error' : error.trim(),
      ),
    );
  }

  Future<Map<String, int>> countsByStatus() async {
    final all = await _listAll();
    final out = <String, int>{
      OutboxOp.statusQueued: 0,
      OutboxOp.statusInFlight: 0,
      OutboxOp.statusDone: 0,
      OutboxOp.statusError: 0,
    };

    for (final op in all) {
      out.update(op.status, (value) => value + 1, ifAbsent: () => 1);
    }
    return out;
  }

  Future<void> pruneDone({
    Duration olderThan = const Duration(days: 7),
  }) async {
    final box = await _ensureBox();
    final threshold = DateTime.now().toUtc().subtract(olderThan);

    final deleteKeys = <String>[];
    for (final key in box.keys) {
      if (key is! String) continue;
      final op = _parse(box.get(key));
      if (op == null) continue;
      if (op.status != OutboxOp.statusDone) continue;
      if (op.createdAt.isBefore(threshold)) {
        deleteKeys.add(key);
      }
    }

    if (deleteKeys.isEmpty) return;
    await box.deleteAll(deleteKeys);
  }

  Future<Box<String>> _ensureBox() async {
    await init();
    return _box!;
  }

  Future<OutboxOp?> _readById(String id) async {
    final box = await _ensureBox();
    final raw = box.get(id);
    return _parse(raw);
  }

  Future<List<OutboxOp>> _listAll() async {
    final box = await _ensureBox();
    final out = <OutboxOp>[];
    for (final value in box.values) {
      final parsed = _parse(value);
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  OutboxOp? _parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      return OutboxOp.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}
