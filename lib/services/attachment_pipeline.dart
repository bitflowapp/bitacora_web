import 'dart:async';

import 'package:flutter/foundation.dart';

import 'diagnostics_log.dart';
import 'web_attachment_capabilities.dart';

enum AttachmentKind { photo, video, audio, doc, location }

enum AttachmentSource { capture, gallery, files, record }

enum AttachmentFailureReason {
  storageBlocked,
  quota,
  unsupportedFormat,
  gestureBlocked,
  decoderFailed,
  permissionDenied,
  userCancel,
  micDenied,
  micUnsupported,
  unknown,
}

extension AttachmentFailureReasonCode on AttachmentFailureReason {
  String get code {
    switch (this) {
      case AttachmentFailureReason.storageBlocked:
        return 'storage_blocked';
      case AttachmentFailureReason.quota:
        return 'quota';
      case AttachmentFailureReason.unsupportedFormat:
        return 'unsupported_format';
      case AttachmentFailureReason.gestureBlocked:
        return 'gesture_blocked';
      case AttachmentFailureReason.decoderFailed:
        return 'decoder_failed';
      case AttachmentFailureReason.permissionDenied:
        return 'permission_denied';
      case AttachmentFailureReason.userCancel:
        return 'user_cancel';
      case AttachmentFailureReason.micDenied:
        return 'mic_denied';
      case AttachmentFailureReason.micUnsupported:
        return 'mic_unsupported';
      case AttachmentFailureReason.unknown:
        return 'unknown';
    }
  }

  String userMessage(AttachmentKind kind) {
    switch (this) {
      case AttachmentFailureReason.storageBlocked:
        return 'No se pudo guardar el adjunto por storage bloqueado.';
      case AttachmentFailureReason.quota:
        return 'No hay espacio disponible para guardar el adjunto.';
      case AttachmentFailureReason.unsupportedFormat:
        return 'El formato del adjunto no es compatible.';
      case AttachmentFailureReason.gestureBlocked:
        return 'El navegador bloqueó la acción por gesto inválido.';
      case AttachmentFailureReason.decoderFailed:
        return kind == AttachmentKind.photo
            ? 'No se pudo procesar la imagen, pero se guardo el original.'
            : 'No se pudo procesar la vista previa del adjunto.';
      case AttachmentFailureReason.permissionDenied:
        return 'Permiso denegado para acceder a cámara/micrófono/archivos.';
      case AttachmentFailureReason.userCancel:
        return 'Operación cancelada por el usuario.';
      case AttachmentFailureReason.micDenied:
        return 'Permiso de microfono denegado.';
      case AttachmentFailureReason.micUnsupported:
        return 'Grabacion no disponible en este navegador.';
      case AttachmentFailureReason.unknown:
        return 'No se pudo completar el adjunto.';
    }
  }
}

class AttachmentClassifiedError implements Exception {
  const AttachmentClassifiedError({
    required this.reason,
    required this.userMessage,
    required this.technicalDetail,
    required this.operationId,
    required this.step,
    this.stackTrace,
  });

  final AttachmentFailureReason reason;
  final String userMessage;
  final String technicalDetail;
  final String operationId;
  final AttachmentPipelineStep step;
  final StackTrace? stackTrace;

  String get code => reason.code;

  @override
  String toString() => 'AttachmentClassifiedError($code): $technicalDetail';
}

class AttachmentPipelineSuccess<T> {
  const AttachmentPipelineSuccess({
    required this.operationId,
    required this.storedRef,
    required this.value,
    this.capabilitySnapshot,
  });

  final String operationId;
  final String storedRef;
  final T value;
  final WebAttachmentCapabilitiesSnapshot? capabilitySnapshot;
}

class AttachmentPipelineFailure {
  const AttachmentPipelineFailure({
    required this.operationId,
    required this.error,
    this.capabilitySnapshot,
  });

  final String operationId;
  final AttachmentClassifiedError error;
  final WebAttachmentCapabilitiesSnapshot? capabilitySnapshot;
}

class AttachmentPipelineResult<T> {
  const AttachmentPipelineResult._({
    required this.operationId,
    this.success,
    this.failure,
  });

  final String operationId;
  final AttachmentPipelineSuccess<T>? success;
  final AttachmentPipelineFailure? failure;

  bool get ok => success != null;

  static AttachmentPipelineResult<T> succeed<T>({
    required String operationId,
    required AttachmentPipelineSuccess<T> success,
  }) {
    return AttachmentPipelineResult<T>._(
      operationId: operationId,
      success: success,
    );
  }

  static AttachmentPipelineResult<T> fail<T>({
    required String operationId,
    required AttachmentPipelineFailure failure,
  }) {
    return AttachmentPipelineResult<T>._(
      operationId: operationId,
      failure: failure,
    );
  }
}

typedef AttachmentPipelineDebugHook = void Function(AttachmentTraceEvent trace);

class AttachmentPipelineRequest<T> {
  AttachmentPipelineRequest({
    required this.kind,
    required this.source,
    required this.cellRef,
    required this.pick,
    required this.persist,
    required this.bindToCell,
    this.normalize,
    this.preview,
    this.captureCapabilities = true,
    this.isCancelled,
  });

  final AttachmentKind kind;
  final AttachmentSource source;
  final String cellRef;
  final FutureOr<T> Function() pick;
  final FutureOr<T> Function(T value)? normalize;
  final FutureOr<String> Function(T value) persist;
  final FutureOr<void> Function(T value, String storedRef) bindToCell;
  final FutureOr<void> Function(T value, String storedRef)? preview;
  final bool captureCapabilities;
  final bool Function()? isCancelled;
}

class AttachmentPipeline {
  AttachmentPipeline({
    WebAttachmentCapabilities? capabilities,
    this.debugHook,
  }) : _capabilities = capabilities ?? WebAttachmentCapabilities.I;

  final WebAttachmentCapabilities _capabilities;
  final AttachmentPipelineDebugHook? debugHook;

  static AttachmentPipeline I = AttachmentPipeline();

  Future<AttachmentPipelineResult<T>> run<T>(
    AttachmentPipelineRequest<T> request,
  ) async {
    final startedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();
    final operationId = _operationId(request.kind);
    WebAttachmentCapabilitiesSnapshot? snapshot;

    void trace(
      AttachmentPipelineStep step, {
      required bool ok,
      String? reason,
      String? detail,
      StackTrace? stack,
    }) {
      final elapsed = stopwatch.elapsedMilliseconds;
      DiagnosticsLog.I.recordAttachmentTrace(
        operationId: operationId,
        cellId: request.cellRef,
        attachmentType: request.kind.name,
        source: request.source.name,
        step: step,
        ok: ok,
        elapsedMs: elapsed,
        reason: reason,
        techDetail: detail,
        stack: stack?.toString(),
      );
      final last = DiagnosticsLog.I.lastAttachmentTrace.value;
      if (last != null) {
        final hook = debugHook;
        if (hook != null) {
          assert(() {
            hook(last);
            return true;
          }());
        }
      }
    }

    bool cancelled() => request.isCancelled?.call() == true;

    AttachmentClassifiedError makeError(
      Object error, {
      required AttachmentPipelineStep step,
      StackTrace? stackTrace,
    }) {
      final classified = _classifyError(
        error.toString(),
        kind: request.kind,
        step: step,
      );
      return AttachmentClassifiedError(
        reason: classified.reason,
        userMessage: classified.reason.userMessage(request.kind),
        technicalDetail: error.toString().trim(),
        operationId: operationId,
        step: step,
        stackTrace: stackTrace,
      );
    }

    if (cancelled()) {
      final err = AttachmentClassifiedError(
        reason: AttachmentFailureReason.userCancel,
        userMessage:
            AttachmentFailureReason.userCancel.userMessage(request.kind),
        technicalDetail: 'cancelled_before_start',
        operationId: operationId,
        step: AttachmentPipelineStep.capability,
      );
      trace(
        AttachmentPipelineStep.capability,
        ok: false,
        reason: err.code,
        detail: err.technicalDetail,
      );
      return AttachmentPipelineResult.fail<T>(
        operationId: operationId,
        failure: AttachmentPipelineFailure(
          operationId: operationId,
          error: err,
        ),
      );
    }

    if (request.captureCapabilities && kIsWeb) {
      try {
        snapshot = await _capabilities.snapshot();
        trace(AttachmentPipelineStep.capability, ok: true);
      } catch (error, stackTrace) {
        final classified = makeError(
          error,
          step: AttachmentPipelineStep.capability,
          stackTrace: stackTrace,
        );
        trace(
          AttachmentPipelineStep.capability,
          ok: false,
          reason: classified.code,
          detail: classified.technicalDetail,
          stack: stackTrace,
        );
        return AttachmentPipelineResult.fail<T>(
          operationId: operationId,
          failure: AttachmentPipelineFailure(
            operationId: operationId,
            error: classified,
            capabilitySnapshot: snapshot,
          ),
        );
      }
    } else {
      trace(AttachmentPipelineStep.capability, ok: true);
    }

    try {
      if (cancelled()) {
        throw const _CancelledByCaller();
      }

      trace(AttachmentPipelineStep.pick, ok: true);
      final picked = await request.pick();

      if (cancelled()) {
        throw const _CancelledByCaller();
      }

      T normalized = picked;
      final normalize = request.normalize;
      if (normalize != null) {
        try {
          normalized = await normalize(picked);
          trace(AttachmentPipelineStep.normalize, ok: true);
        } catch (error, stackTrace) {
          final classified = _classifyError(
            error.toString(),
            kind: request.kind,
            step: AttachmentPipelineStep.normalize,
          );
          if (classified.reason == AttachmentFailureReason.decoderFailed &&
              request.kind == AttachmentKind.photo) {
            // Resiliencia obligatoria: si falla normalizacion/thumbnail, seguimos.
            normalized = picked;
            trace(
              AttachmentPipelineStep.normalize,
              ok: false,
              reason: classified.reason.code,
              detail: error.toString(),
              stack: stackTrace,
            );
          } else {
            final out = AttachmentClassifiedError(
              reason: classified.reason,
              userMessage: classified.reason.userMessage(request.kind),
              technicalDetail: error.toString().trim(),
              operationId: operationId,
              step: AttachmentPipelineStep.normalize,
              stackTrace: stackTrace,
            );
            trace(
              AttachmentPipelineStep.normalize,
              ok: false,
              reason: out.code,
              detail: out.technicalDetail,
              stack: stackTrace,
            );
            return AttachmentPipelineResult.fail<T>(
              operationId: operationId,
              failure: AttachmentPipelineFailure(
                operationId: operationId,
                error: out,
                capabilitySnapshot: snapshot,
              ),
            );
          }
        }
      } else {
        trace(AttachmentPipelineStep.normalize, ok: true);
      }

      if (cancelled()) {
        throw const _CancelledByCaller();
      }

      String storedRef;
      try {
        storedRef = await request.persist(normalized);
        if (storedRef.trim().isEmpty) {
          throw Exception('storage_blocked: empty_stored_ref');
        }
        trace(AttachmentPipelineStep.persist, ok: true);
      } catch (error, stackTrace) {
        final out = makeError(
          error,
          step: AttachmentPipelineStep.persist,
          stackTrace: stackTrace,
        );
        trace(
          AttachmentPipelineStep.persist,
          ok: false,
          reason: out.code,
          detail: out.technicalDetail,
          stack: stackTrace,
        );
        return AttachmentPipelineResult.fail<T>(
          operationId: operationId,
          failure: AttachmentPipelineFailure(
            operationId: operationId,
            error: out,
            capabilitySnapshot: snapshot,
          ),
        );
      }

      if (cancelled()) {
        throw const _CancelledByCaller();
      }

      try {
        await request.bindToCell(normalized, storedRef);
        trace(AttachmentPipelineStep.bind, ok: true);
      } catch (error, stackTrace) {
        final out = makeError(
          error,
          step: AttachmentPipelineStep.bind,
          stackTrace: stackTrace,
        );
        trace(
          AttachmentPipelineStep.bind,
          ok: false,
          reason: out.code,
          detail: out.technicalDetail,
          stack: stackTrace,
        );
        return AttachmentPipelineResult.fail<T>(
          operationId: operationId,
          failure: AttachmentPipelineFailure(
            operationId: operationId,
            error: out,
            capabilitySnapshot: snapshot,
          ),
        );
      }

      final preview = request.preview;
      if (preview != null) {
        try {
          await preview(normalized, storedRef);
          trace(AttachmentPipelineStep.preview, ok: true);
        } catch (error, stackTrace) {
          final classified = _classifyError(
            error.toString(),
            kind: request.kind,
            step: AttachmentPipelineStep.preview,
          );
          trace(
            AttachmentPipelineStep.preview,
            ok: false,
            reason: classified.reason.code,
            detail: error.toString(),
            stack: stackTrace,
          );
        }
      } else {
        trace(AttachmentPipelineStep.preview, ok: true);
      }

      final success = AttachmentPipelineSuccess<T>(
        operationId: operationId,
        storedRef: storedRef,
        value: normalized,
        capabilitySnapshot: snapshot,
      );
      return AttachmentPipelineResult.succeed<T>(
        operationId: operationId,
        success: success,
      );
    } on _CancelledByCaller {
      final err = AttachmentClassifiedError(
        reason: AttachmentFailureReason.userCancel,
        userMessage:
            AttachmentFailureReason.userCancel.userMessage(request.kind),
        technicalDetail:
            'cancelled_after_${stopwatch.elapsedMilliseconds}ms started_at=${startedAt.toIso8601String()}',
        operationId: operationId,
        step: AttachmentPipelineStep.pick,
      );
      trace(
        AttachmentPipelineStep.pick,
        ok: false,
        reason: err.code,
        detail: err.technicalDetail,
      );
      return AttachmentPipelineResult.fail<T>(
        operationId: operationId,
        failure: AttachmentPipelineFailure(
          operationId: operationId,
          error: err,
          capabilitySnapshot: snapshot,
        ),
      );
    } catch (error, stackTrace) {
      final out = makeError(
        error,
        step: AttachmentPipelineStep.pick,
        stackTrace: stackTrace,
      );
      trace(
        AttachmentPipelineStep.pick,
        ok: false,
        reason: out.code,
        detail: out.technicalDetail,
        stack: stackTrace,
      );
      return AttachmentPipelineResult.fail<T>(
        operationId: operationId,
        failure: AttachmentPipelineFailure(
          operationId: operationId,
          error: out,
          capabilitySnapshot: snapshot,
        ),
      );
    } finally {
      stopwatch.stop();
    }
  }

  _ClassifyResult _classifyError(
    String raw, {
    required AttachmentKind kind,
    required AttachmentPipelineStep step,
  }) {
    final lower = raw.toLowerCase();

    if (_containsAny(lower, const <String>[
      'cancelled',
      'canceled',
      'cancelado',
      'picker_closed',
      'sheet_closed',
      '_cancelled_by_caller',
    ])) {
      return const _ClassifyResult(AttachmentFailureReason.userCancel);
    }
    if (_containsAny(lower, const <String>[
      'gesture',
      'user activation',
      'must be handling a user gesture',
      'not allowed by user gesture',
    ])) {
      return const _ClassifyResult(AttachmentFailureReason.gestureBlocked);
    }
    if (_containsAny(lower, const <String>[
      'permission',
      'denied',
      'notallowed',
      'securityerror',
      'forbidden',
    ])) {
      if (_containsAny(lower, const <String>['mic_denied'])) {
        return const _ClassifyResult(AttachmentFailureReason.micDenied);
      }
      return const _ClassifyResult(AttachmentFailureReason.permissionDenied);
    }
    if (_containsAny(lower, const <String>[
      'mic_unsupported',
      'media recorder unavailable',
      'media_recorder',
      'not supported',
      'notsupported',
    ])) {
      return const _ClassifyResult(AttachmentFailureReason.micUnsupported);
    }
    if (_containsAny(lower, const <String>[
      'quota',
      'quotaexceeded',
      'not enough space',
      'insufficient storage',
    ])) {
      return const _ClassifyResult(AttachmentFailureReason.quota);
    }
    if (_containsAny(lower, const <String>[
      'storage_blocked',
      'indexeddb',
      'cache api failed',
      'cache_storage_failed',
      'empty_stored_ref',
      'storage',
    ])) {
      return const _ClassifyResult(AttachmentFailureReason.storageBlocked);
    }
    if (_containsAny(lower, const <String>[
      'decode',
      'heic',
      'heif',
      'toblob failed',
      'decoder_failed',
      'unsupported image',
      'thumbnail',
    ])) {
      return const _ClassifyResult(AttachmentFailureReason.decoderFailed);
    }
    if (_containsAny(lower, const <String>[
      'mime',
      'unsupported format',
      'invalid container',
      'codec',
      'file type',
    ])) {
      return const _ClassifyResult(AttachmentFailureReason.unsupportedFormat);
    }

    if (kind == AttachmentKind.photo &&
        step == AttachmentPipelineStep.normalize) {
      return const _ClassifyResult(AttachmentFailureReason.decoderFailed);
    }
    return const _ClassifyResult(AttachmentFailureReason.unknown);
  }

  bool _containsAny(String value, List<String> needles) {
    for (final needle in needles) {
      if (value.contains(needle)) return true;
    }
    return false;
  }

  String _operationId(AttachmentKind kind) {
    final micros = DateTime.now().microsecondsSinceEpoch;
    return '${kind.name}_$micros';
  }
}

class _ClassifyResult {
  const _ClassifyResult(this.reason);
  final AttachmentFailureReason reason;
}

class _CancelledByCaller implements Exception {
  const _CancelledByCaller();
}
