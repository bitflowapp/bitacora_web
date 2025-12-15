// lib/services/location_web_service.dart
// Web helper: usa el LocationService “industrial” (común) y agrega utilidades
// específicas para Web (Maps URL / abrir / compartir / clipboard / API no-throw).
//
// Ventajas:
// - Un solo motor de precisión/velocidad (LocationService).
// - Sin duplicación de lógica ni colisión de modelos.
// - Consistencia entre Web/Android/iOS.

import 'dart:async';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'location_service.dart'; // <- LocationService + LocationFix + LocationResult

enum MapsProvider { google, osm }

class LocationWebConfig {
  final MapsProvider provider;
  final bool fallbackToOsmIfGoogleFails;

  const LocationWebConfig({
    this.provider = MapsProvider.google,
    this.fallbackToOsmIfGoogleFails = true,
  });

  LocationWebConfig copyWith({
    MapsProvider? provider,
    bool? fallbackToOsmIfGoogleFails,
  }) =>
      LocationWebConfig(
        provider: provider ?? this.provider,
        fallbackToOsmIfGoogleFails:
        fallbackToOsmIfGoogleFails ?? this.fallbackToOsmIfGoogleFails,
      );
}

class LocationWebService {
  LocationWebService._();
  static final LocationWebService I = LocationWebService._();

  LocationWebConfig _config = const LocationWebConfig();

  LocationWebConfig get config => _config;
  set config(LocationWebConfig v) => _config = v;

  /// Fix “simple”: una sola lectura con timeout.
  /// Usa el motor común para permisos/validación/errores.
  Future<LocationFix> getCurrent({
    Duration timeout = const Duration(seconds: 10),
    LocationAccuracy desiredAccuracy = LocationAccuracy.high,
  }) {
    return LocationService.I.getCurrentFix(
      desiredAccuracy: desiredAccuracy,
      timeout: timeout,
    );
  }

  /// Fix “avanzado”: rápido + preciso + confiable.
  ///
  /// En Web suele convenir:
  /// - primer fix rápido (quickTimeout)
  /// - refinamiento corto por stream (refineWindow) para mejorar precisión real
  ///
  /// `samples/betweenSamples` se usan solo para estimar la ventana de refinamiento
  /// (en vez de hacer N getCurrentPosition que en Web suele ser más lento).
  Future<LocationFix> getBestFix({
    int samples = 4,
    Duration perSampleTimeout = const Duration(seconds: 4),
    Duration betweenSamples = const Duration(milliseconds: 600),
    double targetAccuracyMeters = 20,
    double maxAccuracyMeters = 100,
  }) {
    final refineWindow = _refineWindowFromSamples(
      samples: samples,
      betweenSamples: betweenSamples,
    );

    // hardTimeout: margen razonable para race + refine.
    final hardTimeout = perSampleTimeout + const Duration(seconds: 6);

    return LocationService.I.getFixPreciseFast(
      allowCached: true,
      cacheMaxAge: const Duration(seconds: 15),
      quickTimeout: perSampleTimeout,
      hardTimeout: hardTimeout,
      refineWindow: refineWindow,
      targetAccuracyMeters: targetAccuracyMeters,
      maxAccuracyMeters: maxAccuracyMeters,
      rejectMocked: true,
      maxLastKnownAge: const Duration(minutes: 5),
    );
  }

  /// Versión no-throw (ideal para flows corporativos).
  Future<LocationResult> tryGetBestFix({
    int samples = 4,
    Duration perSampleTimeout = const Duration(seconds: 4),
    Duration betweenSamples = const Duration(milliseconds: 600),
    double targetAccuracyMeters = 20,
    double maxAccuracyMeters = 100,
  }) {
    final refineWindow = _refineWindowFromSamples(
      samples: samples,
      betweenSamples: betweenSamples,
    );

    final hardTimeout = perSampleTimeout + const Duration(seconds: 6);

    return LocationService.I.tryGetFixPreciseFast(
      allowCached: true,
      cacheMaxAge: const Duration(seconds: 15),
      quickTimeout: perSampleTimeout,
      hardTimeout: hardTimeout,
      refineWindow: refineWindow,
      targetAccuracyMeters: targetAccuracyMeters,
      maxAccuracyMeters: maxAccuracyMeters,
      rejectMocked: true,
      maxLastKnownAge: const Duration(minutes: 5),
    );
  }

  /// Stream compartido (eficiente) del motor común.
  Stream<LocationFix> watchFixesShared() => LocationService.I.watchFixesShared();

  // -------------------- Maps / Share / Clipboard (Web) --------------------

  Uri mapsUri(double lat, double lng, {MapsProvider? provider}) {
    final p = provider ?? _config.provider;

    switch (p) {
      case MapsProvider.google:
        return Uri.https(
          'www.google.com',
          '/maps/search/',
          <String, String>{'api': '1', 'query': '$lat,$lng'},
        );
      case MapsProvider.osm:
      // OpenStreetMap con marcador (simple y robusto)
        return Uri.https(
          'www.openstreetmap.org',
          '/search',
          <String, String>{'query': '$lat,$lng'},
        );
    }
  }

  String mapsUrl(double lat, double lng, {MapsProvider? provider}) =>
      mapsUri(lat, lng, provider: provider).toString();

  Future<bool> openInMaps(double lat, double lng, {MapsProvider? provider}) async {
    final p = provider ?? _config.provider;

    // 1) Intento principal
    final primary = mapsUri(lat, lng, provider: p);
    final okPrimary =
    await launchUrl(primary, mode: LaunchMode.platformDefault);
    if (okPrimary) return true;

    // 2) Fallback: si es Google y está habilitado, caemos a OSM
    if (p == MapsProvider.google && _config.fallbackToOsmIfGoogleFails) {
      final fallback = mapsUri(lat, lng, provider: MapsProvider.osm);
      return launchUrl(fallback, mode: LaunchMode.platformDefault);
    }

    return false;
  }

  Future<bool> openFixInMaps(LocationFix f, {MapsProvider? provider}) =>
      openInMaps(f.latitude, f.longitude, provider: provider);

  /// Texto para compartir/copy (incluye precisión si existe).
  String shareText(LocationFix f, {bool includeAccuracy = true, bool includeSource = false}) {
    final acc = (includeAccuracy && f.accuracyMeters != null)
        ? ' ±${f.accuracyMeters!.toStringAsFixed(0)} m'
        : '';
    final src = includeSource ? ' (${f.source})' : '';
    return 'Ubicación: ${f.latitude.toStringAsFixed(6)}, ${f.longitude.toStringAsFixed(6)}$acc$src'
        '\n${mapsUrl(f.latitude, f.longitude)}';
  }

  /// Copia al portapapeles (one-tap).
  Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> copyFixToClipboard(LocationFix f) =>
      copyToClipboard(shareText(f));

  // -------------------- Helpers --------------------

  Duration _refineWindowFromSamples({
    required int samples,
    required Duration betweenSamples,
  }) {
    final s = samples.clamp(2, 8);
    final baseMs = 1600;
    final extraMs = (s - 1) * (betweenSamples.inMilliseconds.clamp(250, 900));
    final ms = (baseMs + extraMs).clamp(1800, 5000);
    return Duration(milliseconds: ms);
  }
}
