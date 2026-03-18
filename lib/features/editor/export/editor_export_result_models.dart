import 'package:flutter/material.dart';

enum EditorExportOutcomeKind {
  saved,
  downloadStarted,
  shareOpened,
  systemSheetOpened,
  cancelled,
  error,
  unsupported,
}

enum EditorExportResultAction {
  openFile,
  openLocation,
  retryCurrent,
  retryShare,
  continueEditing,
  closeEditor,
}

enum EditorExportResultTone { neutral, error }

@immutable
class EditorExportOutcome {
  const EditorExportOutcome({
    required this.kind,
    required this.fileName,
    required this.format,
    required this.message,
    required this.shareRequested,
    required this.includeAttachments,
    this.savedPath,
  });

  final EditorExportOutcomeKind kind;
  final String fileName;
  final String format;
  final String message;
  final String? savedPath;
  final bool shareRequested;
  final bool includeAttachments;

  bool get hasSavedPath => (savedPath ?? '').trim().isNotEmpty;

  bool get isError =>
      kind == EditorExportOutcomeKind.error ||
      kind == EditorExportOutcomeKind.unsupported;
}

@immutable
class EditorExportResultCapabilities {
  const EditorExportResultCapabilities({
    this.canOpenFile = false,
    this.canOpenLocation = false,
  });

  static const none = EditorExportResultCapabilities();

  final bool canOpenFile;
  final bool canOpenLocation;
}

@immutable
class EditorExportResultBannerActionModel {
  const EditorExportResultBannerActionModel({
    required this.action,
    required this.label,
  });

  final EditorExportResultAction action;
  final String label;
}

@immutable
class EditorExportResultBannerModel {
  const EditorExportResultBannerModel({
    required this.title,
    required this.formatLabel,
    required this.icon,
    required this.tone,
    required this.fileName,
    required this.message,
    required this.actions,
    this.savedPath,
  });

  final String title;
  final String formatLabel;
  final IconData icon;
  final EditorExportResultTone tone;
  final String fileName;
  final String message;
  final String? savedPath;
  final List<EditorExportResultBannerActionModel> actions;

  bool get isError => tone == EditorExportResultTone.error;

  bool get isRecoverable => actions.any(
        (action) =>
            action.action == EditorExportResultAction.retryCurrent ||
            action.action == EditorExportResultAction.retryShare,
      );
}

@immutable
class EditorExportCloseoutState {
  const EditorExportCloseoutState({
    required this.outcome,
    required this.banner,
  });

  final EditorExportOutcome outcome;
  final EditorExportResultBannerModel banner;
}
