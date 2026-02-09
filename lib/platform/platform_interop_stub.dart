// lib/platform/platform_interop_stub.dart
// Implementación mobile/desktop. Sin dependencias Web.

import 'platform_interop_interface.dart';

class _StubPlatformInterop implements PlatformInterop {
  @override
  bool get isWeb => false;

  final List<void Function(String)> _speech = [];
  final List<void Function(String)> _gps = [];

  @override
  void addSpeechListener(void Function(String text) onText) {
    _speech.add(onText);
  }

  @override
  void addGpsListener(void Function(String payload) onPayload) {
    _gps.add(onPayload);
  }

  @override
  void removeListeners() {
    _speech.clear();
    _gps.clear();
  }

  @override
  void requestGps() {
    // Stub: sin acción.
  }

  @override
  void toggleMic() {
    // Stub: sin acción.
  }
}

/// Devuelve la implementación para plataformas no Web.
PlatformInterop createPlatformInteropImpl() => _StubPlatformInterop();
