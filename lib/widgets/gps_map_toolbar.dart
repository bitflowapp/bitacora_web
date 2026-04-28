// lib/widgets/gps_map_toolbar.dart
//
// GPS profesional para Gridnote / Bitácora:
//
// - Funciona sin conexión de datos: depende sólo del chip de ubicación (geolocator).
// - Filtro matemático:
//     * Suavizado exponencial según precisión reportada.
//     * Descarte de saltos imposibles (velocidad y distancia irreales).
// - Estado de GPS claro: Inicializando / Buscando / Fijado / Señal débil / Sin permisos / Desactivado.
// - Mini mapa con OpenStreetMap (flutter_map):
//     * Si no hay internet, el mapa puede no cargar, pero el GPS y las coords siguen funcionando.
// - Botones: centrarse en posición filtrada, usar punto actual para la fila, abrir mapa grande.
// - Tap en mapa (mini o grande) => callback con lat/lng para vincular con la fila de la grilla.
//
// Dependencias en pubspec.yaml (en dependencies:):
//   geolocator: ^12.0.0
//   flutter_map: ^7.0.0
//   latlong2: ^0.9.0

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

enum _GpsStatus {
  initializing,
  searching,
  locked,
  weak,
  disabled,
  denied,
  error,
}

/// Configuración del filtro de GPS.
class _GpsFilterConfig {
  const _GpsFilterConfig();

  /// Precisión objetivo (m). Por debajo de esto es "ideal".
  final double referenceAccuracyMeters = 15.0;

  /// Si la precisión nueva es peor que esto y ya tenemos punto previo, se descarta.
  final double maxAcceptableAccuracyMeters = 80.0;

  /// Velocidad máxima razonable entre dos puntos (km/h).
  final double maxJumpSpeedKmh = 180.0;

  /// Distancia máxima razonable entre dos puntos (m) en dt corto.
  final double maxJumpDistanceMeters = 400.0;

  /// Peso mínimo del nuevo punto en el suavizado.
  final double minAlpha = 0.3;

  /// Peso máximo del nuevo punto en el suavizado.
  final double maxAlpha = 0.85;

  /// Edad máxima (s) para considerar que la señal sigue "fresca".
  final int maxFreshAgeSeconds = 12;
}

/// Punto de GPS ya filtrado.
class _TrackedPoint {
  const _TrackedPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speedKmh,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final double speedKmh;
  final DateTime timestamp;
}

// ---------------------- Helpers matemáticos ----------------------

double _degToRad(double deg) => deg * (math.pi / 180.0);

double _haversineDistanceMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadius = 6371000.0; // metros
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

double _clampDouble(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

/// Calcula el peso (alpha) según la precisión reportada.
double _computeAlpha(double rawAccuracy, _GpsFilterConfig cfg) {
  final accuracy = rawAccuracy <= 0 ? cfg.referenceAccuracyMeters : rawAccuracy;
  final ratio = cfg.referenceAccuracyMeters / accuracy;
  final mapped = ratio / (1.0 + ratio); // 0..1
  return _clampDouble(mapped, cfg.minAlpha, cfg.maxAlpha);
}

// ---------------------- Widget principal ----------------------

class GpsMapToolbar extends StatefulWidget {
  const GpsMapToolbar({
    super.key,
    this.onCoordinatePicked,
    this.initialLatitude,
    this.initialLongitude,
    this.rowLabel,
  });

  /// Callback al elegir coordenadas (tap mapa o botón "usar punto actual").
  final void Function(double lat, double lng)? onCoordinatePicked;

  /// Coordenadas iniciales de la fila, si ya existían.
  final double? initialLatitude;
  final double? initialLongitude;

  /// Etiqueta opcional para indicar la fila (ej: "Fila 3").
  final String? rowLabel;

  @override
  State<GpsMapToolbar> createState() => _GpsMapToolbarState();
}

class _GpsMapToolbarState extends State<GpsMapToolbar> {
  static const _GpsFilterConfig _filterConfig = _GpsFilterConfig();

  // Centro de respaldo: Neuquén.
  static const LatLng _fallbackCenter = LatLng(-38.9516, -68.0591);

  final MapController _mapController = MapController();

  StreamSubscription<Position>? _positionSub;

  _TrackedPoint? _tracked;

  LatLng? _markerLatLng;
  _GpsStatus _status = _GpsStatus.initializing;

  bool _followUser = true;
  final double _zoom = 16.0;
  bool _gpsStarted = false;
  bool _gpsRequestInFlight = false;
  bool _needsUserAction = false;

  @override
  void initState() {
    super.initState();
    _markerLatLng = _initialMarkerFromProps();
    _initLocation(userInitiated: !kIsWeb);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  LatLng? _initialMarkerFromProps() {
    final lat = widget.initialLatitude;
    final lng = widget.initialLongitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  Future<void> _initLocation({required bool userInitiated}) async {
    if (_gpsStarted || _gpsRequestInFlight) return;
    _gpsRequestInFlight = true;

    setState(() {
      _status = _GpsStatus.initializing;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && !kIsWeb) {
        if (!mounted) return;
        setState(() {
          _status = _GpsStatus.disabled;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && userInitiated) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _needsUserAction = permission == LocationPermission.denied;
        if (!mounted) return;
        setState(() {
          _status = _GpsStatus.denied;
        });
        return;
      }

      _needsUserAction = false;
      if (!mounted) return;
      setState(() {
        _status = _GpsStatus.searching;
      });

      final initialPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return;

      _processPosition(initialPos);

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 2,
        ),
      ).listen((position) {
        if (!mounted) return;
        _processPosition(position);
      });
      _gpsStarted = true;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _GpsStatus.error;
      });
    } finally {
      _gpsRequestInFlight = false;
    }
  }

  void _processPosition(Position position) {
    final timestamp = position.timestamp ?? DateTime.now();
    final rawAccuracy = position.accuracy;
    final accuracy =
        rawAccuracy <= 0 ? _filterConfig.referenceAccuracyMeters : rawAccuracy;

    if (_tracked != null &&
        accuracy > _filterConfig.maxAcceptableAccuracyMeters) {
      return;
    }

    final lat = position.latitude;
    final lng = position.longitude;

    if (_tracked == null) {
      final first = _TrackedPoint(
        latitude: lat,
        longitude: lng,
        accuracy: accuracy,
        speedKmh: 0,
        timestamp: timestamp,
      );
      setState(() {
        _tracked = first;
        _status = _statusFromTracked(first);
        _markerLatLng ??= LatLng(lat, lng);
      });
      if (_followUser) {
        _moveCamera(LatLng(lat, lng));
      }
      return;
    }

    final prev = _tracked!;
    final dtSeconds =
        timestamp.difference(prev.timestamp).inMilliseconds / 1000.0;
    final safeDt = dtSeconds <= 0 ? 1.0 : dtSeconds;

    final distance = _haversineDistanceMeters(
      prev.latitude,
      prev.longitude,
      lat,
      lng,
    );

    final speedMs = distance / safeDt;
    final speedKmh = speedMs * 3.6;

    if (speedKmh > _filterConfig.maxJumpSpeedKmh &&
        distance > _filterConfig.maxJumpDistanceMeters) {
      return;
    }

    final alpha = _computeAlpha(accuracy, _filterConfig);
    final filteredLat = alpha * lat + (1 - alpha) * prev.latitude;
    final filteredLng = alpha * lng + (1 - alpha) * prev.longitude;

    final next = _TrackedPoint(
      latitude: filteredLat,
      longitude: filteredLng,
      accuracy: accuracy,
      speedKmh: speedKmh,
      timestamp: timestamp,
    );

    setState(() {
      _tracked = next;
      _status = _statusFromTracked(next);
      if (_markerLatLng == null && _followUser) {
        _markerLatLng = LatLng(filteredLat, filteredLng);
      }
    });

    if (_followUser) {
      _moveCamera(LatLng(filteredLat, filteredLng));
    }
  }

  _GpsStatus _statusFromTracked(_TrackedPoint p) {
    final ageSeconds = DateTime.now().difference(p.timestamp).inSeconds;
    if (ageSeconds > _filterConfig.maxFreshAgeSeconds) {
      return _GpsStatus.weak;
    }
    if (p.accuracy <= _filterConfig.referenceAccuracyMeters) {
      return _GpsStatus.locked;
    }
    if (p.accuracy <= _filterConfig.maxAcceptableAccuracyMeters) {
      return _GpsStatus.weak;
    }
    return _GpsStatus.searching;
  }

  void _moveCamera(LatLng target) {
    _mapController.move(target, _zoom);
  }

  LatLng _currentCenter() {
    if (_markerLatLng != null) return _markerLatLng!;
    final t = _tracked;
    if (t != null) {
      return LatLng(t.latitude, t.longitude);
    }
    return _fallbackCenter;
  }

  void _handleMiniMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _markerLatLng = point;
      _followUser = false;
    });
    _notifyPicked(point);
  }

  void _handleFullMapTap(LatLng point) {
    setState(() {
      _markerLatLng = point;
      _followUser = false;
    });
    _notifyPicked(point);
  }

  void _notifyPicked(LatLng point) {
    final callback = widget.onCoordinatePicked;
    if (callback != null) {
      callback(point.latitude, point.longitude);
    }
  }

  Future<void> _pickCurrentPosition() async {
    if (_tracked == null || _needsUserAction) {
      await _initLocation(userInitiated: true);
    }
    final t = _tracked;
    if (t == null) return;

    final point = LatLng(t.latitude, t.longitude);
    setState(() {
      _markerLatLng = point;
      _followUser = false;
    });
    _notifyPicked(point);
  }

  Future<void> _centerOnUser() async {
    if (_tracked == null || _needsUserAction) {
      await _initLocation(userInitiated: true);
    }
    final t = _tracked;
    if (t == null) return;

    final latLng = LatLng(t.latitude, t.longitude);
    setState(() {
      _followUser = true;
    });
    _moveCamera(latLng);
  }

  Future<void> _copyCoordinatesToClipboard() async {
    final coords = _coordinateLabel(includeAccuracy: false);
    if (coords.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: coords));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coordenadas copiadas'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _coordinateLabel({bool includeAccuracy = true}) {
    final t = _tracked;
    if (t == null) return '';

    final base =
        '${t.latitude.toStringAsFixed(6)}, ${t.longitude.toStringAsFixed(6)}';

    if (!includeAccuracy) return base;

    final acc = t.accuracy;
    if (acc <= 0) return base;

    final accStr = acc.toStringAsFixed(0);
    return '$base · ±$accStr m';
  }

  void _openFullScreenMap() {
    final trackedLatLng = _tracked == null
        ? null
        : LatLng(_tracked!.latitude, _tracked!.longitude);
    final center = _markerLatLng ?? trackedLatLng ?? _fallbackCenter;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _FullScreenMapSheet(
          initialCenter: center,
          currentLatLng: trackedLatLng,
          initialMarker: _markerLatLng,
          onTap: _handleFullMapTap,
          onConfirmCopy: _copyCoordinatesToClipboard,
        );
      },
    );
  }

  String _statusLabel() {
    switch (_status) {
      case _GpsStatus.initializing:
        return 'Inicializando';
      case _GpsStatus.searching:
        return 'Buscando señal';
      case _GpsStatus.locked:
        return 'GPS fijado';
      case _GpsStatus.weak:
        return 'Señal débil';
      case _GpsStatus.disabled:
        return 'GPS desactivado';
      case _GpsStatus.denied:
        return 'Sin permisos';
      case _GpsStatus.error:
        return 'Error de GPS';
    }
  }

  Color _statusColor(ThemeData theme) {
    final primary = theme.colorScheme.primary;
    switch (_status) {
      case _GpsStatus.locked:
        return primary;
      case _GpsStatus.searching:
        return Colors.amber;
      case _GpsStatus.weak:
        return Colors.orangeAccent;
      case _GpsStatus.disabled:
      case _GpsStatus.denied:
      case _GpsStatus.error:
        return Colors.redAccent;
      case _GpsStatus.initializing:
        return theme.disabledColor;
    }
  }

  Widget _buildStatusPill(ThemeData theme) {
    final color = _statusColor(theme);
    final label = _statusLabel();
    final isDark = theme.brightness == Brightness.dark;
    final bg =
        isDark ? color.withValues(alpha: 0.16) : color.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtle = textColor.withValues(alpha: 0.6);

    final rowLabel = widget.rowLabel;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
          child: const Icon(
            Icons.sensors,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GPS vinculado a grilla',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                rowLabel == null
                    ? 'Usá la fila seleccionada para guardar coordenadas'
                    : 'Fila actual: $rowLabel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: subtle,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildStatusPill(theme),
      ],
    );
  }

  Widget _buildMiniMap(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_status == _GpsStatus.initializing ||
        _status == _GpsStatus.searching && _tracked == null) {
      return Container(
        color: isDark ? const Color(0xFF101010) : const Color(0xFFEDEDED),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_status == _GpsStatus.disabled) {
      return const _MiniMapMessage(
        icon: Icons.location_disabled_outlined,
        title: 'GPS desactivado',
        message: 'Activá la ubicación del dispositivo para ver el mapa.',
      );
    }

    if (_status == _GpsStatus.denied) {
      return const _MiniMapMessage(
        icon: Icons.lock_outline,
        title: 'Permiso denegado',
        message: 'Revisá los permisos de ubicación de la app.',
      );
    }

    final center = _currentCenter();
    final markers = <Marker>[];

    final t = _tracked;
    if (t != null) {
      final currentLatLng = LatLng(t.latitude, t.longitude);
      markers.add(
        Marker(
          width: 36,
          height: 36,
          point: currentLatLng,
          child: _PulseDot(color: theme.colorScheme.primary),
        ),
      );
    }

    final marker = _markerLatLng;
    if (marker != null) {
      markers.add(
        Marker(
          width: 28,
          height: 28,
          point: marker,
          child: const Icon(
            Icons.place,
            size: 26,
            color: Colors.redAccent,
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: _zoom,
        onTap: _handleMiniMapTap,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.gridnote.app',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor =
        isDark ? const Color(0xFF090909) : const Color(0xFFF7F7F7);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtle = textColor.withValues(alpha: 0.7);
    final coords = _coordinateLabel();

    final gpsUnavailable =
        _status == _GpsStatus.disabled || _status == _GpsStatus.error;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      color: cardColor,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 190,
                child: _buildMiniMap(context),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Wrap(
                  spacing: 4,
                  children: [
                    Tooltip(
                      message: 'Centrar en posición filtrada',
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: gpsUnavailable ? null : _centerOnUser,
                        icon: const Icon(Icons.my_location_outlined, size: 20),
                      ),
                    ),
                    Tooltip(
                      message: 'Usar punto actual en la fila',
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: gpsUnavailable ? null : _pickCurrentPosition,
                        icon: const Icon(Icons.push_pin_outlined, size: 20),
                      ),
                    ),
                    Tooltip(
                      message: 'Ver mapa grande',
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: gpsUnavailable ? null : _openFullScreenMap,
                        icon: const Icon(Icons.open_in_full, size: 20),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(Icons.pin_drop_outlined, size: 16, color: subtle),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    coords.isEmpty ? 'Sin coordenadas aún' : coords,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: subtle,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed:
                      coords.isEmpty ? null : _copyCoordinatesToClipboard,
                  child: const Text('Copiar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------- Widgets auxiliares ----------------------

class _MiniMapMessage extends StatelessWidget {
  const _MiniMapMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtle = textColor.withValues(alpha: 0.7);

    return Container(
      color: isDark ? const Color(0xFF101010) : const Color(0xFFEDEDED),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: subtle),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subtle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _scale = Tween<double>(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color;
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: _scale.value,
                child: Opacity(
                  opacity: _opacity.value,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: baseColor,
                    ),
                  ),
                ),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: baseColor,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FullScreenMapSheet extends StatefulWidget {
  const _FullScreenMapSheet({
    required this.initialCenter,
    required this.currentLatLng,
    required this.initialMarker,
    required this.onTap,
    required this.onConfirmCopy,
  });

  final LatLng initialCenter;
  final LatLng? currentLatLng;
  final LatLng? initialMarker;
  final void Function(LatLng point) onTap;
  final VoidCallback onConfirmCopy;

  @override
  State<_FullScreenMapSheet> createState() => _FullScreenMapSheetState();
}

class _FullScreenMapSheetState extends State<_FullScreenMapSheet> {
  final MapController _controller = MapController();
  LatLng? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialMarker ?? widget.initialCenter;
  }

  void _handleTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selected = point;
    });
    widget.onTap(point);
  }

  String _coordLabel() {
    final p = _selected;
    if (p == null) return 'Tocá el mapa para elegir un punto';
    return '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtle = textColor.withValues(alpha: 0.7);

    final markers = <Marker>[];

    final currentLatLng = widget.currentLatLng;
    if (currentLatLng != null) {
      markers.add(
        Marker(
          width: 32,
          height: 32,
          point: currentLatLng,
          child: _PulseDot(color: theme.colorScheme.primary),
        ),
      );
    }

    final selected = _selected;
    if (selected != null) {
      markers.add(
        Marker(
          width: 30,
          height: 30,
          point: selected,
          child: const Icon(
            Icons.place,
            size: 30,
            color: Colors.redAccent,
          ),
        ),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.map_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Mapa en tiempo real',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: FlutterMap(
                    mapController: _controller,
                    options: MapOptions(
                      initialCenter: widget.initialCenter,
                      initialZoom: 16,
                      onTap: _handleTap,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.gridnote.app',
                      ),
                      MarkerLayer(markers: markers),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.pin_drop_outlined, size: 18, color: subtle),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _coordLabel(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: subtle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: widget.onConfirmCopy,
                      child: const Text('Copiar'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
