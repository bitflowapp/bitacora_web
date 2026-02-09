// lib/platform/platform_interop_web.dart
// Implementación Web usando dart:html, aislada por import condicional.
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'platform_interop_interface.dart';

class _WebPlatformInterop implements PlatformInterop {
  html.EventListener? _speechListener;
  html.EventListener? _gpsListener;

  @override
  bool get isWeb => true;

  @override
  void addSpeechListener(void Function(String text) onText) {
    _removeSpeech();
    _speechListener = (e) {
      final ce = e is html.CustomEvent ? e : null;
      final detail = ce?.detail;

      String? out;
      if (detail is Map) {
        final t = detail['text'];
        if (t is String) out = t.trim();
      } else if (detail is String) {
        out = detail.trim();
      }

      if (out != null && out.isNotEmpty) onText(out);
    };
    html.window.addEventListener('bitacora:speech', _speechListener);
  }

  @override
  void addGpsListener(void Function(String payload) onPayload) {
    _removeGps();
    _gpsListener = (e) {
      final ce = e is html.CustomEvent ? e : null;
      final d = ce?.detail;

      String? out;
      if (d is Map) {
        final t = d['text'];
        if (t is String && t.trim().isNotEmpty) {
          out = t.trim();
        } else {
          final lat = (d['lat'] as num?)?.toDouble();
          final lon = (d['lon'] as num?)?.toDouble();
          final acc = (d['accuracy'] as num?)?.toDouble();
          if (lat != null && lon != null) {
            final b = StringBuffer()
              ..write(lat.toStringAsFixed(6))
              ..write(', ')
              ..write(lon.toStringAsFixed(6));
            if (acc != null && acc > 0) b.write(' ±${acc.round()} m');
            out = b.toString();
          }
        }
      } else if (d is String) {
        out = d.trim();
      }

      if (out != null && out.isNotEmpty) onPayload(out);
    };
    html.window.addEventListener('bitacora:gps', _gpsListener);
  }

  @override
  void removeListeners() {
    _removeSpeech();
    _removeGps();
  }

  @override
  void requestGps() {
    try {
      html.window.dispatchEvent(html.CustomEvent('bitacora:askGps'));
    } catch (_) {}
  }

  @override
  void toggleMic() {
    try {
      html.window.dispatchEvent(html.CustomEvent('bitacora:toggleMic'));
    } catch (_) {}
  }

  void _removeSpeech() {
    final l = _speechListener;
    if (l != null) {
      html.window.removeEventListener('bitacora:speech', l);
      _speechListener = null;
    }
  }

  void _removeGps() {
    final l = _gpsListener;
    if (l != null) {
      html.window.removeEventListener('bitacora:gps', l);
      _gpsListener = null;
    }
  }
}

/// Factory para el import condicional desde platform_interop.dart
PlatformInterop createPlatformInteropImpl() => _WebPlatformInterop();
