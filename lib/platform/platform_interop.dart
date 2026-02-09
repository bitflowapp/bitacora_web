// Interfaz común para Web y no-Web.

abstract class PlatformInterop {
  bool get isWeb;

  /// Suscribe callback a eventos de voz.
  void addSpeechListener(void Function(String text) onText);

  /// Suscribe callback a eventos de GPS (payload ya formateado).
  void addGpsListener(void Function(String payload) onPayload);

  /// Limpia todos los listeners registrados.
  void removeListeners();

  /// Solicita GPS en Web (emite 'bitacora:askGps').
  void requestGps();

  /// Alterna dictado en Web (emite 'bitacora:toggleMic').
  void toggleMic();
}
