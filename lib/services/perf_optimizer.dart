// lib/services/perf_optimizer.dart
// Motorcito de rendimiento para Bit Flow (nivel industrial):
// - Ejecuta tareas CPU-heavy en isolate cuando se puede (compute).
// - Backpressure: limita concurrencia de jobs CPU para no saturar.
// - Mide jank REAL usando FrameTiming (build/raster), no estimaciones.
// - Agenda tareas en idle o después de frame para no trabar UI.

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

typedef CpuCallback<P, R> = FutureOr<R> Function(P param);

class PerfStats {
  final Duration frameBudget;
  final int framesMeasured;
  final int jankyFrames;
  final double jankPercent;

  final Duration avgFrame;
  final Duration p95Frame;

  final int activeCpuJobs;
  final int queuedCpuJobs;

  final Duration mainThreadCpuTime;
  final Duration backgroundCpuWallTime;

  final DateTime timestamp;

  const PerfStats({
    required this.frameBudget,
    required this.framesMeasured,
    required this.jankyFrames,
    required this.jankPercent,
    required this.avgFrame,
    required this.p95Frame,
    required this.activeCpuJobs,
    required this.queuedCpuJobs,
    required this.mainThreadCpuTime,
    required this.backgroundCpuWallTime,
    required this.timestamp,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'frame_budget_ms': frameBudget.inMilliseconds,
        'frames_measured': framesMeasured,
        'janky_frames': jankyFrames,
        'jank_percent': jankPercent,
        'avg_frame_ms': avgFrame.inMilliseconds,
        'p95_frame_ms': p95Frame.inMilliseconds,
        'active_cpu_jobs': activeCpuJobs,
        'queued_cpu_jobs': queuedCpuJobs,
        'main_thread_cpu_ms': mainThreadCpuTime.inMilliseconds,
        'background_cpu_wall_ms': backgroundCpuWallTime.inMilliseconds,
        'ts': timestamp.toIso8601String(),
      };
}

class PerfOptimizer {
  PerfOptimizer._();

  static bool _initialized = false;
  static bool _timingsEnabled = false;

  /// Presupuesto de frame (~16 ms para 60fps).
  static Duration _frameBudget = const Duration(milliseconds: 16);

  /// Historial de frames (ms) para p95 y promedio (ring buffer).
  static int _frameHistoryCap = 240;
  static final List<int> _frameMs = <int>[];

  static int _framesMeasured = 0;
  static int _jankyFrames = 0;

  /// Tiempo medido en el hilo principal por jobs inline.
  static Duration _mainThreadCpu = Duration.zero;

  /// Tiempo wall-clock “esperando” jobs de isolate (no bloquea UI, sirve para perf global).
  static Duration _backgroundCpuWall = Duration.zero;

  /// Jobs CPU en curso.
  static int _activeCpuJobs = 0;

  /// Cola / backpressure.
  static _AsyncSemaphore _cpuSemaphore =
      _AsyncSemaphore(2); // default: 2 concurrentes
  static int _queuedCpuJobs = 0;

  /// Stats observable (para overlay interno, logs, etc.).
  static final ValueNotifier<PerfStats> stats =
      ValueNotifier<PerfStats>(_snapshot());

  /// Llamar una sola vez al inicio de la app.
  /// Recomendado habilitar FrameTiming en debug/profile para tener jank real.
  static Future<void> init({
    bool enableFrameTimings = true,
    int frameHistoryCap = 240,
    int maxConcurrentCpuJobs = 2,
  }) async {
    if (_initialized) return;
    _initialized = true;

    _frameHistoryCap = frameHistoryCap.clamp(60, 1200);
    _cpuSemaphore = _AsyncSemaphore(maxConcurrentCpuJobs.clamp(1, 8));

    if (enableFrameTimings) {
      _enableFrameTimings();
    }

    if (kDebugMode) {
      debugPrint('[PerfOptimizer] init() timings=$enableFrameTimings '
          'history=$_frameHistoryCap maxCpu=${_cpuSemaphore.maxPermits}');
    }

    // Warmup mini (JIT/web)
    await Future<void>.delayed(const Duration(milliseconds: 1));
    _publishStats();
  }

  /// Configura el presupuesto de frame (para 120Hz, por ejemplo).
  /// 120Hz ≈ 8ms; 90Hz ≈ 11ms.
  static void configure({
    Duration? frameBudget,
    int? frameHistoryCap,
    int? maxConcurrentCpuJobs,
  }) {
    if (frameBudget != null) _frameBudget = frameBudget;
    if (frameHistoryCap != null) {
      _frameHistoryCap = frameHistoryCap.clamp(60, 1200);
      if (_frameMs.length > _frameHistoryCap) {
        _frameMs.removeRange(0, _frameMs.length - _frameHistoryCap);
      }
    }
    if (maxConcurrentCpuJobs != null) {
      _cpuSemaphore = _AsyncSemaphore(maxConcurrentCpuJobs.clamp(1, 8));
    }
    _publishStats();
  }

  static Duration get frameBudget => _frameBudget;
  static int get framesMeasured => _framesMeasured;
  static int get jankyFrames => _jankyFrames;
  static int get activeCpuJobs => _activeCpuJobs;
  static int get queuedCpuJobs => _queuedCpuJobs;

  static double get jankPercent {
    if (_framesMeasured <= 0) return 0;
    return (_jankyFrames * 100.0) / _framesMeasured;
  }

  static void resetStats({bool keepTimings = true}) {
    _framesMeasured = 0;
    _jankyFrames = 0;
    _frameMs.clear();
    _mainThreadCpu = Duration.zero;
    _backgroundCpuWall = Duration.zero;

    if (!keepTimings && _timingsEnabled) {
      _disableFrameTimings();
    }

    _publishStats();
  }

  /// Ejecuta una función CPU-heavy de manera segura:
  /// - En Web: corre en el mismo hilo (sin isolate), mide costo real (puede causar jank).
  /// - En mobile/desktop: usa `compute` si `preferIsolate == true`.
  ///
  /// Backpressure:
  /// - limita concurrentes (configurable) para que no se amontonen isolates y GC.
  ///
  /// IMPORTANTE: si usás `preferIsolate: true`, `fn` debe ser:
  /// - top-level o static
  /// - sin capturar BuildContext ni objetos no-serializables.
  static Future<R> runCpuBound<R, P>({
    required CpuCallback<P, R> fn,
    required P param,
    bool preferIsolate = true,
    bool measureInlineCost = true,
  }) async {
    // Backpressure: esperamos turno.
    _queuedCpuJobs++;
    _publishStats();
    await _cpuSemaphore.acquire();
    _queuedCpuJobs--;
    _activeCpuJobs++;
    _publishStats();

    try {
      // Web o preferIsolate=false -> inline (bloquea)
      if (kIsWeb || !preferIsolate) {
        final sw = Stopwatch()..start();
        final result = await Future<R>.sync(() => fn(param));
        sw.stop();

        if (measureInlineCost) {
          _registerMainThreadCost(sw.elapsed);
        }
        return result;
      }

      // Isolate: mide wall-clock total (no bloquea UI, pero sirve como métrica).
      final sw = Stopwatch()..start();
      try {
        final result = await compute<P, R>(_computeAdapter(fn), param);
        sw.stop();
        _backgroundCpuWall += sw.elapsed;
        _publishStats();
        return result;
      } catch (e) {
        // Fallback: si compute falla (casos raros), ejecutamos inline como último recurso.
        sw.stop();
        _backgroundCpuWall += sw.elapsed;
        _publishStats();

        if (kDebugMode) {
          debugPrint('[PerfOptimizer] compute failed, fallback inline: $e');
        }

        final sw2 = Stopwatch()..start();
        final result = await Future<R>.sync(() => fn(param));
        sw2.stop();
        if (measureInlineCost) {
          _registerMainThreadCost(sw2.elapsed);
        }
        return result;
      }
    } finally {
      _activeCpuJobs--;
      _cpuSemaphore.release();
      _publishStats();
    }
  }

  /// Agenda una tarea liviana para después del frame actual (sin bloquear gestos).
  static Future<void> runAfterFrame(FutureOr<void> Function() task) async {
    if (!_initialized) {
      // No obligamos init, pero nos aseguramos de tener stats coherentes.
      await init(enableFrameTimings: false);
    }

    // Si estamos idle (sin frame), ejecutamos directo.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await task();
      return;
    }

    // Espera al final del frame.
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await task();
  }

  /// Agenda una tarea para cuando el scheduler esté “idle”.
  /// Ideal para persistencia, telemetría, limpieza de caches, etc.
  static Future<T> runWhenIdle<T>(
    FutureOr<T> Function() task, {
    Priority priority = Priority.idle,
  }) {
    if (!_initialized) {
      // No bloqueamos: pero inicializamos soft.
      _fireAndForget(init(enableFrameTimings: false));
    }

    final completer = Completer<T>();
    SchedulerBinding.instance.scheduleTask<T>(
      () async {
        try {
          final result = await Future<T>.sync(task);
          if (!completer.isCompleted) completer.complete(result);
          return result;
        } catch (e, st) {
          if (!completer.isCompleted) completer.completeError(e, st);
          rethrow;
        }
      },
      priority,
      debugLabel: 'PerfOptimizer.runWhenIdle',
    );

    return completer.future;
  }

  // ---------------- FrameTiming (jank real) ----------------

  static void _enableFrameTimings() {
    if (_timingsEnabled) return;
    _timingsEnabled = true;

    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  static void _disableFrameTimings() {
    if (!_timingsEnabled) return;
    _timingsEnabled = false;

    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
  }

  static void _onFrameTimings(List<FrameTiming> timings) {
    // Cada timing representa un frame “real” con build/raster.
    for (final t in timings) {
      final total = t.buildDuration + t.rasterDuration;
      final ms = total.inMilliseconds;

      _framesMeasured++;
      _pushFrameMs(ms);

      if (total > _frameBudget) {
        _jankyFrames++;
      }
    }

    _publishStats();
  }

  static void _pushFrameMs(int ms) {
    _frameMs.add(ms);
    if (_frameMs.length > _frameHistoryCap) {
      _frameMs.removeAt(0);
    }
  }

  // ---------------- Main thread cost ----------------

  static void _registerMainThreadCost(Duration cost) {
    _mainThreadCpu += cost;

    // También dejamos trazas útiles en debug.
    if (kDebugMode && cost > _frameBudget) {
      debugPrint(
        '[PerfOptimizer] Main-thread spike: '
        '${cost.inMilliseconds}ms (budget ${_frameBudget.inMilliseconds}ms)',
      );
    }

    // No “inventamos” drops: ya medimos jank real por FrameTiming.
    // Esto queda como métrica de carga del hilo principal.
    _publishStats();
  }

  // ---------------- Snapshot / Publish ----------------

  static PerfStats _snapshot() {
    final hist = List<int>.from(_frameMs);
    final avgMs =
        hist.isEmpty ? 0 : (hist.reduce((a, b) => a + b) / hist.length).round();

    final p95Ms = _percentileMs(hist, 0.95);

    final jp =
        (_framesMeasured <= 0) ? 0.0 : (_jankyFrames * 100.0) / _framesMeasured;

    return PerfStats(
      frameBudget: _frameBudget,
      framesMeasured: _framesMeasured,
      jankyFrames: _jankyFrames,
      jankPercent: jp,
      avgFrame: Duration(milliseconds: avgMs),
      p95Frame: Duration(milliseconds: p95Ms),
      activeCpuJobs: _activeCpuJobs,
      queuedCpuJobs: _queuedCpuJobs,
      mainThreadCpuTime: _mainThreadCpu,
      backgroundCpuWallTime: _backgroundCpuWall,
      timestamp: DateTime.now(),
    );
  }

  static int _percentileMs(List<int> ms, double p) {
    if (ms.isEmpty) return 0;
    final sorted = List<int>.from(ms)..sort();
    final idx = ((sorted.length - 1) * p).round().clamp(0, sorted.length - 1);
    return sorted[idx];
  }

  static void _publishStats() {
    stats.value = _snapshot();
  }

  static void _fireAndForget(Future<void> f) {
    f.catchError((Object e) {
      debugPrint('[PerfOptimizer] fireAndForget error: $e');
    });
  }

  // ---------------- compute adapter ----------------
  //
  // compute exige callback top-level/static con firma FutureOr<R> Function(P).
  // Para mantener el tipo CpuCallback, lo adaptamos con un wrapper que Flutter acepta.
  static ComputeCallback<P, R> _computeAdapter<P, R>(CpuCallback<P, R> fn) {
    // ignore: unnecessary_cast
    return (P message) => fn(message) as FutureOr<R>;
  }
}

class _AsyncSemaphore {
  final int maxPermits;
  int _permits;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  _AsyncSemaphore(int permits)
      : maxPermits = permits,
        _permits = permits;

  Future<void> acquire() {
    if (_permits > 0) {
      _permits--;
      return Future<void>.value();
    }
    final c = Completer<void>();
    _waiters.addLast(c);
    return c.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      final c = _waiters.removeFirst();
      if (!c.isCompleted) c.complete();
      return;
    }
    _permits = math.min(maxPermits, _permits + 1);
  }
}
