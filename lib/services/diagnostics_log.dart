import 'package:flutter/foundation.dart';

enum DiagnosticActionType { gps, photo, audio, video, file, location }

enum AttachmentPipelineStep {
  capability,
  pick,
  normalize,
  persist,
  bind,
  preview,
}

class AttachmentTraceEvent {
  AttachmentTraceEvent({
    required this.operationId,
    required this.cellId,
    required this.attachmentType,
    required this.source,
    required this.step,
    required this.ok,
    required this.elapsedMs,
    required this.at,
    this.reason,
    this.techDetail,
    this.stack,
  });

  final String operationId;
  final String cellId;
  final String attachmentType;
  final String source;
  final AttachmentPipelineStep step;
  final bool ok;
  final int elapsedMs;
  final DateTime at;
  final String? reason;
  final String? techDetail;
  final String? stack;
}

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

  final ValueNotifier<AttachmentTraceEvent?> lastAttachmentTrace =
      ValueNotifier<AttachmentTraceEvent?>(null);

  final ValueNotifier<Map<String, int>> attachmentReasonCounters =
      ValueNotifier<Map<String, int>>(const <String, int>{});

  final List<AttachmentTraceEvent> _attachmentTraces = <AttachmentTraceEvent>[];
  static const int _maxAttachmentTraces = 120;

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

  List<AttachmentTraceEvent> recentAttachmentTraces({int limit = 60}) {
    final safe = limit <= 0 ? _attachmentTraces.length : limit;
    final start = _attachmentTraces.length - safe;
    final idx = start < 0 ? 0 : start;
    return _attachmentTraces.sublist(idx);
  }

  void recordAttachmentTrace({
    required String operationId,
    required String cellId,
    required String attachmentType,
    required String source,
    required AttachmentPipelineStep step,
    required bool ok,
    required int elapsedMs,
    String? reason,
    String? techDetail,
    String? stack,
  }) {
    final event = AttachmentTraceEvent(
      operationId: operationId,
      cellId: cellId.trim().isEmpty ? 'n/a' : cellId.trim(),
      attachmentType:
          attachmentType.trim().isEmpty ? 'unknown' : attachmentType.trim(),
      source: source.trim().isEmpty ? 'unknown' : source.trim(),
      step: step,
      ok: ok,
      elapsedMs: elapsedMs < 0 ? 0 : elapsedMs,
      at: DateTime.now(),
      reason: (reason ?? '').trim().isEmpty ? null : reason!.trim(),
      techDetail: (techDetail ?? '').trim().isEmpty ? null : techDetail!.trim(),
      stack: (stack ?? '').trim().isEmpty ? null : stack!.trim(),
    );

    _attachmentTraces.add(event);
    if (_attachmentTraces.length > _maxAttachmentTraces) {
      _attachmentTraces.removeRange(
        0,
        _attachmentTraces.length - _maxAttachmentTraces,
      );
    }

    if (!event.ok && (event.reason ?? '').trim().isNotEmpty) {
      final next = Map<String, int>.from(attachmentReasonCounters.value);
      final key = event.reason!.trim();
      next[key] = (next[key] ?? 0) + 1;
      final ordered = Map<String, int>.fromEntries(
        next.entries.toList(growable: false)
          ..sort((a, b) => a.key.compareTo(b.key)),
      );
      attachmentReasonCounters.value = ordered;
    }

    lastAttachmentTrace.value = event;
  }

  @visibleForTesting
  void debugResetAttachmentTraces() {
    _attachmentTraces.clear();
    attachmentReasonCounters.value = const <String, int>{};
    lastAttachmentTrace.value = null;
  }
}
