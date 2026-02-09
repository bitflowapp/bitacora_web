class LocationWritePlan {
  const LocationWritePlan({
    required this.latCol,
    required this.lngCol,
    required this.fallbackCol,
  });

  final int? latCol;
  final int? lngCol;
  final int fallbackCol;

  bool get hasLatLng => latCol != null && lngCol != null;
}

String formatLatLng(double lat, double lng, {int decimals = 6}) {
  final d = decimals.clamp(5, 6);
  return '${lat.toStringAsFixed(d)}, ${lng.toStringAsFixed(d)}';
}

LocationWritePlan planLocationColumns(
  List<String> headers, {
  int? currentCol,
}) {
  int? findIndex(List<String> options) {
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].trim().toLowerCase();
      if (options.contains(h)) return i;
    }
    return null;
  }

  final latCol = findIndex(const ['lat', 'latitude', 'latitud']);
  final lngCol = findIndex(const ['lng', 'lon', 'longitude', 'longitud']);

  final maxEditable = headers.isEmpty ? 0 : headers.length - 1;
  final safeCurrent = () {
    final c = currentCol ?? 0;
    if (maxEditable <= 0) return 0;
    final capped = c.clamp(0, maxEditable - 1);
    return capped;
  }();

  if (latCol != null && lngCol != null) {
    return LocationWritePlan(
      latCol: latCol,
      lngCol: lngCol,
      fallbackCol: safeCurrent,
    );
  }

  final fallback = latCol ?? lngCol ?? safeCurrent;
  return LocationWritePlan(
    latCol: latCol,
    lngCol: lngCol,
    fallbackCol: fallback,
  );
}
