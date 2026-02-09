// lib/platform/platform_interop_interface.dart
// Solo la interfaz. Sin imports condicionales.

abstract class PlatformInterop {
  bool get isWeb;

  /// Suscribe callback a eventos de voz.
  void addSpeechListener(void Function(String text) onText);

  /// Suscribe callback a eventos de GPS (payload formateado).
  void addGpsListener(void Function(String payload) onPayload);

  /// Limpia todos los listeners.
  void removeListeners();

  /// Solicita GPS en Web.
  void requestGps();

  /// Alterna dictado en Web.
  void toggleMic();
}
