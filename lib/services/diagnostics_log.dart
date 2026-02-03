import 'package:flutter/foundation.dart';

enum DiagnosticActionType { gps, photo, audio }

class DiagnosticEvent {
  DiagnosticEvent({
    required this.type,
    required this.ok,
    required this.message,
    required this.at,
  });

  final DiagnosticActionType type;
  final bool ok;
  final String message;
  final DateTime at;
}

class DiagnosticsLog {
  DiagnosticsLog._();

  static final DiagnosticsLog I = DiagnosticsLog._();

  final ValueNotifier<DiagnosticEvent?> lastEvent =
      ValueNotifier<DiagnosticEvent?>(null);

  void record({
    required DiagnosticActionType type,
    required bool ok,
    required String message,
  }) {
    lastEvent.value = DiagnosticEvent(
      type: type,
      ok: ok,
      message: message.trim(),
      at: DateTime.now(),
    );
  }
}
