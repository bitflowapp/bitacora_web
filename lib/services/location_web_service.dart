// lib/services/location_web_service.dart
// Servicio de ubicación para Web usando Geolocator.
// Enfoque en precisión: varios samples + filtrado de lecturas malas.

import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationFix {
  final double lat;
  final double lng;
  final double? accuracyM;
  final DateTime ts;

  const LocationFix({
    required this.lat,
    required this.lng,
    this.accuracyM,
    required this.ts,
  });

  String toCompactString() {
    final acc =
    accuracyM != null ? ' ±${accuracyM!.toStringAsFixed(0)} m' : '';
    return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}$acc';
  }
}

class LocationWebService {
  LocationWebService._();
  static final LocationWebService I = LocationWebService._();

  Future<void> _ensurePerms() async {
    final svc = await Geolocator.isLocationServiceEnabled();
    if (!svc) {
      throw 'Activá el servicio de ubicación del dispositivo.';
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied) {
      throw 'Permiso de ubicación denegado.';
    }
    if (p == LocationPermission.deniedForever) {
      throw 'Permiso denegado permanentemente. Habilitalo en Ajustes.';
    }
  }

  /// Fix “simple”: una sola lectura con timeout.
  Future<LocationFix> getCurrent({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await _ensurePerms();
    final pos = await Geolocator.getCurrentPosition(
      timeLimit: timeout,
      desiredAccuracy: LocationAccuracy.high,
    );
    if (!_valid(pos.latitude, pos.longitude)) {
      throw 'Fix inválido (0,0).';
    }
    return LocationFix(
      lat: pos.latitude,
      lng: pos.longitude,
      accuracyM: pos.accuracy.isFinite ? pos.accuracy : null,
      ts: pos.timestamp ?? DateTime.now(),
    );
  }

  /// Fix “avanzado”: intenta varias lecturas y promedia las mejores.
  ///
  /// Estrategia:
  /// - Pide hasta [samples] lecturas con `bestForNavigation`.
  /// - Descarta lecturas con lat/lng inválidos o precisión > [maxAccuracyMeters].
  /// - Si alguna tiene precisión <= [targetAccuracyMeters], corta antes.
  /// - Calcula media ponderada por 1/accuracy^2.
  /// - Si nada sirve, cae a [getCurrent].
  Future<LocationFix> getBestFix({
    int samples = 4,
    Duration perSampleTimeout = const Duration(seconds: 4),
    Duration betweenSamples = const Duration(milliseconds: 600),
    double targetAccuracyMeters = 20,
    double maxAccuracyMeters = 100,
  }) async {
    await _ensurePerms();

    final List<Position> valid = <Position>[];

    for (var i = 0; i < samples; i++) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          timeLimit: perSampleTimeout,
          desiredAccuracy: LocationAccuracy.bestForNavigation,
        );

        if (!_valid(pos.latitude, pos.longitude)) {
          continue;
        }

        final acc = pos.accuracy;
        if (!acc.isFinite || acc <= 0 || acc > maxAccuracyMeters) {
          continue;
        }

        valid.add(pos);

        if (acc <= targetAccuracyMeters) {
          // Ya tenemos un fix suficientemente preciso.
          break;
        }
      } on TimeoutException {
        // Ignoramos y seguimos probando.
      } catch (_) {
        // Cualquier otro error se ignora para este sample.
      }

      if (i < samples - 1) {
        await Future<void>.delayed(betweenSamples);
      }
    }

    if (valid.isEmpty) {
      // Como último recurso, al menos intentamos el fix simple.
      return getCurrent(timeout: perSampleTimeout);
    }

    if (valid.length == 1) {
      final p = valid.first;
      return LocationFix(
        lat: p.latitude,
        lng: p.longitude,
        accuracyM: p.accuracy.isFinite ? p.accuracy : null,
        ts: p.timestamp ?? DateTime.now(),
      );
    }

    final aggregated = _aggregatePositions(valid);
    return aggregated;
  }

  /// Promedia varias lecturas usando un peso 1/accuracy^2 para lat/lng.
  LocationFix _aggregatePositions(List<Position> positions) {
    double sumLat = 0;
    double sumLng = 0;
    double sumWeight = 0;
    double? bestAccuracy;
    DateTime ts = DateTime.now();

    for (final p in positions) {
      final acc = p.accuracy;
      if (!acc.isFinite || acc <= 0) continue;

      final w = 1.0 / (acc * acc);
      sumLat += p.latitude * w;
      sumLng += p.longitude * w;
      sumWeight += w;

      if (p.timestamp != null && p.timestamp!.isAfter(ts)) {
        ts = p.timestamp!;
      }

      if (bestAccuracy == null || acc < bestAccuracy) {
        bestAccuracy = acc;
      }
    }

    if (sumWeight == 0 || bestAccuracy == null) {
      // Si algo salió raro, devolvemos la más precisa individual.
      final best = positions.reduce(
            (a, b) => a.accuracy <= b.accuracy ? a : b,
      );
      return LocationFix(
        lat: best.latitude,
        lng: best.longitude,
        accuracyM: best.accuracy.isFinite ? best.accuracy : null,
        ts: best.timestamp ?? DateTime.now(),
      );
    }

    final lat = sumLat / sumWeight;
    final lng = sumLng / sumWeight;

    return LocationFix(
      lat: lat,
      lng: lng,
      accuracyM: bestAccuracy,
      ts: ts,
    );
  }

  Future<bool> openInMaps(double lat, double lng) async {
    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      <String, String>{'api': '1', 'query': '$lat,$lng'},
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String mapsUrl(double lat, double lng) => Uri.https(
    'www.google.com',
    '/maps/search/',
    <String, String>{'api': '1', 'query': '$lat,$lng'},
  ).toString();

  String shareText(LocationFix f) =>
      'Ubicación: ${f.lat.toStringAsFixed(6)}, ${f.lng.toStringAsFixed(6)}'
          '\n${mapsUrl(f.lat, f.lng)}';

  bool _valid(double lat, double lng) =>
      lat.isFinite &&
          lng.isFinite &&
          (lat.abs() > 1e-6 || lng.abs() > 1e-6) &&
          lat.abs() <= 90 &&
          lng.abs() <= 180;
}
