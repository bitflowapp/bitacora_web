import 'package:flutter/widgets.dart';
import 'speech_port.dart';

class SpeechService implements SpeechPort {
  SpeechService._();
  static final SpeechService I = SpeechService._();

  @override
  String? get currentLocale => _currentLocale;
  String? _currentLocale;

  @override
  bool get isAvailable => false;

  @override
  bool get isListening => false;

  @override
  Future<bool> init({String? preferredLocale}) async {
    _currentLocale = preferredLocale;
    return false;
  }

  @override
  Future<String?> listenOnce({
    String? localeId,
    ValueChanged<String>? partial,
    ValueChanged<double>? level,
    Duration autoTimeout = const Duration(seconds: 60),
  }) async {
    return null;
  }

  @override
  Future<void> fillControllerOnce(
      TextEditingController controller, {
        String? localeId,
        Duration autoTimeout = const Duration(seconds: 60),
      }) async {
    // no-op
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}
