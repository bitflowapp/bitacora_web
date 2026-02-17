import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:bitacora_web/services/cloud_store.dart';

import 'outbox_op.dart';
import 'outbox_store.dart';

abstract class OutboxExecutor {
  Future<void> execute(OutboxOp op);
}

class DefaultOutboxExecutor implements OutboxExecutor {
  static const String kindSyncDirtyAttachments = 'sync_dirty_attachments';

  @override
  Future<void> execute(OutboxOp op) async {
    switch (op.kind) {
      case kindSyncDirtyAttachments:
        await CloudStore.syncPendingNow();
        return;
      default:
        throw UnsupportedError('No handler for kind: ${op.kind}');
    }
  }
}

class SyncCoordinator {
  SyncCoordinator._({
    OutboxStore? store,
    OutboxExecutor? executor,
  })  : _store = store ?? OutboxStore.instance,
        _executor = executor ?? DefaultOutboxExecutor();

  static final SyncCoordinator instance = SyncCoordinator._();

  final OutboxStore _store;
  OutboxExecutor _executor;

  bool _running = false;
  bool _disposed = false;
  bool _pumpInProgress = false;
  bool _pumpRequestedAgain = false;
  Timer? _timer;

  static const Duration _tickInterval = Duration(seconds: 12);
  static const int _maxOpsPerPump = 3;
  static final math.Random _rng = math.Random();

  @visibleForTesting
  void setExecutor(OutboxExecutor executor) {
    _executor = executor;
  }

  void start() {
    if (_disposed || _running) return;
    _running = true;
    _timer?.cancel();
    _timer = Timer.periodic(_tickInterval, (_) {
      if (!_running || _disposed) return;
      unawaited(_pump());
    });
    kick();
  }

  void kick() {
    if (_disposed) return;
    if (!_running) {
      start();
      return;
    }
    unawaited(_pump());
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _pump() async {
    if (_disposed || !_running) return;

    if (_pumpInProgress) {
      _pumpRequestedAgain = true;
      return;
    }

    _pumpInProgress = true;
    try {
      var processed = 0;
      while (processed < _maxOpsPerPump) {
        final ready = await _store.listReady(limit: 1);
        if (ready.isEmpty) break;

        final op = ready.first;
        await _store.markInFlight(op.id);

        try {
          await _executor.execute(op);
          await _store.markDone(op.id);
        } catch (error) {
          final now = DateTime.now().toUtc();
          final nextAttempt = _computeNextAttemptAt(op, error, now);
          await _store.markError(op.id, _errorMessage(error), nextAttempt);
        }

        processed++;
      }

      final counts = await _store.countsByStatus();
      debugPrint(
        '[sync] pump queued=${counts[OutboxOp.statusQueued] ?? 0} '
        'in_flight=${counts[OutboxOp.statusInFlight] ?? 0} '
        'error=${counts[OutboxOp.statusError] ?? 0}',
      );
    } finally {
      _pumpInProgress = false;
      if (_pumpRequestedAgain && !_disposed && _running) {
        _pumpRequestedAgain = false;
        unawaited(_pump());
      }
    }
  }

  DateTime _computeNextAttemptAt(OutboxOp op, Object error, DateTime nowUtc) {
    final statusCode = _extractStatusCode(error);
    final transient = _isTransient(error, statusCode);

    if (!transient) {
      return nowUtc.add(
        Duration(hours: 24, milliseconds: _rng.nextInt(1001)),
      );
    }

    final nextAttempts = (op.attempts < 0 ? 0 : op.attempts) + 1;
    final multiplier = math.pow(2, nextAttempts).toInt();
    final seconds = math.min(multiplier * 2, 300);
    return nowUtc.add(
      Duration(seconds: seconds, milliseconds: _rng.nextInt(1001)),
    );
  }

  bool _isTransient(Object error, int? statusCode) {
    if (error is TimeoutException) return true;

    final typeName = error.runtimeType.toString();
    if (typeName.contains('SocketException')) return true;

    if (statusCode != null) {
      if (statusCode >= 500) return true;
      if (statusCode == 408 || statusCode == 429) return true;
      if (statusCode >= 400 && statusCode <= 499) return false;
    }

    return true;
  }

  int? _extractStatusCode(Object error) {
    if (error is OutboxHttpException) return error.statusCode;

    try {
      final dynamicError = error as dynamic;
      final code = dynamicError.statusCode;
      if (code is num) return code.toInt();
    } catch (_) {}

    try {
      final dynamicError = error as dynamic;
      final response = dynamicError.response;
      final code = response?.statusCode;
      if (code is num) return code.toInt();
    } catch (_) {}

    return null;
  }

  String _errorMessage(Object error) {
    final text = error.toString().trim();
    return text.isEmpty ? 'sync_error' : text;
  }
}

class OutboxHttpException implements Exception {
  const OutboxHttpException(this.statusCode, [this.message = '']);

  final int statusCode;
  final String message;

  @override
  String toString() {
    final tail = message.trim();
    if (tail.isEmpty) return 'HTTP $statusCode';
    return 'HTTP $statusCode: $tail';
  }
}
