part of 'editor_screen.dart';

// ============================== Constantes globales ========================

const int kDefaultCols = 15; // 14 + Foto / Evidencia
const String kPhotosHeader = 'Foto / Evidencia';
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

class _RowEvidenceItem {
  const _RowEvidenceItem({
    required this.refKey,
    required this.cellLabel,
    required this.kind,
    required this.title,
    required this.timestamp,
    required this.storedRef,
  });

  final String refKey;
  final String cellLabel;
  final String kind;
  final String title;
  final DateTime timestamp;
  final String storedRef;
}

String _reviewStateLabel(String raw) {
  switch (_normalizeReviewState(raw)) {
    case 'observada':
      return 'Observada';
    case 'corregida':
      return 'Corregida';
    case 'aprobada':
      return 'Aprobada';
    case 'sin_revision':
    default:
      return 'Sin revision';
  }
}

class _ReviewStatePill extends StatelessWidget {
  const _ReviewStatePill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final colors = _reviewStateColorsForAppTheme(t, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Text(
        _reviewStateLabel(status),
        style: TextStyle(
          color: colors.fg,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

({Color bg, Color border, Color fg}) _reviewStateColorsForAppTheme(
  AppThemeData theme,
  String reviewState,
) {
  switch (_normalizeReviewState(reviewState)) {
    case 'observada':
      return (
        bg: theme.colors.accentMuted,
        border: theme.colors.accent.withValues(alpha: 0.28),
        fg: theme.colors.accent,
      );
    case 'corregida':
      return (
        bg: theme.colors.warningBg,
        border: theme.colors.warningFg.withValues(alpha: 0.30),
        fg: theme.colors.warningFg,
      );
    case 'aprobada':
      return (
        bg: theme.colors.successBg,
        border: theme.colors.successFg.withValues(alpha: 0.24),
        fg: theme.colors.successFg,
      );
    case 'sin_revision':
    default:
      return (
        bg: theme.colors.surfaceMuted,
        border: theme.colors.border,
        fg: theme.colors.textSecondary,
      );
  }
}

class _ReviewMetaLine extends StatelessWidget {
  const _ReviewMetaLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
            child: Text(
              label,
              style: t.text.bodyMedium?.copyWith(
                color: t.colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: t.text.bodyMedium?.copyWith(
                color: t.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
