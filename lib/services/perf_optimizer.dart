// lib/services/perf_optimizer.dart
// Motorcito de rendimiento para Bit Flow:
// - Ejecuta tareas CPU-heavy en isolate cuando se puede.
// - Mide “jank” estimado.
// - Corre tareas después de frame para no trabar scroll/gestos.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

typedef CpuCallback<P, R> = R Function(P param);

class PerfOptimizer {
  PerfOptimizer._();

  static bool _initialized = false;

  /// Presupuesto de frame (~16 ms para 60fps).
  static Duration _frameBudget = const Duration(milliseconds: 16);

  /// Cantidad acumulada de frames “virtuales” que probablemente se dropearon.
  static int _frameDrops = 0;

  /// Cantidad de jobs CPU-bound en curso.
  static int _activeCpuJobs = 0;

  /// Llamar una sola vez al inicio de la app (opcional).
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Pequeño warmup para JIT / web.
    if (kDebugMode) {
      debugPrint('[PerfOptimizer] init()');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }

  /// Configura el presupuesto de frame (para 120Hz, por ejemplo).
  static void configure({Duration? frameBudget}) {
    if (frameBudget != null) {
      _frameBudget = frameBudget;
    }
  }

  static Duration get frameBudget => _frameBudget;
  static int get frameDrops => _frameDrops;
  static int get activeCpuJobs => _activeCpuJobs;

  /// “Jank rate” estimado por job, 0 = fluido.
  static double get estimatedJankRate {
    if (_activeCpuJobs <= 0 || _frameDrops <= 0) return 0;
    return _frameDrops / math.max(1, _activeCpuJobs);
  }

  /// Ejecuta una función CPU-heavy de manera segura:
  /// - En Web: corre en el mismo hilo (no hay compute).
  /// - En Android/iOS/desktop: usa `compute` (otro isolate) si `preferIsolate == true`.
  ///
  /// IMPORTANTE: si usás `preferIsolate: true`, `fn` debe ser:
  /// - top-level o static
  /// - sin capturar `BuildContext` ni objetos no-serializables.
  static Future<R> runCpuBound<R, P>({
    required CpuCallback<P, R> fn,
    required P param,
    bool preferIsolate = true,
  }) async {
    _activeCpuJobs++;
    try {
      // En Web no hay compute real; corremos inline pero medimos tiempo.
      if (kIsWeb || !preferIsolate) {
        final sw = Stopwatch()..start();
        final result = fn(param);
        sw.stop();
        _registerCost(sw.elapsed);
        return result;
      }

      // compute<Q, R>(callback, Q message)
      // Q = P (parámetro), R = R (resultado)
      final result = await compute<P, R>(fn, param);
      // En isolate no tenemos Stopwatch, pero sí sabemos que era pesado.
      return result;
    } finally {
      _activeCpuJobs--;
    }
  }

  /// Agenda una tarea liviana para después del frame actual.
  /// Útil para:
  /// - Guardados en background.
  /// - Telemetría.
  /// - Flush de caches, etc.
  static Future<void> runAfterFrame(FutureOr<void> Function() task) async {
    // Si no hay frame pendiente, ejecutamos directo.
    if (!SchedulerBinding.instance.hasScheduledFrame) {
      await task();
      return;
    }

    final completer = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      try {
        // Pequeño delay para dejar respirar la UI.
        await Future<void>.delayed(const Duration(milliseconds: 2));
        await task();
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });
    return completer.future;
  }

  /// Registra el costo de una operación en el hilo principal
  /// y lo traduce a “frames” estimados.
  static void _registerCost(Duration cost) {
    if (cost <= _frameBudget) return;

    final dropped = math.max(
      1,
      cost.inMilliseconds ~/ _frameBudget.inMilliseconds,
    );
    _frameDrops += dropped;

    if (kDebugMode) {
      debugPrint(
        '[PerfOptimizer] CPU spike: '
            '${cost.inMilliseconds} ms (budget ${_frameBudget.inMilliseconds} ms) '
            '→ +$dropped frame(s) estimados',
      );
    }
  }
}
