// lib/services/speech_port.dart
// Contrato común IO/Web para reconocimiento de voz (STT).
// Se implementa en:
//   - speech_service_io_impl.dart
//   - speech_service_web_impl.dart
// El resto de la app solo debería depender de esta interfaz.

import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:flutter/widgets.dart' show TextEditingController;

/// API mínima y estable para un motor de reconocimiento de voz.
abstract class SpeechPort {
  /// Locale actual configurado (p.ej. 'es_AR').
  String? get currentLocale;

  /// Indica si el motor está inicializado y listo.
  bool get isAvailable;

  /// Indica si actualmente se está escuchando.
  bool get isListening;

  /// Inicializa el motor de STT.
  ///
  /// [preferredLocale] permite sugerir un locale (ej: 'es_AR').
  /// Devuelve `true` si quedó operativo.
  Future<bool> init({String? preferredLocale});

  /// Empieza a escuchar y devuelve una única transcripción final.
  ///
  /// - [localeId]: locale deseado; `null` => por defecto del sistema/motor.
  /// - [partial]: callback opcional para resultados parciales.
  /// - [level]: callback opcional para nivel de audio normalizado (0–1 aprox).
  /// - [autoTimeout]: detiene automáticamente si no hay entrada suficiente
  ///   dentro de este período.
  ///
  /// Devuelve el texto final o `null` si no hubo resultado útil.
  Future<String?> listenOnce({
    String? localeId,
    ValueChanged<String>? partial,
    ValueChanged<double>? level,
    Duration autoTimeout = const Duration(seconds: 60),
  });

  /// Variante de [listenOnce] que rellena directamente un [TextEditingController].
  ///
  /// Si no se reconoce nada o el usuario cancela, el texto se mantiene igual.
  Future<void> fillControllerOnce(
      TextEditingController controller, {
        String? localeId,
        Duration autoTimeout = const Duration(seconds: 60),
      });

  /// Detiene la escucha actual intentando cerrar con un resultado final.
  Future<void> stop();

  /// Cancela la escucha actual sin devolver resultado.
  Future<void> cancel();
}
