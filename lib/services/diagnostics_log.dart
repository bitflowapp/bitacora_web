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

class PhotoAttemptInfo {
  PhotoAttemptInfo({
    required this.stage,
    DateTime? at,
    this.fileName,
    this.fileSize,
    this.fileType,
    this.reportedMime,
    this.sniffedMime,
    this.size,
    this.bytes,
    this.storageMode,
    this.storageKey,
    this.previewable,
    this.error,
    this.stack,
    this.ua,
    this.secureContext,
    this.inAppBrowser,
    this.isIOS,
    this.isSafari,
    this.visibility,
    this.hasFocus,
  }) : at = at ?? DateTime.now();

  final String stage;
  final DateTime at;
  final String? fileName;
  final int? fileSize;
  final String? fileType;
  final String? reportedMime;
  final String? sniffedMime;
  final int? size;
  final int? bytes;
  final String? storageMode;
  final String? storageKey;
  final bool? previewable;
  final String? error;
  final String? stack;
  final String? ua;
  final bool? secureContext;
  final bool? inAppBrowser;
  final bool? isIOS;
  final bool? isSafari;
  final String? visibility;
  final bool? hasFocus;
}

class DiagnosticsLog {
  DiagnosticsLog._();

  static final DiagnosticsLog I = DiagnosticsLog._();

  final ValueNotifier<DiagnosticEvent?> lastEvent =
      ValueNotifier<DiagnosticEvent?>(null);

  final ValueNotifier<PhotoAttemptInfo?> lastPhotoAttempt =
      ValueNotifier<PhotoAttemptInfo?>(null);

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

  void updatePhotoAttempt({
    String? stage,
    String? fileName,
    int? fileSize,
    String? fileType,
    String? reportedMime,
    String? sniffedMime,
    int? size,
    int? bytes,
    String? storageMode,
    String? storageKey,
    bool? previewable,
    String? error,
    String? stack,
    String? ua,
    bool? secureContext,
    bool? inAppBrowser,
    bool? isIOS,
    bool? isSafari,
    String? visibility,
    bool? hasFocus,
    bool reset = false,
    bool clearError = false,
    bool clearStack = false,
  }) {
    final prev = reset ? null : lastPhotoAttempt.value;
    lastPhotoAttempt.value = PhotoAttemptInfo(
      stage: stage ?? prev?.stage ?? 'init',
      at: DateTime.now(),
      fileName: fileName ?? prev?.fileName,
      fileSize: fileSize ?? prev?.fileSize,
      fileType: fileType ?? prev?.fileType,
      reportedMime: reportedMime ?? prev?.reportedMime,
      sniffedMime: sniffedMime ?? prev?.sniffedMime,
      size: size ?? prev?.size,
      bytes: bytes ?? prev?.bytes,
      storageMode: storageMode ?? prev?.storageMode,
      storageKey: storageKey ?? prev?.storageKey,
      previewable: previewable ?? prev?.previewable,
      error: clearError ? null : (error ?? prev?.error),
      stack: clearStack ? null : (stack ?? prev?.stack),
      ua: ua ?? prev?.ua,
      secureContext: secureContext ?? prev?.secureContext,
      inAppBrowser: inAppBrowser ?? prev?.inAppBrowser,
      isIOS: isIOS ?? prev?.isIOS,
      isSafari: isSafari ?? prev?.isSafari,
      visibility: visibility ?? prev?.visibility,
      hasFocus: hasFocus ?? prev?.hasFocus,
    );
  }
}
