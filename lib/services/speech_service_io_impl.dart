// lib/services/speech_service_io_impl.dart
// Implementación STT para plataformas IO (Android / iOS / desktop)
// usando speech_to_text.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'speech_port.dart';

class SpeechService implements SpeechPort {
  SpeechService._();
  static final SpeechService I = SpeechService._();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _initialized = false;
  bool _available = false;
  bool _isListening = false;
  bool _busy = false;
  String? _currentLocale;
  String? _lastPartial;

  @override
  String? get currentLocale => _currentLocale;

  @override
  bool get isAvailable => _available;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> init({String? preferredLocale}) async {
    if (_initialized) return _available;

    try {
      _available = await _speech.initialize(
        onError: (e) {
          _isListening = false;
          _busy = false;
        },
        onStatus: (s) {
          if (s == 'notListening' || s == 'done') {
            _isListening = false;
            _busy = false;
          }
        },
      );
      _initialized = true;
      if (!_available) return false;

      final locales = await _speech.locales();
      String? pick = preferredLocale;

      if (preferredLocale != null && locales.isNotEmpty) {
        final lower = preferredLocale.toLowerCase();

        // Match exacto por localeId.
        stt.LocaleName? exact;
        for (final l in locales) {
          if (l.localeId.toLowerCase() == lower) {
            exact = l;
            break;
          }
        }
        if (exact != null) {
          pick = exact.localeId;
        } else {
          // Match por idioma (es, en, pt, etc.).
          final langOnly = lower.split('_').first;
          stt.LocaleName? langMatch;
          for (final l in locales) {
            if (l.localeId.toLowerCase().startsWith(langOnly)) {
              langMatch = l;
              break;
            }
          }
          if (langMatch != null) {
            pick = langMatch.localeId;
          }
        }
      }

      pick ??= (await _speech.systemLocale())?.localeId;
      if (pick == null && locales.isNotEmpty) {
        pick = locales.first.localeId;
      }

      _currentLocale = pick;
      return true;
    } catch (_) {
      _available = false;
      _initialized = true;
      return false;
    }
  }

  @override
  Future<String?> listenOnce({
    String? localeId,
    ValueChanged<String>? partial,
    ValueChanged<double>? level,
    Duration autoTimeout = const Duration(seconds: 60),
  }) async {
    if (!_available) return null;

    // Evita superposición si quedó algo escuchando.
    if (_isListening || _busy) {
      try {
        await _speech.cancel();
      } catch (_) {}
      _isListening = false;
      _busy = false;
    }

    _busy = true;
    _isListening = true;
    _lastPartial = null;

    final completer = Completer<String?>();
    Timer? to;

    Future<void> finish([String? value]) async {
      if (to != null && to!.isActive) {
        to!.cancel();
      }
      if (_isListening) {
        try {
          await _speech.stop();
        } catch (_) {}
      }
      _isListening = false;
      _busy = false;
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }

    try {
      to = Timer(autoTimeout, () => finish(_lastPartial));

      await _speech.listen(
        localeId: localeId ?? _currentLocale,
        listenMode: stt.ListenMode.dictation,
        listenFor: autoTimeout,
        partialResults: true,
        cancelOnError: true,
        onResult: (r) {
          final text = r.recognizedWords.trim();
          if (text.isNotEmpty) {
            _lastPartial = text;
            partial?.call(text);
          }
          if (r.finalResult) {
            finish(text.isNotEmpty ? text : _lastPartial);
          }
        },
        onSoundLevelChange: (lv) {
          // speech_to_text suele devolver 0..50 aprox → normalizamos a 0..1.
          final norm = (lv / 50.0).clamp(0.0, 1.0);
          level?.call(norm);
        },
      );
    } catch (_) {
      await finish(_lastPartial);
    }

    final res = await completer.future;
    return (res != null && res.trim().isNotEmpty) ? res : null;
  }

  @override
  Future<void> fillControllerOnce(
      TextEditingController controller, {
        String? localeId,
        Duration autoTimeout = const Duration(seconds: 60),
      }) async {
    final text = await listenOnce(
      localeId: localeId,
      autoTimeout: autoTimeout,
    );
    if (text == null || text.trim().isEmpty) return;

    final has = controller.text.trim().isNotEmpty;
    controller.text = has ? '${controller.text} $text' : text;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
    _isListening = false;
    _busy = false;
  }

  @override
  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {}
    _isListening = false;
    _busy = false;
  }
}
