// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Datos del evento GPS
typedef GpsDetail = ({double lat, double lon, num? accuracy, String text});
typedef SpeechDetail = ({String text});

class WebInteropBridge {
  WebInteropBridge({required this.onGps, required this.onSpeech});
  final void Function(GpsDetail) onGps;
  final void Function(SpeechDetail) onSpeech;

  /// Llamar una vez (por ejemplo en initState) solo en web.
  void attach() {
    web.window.addEventListener('bitacora:gps', (web.Event e) {
      final detailAny = (e as web.CustomEvent).detail as JSAny?;
      final map = detailAny?.dartify() as Map<Object?, Object?>?;
      if (map == null) return;
      final lat = (map['lat'] as num).toDouble();
      final lon = (map['lon'] as num).toDouble();
      final acc = map['accuracy'] as num?;
      final txt = (map['text'] as String?) ?? '';
      onGps((lat: lat, lon: lon, accuracy: acc, text: txt));
    }.toJS);

    web.window.addEventListener('bitacora:speech', (web.Event e) {
      final detailAny = (e as web.CustomEvent).detail as JSAny?;
      final map = detailAny?.dartify() as Map<Object?, Object?>?;
      final txt = (map?['text'] as String?) ?? '';
      if (txt.isNotEmpty) onSpeech((text: txt));
    }.toJS);
  }
}
