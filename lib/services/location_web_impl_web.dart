import 'dart:async';
import 'dart:html' as html; // ignore: avoid_web_libraries_in_flutter

import 'package:flutter/foundation.dart';

import 'location_service.dart';

Future<LocationFix> browserCurrentPosition({
  Duration timeout = const Duration(seconds: 10),
  bool enableHighAccuracy = true,
  Duration maximumAge = Duration.zero,
}) async {
  final geo = html.window.navigator.geolocation;
  if (geo == null) {
    throw const LocationException(
        'Geolocalización no soportada en este navegador.');
  }
  if (html.window.isSecureContext != true) {
    throw const LocationException(
        'Geolocalización requiere HTTPS (o localhost).');
  }

  try {
    final pos = await geo.getCurrentPosition(
      enableHighAccuracy: enableHighAccuracy,
      timeout: timeout,
      maximumAge: maximumAge,
    );
    final coords = pos.coords;
    if (coords == null) {
      throw const LocationException('Ubicación no disponible.');
    }
    final tsMillis = pos.timestamp?.toInt();
    final ts = tsMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(tsMillis)
        : DateTime.now();
    final fix = LocationFix(
      latitude: coords.latitude?.toDouble() ?? 0.0,
      longitude: coords.longitude?.toDouble() ?? 0.0,
      accuracyMeters: coords.accuracy?.toDouble(),
      altitudeMeters: coords.altitude?.toDouble(),
      speedMps: coords.speed?.toDouble(),
      headingDeg: coords.heading?.toDouble(),
      timestamp: ts,
      source: 'web',
    );
    if (kDebugMode) {
      debugPrint(
        '[web-gps] ok lat=${fix.latitude}, lng=${fix.longitude}, '
        'acc=${fix.accuracyMeters}, ts=${fix.timestamp.toIso8601String()}',
      );
    }
    return fix;
  } on html.PositionError catch (err) {
    if (kDebugMode) {
      debugPrint('[web-gps] error code=${err.code} msg=${err.message ?? ''}');
    }
    switch (err.code) {
      case html.PositionError.PERMISSION_DENIED:
        throw const LocationException(
            'Permiso de ubicación denegado. Ajustes > Safari > Ubicación.');
      case html.PositionError.POSITION_UNAVAILABLE:
        throw const LocationException('Ubicación no disponible.');
      case html.PositionError.TIMEOUT:
        throw const LocationException('Timeout obteniendo ubicación.');
      default:
        throw LocationException(err.message ?? 'Error de geolocalización.');
    }
  } on TimeoutException {
    throw TimeoutException('Timeout navegador obteniendo ubicación.');
  }
}
