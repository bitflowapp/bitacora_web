part of 'editor_screen.dart';

// ============================== Constantes globales ========================

const int kDefaultCols = 15; // 14 + Photos
const String kPhotosHeader = 'Photos';
const String kPhotosColId = 'col_photos';
const double _kMobileQuickBarH = 62.0;
const int _kMaxPhotosPerCell = 6;
const int _kMaxPhotosBytesPerCell = 25 * 1024 * 1024;
const int _kStableIdRandomMaxExclusive = 0x100000000; // 2^32
const bool _kDebugEditorPerfInstrumentation = bool.fromEnvironment(
  'BITFLOW_DEBUG_EDITOR_PERF',
  defaultValue: false,
);
const bool _kDebugGridBuildCounter = bool.fromEnvironment(
  'BITFLOW_DEBUG_GRID_REBUILDS',
  defaultValue: false,
);
const bool _kFlutterTestEnv = bool.fromEnvironment('FLUTTER_TEST');
const bool _kEnableEditorPerfInstrumentation =
    _kDebugEditorPerfInstrumentation || _kDebugGridBuildCounter;

// Persistencia segura: NO guardar thumbs base64 en prefs/localStorage.
const bool _kPersistPhotoThumbs = true;
const String _kPrefEngineApiKey = 'bitflow.engine_api_key';
const String _kPrefEngineApiKeyAlt = 'bitflow_engine_api_key';
const String _kPrefCameraRationaleSeen =
    'bitflow.permission_rationale.camera.v1';
const String _kPrefMicrophoneRationaleSeen =
    'bitflow.permission_rationale.microphone.v1';
const String _kPrefQuickCaptureQueue = 'bitflow.quick_capture_queue.v1';
const String _kPrefEditorTourSeen = 'bitflow.editor.tour_seen.v1';
const String _kPrefEditorTourDismissed = 'bitflow.editor.tour_dismissed.v1';
const String _kPrefSmartPasteInteracted =
    'bitflow.editor.smart_paste_interacted.v1';
const String _kPrefTemplateInteracted = 'bitflow.editor.template_interacted.v1';
const String _kPrefAndroidInstallHelperDismissed =
    'bitflow.editor.android_install_helper_dismissed.v1';
const String _kPrefExportPreset = 'bitflow.editor.export_preset.v1';
const String _kPrefColumnTemplates = 'bitflow.editor.column_templates.v1';
const String _kPrefSavedViews = 'bitflow.editor.saved_views.v1';
const String _kPrefHistoryLog = 'bitflow.editor.history_log.v1';
const String _kPrefFlowBotUseLocalLlm =
    'bitflow.editor.flowbot.use_local_llm.v1';
const String _kPrefFlowBotLocalModelPath =
    'bitflow.editor.flowbot.local_model_path.v1';
const String _kPrefFlowBotHistory = 'bitflow.editor.flowbot.history.v1';
const String _kPrefFlowBotLastScope = 'bitflow.editor.flowbot.last_scope.v1';
const String _kPrefFlowBotMacros = 'bitflow.editor.flowbot.macros.v1';
const String _kPrefMobileCompactMode = 'bitflow.editor.mobile_compact_mode.v1';
const String _kPrefZenMode = 'bitflow.editor.zen_mode.v1';
const String _kPrefMobileFocusCellMode =
    'bitflow.editor.mobile_focus_cell_mode.v1';
const String _kPrefFieldMode = 'bitflow.editor.field_mode.v1';

// ============================== Enums ======================================

enum _OverlayMove { none, next, prev, down, up }

enum _ReviewFilterMode { all, pending, reviewed }

enum _HistoryFilterWindow { all, today, week }

enum _GridDensity { compact, normal, roomy }

enum _MobileEditPhase { closed, opening, open, switching, closing }

enum _GpsWriteMode { pasteActive, pickTarget, metadataOnly }

// ============================== Helper types ================================

class _CellTarget {
  const _CellTarget(this.row, this.col);
  final int row;
  final int col;
}

class _EditorLongOperationState {
  const _EditorLongOperationState({
    required this.message,
    required this.cancellable,
    this.cancelRequested = false,
  });

  final String message;
  final bool cancellable;
  final bool cancelRequested;

  _EditorLongOperationState copyWith({
    String? message,
    bool? cancellable,
    bool? cancelRequested,
  }) {
    return _EditorLongOperationState(
      message: message ?? this.message,
      cancellable: cancellable ?? this.cancellable,
      cancelRequested: cancelRequested ?? this.cancelRequested,
    );
  }
}

class _EditorLongOperationCancelled implements Exception {
  const _EditorLongOperationCancelled();
}

typedef _DebugSaveImageHook = Future<AttachmentSaveResult?> Function({
  required CellRef cellRef,
  required String attachmentId,
  required Uint8List bytes,
  required String originalName,
  required String mime,
  Object? webFile,
});

typedef _DebugAttachmentTraceHook = void Function(AttachmentTraceEvent trace);
