// lib/services/location_service.dart
// Geolocator 12.x: lecturas puntuales + stream continuo, con fallback y helpers.
// Enfoque en precisión “real” filtrando lecturas malas y promediando varias.
// Null-safe. Android 9–14 / iOS / Web (plugin federado).

import 'dart:async';

import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, debugPrint;
import 'package:geolocator/geolocator.dart';

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);

  @override
  String toString() => 'LocationException: $message';
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

  const LocationFix({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.altitudeMeters,
    this.speedMps,
    this.headingDeg,
    required this.timestamp,
  });

  factory LocationFix.fromPosition(Position p) => LocationFix(
    latitude: p.latitude,
    longitude: p.longitude,
    accuracyMeters: _numOrNull(p.accuracy),
    altitudeMeters: _numOrNull(p.altitude),
    speedMps: _numOrNull(p.speed),
    headingDeg: _numOrNull(p.heading),
    timestamp: p.timestamp ?? DateTime.now(),
  );

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
  };

  static double? _numOrNull(double? v) {
    if (v == null) return null;
    if (v.isNaN || v.isInfinite) return null;
    return v;
  }
}

/// Servicio centralizado de ubicación.
/// Usa singleton [LocationService.I] para simplificar el acceso.
class LocationService {
  LocationService._();
  static final LocationService I = LocationService._();

  final ValueNotifier<LocationFix?> _cache =
  ValueNotifier<LocationFix?>(null);

  /// Último fix válido cacheado (para mostrar en UI sin pedir GPS de nuevo).
  ValueListenable<LocationFix?> get lastFixListenable => _cache;

  // ---------- Permisos / ajustes ----------

  Future<void> _ensureServiceAndPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const LocationException('Activá el servicio de ubicación.');
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied) {
      throw const LocationException('Permiso de ubicación denegado.');
    }

    if (perm == LocationPermission.deniedForever) {
      throw const LocationException(
        'Permiso denegado permanentemente. Revisá los ajustes de la app.',
      );
    }
  }

  Future<bool> hasPermission() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always ||
        p == LocationPermission.whileInUse;
  }

  Future<bool> openSystemLocationSettings() =>
      Geolocator.openLocationSettings();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  // ---------- Lectura puntual básica ----------

  /// Obtiene la posición actual con timeout y fallback a `lastKnown`.
  ///
  /// Lanza:
  /// - [LocationException] si el fix es inválido o sin permisos.
  /// - [TimeoutException] si no se obtiene posición y no hay `lastKnown`.
  Future<Position> getCurrent({
    LocationAccuracy desiredAccuracy = LocationAccuracy.best,
    Duration timeout = const Duration(seconds: 10),
    bool rejectMocked = true,
  }) async {
    await _ensureServiceAndPermission();
    try {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: desiredAccuracy,
        timeLimit: timeout,
      );
      if (!_validPos(p, rejectMocked: rejectMocked)) {
        throw const LocationException('Fix de ubicación inválido.');
      }
      return p;
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && _validPos(last, rejectMocked: rejectMocked)) {
        return last;
      }
      rethrow;
    } catch (e) {
      debugPrint('LocationService.getCurrent error: $e');
      rethrow;
    }
  }

  /// Igual a [getCurrent] pero devuelve [LocationFix] “limpio” y lo cachea.
  Future<LocationFix> getCurrentFix({
    LocationAccuracy desiredAccuracy = LocationAccuracy.best,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final p = await getCurrent(
      desiredAccuracy: desiredAccuracy,
      timeout: timeout,
    );
    final fix = LocationFix.fromPosition(p);
    _cache.value = fix;
    return fix;
  }

  /// Estrategia “smart”:
  /// - Primero intenta alta precisión rápido.
  /// - Si falla, usa precisión media con timeout más relajado.
  Future<LocationFix> getCurrentFixSmart({
    Duration fastTimeout = const Duration(seconds: 5),
  }) async {
    try {
      return await getCurrentFix(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeout: fastTimeout,
      );
    } on Exception {
      final p = await getCurrent(
        desiredAccuracy: LocationAccuracy.medium,
        timeout: const Duration(seconds: 10),
      );
      final fix = LocationFix.fromPosition(p);
      _cache.value = fix;
      return fix;
    }
  }

  // ---------- Lectura puntual avanzada (más precisión) ----------

  /// Intenta conseguir un fix más preciso promediando varias lecturas.
  ///
  /// Estrategia:
  /// - Pide hasta [samples] lecturas con `bestForNavigation`.
  /// - Descarta lecturas mocked o con precisión peor a [maxAccuracyMeters].
  /// - Si alguna cumple [targetAccuracyMeters], corta antes.
  /// - Calcula una media ponderada por 1/accuracy² para lat/lon/alt.
  /// - Si todo falla, cae en [getCurrentFixSmart].
  Future<LocationFix> getBestFix({
    int samples = 4,
    Duration perSampleTimeout = const Duration(seconds: 4),
    Duration betweenSamples = const Duration(milliseconds: 700),
    double targetAccuracyMeters = 15,
    double maxAccuracyMeters = 80,
  }) async {
    await _ensureServiceAndPermission();

    final List<Position> valid = <Position>[];

    for (var i = 0; i < samples; i++) {
      try {
        final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: perSampleTimeout,
        );

        if (!_validPos(p, rejectMocked: true)) {
          continue;
        }

        final acc = p.accuracy;
        if (!acc.isFinite || acc <= 0 || acc > maxAccuracyMeters) {
          continue;
        }

        valid.add(p);

        if (acc <= targetAccuracyMeters) {
          // Ya tenemos un fix “lo bastante bueno”.
          break;
        }
      } on TimeoutException {
        // Ignoramos y seguimos con otros intentos.
      } catch (e) {
        debugPrint('LocationService.getBestFix sample error: $e');
      }

      if (i < samples - 1) {
        // Pequeña espera entre muestras para que el GPS se estabilice.
        await Future<void>.delayed(betweenSamples);
      }
    }

    if (valid.isEmpty) {
      // Fallback: al menos intentar la estrategia smart.
      return getCurrentFixSmart();
    }

    if (valid.length == 1) {
      final single = LocationFix.fromPosition(valid.first);
      _cache.value = single;
      return single;
    }

    final aggregated = _aggregatePositions(valid);
    _cache.value = aggregated;
    return aggregated;
  }

  /// Calcula una media ponderada (1/accuracy²) de varias lecturas.
  LocationFix _aggregatePositions(List<Position> positions) {
    double sumLat = 0;
    double sumLon = 0;
    double sumAlt = 0;
    double sumWeight = 0;
    double? bestAccuracy;

    for (final p in positions) {
      final acc = p.accuracy;
      if (!acc.isFinite || acc <= 0) continue;

      final weight = 1.0 / (acc * acc);
      sumLat += p.latitude * weight;
      sumLon += p.longitude * weight;

      if (p.altitude.isFinite) {
        sumAlt += p.altitude * weight;
      }

      sumWeight += weight;

      if (bestAccuracy == null || acc < bestAccuracy) {
        bestAccuracy = acc;
      }
    }

    if (sumWeight == 0 || bestAccuracy == null) {
      // Si algo salió raro, nos quedamos con la mejor posición individual.
      final best = positions.reduce(
            (a, b) => a.accuracy <= b.accuracy ? a : b,
      );
      return LocationFix.fromPosition(best);
    }

    final lat = sumLat / sumWeight;
    final lon = sumLon / sumWeight;
    final alt = sumAlt / sumWeight;

    final best = positions.reduce(
          (a, b) => a.accuracy <= b.accuracy ? a : b,
    );

    return LocationFix(
      latitude: lat,
      longitude: lon,
      accuracyMeters: bestAccuracy,
      altitudeMeters: best.altitude.isFinite ? alt : null,
      speedMps: LocationFix._numOrNull(best.speed),
      headingDeg: LocationFix._numOrNull(best.heading),
      timestamp: best.timestamp ?? DateTime.now(),
    );
  }

  // ---------- Stream continuo ----------

  /// Stream de fixes filtrados:
  /// - Filtra posiciones mocked.
  /// - Filtra precisiones peores a [rejectAboveAccuracyMeters].
  Stream<LocationFix> watchFixes({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilterMeters = 2,
    double rejectAboveAccuracyMeters = 100,
  }) async* {
    await _ensureServiceAndPermission();

    final settings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilterMeters,
    );

    final stream = Geolocator.getPositionStream(locationSettings: settings);

    await for (final p in stream) {
      if (!_validPos(p, rejectMocked: true)) continue;
      final acc = p.accuracy;
      if (acc.isFinite && acc > rejectAboveAccuracyMeters) continue;

      final fix = LocationFix.fromPosition(p);
      _cache.value = fix;
      yield fix;
    }
  }

  // ---------- Helpers ----------

  /// Distancia en metros entre dos coordenadas.
  static double distanceMeters({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) =>
      Geolocator.distanceBetween(fromLat, fromLon, toLat, toLon);

  bool _validPos(Position p, {bool rejectMocked = true}) {
    if (!_isValidLatLng(p.latitude, p.longitude)) return false;

    final acc = p.accuracy;
    if (!acc.isFinite || acc <= 0 || acc > 150) return false;

    if (rejectMocked && p.isMocked) return false;

    return true;
  }
}

bool _isValidLatLng(double lat, double lng) =>
    lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180 &&
        (lat.abs() > 1e-6 || lng.abs() > 1e-6);
