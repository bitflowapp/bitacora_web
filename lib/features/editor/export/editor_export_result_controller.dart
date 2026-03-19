import 'package:flutter/material.dart';

import 'package:bitacora_web/features/editor/export/editor_export_result_mapper.dart';
import 'package:bitacora_web/features/editor/export/editor_export_result_models.dart';

typedef EditorExportCloseoutStateChanged = void Function(
  EditorExportCloseoutState? state,
);
typedef EditorExportCloseoutFeedback = void Function(
  String message, {
  required bool isError,
  IconData? icon,
});
typedef EditorExportCloseoutRetry = Future<void> Function({
  required String format,
  required bool includeAttachments,
  required bool share,
});
typedef EditorExportCloseoutOpenPath = Future<bool> Function(String path);
typedef EditorExportCloseoutCloseEditor = Future<void> Function();
typedef EditorExportCloseoutCapabilitiesResolver
    = EditorExportResultCapabilities Function(EditorExportOutcome outcome);
typedef EditorExportCloseoutAuditSink = void Function(
  EditorExportCloseoutAuditEvent event,
);

class EditorExportResultController {
  EditorExportResultController({
    required EditorExportResultMapper mapper,
    required EditorExportCloseoutStateChanged onStateChanged,
    required EditorExportCloseoutFeedback showFeedback,
    required EditorExportCloseoutRetry retryExport,
    required EditorExportCloseoutOpenPath openExternalPath,
    required EditorExportCloseoutCloseEditor closeEditor,
    required EditorExportCloseoutCapabilitiesResolver resolveCapabilities,
    EditorExportCloseoutAuditSink? onAuditEvent,
  })  : _mapper = mapper,
        _onStateChanged = onStateChanged,
        _showFeedback = showFeedback,
        _retryExport = retryExport,
        _openExternalPath = openExternalPath,
        _closeEditor = closeEditor,
        _resolveCapabilities = resolveCapabilities,
        _onAuditEvent = onAuditEvent;

  final EditorExportResultMapper _mapper;
  final EditorExportCloseoutStateChanged _onStateChanged;
  final EditorExportCloseoutFeedback _showFeedback;
  final EditorExportCloseoutRetry _retryExport;
  final EditorExportCloseoutOpenPath _openExternalPath;
  final EditorExportCloseoutCloseEditor _closeEditor;
  final EditorExportCloseoutCapabilitiesResolver _resolveCapabilities;
  final EditorExportCloseoutAuditSink? _onAuditEvent;

  EditorExportCloseoutState? _state;
  EditorExportCloseoutOrigin? _lastOrigin;

  EditorExportCloseoutState? get state => _state;

  void publishExportOutcome(
    EditorExportOutcome outcome, {
    bool showSnack = true,
  }) {
    publishCloseoutOutcome(
      origin: EditorExportCloseoutOrigin.export,
      outcome: outcome,
      showSnack: showSnack,
    );
  }

  void publishAttachmentOutcome(
    EditorExportOutcome outcome, {
    bool showSnack = true,
  }) {
    publishCloseoutOutcome(
      origin: EditorExportCloseoutOrigin.attachment,
      outcome: outcome,
      showSnack: showSnack,
    );
  }

  void publishCloseoutOutcome({
    required EditorExportCloseoutOrigin origin,
    required EditorExportOutcome outcome,
    bool showSnack = true,
  }) {
    final nextState = _mapper.map(
      outcome,
      capabilities: _resolveCapabilities(outcome),
    );
    _lastOrigin = origin;
    _state = nextState;
    _onStateChanged(nextState);
    _onAuditEvent?.call(
      EditorExportCloseoutAuditEvent.publish(
        origin: origin,
        outcomeKind: outcome.kind,
        showSnack: showSnack,
      ),
    );
    if (!showSnack) return;
    _showFeedback(
      nextState.banner.message,
      isError: nextState.banner.isError,
      icon: nextState.banner.icon,
    );
  }

  void dismissCloseout({
    EditorExportCloseoutDismissReason reason =
        EditorExportCloseoutDismissReason.user,
  }) {
    if (_state == null) return;
    _onAuditEvent?.call(
      EditorExportCloseoutAuditEvent.dismiss(
        origin: _lastOrigin,
        outcomeKind: _state?.outcome.kind,
        dismissReason: reason,
      ),
    );
    _state = null;
    _lastOrigin = null;
    _onStateChanged(null);
  }

  Future<void> handleAction(EditorExportResultAction action) async {
    final currentState = _state;
    if (currentState == null) return;
    final outcome = currentState.outcome;
    switch (action) {
      case EditorExportResultAction.openFile:
        await _openPath(
          path: outcome.savedPath,
          failureMessage: 'No pudimos abrir el archivo guardado.',
        );
        return;
      case EditorExportResultAction.openLocation:
        final folder = parentDirectoryFromPath(outcome.savedPath);
        await _openPath(
          path: folder,
          failureMessage: 'No pudimos abrir la carpeta del archivo.',
        );
        return;
      case EditorExportResultAction.retryCurrent:
        dismissCloseout(
          reason: EditorExportCloseoutDismissReason.retryCurrent,
        );
        await _retryExport(
          format: outcome.format,
          includeAttachments: outcome.includeAttachments,
          share: outcome.shareRequested,
        );
        return;
      case EditorExportResultAction.retryShare:
        dismissCloseout(
          reason: EditorExportCloseoutDismissReason.retryShare,
        );
        await _retryExport(
          format: outcome.format,
          includeAttachments: outcome.includeAttachments,
          share: true,
        );
        return;
      case EditorExportResultAction.continueEditing:
        dismissCloseout(
          reason: EditorExportCloseoutDismissReason.continueEditing,
        );
        return;
      case EditorExportResultAction.closeEditor:
        dismissCloseout(
          reason: EditorExportCloseoutDismissReason.closeEditor,
        );
        await _closeEditor();
        return;
    }
  }

  static Uri fileUriFromPath(String path) {
    return Uri.file(path, windows: path.contains('\\'));
  }

  static String? parentDirectoryFromPath(String? path) {
    final trimmed = (path ?? '').trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.replaceAll('\\', '/');
    final slashIndex = normalized.lastIndexOf('/');
    if (slashIndex <= 0) return null;
    final folder = normalized.substring(0, slashIndex);
    return trimmed.contains('\\') ? folder.replaceAll('/', '\\') : folder;
  }

  Future<void> _openPath({
    required String? path,
    required String failureMessage,
  }) async {
    final trimmed = (path ?? '').trim();
    if (trimmed.isEmpty) return;
    try {
      final ok = await _openExternalPath(trimmed);
      if (!ok) {
        _showPathOpenError(failureMessage);
      }
    } catch (_) {
      _showPathOpenError(failureMessage);
    }
  }

  void _showPathOpenError(String message) {
    _showFeedback(
      message,
      isError: true,
      icon: Icons.folder_off_rounded,
    );
  }
}
