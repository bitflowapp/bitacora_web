import 'dart:async';

import 'location_service.dart';

Future<LocationFix> browserCurrentPosition({
  Duration timeout = const Duration(seconds: 10),
  bool enableHighAccuracy = true,
  Duration maximumAge = Duration.zero,
}) async {
  throw const LocationException(
      'navigator.geolocation no está disponible fuera de Web.');
}
