// lib/services/location_service.dart
// Geolocator 12.x: lecturas puntuales + stream continuo, con fallback y helpers.
// Enfoque: máximo rendimiento (rápido) + máxima precisión “real” (filtrado + agregado).
// Null-safe. Android 9–14 / iOS / Web (plugin federado).

import 'dart:async';

import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, debugPrint, kIsWeb;
import 'package:geolocator/geolocator.dart';

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);

  @override
  String toString() => 'LocationException: $message';
}

/// Estado “operable” para UI/telemetría corporativa.
enum LocationPhase { idle, requesting, ok, error }

class LocationStatus {
  final LocationPhase phase;
  final String? message;
  final DateTime timestamp;
  final double? accuracyMeters;
  final String? source; // cache / current / stream / lastKnown / aggregate
  final Object? error;

  const LocationStatus._({
    required this.phase,
    required this.timestamp,
    this.message,
    this.accuracyMeters,
    this.source,
    this.error,
  });

  factory LocationStatus.idle() =>
      LocationStatus._(phase: LocationPhase.idle, timestamp: DateTime.now());

  factory LocationStatus.requesting([String? message]) => LocationStatus._(
        phase: LocationPhase.requesting,
        timestamp: DateTime.now(),
        message: message,
      );

  factory LocationStatus.ok({
    String? source,
    double? accuracyMeters,
    String? message,
  }) =>
      LocationStatus._(
        phase: LocationPhase.ok,
        timestamp: DateTime.now(),
        source: source,
        accuracyMeters: accuracyMeters,
        message: message,
      );

  factory LocationStatus.error(Object error, [String? message]) =>
      LocationStatus._(
        phase: LocationPhase.error,
        timestamp: DateTime.now(),
        message: message,
        error: error,
      );
}

/// Fix de ubicación “sanitizado” para usar en la app.
class LocationFix {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? altitudeMeters;
  final double? speedMps;
  final double? headingDeg;
  final DateTime timestamp;

  /// Origen del fix (para UI/operación): cache/current/stream/aggregate/lastKnown.
  final String source;

  const LocationFix({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.altitudeMeters,
    this.speedMps,
    this.headingDeg,
    required this.timestamp,
    this.source = 'unknown',
  });

  factory LocationFix.fromPosition(Position p, {String source = 'position'}) =>
      LocationFix(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracyMeters: _numOrNull(p.accuracy),
        altitudeMeters: _numOrNull(p.altitude),
        speedMps: _numOrNull(p.speed),
        headingDeg: _numOrNull(p.heading),
        timestamp: p.timestamp ?? DateTime.now(),
        source: source,
      );

  Duration age() => DateTime.now().difference(timestamp);

  bool isFresh(Duration maxAge) {
    final a = age();
    return a >= Duration.zero && a <= maxAge;
  }

  /// Ej: `-38.957123, -68.045678 ±5 m`
  String toCompactString() {
    final acc = accuracyMeters != null
        ? ' ±${accuracyMeters!.toStringAsFixed(0)} m'
        : '';
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}$acc';
  }

  Map<String, Object?> toJson() => {
        'lat': latitude,
        'lon': longitude,
        'accuracy_m': accuracyMeters,
        'alt_m': altitudeMeters,
        'speed_mps': speedMps,
        'heading_deg': headingDeg,
        'ts': timestamp.toIso8601String(),
        'source': source,
      };

  static double? _numOrNull(double? v) {
    if (v == null) return null;
    if (v.isNaN || v.isInfinite) return null;
    return v;
  }
}

/// Resultado “no throw” (útil en flows corporativos).
class LocationResult {
  final bool ok;
  final LocationFix? fix;
  final String? message;
  final String? code;

  const LocationResult._({
    required this.ok,
    this.fix,
    this.message,
    this.code,
  });

  factory LocationResult.success(LocationFix fix) =>
      LocationResult._(ok: true, fix: fix);

  factory LocationResult.fail(String code, String message) =>
      LocationResult._(ok: false, code: code, message: message);
}

/// Callback de telemetría (Sentry/Crashlytics/log).
typedef LocationEventCallback = void Function(
  String event,
  Map<String, Object?> data,
);

/// Servicio centralizado de ubicación.
/// Usa singleton [LocationService.I] para simplificar el acceso.
class LocationService {
  LocationService._();
  static final LocationService I = LocationService._();

  // Telemetría (opcional).
  LocationEventCallback? onEvent;

  final ValueNotifier<LocationFix?> _cache = ValueNotifier<LocationFix?>(null);
  final ValueNotifier<LocationStatus> _status =
      ValueNotifier<LocationStatus>(LocationStatus.idle());

  /// Último fix “publicable” (cacheado con rate-limit para UI).
  ValueListenable<LocationFix?> get lastFixListenable => _cache;

  /// Status corporativo para UI/telemetría.
  ValueListenable<LocationStatus> get statusListenable => _status;

  LocationFix? get lastFix => _cache.value;

  // Último fix “visto” (interno): se actualiza aunque no se emita, para precisión/refine/outliers.
  LocationFix? _lastSeenFix;

  // Concurrencia: evita que 2 pantallas pidan GPS al mismo tiempo.
  Completer<LocationFix>? _inflightFix;

  // Shared stream: una sola suscripción real a Geolocator.
  StreamController<LocationFix>? _sharedController;
  StreamSubscription<Position>? _sharedSub;
  Timer? _sharedStopTimer;

  // Para “refine” por stream compartido: taps internos.
  final Set<void Function(LocationFix)> _internalTaps =
      <void Function(LocationFix)>{};

  // Rate limiting / anti-spam (shared emit)
  DateTime? _sharedLastEmitAt;
  LocationFix? _sharedLastEmittedFix;

  // Rate limiting / anti-spam (public cache)
  DateTime? _cacheLastUpdateAt;
  LocationFix? _cacheLastPromotedFix;

  // ---------- Defaults “rápido + preciso” ----------
  static const Duration _defaultCacheMaxAge = Duration(seconds: 20);
  static const Duration _defaultHardTimeout = Duration(seconds: 8);
  static const Duration _defaultQuickTimeout = Duration(seconds: 4);
  static const Duration _defaultRefineWindow = Duration(milliseconds: 2200);

  static const Duration _defaultMaxLastKnownAge = Duration(minutes: 5);

  static const double _defaultTargetAccuracy = 12; // m
  static const double _defaultMaxAccuracy = 80; // m
  static const double _defaultOutlierSpeedMps = 60; // ~216 km/h

  // Shared stream anti-spam
  static const Duration _sharedMinEmitInterval = Duration(milliseconds: 320);
  static const Duration _sharedForceEmitInterval = Duration(seconds: 2);
  static const double _sharedMinMoveMeters = 0.8;

  // Public cache anti-spam (para no matar UI)
  static const Duration _cacheMinUpdateInterval = Duration(milliseconds: 350);
  static const Duration _cacheForceUpdateInterval = Duration(seconds: 2);

  void _setStatus(LocationStatus s) {
    _status.value = s;
  }

  void _emitEvent(String event, Map<String, Object?> data) {
    final cb = onEvent;
    if (cb == null) return;
    try {
      cb(event, data);
    } catch (e) {
      debugPrint('LocationService.onEvent error: $e');
    }
  }

  void _fireAndForget(Future<void> f) {
    f.catchError((Object e) {
      debugPrint('LocationService fireAndForget error: $e');
    });
  }

  // ---------- Permisos / ajustes ----------
  Future<void> _ensureServiceAndPermission() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled && !kIsWeb) {
        _emitEvent('service_disabled', {'platform_web': kIsWeb});
        throw const LocationException('Activá el servicio de ubicación.');
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.denied) {
        _emitEvent('permission_denied', {'perm': perm.toString()});
        throw const LocationException('Permiso de ubicación denegado.');
      }

      if (perm == LocationPermission.deniedForever) {
        _emitEvent('permission_denied_forever', {'perm': perm.toString()});
        throw const LocationException(
          'Permiso denegado permanentemente. Revisá los ajustes de la app.',
        );
      }
    } on LocationServiceDisabledException {
      _emitEvent('service_disabled_exception', {});
      throw const LocationException('Activá el servicio de ubicación.');
    } on PermissionDeniedException {
      final p = await Geolocator.checkPermission();
      if (p == LocationPermission.deniedForever) {
        _emitEvent(
            'permission_denied_forever_exception', {'perm': p.toString()});
        throw const LocationException(
          'Permiso denegado permanentemente. Revisá los ajustes de la app.',
        );
      }
      _emitEvent('permission_denied_exception', {'perm': p.toString()});
      throw const LocationException('Permiso de ubicación denegado.');
    } catch (e) {
      _emitEvent('permission_or_service_error', {'error': e.toString()});
      debugPrint('LocationService permission/service error: $e');
      rethrow;
    }
  }

  Future<bool> hasPermission() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  Future<bool> openSystemLocationSettings() =>
      Geolocator.openLocationSettings();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  // ---------- Cache con TTL ----------
  bool _isCacheFresh(Duration maxAge) {
    final fix = _cache.value;
    if (fix == null) return false;
    return fix.isFresh(maxAge);
  }

  // ---------- Last known (con antigüedad máxima) ----------
  Future<LocationFix?> getLastKnownFix({
    bool rejectMocked = true,
    double maxAccuracyMeters = 150,
    Duration maxAge = _defaultMaxLastKnownAge,
    bool requireTimestamp = true,
  }) async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) return null;

      final ts = last.timestamp;
      if (ts == null && requireTimestamp) return null;

      final when = ts ?? DateTime.fromMillisecondsSinceEpoch(0);
      final age = DateTime.now().difference(when);
      if (age.isNegative || age > maxAge) {
        _emitEvent('lastKnown_too_old', {
          'age_s': age.inSeconds,
          'maxAge_s': maxAge.inSeconds,
        });
        return null;
      }

      if (!_validPos(
        last,
        rejectMocked: rejectMocked,
        maxAccuracyMeters: maxAccuracyMeters,
      )) return null;

      final fix = LocationFix.fromPosition(last, source: 'lastKnown');
      _promoteCacheIfNeeded(fix, sourceForStatus: 'lastKnown');

      _emitEvent('fallback_lastKnown_used', {
        'age_s': age.inSeconds,
        'accuracy_m': fix.accuracyMeters,
      });

      return fix;
    } catch (e) {
      debugPrint('LocationService.getLastKnownFix error: $e');
      _emitEvent('lastKnown_error', {'error': e.toString()});
      return null;
    }
  }

  // ---------- API principal (fácil de usar) ----------
  /// Llamalo y listo: rápido + preciso + confiable.
  ///
  /// - Usa cache si está fresco.
  /// - Hace race: currentPosition vs primer fix bueno del stream.
  /// - Si no alcanza target, refina por ventana usando el stream compartido (muestras reales).
  /// - Anti-carreras: si ya hay una solicitud en curso, se comparte resultado.
  /// - Fallback lastKnown solo si no está viejo ([maxLastKnownAge]).
  Future<LocationFix> getFixPreciseFast({
    bool allowCached = true,
    Duration cacheMaxAge = _defaultCacheMaxAge,
    Duration hardTimeout = _defaultHardTimeout,
    Duration quickTimeout = _defaultQuickTimeout,
    Duration refineWindow = _defaultRefineWindow,
    double targetAccuracyMeters = _defaultTargetAccuracy,
    double maxAccuracyMeters = _defaultMaxAccuracy,
    bool rejectMocked = true,
    Duration maxLastKnownAge = _defaultMaxLastKnownAge,
  }) async {
    if (allowCached && _isCacheFresh(cacheMaxAge)) {
      final cached = _cache.value!;
      final out = LocationFix(
        latitude: cached.latitude,
        longitude: cached.longitude,
        accuracyMeters: cached.accuracyMeters,
        altitudeMeters: cached.altitudeMeters,
        speedMps: cached.speedMps,
        headingDeg: cached.headingDeg,
        timestamp: cached.timestamp,
        source: 'cache',
      );

      _setStatus(LocationStatus.ok(
        source: 'cache',
        accuracyMeters: out.accuracyMeters,
      ));

      _emitEvent('fix_cache_used', {
        'age_s': out.age().inSeconds,
        'accuracy_m': out.accuracyMeters,
      });

      return out;
    }

    final existing = _inflightFix;
    if (existing != null) return existing.future;

    final completer = Completer<LocationFix>();
    _inflightFix = completer;

    _setStatus(LocationStatus.requesting('Obteniendo ubicación…'));
    _emitEvent('fix_request_start', {
      'quickTimeout_ms': quickTimeout.inMilliseconds,
      'hardTimeout_ms': hardTimeout.inMilliseconds,
      'targetAccuracy_m': targetAccuracyMeters,
    });

    try {
      await _ensureServiceAndPermission();

      // 1) Primer fix rápido: race entre getCurrentPosition y stream temporal.
      final first = await _raceFirstSuccessfulPosition(
        futures: <Future<Position>>[
          Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation,
            timeLimit: quickTimeout,
          ),
          _firstGoodFromStream(
            settings: _bestStreamSettings(),
            timeout: quickTimeout,
          ),
        ],
        hardTimeout: hardTimeout,
      );

      if (!_validPos(
        first,
        rejectMocked: rejectMocked,
        maxAccuracyMeters: maxAccuracyMeters,
      )) {
        throw const LocationException('Fix de ubicación inválido.');
      }

      final seed = LocationFix.fromPosition(first, source: 'current/stream');
      _lastSeenFix = seed;

      // Guardrails: outlier vs último visto/publicado
      if (_isOutlier(seed, last: _lastSeenFix ?? _cache.value)) {
        _emitEvent('outlier_dropped', {
          'stage': 'seed',
          'accuracy_m': seed.accuracyMeters,
        });
      } else {
        _promoteCacheIfNeeded(seed, sourceForStatus: 'current/stream');
      }

      final acc0 = first.accuracy;
      if (acc0.isFinite && acc0 > 0 && acc0 <= targetAccuracyMeters) {
        _emitEvent('fix_target_reached_fast', {'accuracy_m': acc0});
        completer.complete(seed);
        return seed;
      }

      // 2) Refinamiento usando el stream compartido (muestras reales, sin N llamadas puntuales).
      final refined = await _refineUsingSharedStream(
        seed: seed,
        window: refineWindow,
        targetAccuracyMeters: targetAccuracyMeters,
        maxAccuracyMeters: maxAccuracyMeters,
        rejectMocked: rejectMocked,
      );

      _promoteCacheIfNeeded(refined, sourceForStatus: 'aggregate');

      _emitEvent('aggregate_used', {
        'window_ms': refineWindow.inMilliseconds,
        'seed_acc_m': seed.accuracyMeters,
        'best_acc_m': refined.accuracyMeters,
      });

      completer.complete(refined);
      return refined;
    } on TimeoutException catch (e) {
      final last = await getLastKnownFix(
        rejectMocked: rejectMocked,
        maxAccuracyMeters: maxAccuracyMeters,
        maxAge: maxLastKnownAge,
        requireTimestamp: true,
      );
      if (last != null) {
        completer.complete(last);
        return last;
      }

      _setStatus(LocationStatus.error(e, 'Timeout obteniendo ubicación.'));
      _emitEvent('fix_timeout', {'error': e.toString()});
      completer.completeError(e);
      rethrow;
    } catch (e) {
      final last = await getLastKnownFix(
        rejectMocked: rejectMocked,
        maxAccuracyMeters: maxAccuracyMeters,
        maxAge: maxLastKnownAge,
        requireTimestamp: true,
      );
      if (last != null) {
        completer.complete(last);
        return last;
      }

      _setStatus(LocationStatus.error(e, 'Error obteniendo ubicación.'));
      _emitEvent('fix_error', {'error': e.toString()});
      completer.completeError(e);
      rethrow;
    } finally {
      _inflightFix = null;
    }
  }

  /// Variante “no throw” para flows corporativos.
  Future<LocationResult> tryGetFixPreciseFast({
    bool allowCached = true,
    Duration cacheMaxAge = _defaultCacheMaxAge,
    Duration hardTimeout = _defaultHardTimeout,
    Duration quickTimeout = _defaultQuickTimeout,
    Duration refineWindow = _defaultRefineWindow,
    double targetAccuracyMeters = _defaultTargetAccuracy,
    double maxAccuracyMeters = _defaultMaxAccuracy,
    bool rejectMocked = true,
    Duration maxLastKnownAge = _defaultMaxLastKnownAge,
  }) async {
    try {
      final fix = await getFixPreciseFast(
        allowCached: allowCached,
        cacheMaxAge: cacheMaxAge,
        hardTimeout: hardTimeout,
        quickTimeout: quickTimeout,
        refineWindow: refineWindow,
        targetAccuracyMeters: targetAccuracyMeters,
        maxAccuracyMeters: maxAccuracyMeters,
        rejectMocked: rejectMocked,
        maxLastKnownAge: maxLastKnownAge,
      );
      return LocationResult.success(fix);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('permanentemente')) {
        return LocationResult.fail('permission_denied_forever', msg);
      }
      if (msg.contains('denegado')) {
        return LocationResult.fail('permission_denied', msg);
      }
      if (msg.contains('Activá')) {
        return LocationResult.fail('service_disabled', msg);
      }
      if (e is TimeoutException) {
        return LocationResult.fail('timeout', msg);
      }
      return LocationResult.fail('unknown', msg);
    }
  }

  // ---------- Stream compartido (corporativo) ----------
  /// Stream compartido: una sola suscripción real al GPS.
  ///
  /// - Se activa cuando el primer listener se suscribe.
  /// - Se apaga cuando no queda nadie escuchando (con delay corto).
  /// - Filtra outliers y aplica rate limiting / anti-spam.
  Stream<LocationFix> watchFixesShared({
    bool rejectMocked = true,
    double rejectAboveAccuracyMeters = 120,
  }) {
    _sharedController ??= StreamController<LocationFix>.broadcast(
      onListen: () {
        _sharedStopTimer?.cancel();
        _fireAndForget(_startSharedStream(
          rejectMocked: rejectMocked,
          rejectAboveAccuracyMeters: rejectAboveAccuracyMeters,
        ));
      },
      onCancel: () {
        _sharedStopTimer?.cancel();
        _sharedStopTimer = Timer(const Duration(seconds: 2), () {
          if (_sharedController == null) return;
          if (!_sharedController!.hasListener) {
            _fireAndForget(_stopSharedStream());
          }
        });
      },
    );

    return _sharedController!.stream;
  }

  Future<void> _startSharedStream({
    required bool rejectMocked,
    required double rejectAboveAccuracyMeters,
  }) async {
    if (_sharedSub != null) return;

    _emitEvent('shared_stream_start', {
      'rejectAboveAccuracy_m': rejectAboveAccuracyMeters,
    });

    try {
      await _ensureServiceAndPermission();
    } catch (e) {
      _setStatus(
          LocationStatus.error(e, 'Sin permisos/servicio de ubicación.'));
      _sharedController?.addError(e);
      _emitEvent('shared_stream_start_failed', {'error': e.toString()});
      return;
    }

    final settings = _bestStreamSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilterMeters: 0,
    );

    _sharedSub =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (p) {
        if (!_validPos(
          p,
          rejectMocked: rejectMocked,
          maxAccuracyMeters: rejectAboveAccuracyMeters,
        )) return;

        final fix = LocationFix.fromPosition(p, source: 'stream(shared)');

        final lastForOutlier = _lastSeenFix ?? _cache.value;
        if (_isOutlier(fix, last: lastForOutlier)) {
          _emitEvent('outlier_dropped', {
            'stage': 'shared_stream',
            'accuracy_m': fix.accuracyMeters,
          });
          return;
        }

        // Último “visto” siempre (para refine/outliers).
        _lastSeenFix = fix;

        // Taps internos (refine) reciben TODOS los fixes aceptados.
        for (final tap in _internalTaps) {
          try {
            tap(fix);
          } catch (_) {}
        }

        // Cache público: con rate-limit para no matar UI.
        _promoteCacheIfNeeded(fix, sourceForStatus: 'stream(shared)');

        // Emisión compartida: rate-limit + distinción por movimiento/mejora de accuracy.
        if (_shouldEmitShared(fix)) {
          _sharedLastEmitAt = DateTime.now();
          _sharedLastEmittedFix = fix;
          _sharedController?.add(fix);

          _emitEvent('shared_stream_emit', {
            'accuracy_m': fix.accuracyMeters,
            'source': fix.source,
          });
        }
      },
      onError: (e) {
        _setStatus(LocationStatus.error(e, 'Error en stream de ubicación.'));
        _sharedController?.addError(e);
        _emitEvent('shared_stream_error', {'error': e.toString()});
      },
    );
  }

  Future<void> _stopSharedStream() async {
    _emitEvent('shared_stream_stop', {});
    try {
      await _sharedSub?.cancel();
    } catch (_) {}
    _sharedSub = null;
  }

  // ---------- Refinamiento usando stream compartido ----------
  Future<LocationFix> _refineUsingSharedStream({
    required LocationFix seed,
    required Duration window,
    required double targetAccuracyMeters,
    required double maxAccuracyMeters,
    required bool rejectMocked,
  }) async {
    // Si el seed ya es bueno, no hay nada que refinar.
    final seedAcc = seed.accuracyMeters;
    if (seedAcc != null && seedAcc.isFinite && seedAcc > 0) {
      if (seedAcc <= targetAccuracyMeters) return seed;
    }

    // Garantizá que el shared stream esté corriendo (aunque no haya listeners).
    final wasRunning = _sharedSub != null;
    if (!wasRunning) {
      _fireAndForget(_startSharedStream(
        rejectMocked: rejectMocked,
        rejectAboveAccuracyMeters: maxAccuracyMeters,
      ));
    }

    final samples = <LocationFix>[seed];
    final completer = Completer<void>();
    Timer? timer;

    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    timer = Timer(window, finish);

    void tap(LocationFix fix) {
      final acc = fix.accuracyMeters;
      if (acc == null || !acc.isFinite || acc <= 0) return;
      if (acc > maxAccuracyMeters) return;

      samples.add(fix);

      if (acc <= targetAccuracyMeters) {
        finish();
      }
    }

    _internalTaps.add(tap);

    try {
      await completer.future;
    } finally {
      _internalTaps.remove(tap);
      timer?.cancel();

      // Si lo arrancamos “solo para refinar” y no hay listeners, apagalo.
      final hasListeners = _sharedController?.hasListener ?? false;
      if (!wasRunning && !hasListeners) {
        _fireAndForget(_stopSharedStream());
      }
    }

    if (samples.length == 1) return seed;

    final agg = _aggregateFixes(samples);

    return LocationFix(
      latitude: agg.latitude,
      longitude: agg.longitude,
      accuracyMeters: agg.accuracyMeters,
      altitudeMeters: agg.altitudeMeters,
      speedMps: agg.speedMps,
      headingDeg: agg.headingDeg,
      timestamp: agg.timestamp,
      source: 'aggregate',
    );
  }

  // ---------- Lectura puntual básica (compat) ----------
  Future<Position> getCurrent({
    LocationAccuracy desiredAccuracy = LocationAccuracy.best,
    Duration timeout = const Duration(seconds: 10),
    bool rejectMocked = true,
    double maxAccuracyMeters = 150,
  }) async {
    await _ensureServiceAndPermission();

    try {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: desiredAccuracy,
        timeLimit: timeout,
      );

      if (!_validPos(
        p,
        rejectMocked: rejectMocked,
        maxAccuracyMeters: maxAccuracyMeters,
      )) {
        throw const LocationException('Fix de ubicación inválido.');
      }
      return p;
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          _validPos(
            last,
            rejectMocked: rejectMocked,
            maxAccuracyMeters: maxAccuracyMeters,
          )) {
        return last;
      }
      rethrow;
    } on LocationServiceDisabledException {
      throw const LocationException('Activá el servicio de ubicación.');
    } on PermissionDeniedException {
      final p = await Geolocator.checkPermission();
      if (p == LocationPermission.deniedForever) {
        throw const LocationException(
          'Permiso denegado permanentemente. Revisá los ajustes de la app.',
        );
      }
      throw const LocationException('Permiso de ubicación denegado.');
    } catch (e) {
      debugPrint('LocationService.getCurrent error: $e');
      rethrow;
    }
  }

  Future<LocationFix> getCurrentFix({
    LocationAccuracy desiredAccuracy = LocationAccuracy.best,
    Duration timeout = const Duration(seconds: 10),
    bool rejectMocked = true,
    double maxAccuracyMeters = 150,
  }) async {
    final p = await getCurrent(
      desiredAccuracy: desiredAccuracy,
      timeout: timeout,
      rejectMocked: rejectMocked,
      maxAccuracyMeters: maxAccuracyMeters,
    );
    final fix = LocationFix.fromPosition(p, source: 'current');
    _lastSeenFix = fix;
    _promoteCacheIfNeeded(fix, sourceForStatus: 'current');
    return fix;
  }

  // ---------- Stream directo (parametrizable) ----------
  /// Si querés un stream “dedicado” con parámetros propios, usá esto.
  /// Si querés eficiencia corporativa (uno solo), usá [watchFixesShared].
  Stream<LocationFix> watchFixes({
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
    int distanceFilterMeters = 0,
    double rejectAboveAccuracyMeters = 120,
    bool rejectMocked = true,
  }) async* {
    await _ensureServiceAndPermission();

    final settings = _bestStreamSettings(
      accuracy: accuracy,
      distanceFilterMeters: distanceFilterMeters,
    );

    final stream = Geolocator.getPositionStream(locationSettings: settings);

    await for (final p in stream) {
      if (!_validPos(
        p,
        rejectMocked: rejectMocked,
        maxAccuracyMeters: rejectAboveAccuracyMeters,
      )) continue;

      final fix = LocationFix.fromPosition(p, source: 'stream');
      final lastForOutlier = _lastSeenFix ?? _cache.value;
      if (_isOutlier(fix, last: lastForOutlier)) continue;

      _lastSeenFix = fix;
      _promoteCacheIfNeeded(fix, sourceForStatus: 'stream');
      yield fix;
    }
  }

  // ---------- Settings (compatibles con tu geolocator) ----------
  LocationSettings _bestStreamSettings({
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
    int distanceFilterMeters = 0,
  }) {
    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilterMeters,
    );
  }

  // ---------- Core: race “primer éxito” ----------
  Future<Position> _raceFirstSuccessfulPosition({
    required List<Future<Position>> futures,
    required Duration hardTimeout,
  }) async {
    final completer = Completer<Position>();
    final errors = <Object>[];
    var remaining = futures.length;

    void tryCompleteErrorIfDone() {
      remaining--;
      if (remaining <= 0 && !completer.isCompleted) {
        completer.completeError(
          errors.isNotEmpty
              ? errors.first
              : const LocationException('No se pudo obtener ubicación.'),
        );
      }
    }

    for (final f in futures) {
      f.then((pos) {
        if (!completer.isCompleted) completer.complete(pos);
      }).catchError((e) {
        errors.add(e);
        tryCompleteErrorIfDone();
      });
    }

    return completer.future.timeout(hardTimeout);
  }

  Future<Position> _firstGoodFromStream({
    required LocationSettings settings,
    required Duration timeout,
  }) async {
    final completer = Completer<Position>();
    StreamSubscription<Position>? sub;

    Timer? timer;
    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Timeout esperando stream de ubicación.', timeout),
        );
      }
    });

    try {
      sub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (p) {
          if (!_isValidLatLng(p.latitude, p.longitude)) return;
          final acc = p.accuracy;
          if (!acc.isFinite || acc <= 0) return;

          if (!completer.isCompleted) completer.complete(p);
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
      );

      return await completer.future;
    } finally {
      timer?.cancel();
      await sub?.cancel();
    }
  }

  // ---------- Anti-spam: shared emit decision ----------
  bool _shouldEmitShared(LocationFix fix) {
    final now = DateTime.now();
    final lastAt = _sharedLastEmitAt;
    final lastFix = _sharedLastEmittedFix;

    // Rate limit mínimo.
    if (lastAt != null) {
      final dt = now.difference(lastAt);
      if (dt < _sharedMinEmitInterval) {
        // Sólo emitimos si pasó mucho sin emitir.
        if (dt < _sharedForceEmitInterval) return false;
      }
    }

    if (lastFix == null) return true;

    // Movimiento mínimo o mejora fuerte de accuracy.
    final d = distanceMeters(
      fromLat: lastFix.latitude,
      fromLon: lastFix.longitude,
      toLat: fix.latitude,
      toLon: fix.longitude,
    );

    final accNow = fix.accuracyMeters ?? 9999;
    final accLast = lastFix.accuracyMeters ?? 9999;
    final accImprovedALot = accNow.isFinite &&
        accLast.isFinite &&
        accNow > 0 &&
        accLast > 0 &&
        (accNow <= accLast * 0.65);

    if (d >= _sharedMinMoveMeters) return true;
    if (accImprovedALot) return true;

    // Si pasó mucho, emití igual (evita “silencio”).
    if (lastAt != null && now.difference(lastAt) >= _sharedForceEmitInterval) {
      return true;
    }

    return false;
  }

  // ---------- Anti-spam: public cache promotion ----------
  void _promoteCacheIfNeeded(LocationFix fix,
      {required String sourceForStatus}) {
    final now = DateTime.now();
    final lastAt = _cacheLastUpdateAt;
    final lastFix = _cacheLastPromotedFix ?? _cache.value;

    bool shouldPromote = false;

    if (lastAt == null) {
      shouldPromote = true;
    } else {
      final dt = now.difference(lastAt);
      if (dt >= _cacheForceUpdateInterval) {
        shouldPromote = true;
      } else if (dt >= _cacheMinUpdateInterval) {
        // movimiento mínimo o mejora fuerte de accuracy
        if (lastFix == null) {
          shouldPromote = true;
        } else {
          final d = distanceMeters(
            fromLat: lastFix.latitude,
            fromLon: lastFix.longitude,
            toLat: fix.latitude,
            toLon: fix.longitude,
          );

          final accNow = fix.accuracyMeters ?? 9999;
          final accLast = lastFix.accuracyMeters ?? 9999;
          final accImprovedALot = accNow.isFinite &&
              accLast.isFinite &&
              accNow > 0 &&
              accLast > 0 &&
              (accNow <= accLast * 0.70);

          if (d >= _sharedMinMoveMeters) shouldPromote = true;
          if (accImprovedALot) shouldPromote = true;
        }
      }
    }

    if (!shouldPromote) return;

    _cacheLastUpdateAt = now;
    _cacheLastPromotedFix = fix;
    _cache.value = fix;

    _setStatus(LocationStatus.ok(
      source: sourceForStatus,
      accuracyMeters: fix.accuracyMeters,
    ));
  }

  // ---------- Agregado ponderado (fixes) ----------
  LocationFix _aggregateFixes(List<LocationFix> fixes) {
    double sumLat = 0;
    double sumLon = 0;
    double sumAlt = 0;
    double sumWeight = 0;
    double? bestAccuracy;

    LocationFix? best;
    for (final f in fixes) {
      final acc = f.accuracyMeters;
      if (acc == null || !acc.isFinite || acc <= 0) continue;

      final w = 1.0 / (acc * acc);
      sumLat += f.latitude * w;
      sumLon += f.longitude * w;

      final alt = f.altitudeMeters;
      if (alt != null && alt.isFinite) {
        sumAlt += alt * w;
      }

      sumWeight += w;

      if (bestAccuracy == null || acc < bestAccuracy) {
        bestAccuracy = acc;
        best = f;
      }
    }

    if (sumWeight == 0 || bestAccuracy == null || best == null) {
      // fallback: más reciente “usable”
      final latest =
          fixes.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);
      return latest;
    }

    final lat = sumLat / sumWeight;
    final lon = sumLon / sumWeight;

    double? altOut;
    if (best.altitudeMeters != null && best.altitudeMeters!.isFinite) {
      altOut = sumAlt / sumWeight;
    }

    return LocationFix(
      latitude: lat,
      longitude: lon,
      accuracyMeters: bestAccuracy,
      altitudeMeters: altOut,
      speedMps: best.speedMps,
      headingDeg: best.headingDeg,
      timestamp: best.timestamp,
      source: 'aggregate',
    );
  }

  // ---------- Helpers ----------
  static double distanceMeters({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) =>
      Geolocator.distanceBetween(fromLat, fromLon, toLat, toLon);

  bool _validPos(
    Position p, {
    required bool rejectMocked,
    required double maxAccuracyMeters,
  }) {
    if (!_isValidLatLng(p.latitude, p.longitude)) return false;

    final acc = p.accuracy;
    if (!acc.isFinite || acc <= 0) return false;
    if (acc > maxAccuracyMeters) return false;

    if (rejectMocked && p.isMocked) return false;

    return true;
  }

  /// Outlier industrial:
  /// - Regla 1: distancia vs accuracy (si “salta” mucho más de lo que el error permite).
  /// - Regla 2: velocidad implícita (teletransporte).
  bool _isOutlier(LocationFix fix, {LocationFix? last}) {
    if (last == null) return false;

    final dtMs = fix.timestamp.difference(last.timestamp).inMilliseconds;
    if (dtMs <= 0) return false;

    final seconds = dtMs / 1000.0;

    final d = distanceMeters(
      fromLat: last.latitude,
      fromLon: last.longitude,
      toLat: fix.latitude,
      toLon: fix.longitude,
    );

    final accNow = fix.accuracyMeters ?? 9999;
    final accLast = last.accuracyMeters ?? 9999;
    final maxAcc = (accNow > accLast) ? accNow : accLast;

    // Regla 1: si en pocos segundos se mueve muchísimo más que el error permitido, descartar.
    if (seconds < 8 && maxAcc.isFinite && maxAcc > 0) {
      final threshold = (8.0 * maxAcc) + 5.0;
      if (d > threshold) {
        return true;
      }
    }

    // Regla 2: velocidad implícita absurda (con precisión mediocre).
    if (seconds >= 0.8) {
      final impliedSpeed = d / seconds;
      final precisionBad = accNow > 20;
      if (precisionBad && impliedSpeed > _defaultOutlierSpeedMps) {
        return true;
      }
    }

    return false;
  }

  // ---------- Lifecycle ----------
  /// Cierra recursos internos (útil para tests / reinicios controlados).
  Future<void> dispose({bool clearCache = false}) async {
    _emitEvent('dispose', {});
    _sharedStopTimer?.cancel();
    _sharedStopTimer = null;

    try {
      await _stopSharedStream();
    } catch (_) {}

    try {
      await _sharedController?.close();
    } catch (_) {}
    _sharedController = null;

    _internalTaps.clear();
    _sharedLastEmitAt = null;
    _sharedLastEmittedFix = null;

    _cacheLastUpdateAt = null;
    _cacheLastPromotedFix = null;

    _lastSeenFix = null;

    if (clearCache) {
      _cache.value = null;
      _setStatus(LocationStatus.idle());
    }
  }
}

bool _isValidLatLng(double lat, double lng) =>
    lat.isFinite &&
    lng.isFinite &&
    lat.abs() <= 90 &&
    lng.abs() <= 180 &&
    (lat.abs() > 1e-6 || lng.abs() > 1e-6);
