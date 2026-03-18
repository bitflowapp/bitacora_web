import 'package:flutter/material.dart';

import 'package:bitacora_web/features/editor/export/editor_export_result_models.dart';

enum _ExportMessageKind { pdf, zip, xlsx, other }

class EditorExportOutcomeFactory {
  const EditorExportOutcomeFactory._();

  static String describeSaveLocation(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= 72) return trimmed;
    final parts = trimmed.split(RegExp(r'[\\/]'));
    if (parts.length < 2) return trimmed;
    return '.../${parts[parts.length - 2]}/${parts.last}';
  }

  static String shareFormatLabelFromFileName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.xlsx')) return 'XLSX';
    if (lower.endsWith('.pdf')) return 'PDF';
    if (lower.endsWith('.zip')) return 'paquete ZIP';
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'HTML';
    return 'archivo';
  }

  static String formatFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'pdf';
    if (lower.endsWith('.zip')) return 'zip';
    if (lower.endsWith('.xlsx')) return 'xlsx';
    return 'file';
  }

  static String formatLabel(String format) {
    switch (format) {
      case 'pdf':
        return 'PDF';
      case 'zip':
        return 'ZIP';
      case 'xlsx':
        return 'XLSX';
      default:
        return format.toUpperCase();
    }
  }

  static String cancelledMessage({required bool share}) {
    return share
        ? 'Compartir cancelado. No se envio ningun archivo.'
        : 'Exportacion cancelada. No se genero ningun archivo.';
  }

  static String failureMessage({
    required bool share,
    required String format,
  }) {
    final target = _targetLabel(format);
    if (share) {
      return 'No pudimos abrir compartir para $target. Intenta de nuevo o exporta el archivo.';
    }
    return 'No pudimos dejar listo $target. Intenta de nuevo.';
  }

  static String unsupportedMessage({
    required bool share,
    required String format,
  }) {
    final target = _targetLabel(format);
    if (share) {
      return 'Este dispositivo no permite compartir $target desde aqui. Exportalo primero.';
    }
    return 'Este dispositivo no permite generar $target desde aqui.';
  }

  static EditorExportOutcome saved({
    required String name,
    required bool shareRequested,
    required bool includeAttachments,
    String? savedPath,
  }) {
    final path = (savedPath ?? '').trim();
    final label = path.isEmpty ? name : describeSaveLocation(path);
    final message = shareRequested
        ? _shareFallbackSavedMessage(name: name, location: label)
        : _fileReadyMessage(label.isEmpty ? name : label, name: name);
    return EditorExportOutcome(
      kind: EditorExportOutcomeKind.saved,
      fileName: name,
      format: formatFromFileName(name),
      message: message,
      savedPath: path.isEmpty ? null : path,
      shareRequested: shareRequested,
      includeAttachments: includeAttachments,
    );
  }

  static EditorExportOutcome downloadStarted({
    required String name,
    required bool shareRequested,
    required bool includeAttachments,
    String? message,
  }) {
    final resolvedMessage = (message ?? '').trim().isEmpty
        ? _downloadStartedMessage(name)
        : message!.trim();
    return EditorExportOutcome(
      kind: EditorExportOutcomeKind.downloadStarted,
      fileName: name,
      format: formatFromFileName(name),
      message: resolvedMessage,
      shareRequested: shareRequested,
      includeAttachments: includeAttachments,
    );
  }

  static EditorExportOutcome shareOpened({
    required String name,
    required bool includeAttachments,
    String? message,
  }) {
    final resolvedMessage = (message ?? '').trim().isEmpty
        ? _shareOpenedMessage(name)
        : message!.trim();
    return EditorExportOutcome(
      kind: EditorExportOutcomeKind.shareOpened,
      fileName: name,
      format: formatFromFileName(name),
      message: resolvedMessage,
      shareRequested: true,
      includeAttachments: includeAttachments,
    );
  }

  static EditorExportOutcome systemSheetOpened({
    required String name,
    required bool includeAttachments,
  }) {
    return EditorExportOutcome(
      kind: EditorExportOutcomeKind.systemSheetOpened,
      fileName: name,
      format: formatFromFileName(name),
      message: _exportSheetOpenedMessage(name),
      shareRequested: false,
      includeAttachments: includeAttachments,
    );
  }

  static EditorExportOutcome cancelled({
    required String fileName,
    required String format,
    required bool shareRequested,
    required bool includeAttachments,
  }) {
    return EditorExportOutcome(
      kind: EditorExportOutcomeKind.cancelled,
      fileName: fileName,
      format: format,
      message: cancelledMessage(share: shareRequested),
      shareRequested: shareRequested,
      includeAttachments: includeAttachments,
    );
  }

  static EditorExportOutcome error({
    required String fileName,
    required String format,
    required bool shareRequested,
    required bool includeAttachments,
    required String message,
  }) {
    return EditorExportOutcome(
      kind: EditorExportOutcomeKind.error,
      fileName: fileName,
      format: format,
      message: message,
      shareRequested: shareRequested,
      includeAttachments: includeAttachments,
    );
  }

  static EditorExportOutcome unsupported({
    required String fileName,
    required String format,
    required bool shareRequested,
    required bool includeAttachments,
  }) {
    return EditorExportOutcome(
      kind: EditorExportOutcomeKind.unsupported,
      fileName: fileName,
      format: format,
      message: unsupportedMessage(share: shareRequested, format: format),
      shareRequested: shareRequested,
      includeAttachments: includeAttachments,
    );
  }

  static String _targetLabel(String format) {
    switch (format) {
      case 'pdf':
        return 'el PDF';
      case 'zip':
        return 'el paquete ZIP';
      case 'xlsx':
        return 'el Excel';
      default:
        return 'el archivo';
    }
  }

  static String _fileReadyMessage(String label, {required String name}) =>
      switch (_messageKind(name)) {
        _ExportMessageKind.pdf => 'PDF guardado en $label',
        _ExportMessageKind.zip =>
          'Paquete ZIP guardado en $label. Incluye planilla y evidencias.',
        _ExportMessageKind.xlsx => 'Excel guardado en $label',
        _ExportMessageKind.other => 'Archivo guardado en $label',
      };

  static String _downloadStartedMessage(String name) =>
      switch (_messageKind(name)) {
        _ExportMessageKind.pdf => 'Descarga iniciada: $name. Revisa Descargas.',
        _ExportMessageKind.zip =>
          'Descarga iniciada: $name. Revisa Descargas. Incluye planilla y evidencias.',
        _ExportMessageKind.xlsx =>
          'Descarga iniciada: $name. Revisa Descargas.',
        _ExportMessageKind.other =>
          'Descarga iniciada: $name. Revisa Descargas.',
      };

  static String _shareOpenedMessage(String name) =>
      'Abrimos compartir para $name. Completa el envio para terminar.';

  static String _exportSheetOpenedMessage(String name) {
    return 'Abrimos las opciones del sistema para guardar o compartir $name. Completa ese paso para terminar.';
  }

  static String _shareFallbackSavedMessage({
    required String name,
    String? location,
  }) {
    final target = (location ?? '').trim().isEmpty ? name : location!.trim();
    return 'No pudimos abrir compartir. Guardamos $name en $target.';
  }

  static _ExportMessageKind _messageKind(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return _ExportMessageKind.pdf;
    if (lower.endsWith('.zip')) return _ExportMessageKind.zip;
    if (lower.endsWith('.xlsx')) return _ExportMessageKind.xlsx;
    return _ExportMessageKind.other;
  }
}

class EditorExportResultMapper {
  const EditorExportResultMapper();

  EditorExportCloseoutState map(
    EditorExportOutcome outcome, {
    EditorExportResultCapabilities capabilities =
        EditorExportResultCapabilities.none,
  }) {
    final actions = _buildActions(outcome, capabilities);
    final bannerActions = actions
        .map(
          (action) => EditorExportResultBannerActionModel(
            action: action,
            label: _actionLabel(outcome, action),
          ),
        )
        .toList(growable: false);

    return EditorExportCloseoutState(
      outcome: outcome,
      banner: EditorExportResultBannerModel(
        title: _title(outcome.kind),
        formatLabel: EditorExportOutcomeFactory.formatLabel(outcome.format),
        icon: _icon(outcome.kind),
        tone: outcome.isError
            ? EditorExportResultTone.error
            : EditorExportResultTone.neutral,
        fileName: outcome.fileName,
        message: outcome.message,
        savedPath: outcome.savedPath,
        actions: bannerActions,
      ),
    );
  }

  List<EditorExportResultAction> _buildActions(
    EditorExportOutcome outcome,
    EditorExportResultCapabilities capabilities,
  ) {
    final actions = <EditorExportResultAction>[];
    switch (outcome.kind) {
      case EditorExportOutcomeKind.saved:
        if (capabilities.canOpenFile) {
          actions.add(EditorExportResultAction.openFile);
        }
        if (capabilities.canOpenLocation) {
          actions.add(EditorExportResultAction.openLocation);
        }
        if (outcome.shareRequested) {
          actions.add(EditorExportResultAction.retryShare);
        }
        actions.add(EditorExportResultAction.continueEditing);
        return actions;
      case EditorExportOutcomeKind.downloadStarted:
        actions.add(
          outcome.shareRequested
              ? EditorExportResultAction.retryShare
              : EditorExportResultAction.retryCurrent,
        );
        actions.add(EditorExportResultAction.continueEditing);
        return actions;
      case EditorExportOutcomeKind.shareOpened:
      case EditorExportOutcomeKind.systemSheetOpened:
        return const <EditorExportResultAction>[
          EditorExportResultAction.retryShare,
          EditorExportResultAction.continueEditing,
          EditorExportResultAction.closeEditor,
        ];
      case EditorExportOutcomeKind.cancelled:
      case EditorExportOutcomeKind.error:
        return const <EditorExportResultAction>[
          EditorExportResultAction.retryCurrent,
          EditorExportResultAction.continueEditing,
        ];
      case EditorExportOutcomeKind.unsupported:
        return const <EditorExportResultAction>[
          EditorExportResultAction.continueEditing,
        ];
    }
  }

  String _title(EditorExportOutcomeKind kind) {
    switch (kind) {
      case EditorExportOutcomeKind.saved:
        return 'Archivo guardado';
      case EditorExportOutcomeKind.downloadStarted:
        return 'Descarga iniciada';
      case EditorExportOutcomeKind.shareOpened:
        return 'Compartir abierto';
      case EditorExportOutcomeKind.systemSheetOpened:
        return 'Opciones del sistema abiertas';
      case EditorExportOutcomeKind.cancelled:
        return 'Salida cancelada';
      case EditorExportOutcomeKind.error:
        return 'Salida no completada';
      case EditorExportOutcomeKind.unsupported:
        return 'Salida no disponible';
    }
  }

  IconData _icon(EditorExportOutcomeKind kind) {
    switch (kind) {
      case EditorExportOutcomeKind.saved:
        return Icons.download_done_rounded;
      case EditorExportOutcomeKind.downloadStarted:
        return Icons.download_rounded;
      case EditorExportOutcomeKind.shareOpened:
        return Icons.ios_share_rounded;
      case EditorExportOutcomeKind.systemSheetOpened:
        return Icons.open_in_new_rounded;
      case EditorExportOutcomeKind.cancelled:
        return Icons.info_outline_rounded;
      case EditorExportOutcomeKind.error:
      case EditorExportOutcomeKind.unsupported:
        return Icons.error_outline_rounded;
    }
  }

  String _actionLabel(
    EditorExportOutcome outcome,
    EditorExportResultAction action,
  ) {
    switch (action) {
      case EditorExportResultAction.openFile:
        return 'Abrir archivo';
      case EditorExportResultAction.openLocation:
        return 'Ver carpeta';
      case EditorExportResultAction.retryCurrent:
        if (outcome.kind == EditorExportOutcomeKind.cancelled) {
          return outcome.shareRequested
              ? 'Compartir de nuevo'
              : 'Volver a exportar';
        }
        if (outcome.kind == EditorExportOutcomeKind.downloadStarted &&
            !outcome.shareRequested) {
          return 'Exportar otra vez';
        }
        return 'Reintentar';
      case EditorExportResultAction.retryShare:
        return outcome.kind == EditorExportOutcomeKind.systemSheetOpened &&
                !outcome.shareRequested
            ? 'Abrir compartir'
            : 'Compartir de nuevo';
      case EditorExportResultAction.continueEditing:
        return 'Seguir editando';
      case EditorExportResultAction.closeEditor:
        return 'Cerrar editor';
    }
  }
}
