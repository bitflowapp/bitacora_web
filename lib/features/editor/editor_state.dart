part of 'editor_screen.dart';

// ============================== Constantes globales ========================

const int kDefaultCols = 15; // 14 + Fotos
const String kPhotosHeader = 'Fotos';
const String kPhotosColId = 'col_photos';
const double _kMobileInlineCompactBarH = 68.0;
const double _kMinMobileGridVisiblePx = 200.0;
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

class EditorStorageFallbackReasonMapping {
  const EditorStorageFallbackReasonMapping({
    required this.storageVariant,
    required this.snackVariant,
  });

  final String storageVariant;
  final String snackVariant;
}

EditorStorageFallbackReasonMapping classifyEditorStorageFallbackReason(
  String? reasonCode,
) {
  final normalizedReason = (reasonCode ?? '').trim().toLowerCase();
  switch (normalizedReason) {
    case 'quota_exceeded':
      return const EditorStorageFallbackReasonMapping(
        storageVariant: 'quota_exceeded',
        snackVariant: 'quota_exceeded',
      );
    case 'storage_session_only':
      return const EditorStorageFallbackReasonMapping(
        storageVariant: 'storage_session_only',
        snackVariant: 'storage_session_only',
      );
    case 'storage_blocked':
      return const EditorStorageFallbackReasonMapping(
        storageVariant: 'storage_blocked',
        snackVariant: 'storage_blocked',
      );
    case 'unknown_storage_error':
      return const EditorStorageFallbackReasonMapping(
        storageVariant: 'unknown_storage_error',
        snackVariant: 'generic',
      );
    default:
      return const EditorStorageFallbackReasonMapping(
        storageVariant: 'generic',
        snackVariant: 'generic',
      );
  }
}

// ??? Persistencia segura: NO guardar thumbs base64 en prefs/localStorage.
const bool _kPersistPhotoThumbs = true;
const String _kPrefEngineApiKey = 'bitflow.engine_api_key';
const String _kPrefEngineApiKeyAlt = 'bitflow_engine_api_key';
const String _kPrefCameraRationaleSeen =
    'bitflow.permission_rationale.camera.v1';
const String _kPrefMicrophoneRationaleSeen =
    'bitflow.permission_rationale.microphone.v1';
const String _kPrefLocationRationaleSeen =
    'bitflow.permission_rationale.location.v1';
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
const String _kPrefFlowBotRecentByContext =
    'bitflow.editor.flowbot.recent_by_context.v2';
const String _kPrefFlowBotFavoritesByContext =
    'bitflow.editor.flowbot.favorites_by_context.v1';
const String _kPrefFlowBotLastScope = 'bitflow.editor.flowbot.last_scope.v1';
const String _kPrefFlowBotMacros = 'bitflow.editor.flowbot.macros.v1';
const String _kPrefMobileCompactMode = 'bitflow.editor.mobile_compact_mode.v1';
const String _kPrefZenMode = 'bitflow.editor.zen_mode.v1';
const String _kPrefMobileFocusCellMode =
    'bitflow.editor.mobile_focus_cell_mode.v1';
const String _kPrefFieldMode = 'bitflow.editor.field_mode.v1';

enum _OverlayMove { none, next, prev, down, up }

enum _ReviewFilterMode { all, pending, reviewed }

enum _HistoryFilterWindow { all, today, week }

enum _GridDensity { compact, normal, roomy }

enum _MobileEditPhase { closed, opening, open, switching, closing }

enum _GpsWriteMode { pasteActive, pickTarget, metadataOnly }

enum _InlineSearchScope { allSheet, currentRow, currentColumn }

enum _UnsavedExitAction { discard, save, cancel }

class _CellTarget {
  const _CellTarget(this.row, this.col);
  final int row;
  final int col;
}

class _SheetQualitySnapshot {
  const _SheetQualitySnapshot({
    required this.rowsTotal,
    required this.rowsWithData,
    required this.rowsReady,
    required this.invalidCells,
    required this.pendingRequired,
    required this.requiredCellsTotal,
    required this.requiredCellsValid,
  });

  const _SheetQualitySnapshot.empty()
      : rowsTotal = 0,
        rowsWithData = 0,
        rowsReady = 0,
        invalidCells = 0,
        pendingRequired = 0,
        requiredCellsTotal = 0,
        requiredCellsValid = 0;

  final int rowsTotal;
  final int rowsWithData;
  final int rowsReady;
  final int invalidCells;
  final int pendingRequired;
  final int requiredCellsTotal;
  final int requiredCellsValid;

  bool get hasIssues => invalidCells > 0 || pendingRequired > 0;

  int get requiredCompletionPercent {
    if (requiredCellsTotal <= 0) {
      return rowsWithData > 0 ? 100 : 0;
    }
    return ((requiredCellsValid / requiredCellsTotal) * 100)
        .round()
        .clamp(0, 100);
  }

  String get statusLabel {
    if (rowsWithData <= 0) return 'Sin carga';
    if (hasIssues) return 'Requiere revision';
    return 'Lista para presentar';
  }

  bool sameAs(_SheetQualitySnapshot other) {
    return rowsTotal == other.rowsTotal &&
        rowsWithData == other.rowsWithData &&
        rowsReady == other.rowsReady &&
        invalidCells == other.invalidCells &&
        pendingRequired == other.pendingRequired &&
        requiredCellsTotal == other.requiredCellsTotal &&
        requiredCellsValid == other.requiredCellsValid;
  }
}

class _FlowBotQuickContext {
  const _FlowBotQuickContext({
    required this.sheetName,
    required this.row,
    required this.col,
    required this.rowNumber,
    required this.cellToken,
    required this.columnLabel,
    required this.visibleColumnLabels,
    required this.hasRows,
    required this.hasPreviousRow,
    required this.hasBlankCellsInColumn,
    required this.canExport,
  });

  final String sheetName;
  final int row;
  final int col;
  final int rowNumber;
  final String cellToken;
  final String columnLabel;
  final List<String> visibleColumnLabels;
  final bool hasRows;
  final bool hasPreviousRow;
  final bool hasBlankCellsInColumn;
  final bool canExport;
}

class _FlowBotQuickActionSpec {
  const _FlowBotQuickActionSpec({
    required this.id,
    required this.label,
    required this.icon,
    required this.buildCommand,
    this.requiresValue = false,
    this.promptTitle,
    this.promptLabel,
    this.promptHint,
  });

  final String id;
  final String label;
  final IconData icon;
  final String Function(String? value) buildCommand;
  final bool requiresValue;
  final String? promptTitle;
  final String? promptLabel;
  final String? promptHint;
}

class _FlowBotTemplateFavoriteSpec {
  const _FlowBotTemplateFavoriteSpec({
    required this.quickActionId,
    required this.label,
  });

  final String quickActionId;
  final String label;
}

class _FlowBotInlineQuickActionView {
  const _FlowBotInlineQuickActionView({
    required this.id,
    required this.label,
    required this.icon,
    required this.action,
    required this.source,
  });

  final String id;
  final String label;
  final IconData icon;
  final _FlowBotQuickActionSpec action;
  final String source;
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
typedef _DebugShareHook = Future<void> Function(ShareParams params);
typedef _DebugSaveLocationHook = Future<FileSaveLocation?> Function({
  required String suggestedName,
  required List<XTypeGroup> acceptedTypeGroups,
});
typedef _DebugSaveFileHook = Future<void> Function(XFile file, String path);
typedef _DebugPersistShareTempFileHook = Future<String?> Function({
  required String fileName,
  required Uint8List bytes,
});
typedef _DebugGpsOutcomeHook = Future<Map<String, Object?>> Function(
  Duration timeout,
);
typedef _DebugStartAudioRecordingHook = Future<void> Function({
  required String sheetId,
});
typedef _DebugStopAudioRecordingHook = Future<RecordedAudio?> Function();
typedef _DebugSaveAudioHook = Future<StoredAudio?> Function({
  required String sheetId,
  required String cellKey,
  required String attachmentId,
  required RecordedAudio recording,
});

// ============================== Pantalla principal =========================

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.sheetId,
    this.initialName,
    this.initialTemplateKind,
    this.initialHeaders,
    this.initialRows,
    this.engineBaseUrl,
    this.engineApiKey,
    this.initialSelectionRow,
    this.initialSelectionCol,
    this.perfHarnessEnabled = false,
    this.isLight, // compat StartPage
    this.onToggleTheme, // compat StartPage
  });

  final String sheetId;
  final String? initialName;
  final String? initialTemplateKind;
  final List<String>? initialHeaders;
  final List<List<String>>? initialRows;
  final String? engineBaseUrl;
  final String? engineApiKey;
  final int? initialSelectionRow;
  final int? initialSelectionCol;
  final bool perfHarnessEnabled;

  /// Si StartPage te lo pasa (modo controlado), se respeta.
  final bool? isLight;

  /// Si StartPage lo maneja global, se dispara desde ac??.
  final VoidCallback? onToggleTheme;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ------------------------------ Constantes -------------------------------

  static const int kMaxUndo = 50;
  static const Duration _blinkDuration = Duration(milliseconds: 110);
  static const Duration _saveDebounce = Duration(milliseconds: 700);
  static const Duration _saveThrottle = Duration(milliseconds: 1500);
  static const Duration _autosavePulse = Duration(seconds: 15);
  static const Duration _validationDebounce = Duration(milliseconds: 260);
  static const Duration _cellDraftSyncDebounce = Duration(milliseconds: 120);
  static const Duration _toastCoalesceWindow = Duration(milliseconds: 900);
  static const Duration _slowValidationThreshold = Duration(milliseconds: 12);
  static const String _kPhotoReadErrorMsg =
      'No se pudo leer la imagen (bytes vacios).';
  // ------------------------------ Estado ----------------------------------

  late String _sheetName;
  String _sheetTemplateKind = '';
  DateTime? _lastSavedAt;

  late List<String> _headers;
  late List<String> _colIds;
  late Map<String, _ColumnPrefs> _columnPrefsById;
  late List<String> _columnOrder;
  String? _frozenColId;
  String _displayColumnsCacheKey = '';
  List<int> _displayColumnsCache = const <int>[];
  Map<int, int> _displayIndexByActualCache = const <int, int>{};
  late List<_RowModel> _rows;
  final FormulaEngine _formulaEngine = const FormulaEngine();
  final Map<_CellRef, String> _formulaDisplayValues = <_CellRef, String>{};
  final Map<_CellRef, ParsedFormula> _formulaParsedByCell =
      <_CellRef, ParsedFormula>{};
  final Set<_CellRef> _invalidFormulaCells = <_CellRef>{};
  final Map<_CellRef, Set<_CellRef>> _formulaDependenciesByCell =
      <_CellRef, Set<_CellRef>>{};
  final Map<_CellRef, Set<_CellRef>> _formulaDependentsByCell =
      <_CellRef, Set<_CellRef>>{};
  final Set<_CellRef> _pendingFormulaSeeds = <_CellRef>{};
  bool _formulaGraphDirty = true;

  bool _isLight = true;
  bool _isDirty = false;
  late final ValueNotifier<EditorSaveSnapshot> _saveStatus = ValueNotifier(
    const EditorSaveSnapshot(state: EditorSaveState.idle),
  );
  late final ValueNotifier<OfflineSyncSnapshot> _offlineStatus = ValueNotifier(
    const OfflineSyncSnapshot(state: OfflineSyncState.synced, pendingCount: 0),
  );
  late final EditorController _controller = EditorController(
    saveStatus: _saveStatus,
    offlineStatus: _offlineStatus,
    openOfflineQueue: _openOfflineQueueDialog,
    openAttachments: (ref) {
      final idx = _cellIndexForRef(ref);
      if (idx == null) return;
      _openPhotosSheetForCell(idx.r, idx.c);
    },
    closeAttachments: () {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    },
    addAttachment: (ref) async {
      final idx = _cellIndexForRef(ref);
      if (idx == null) return;
      await _pickMultiplePhotosForCell(idx.r, idx.c);
    },
    removeAttachment: (ref, index) async {
      final idx = _cellIndexForRef(ref);
      if (idx == null) return;
      await _deletePhotoFromCell(idx.r, idx.c, index);
    },
    previewAttachment: (ctx, attachment) => _openPhotoPreview(ctx, attachment),
  );

  int _selRow = 0;
  int _selCol = 0;
  final math.Random _idRand = math.Random();
  final GridSelectionController _selection = GridSelectionController(
    initial: null,
  );
  final Set<int> _selectedRows = <int>{};
  int? _rowSelectionAnchor;

  final Map<String, CellMeta> _cellMeta = <String, CellMeta>{};
  _GpsWriteMode _gpsWriteMode = _GpsWriteMode.pasteActive;
  _GpsFix? _pendingGpsFix;
  bool _gpsPickingTarget = false;
  bool _gpsRequestInFlight = false;
  String? _gpsRequestLabel;
  Future<_GpsOutcome>? _gpsFetchInFlight;
  bool _autoGpsBatchEnabled = false;
  static const String _prefGpsMode = 'bitflow:gps_mode';
  static const String _prefAutoGpsBatch = 'bitflow:auto_gps_batch';
  static const String _prefGridDensity = 'bitflow:grid_density';

  _GridDensity _gridDensity = _GridDensity.normal;
  bool _gridDensityExplicit = false;
  bool _inAppModalShown = false;

  // ??? Guardado robusto
  int _rev = 0;
  int _lastSavedRev = 0;
  bool _savePending = false;
  DateTime _lastSaveStartedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _backupEvery = Duration(minutes: 5);
  static const int _maxBackups = 10;
  Timer? _backupTimer;
  DateTime _lastBackup = DateTime.fromMillisecondsSinceEpoch(0);

  // Nombre (header Apple)
  late final TextEditingController _nameEC = TextEditingController();
  late final FocusNode _nameFocus = FocusNode(
    debugLabel: 'SheetNameAppleFocus',
  );
  Timer? _nameDebounceT;

  // Overlay editor (desktop)
  final LayerLink _editorLink = LayerLink();
  OverlayEntry? _cellEditorEntry;
  final TextEditingController _cellEC = TextEditingController();
  final FocusNode _cellFocus = FocusNode(debugLabel: 'CellEditorFocus');

  _CellRef? _overlayTargetCell;
  int? _overlayTargetHeaderCol;
  double _overlayTargetWidth = 320;

  // Draft live sync (edicion en vivo)
  final Map<_CellRef, String> _draftCells = <_CellRef, String>{};
  final Map<int, String> _draftHeaders = <int, String>{};
  final Set<_CellRef> _attachmentProcessingCells = <_CellRef>{};
  _CellRef? _editingCellRef;
  int? _editingHeaderCol;
  final ValueNotifier<int> _gridVersion = ValueNotifier<int>(0);
  final Map<String, ValueNotifier<int>> _rowVersionById =
      <String, ValueNotifier<int>>{};
  final _ThumbDecodeCache _thumbDecodeCache =
      _ThumbDecodeCache(maxEntries: 220, maxBytes: 14 * 1024 * 1024);
  int _debugGridBuilds = 0;
  int _debugRowBuilds = 0;
  int _debugCellBuilds = 0;
  int _debugInputEvents = 0;
  final Map<String, Stopwatch> _debugPendingInputLatencyByRow =
      <String, Stopwatch>{};
  final List<int> _debugInputLatencySamplesUs = <int>[];
  DateTime _debugGridBuildsWindowStart = DateTime.now();
  bool _perfHarnessRequested = false;
  bool _perfOverlayExpanded = false;
  bool _perfScenarioRunning = false;
  int _perfScenarioRuns = 0;
  DateTime? _perfScenarioLastAt;
  bool _isInAppBrowser = false;
  bool _isSecureContext = true;
  bool? _storageOk;
  String? _storageMessage;
  final Set<String> _storageWarnedReasons = <String>{};
  VoidCallback? _cellDraftListener;
  VoidCallback? _mobileDraftListener;
  Timer? _cellDraftSyncT;

  // Blink visual
  final ValueNotifier<_CellRef?> _blinkCell = ValueNotifier<_CellRef?>(null);

  // ??? FIX: blink timer cancelable (evita callback tras dispose)
  Timer? _blinkT;

  // Scroll
  final ScrollController _vScroll = ScrollController();
  final ScrollController _hScroll = ScrollController();
  final ScrollController _mobileHeaderScroll = ScrollController();
  final List<ScrollController?> _mobileRowScrolls = <ScrollController?>[];
  final List<GlobalKey?> _mobileRowKeys = <GlobalKey?>[];
  final GlobalKey _mobileHeaderKey = GlobalKey();
  bool _mobileHSyncing = false;
  double _mobileSharedHorizontalOffset = 0;

  // Guardado
  Timer? _saveT;
  Timer? _autosavePulseT;
  Timer? _validationDebounceT;
  bool _saving = false;
  bool _lastSaveSucceeded = true;
  String? _lastSaveErrorMessage;
  bool _allowPopOnce = false;
  _EditorLongOperationState? _longOperation;
  bool _saveHapticPending = false;
  final EditorAtomicSnapshotStore _atomicSnapshotStore =
      EditorAtomicSnapshotStore();

  // ??? Teclado m??vil: controlador robusto de insets
  late final KeyboardInsetsController _kbController = KeyboardInsetsController(
    onLog: kDebugMode ? debugPrint : null,
  );
  late final AttachmentStore _attachmentStore = AttachmentStore.I;
  late final AudioService _audioService = AudioService.I;
  late final AudioStorageService _audioStore = AudioStorageService.I;
  _DebugAttachmentTraceHook? _debugAttachmentTraceHook;
  late final AttachmentPipeline _attachmentPipeline = AttachmentPipeline(
    debugHook: (trace) {
      final hook = _debugAttachmentTraceHook;
      if (hook == null) return;
      assert(() {
        hook(trace);
        return true;
      }());
    },
  );
  late final WebAttachmentCapabilities _webAttachmentCapabilities =
      WebAttachmentCapabilities.I;
  WebAttachmentCapabilitiesSnapshot? _lastAttachmentCapabilities;
  _DebugSaveImageHook? _debugSaveImageHook;
  _DebugShareHook? _debugShareHook;
  _DebugSaveLocationHook? _debugSaveLocationHook;
  _DebugSaveFileHook? _debugSaveFileHook;
  _DebugPersistShareTempFileHook? _debugPersistShareTempFileHook;
  _DebugGpsOutcomeHook? _debugGpsOutcomeHook;
  _DebugStartAudioRecordingHook? _debugStartAudioRecordingHook;
  _DebugStopAudioRecordingHook? _debugStopAudioRecordingHook;
  _DebugSaveAudioHook? _debugSaveAudioHook;
  WebImageNormalizer? _debugWebImageNormalizer;
  bool _debugForceWebImageNormalization = false;
  bool _debugSkipAttachmentGps = false;
  WebAudioRecorderSupport? _lastAudioSupport;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<void>? _audioCompleteSub;
  CellRef? _recordingAudioCellRef;
  bool _audioRecording = false;
  String? _playingAudioId;
  Timer? _kbEnsureDebounceT;
  Timer? _mobileEnsureLateT;
  Timer? _mobileFocusRetryT;

  // Undo/Redo
  final List<_SheetSnapshot> _undo = <_SheetSnapshot>[];
  final List<_SheetSnapshot> _redo = <_SheetSnapshot>[];
  bool _suspendUndoSnapshot = false;

  // Engine compute (opcional)
  bool _engineBusy = false;
  String? _engineStatus;
  bool _engineStatusIsError = false;
  String? _lastErrorFeedbackMessage;
  String? _photoFlowStatus;
  CellRef? _photoFlowTarget;
  bool _photoFlowActive = false;
  Timer? _photoFlowClearT;
  String? _engineBaseResolved;
  String? _engineKeyResolved;
  bool _engineHealthCheckInFlight = false;
  bool _engineFallbackMode = false;
  late final EngineApi _engineApi = EngineApi();

  bool get _engineHasBase =>
      _engineBaseResolved != null && _engineBaseResolved!.trim().isNotEmpty;

  bool get _isWidgetTestRuntime {
    if (_kFlutterTestEnv) return true;
    final bindingType = WidgetsBinding.instance.runtimeType.toString();
    return bindingType.contains('TestWidgetsFlutterBinding');
  }

  WebImageNormalizer get _webImageNormalizer =>
      _debugWebImageNormalizer ?? WebImageNormalizer.I;

  // ---------------- Smoke test (query param ?smoke=1) ---------------------

  bool _smokeRequested = false;
  bool _smokeRan = false;
  String? _smokeStatus;
  bool? _smokeOk;

  // ---------------- Mobile inline editor (FIJO arriba del teclado) --------

  bool _mobileEditorOpen = false;
  _MobileEditPhase _mobilePhase = _MobileEditPhase.closed;
  bool _mobileTopBarCollapsed = false;
  bool _mobileEditorExpanded = false;
  bool _mobileEditingHeader = false;
  int _mobileRow = -1;
  int _mobileCol = 0;
  String _mobileTitle = '';

  final TextEditingController _mobileEC = TextEditingController();
  final FocusNode _mobileFocus = FocusNode(
    debugLabel: 'MobileInlineEditorFocus',
  );

  List<_MobileAction> _mobileActions = const [];
  final GlobalKey _mobileBarKey = GlobalKey();
  final Key _mobileFieldKey = const ValueKey('mobileInlineEditorField');
  double _mobileBarH = 0.0;
  bool _mobileBarMeasureScheduled = false;
  String? _lastMobileSnack;
  String? _lastToastMessage;
  DateTime _lastToastAt = DateTime.fromMillisecondsSinceEpoch(0);
  VoidCallback? _detachWebFlushSignal;
  int _fillDownCount = 5;
  final int _incrementCount = 5;
  final int _incrementStep = 1;
  Set<_CellRef> _invalidCells = <_CellRef>{};
  Map<_CellRef, String> _invalidCellMessages = <_CellRef, String>{};
  int _pendingRequired = 0;
  _SheetQualitySnapshot _sheetQuality = const _SheetQualitySnapshot.empty();
  bool _errorsPanelOpen = false;
  final List<_ColumnTemplate> _columnTemplates = <_ColumnTemplate>[];
  bool _inlineSearchOpen = false;
  _InlineSearchScope _inlineSearchScope = _InlineSearchScope.allSheet;
  final TextEditingController _inlineSearchEC = TextEditingController();
  final FocusNode _inlineSearchFocus = FocusNode(
    debugLabel: 'InlineSearchFocus',
  );
  Timer? _inlineSearchDebounceT;
  List<_CellRef> _searchMatches = <_CellRef>[];
  Set<_CellRef> _searchHitSet = <_CellRef>{};
  int _searchMatchIndex = -1;
  String _lastSearchQuery = '';
  _CellRef? _lastSearchHit;
  static const int _maxRecentValuesPerColumn = 10;
  static const int _maxPersistedRecentValuesPerColumn = 10;
  final Map<int, List<String>> _recentValuesByCol = <int, List<String>>{};
  Timer? _recentValuesSaveT;
  bool _defaultDateTodayEnabled = true;
  bool _defaultStatusOkEnabled = true;
  bool _autoIncrementIdEnabled = false;
  bool _cellInlinePreviewsEnabled = true;
  bool _mobileCompactModeEnabled = true;
  bool _zenModeEnabled = false;
  bool _mobileFocusCellModeEnabled = true;
  bool _flowBotUseLocalLlm = false;
  String _flowBotLocalModelPath = '';
  bool _flowBotModelDownloading = false;
  double _flowBotModelDownloadProgress = 0;
  static const int _maxFlowBotHistoryItems = 6;
  static const int _maxFlowBotFavoriteItems = 6;
  static const bool _flowBotShowDebugTools = bool.fromEnvironment(
    'BITFLOW_SHOW_FLOWBOT_DEBUG_TOOLS',
    defaultValue: false,
  );
  final List<String> _flowBotHistory = <String>[];
  final List<FlowBotFavoriteShortcut> _flowBotFavorites =
      <FlowBotFavoriteShortcut>[];
  final List<FlowBotMacroPreset> _flowBotMacros = <FlowBotMacroPreset>[];
  String _flowBotLastScope = 'seleccion';
  String _lastFlowBotValidCommand = '';
  bool _fieldModeEnabled = false;
  final RuleBasedFlowBot _flowBotRuleEngine = const RuleBasedFlowBot();
  final FlowBotLocalLlmEngine _flowBotLocalLlmEngine = FlowBotLocalLlmEngine();
  final FlowBotLocalModelManager _flowBotLocalModelManager =
      createFlowBotLocalModelManager();
  String _lastExportPreset = 'pdf';
  final List<_QuickCapturePending> _quickCaptureQueue =
      <_QuickCapturePending>[];
  final List<_EditPending> _editQueue = <_EditPending>[];
  final OutboxStore _outboxStore = OutboxStore.instance;
  int _outboxQueuedCount = 0;
  int _outboxErrorCount = 0;
  Timer? _outboxBadgeTimer;
  final OfflineQueueStore _offlineQueueStore = OfflineQueueStore();
  final NetworkStatusService _networkStatusService =
      const NetworkStatusService();
  bool _offlineSyncing = false;
  String? _offlineLastError;
  DateTime? _offlineRetryAt;
  Timer? _quickCaptureSyncTimer;
  bool _lastOnlineState = true;
  bool _editorTourVisible = false;
  bool _editorTourDismissed = false;
  bool _editorSmartPasteInteracted = false;
  bool _editorTemplateInteracted = false;
  bool _mobileFabMenuOpen = false;
  bool _debugEditorFirstFrameLogged = false;
  int _debugMobileEnsureVisibleCalls = 0;
  int _progressiveAutoStep = 10;
  final List<_SavedView> _savedViews = <_SavedView>[];
  String? _activeSavedViewId;
  _ReviewFilterMode _reviewFilterMode = _ReviewFilterMode.all;
  final List<HistoryEventRecord> _historyEvents = <HistoryEventRecord>[];
  Timer? _historyPersistT;
  String _rowViewCacheKey = '';
  List<int> _visibleRowIndexesCache = const <int>[];
  Map<int, int> _displayRowToActualCache = const <int, int>{};
  Map<int, int> _actualRowToDisplayCache = const <int, int>{};
  List<_RowModel> _visibleRowModelsCache = const <_RowModel>[];
  String? _recoveryStagingRaw;
  bool _recoveryBannerVisible = false;
  bool _androidInstallHelperHiddenSession = false;
  bool _androidInstallHelperDismissed = false;
  DateTime _lastBlinkHapticAt = DateTime.fromMillisecondsSinceEpoch(0);

  // ??? para evitar setState dentro de dispose
  bool _isDisposing = false;

  // ------------------------------ Init/Dispose ----------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mobileFocus.addListener(_handleMobileFocusChange);
    BitFlowProductService.I.features.entitlement
        .addListener(_handleEntitlementChanged);
    _kbController.attach();
    _kbController.kbInsetDp.addListener(_handleKbInsetChanged);
    if (kIsWeb) {
      _detachWebFlushSignal = WebFlushSignal.attach(
        _flushLocalStateForBackground,
      );
    }

    _sheetName = (widget.initialName?.trim().isNotEmpty ?? false)
        ? widget.initialName!.trim()
        : 'Hoja';
    _sheetTemplateKind = (widget.initialTemplateKind ?? '').trim();
    _nameEC.text = _sheetName;

    _isLight = widget.isLight ??
        (WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light);

    _isInAppBrowser = kIsWeb && WebCapabilities.isInAppBrowser;
    _isSecureContext = !kIsWeb || WebCapabilities.isSecureContext;
    unawaited(_loadStorageStatus());

    if (_isInAppBrowser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_showInAppBlockingModal());
      });
    }

    final initial = _buildInitialState();
    _headers = initial.headers;
    _colIds = initial.colIds;
    _columnPrefsById = _normalizeColumnPrefs(
      colIds: _colIds,
      incoming: initial.columnPrefsById,
    );
    _columnOrder = _normalizeColumnOrder(
      colIds: _colIds,
      incoming: initial.columnOrder,
    );
    _frozenColId = _normalizeFrozenColId(
      colIds: _colIds,
      requested: initial.frozenColId,
    );
    _rows = initial.rows;
    _selRow = (widget.initialSelectionRow ?? 0).clamp(0, _rows.length - 1);
    _selCol = (widget.initialSelectionCol ?? 0).clamp(0, _headers.length - 1);
    _selectedRows
      ..clear()
      ..add(_selRow);
    _rowSelectionAnchor = _selRow;
    _refreshFormulaCaches();
    _syncRowVersionNotifiers();
    _resetMobileRowCaches();
    _scheduleValidationRecompute(immediate: true);

    _audioCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _playingAudioId = null);
    });

    _rev = 0;
    _lastSavedRev = 0;
    _savePending = false;
    _updateSaveStatus();
    _updateOfflineStatus();
    _lastOnlineState = true;
    _autosavePulseT = Timer.periodic(
      _autosavePulse,
      (_) => unawaited(_tickAutosavePulse()),
    );
    if (kDebugMode) {
      debugPrint(
        '[editor:init] sheet=${widget.sheetId} headers=${_headers.length} rows=${_rows.length} mounted=$mounted',
      );
    }
    unawaited(_refreshOnlineState());
    _quickCaptureSyncTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(_tickQuickCaptureSync(fromTimer: true)),
    );
    _outboxBadgeTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_refreshOutboxBadgeCounts()),
    );
    unawaited(_refreshOutboxBadgeCounts());
    unawaited(_loadQuickCaptureQueue());

    _pushUndoSnapshot(); // estado inicial
    _smokeRequested = _isSmokeRequested();
    _perfHarnessRequested = widget.perfHarnessEnabled || _isPerfRequested();
    if (_perfHarnessRequested && kDebugMode) {
      unawaited(_initPerfHarness());
    }
    unawaited(_loadGpsMode());
    unawaited(_loadAutoGpsBatch());
    unawaited(_loadGridDensity());
    unawaited(_loadEditorDefaultsPrefs());
    unawaited(_loadFlowBotHistoryPrefs());
    unawaited(_loadFlowBotFavoritesPrefs());
    unawaited(_loadFlowBotUiPrefs());
    unawaited(_loadExportPresetPref());
    unawaited(_loadRecentValuesFromPrefs());
    unawaited(_loadColumnTemplatesPref());
    unawaited(_loadSavedViewsPref());
    unawaited(_loadHistoryLogPref());
    unawaited(_loadEditorTourPrefs());
    unawaited(_loadAndroidInstallHelperPref());
    unawaited(_loadLocal().whenComplete(() => unawaited(_maybeRunSmoke())));
    unawaited(
      _initEngineConnection().whenComplete(() => unawaited(_maybeRunSmoke())),
    );
  }

  Future<void> _loadStorageStatus() async {
    final result = await StorageDiagnostics.check();
    WebAttachmentCapabilitiesSnapshot? webCaps;
    if (kIsWeb) {
      try {
        webCaps = await _webAttachmentCapabilities.snapshot();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _lastAttachmentCapabilities = webCaps;
      if (webCaps?.privateModeLikely == true) {
        _storageOk = false;
        _storageMessage = 'Modo temporal del navegador';
      } else {
        _storageOk = result.ok;
        _storageMessage = result.message;
      }
    });
    if (webCaps?.privateModeLikely == true) {
      _showActionSnack(
        'Modo temporal detectado: al recargar o cerrar la pesta\u00f1a podr\u00edas perder adjuntos. Export\u00e1 ZIP para conservar.',
        isError: false,
        icon: Icons.info_outline_rounded,
      );
    }
  }

  @override
  void didUpdateWidget(covariant EditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.sheetId != oldWidget.sheetId) {
      _resetDraftsAndEditors();
    }

    // Si el padre cambia isLight, lo reflejamos localmente.
    final newLight = widget.isLight;
    if (newLight != null &&
        newLight != oldWidget.isLight &&
        newLight != _isLight) {
      setState(() => _isLight = newLight);
    }
  }

  @override
  void dispose() {
    _isDisposing = true;

    WidgetsBinding.instance.removeObserver(this);
    BitFlowProductService.I.features.entitlement
        .removeListener(_handleEntitlementChanged);
    _saveT?.cancel();
    _autosavePulseT?.cancel();
    _validationDebounceT?.cancel();
    _nameDebounceT?.cancel();
    _inlineSearchDebounceT?.cancel();
    _cellDraftSyncT?.cancel();
    _recentValuesSaveT?.cancel();
    _historyPersistT?.cancel();
    _blinkT?.cancel();
    _kbEnsureDebounceT?.cancel();
    _mobileEnsureLateT?.cancel();
    _mobileFocusRetryT?.cancel();
    _photoFlowClearT?.cancel();
    _quickCaptureSyncTimer?.cancel();
    _outboxBadgeTimer?.cancel();
    _mobileFocus.removeListener(_handleMobileFocusChange);
    _kbController.kbInsetDp.removeListener(_handleKbInsetChanged);
    _kbController.dispose();
    _detachWebFlushSignal?.call();
    _detachWebFlushSignal = null;

    _vScroll.dispose();
    _hScroll.dispose();
    _mobileHeaderScroll.dispose();
    for (final controller in _mobileRowScrolls) {
      controller?.dispose();
    }
    _mobileRowScrolls.clear();
    _mobileRowKeys.clear();

    _detachCellDraftListener();
    _detachMobileDraftListener();
    _cellEC.dispose();
    _cellFocus.dispose();

    _mobileEC.dispose();
    _mobileFocus.dispose();

    // ??? primero removemos overlay sin setState
    _removeCellEditor(notifyState: false);

    _blinkCell.dispose();
    _gridVersion.dispose();
    for (final notifier in _rowVersionById.values) {
      notifier.dispose();
    }
    _rowVersionById.clear();
    _thumbDecodeCache.clear();
    _attachmentProcessingCells.clear();
    _saveStatus.dispose();
    _offlineStatus.dispose();

    _nameEC.dispose();
    _nameFocus.dispose();
    _inlineSearchEC.dispose();
    _inlineSearchFocus.dispose();
    _engineApi.dispose();
    _backupTimer?.cancel();
    unawaited(_audioService.dispose());
    _audioCompleteSub?.cancel();
    _audioPlayer.dispose();

    super.dispose();
  }

  void _handleKbInsetChanged() {
    if (!_mobileEditorOpen) return;
    if (!_mobileFocusCellModeEnabled) return;
    final targetRow = _mobileEditingHeader ? -1 : _mobileRow;
    if (_mobileEditingHeader || _mobileRow >= 0) {
      _debouncedEnsureRowVisible(targetRow);
    }
  }

  void _handleEntitlementChanged() {
    if (!mounted || _isDisposing) return;
    setState(() {
      _refreshFormulaCaches(notifyRows: true);
    });
  }

  void _setMobileTopBarCollapsed(bool collapsed) {
    if (_zenModeEnabled) return;
    if (!_mobileCompactModeEnabled && collapsed) return;
    if (_mobileTopBarCollapsed == collapsed) return;
    if (!mounted) {
      _mobileTopBarCollapsed = collapsed;
      return;
    }
    setState(() => _mobileTopBarCollapsed = collapsed);
  }

  void _handleMobileGridScrollDirection(ScrollDirection direction) {
    if (_zenModeEnabled) return;
    if (!_mobileCompactModeEnabled) return;
    if (_mobileEditorOpen) return;
    if (direction == ScrollDirection.idle) return;
    if (direction == ScrollDirection.reverse) {
      _setMobileTopBarCollapsed(true);
      return;
    }
    if (direction == ScrollDirection.forward) {
      _setMobileTopBarCollapsed(false);
    }
  }

  Future<void> _setZenMode(bool enabled) async {
    if (_zenModeEnabled == enabled) return;
    if (mounted) {
      setState(() {
        _zenModeEnabled = enabled;
        _mobileTopBarCollapsed = enabled;
      });
    } else {
      _zenModeEnabled = enabled;
      _mobileTopBarCollapsed = enabled;
    }
    await _saveEditorDefaultsPrefs();
  }

  Future<void> _toggleZenMode() => _setZenMode(!_zenModeEnabled);

  Future<void> _initPerfHarness() async {
    try {
      await PerfOptimizer.init(
        enableFrameTimings: true,
        frameHistoryCap: 360,
        maxConcurrentCpuJobs: 2,
      );
      PerfOptimizer.configure(
        frameBudget: const Duration(milliseconds: 8),
        frameHistoryCap: 360,
        maxConcurrentCpuJobs: 2,
      );
      PerfOptimizer.resetStats();
    } catch (_) {
      // Guardrail: perf harness nunca debe bloquear apertura del editor.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    // Guardar ???duro??? cuando la app pasa a background/inactive.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _flushLocalStateForBackground();
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_tickQuickCaptureSync());
    }
  }

  void _flushLocalStateForBackground() {
    if (!mounted) return;
    _commitActiveEditors();
    _saveT?.cancel();
    if (_isDirty || _savePending) {
      unawaited(_saveLocalNow());
    }
  }

  // ------------------------------ Construcci??n inicial --------------------

  _SheetModel _buildInitialState() {
    final headers =
        (widget.initialHeaders != null && widget.initialHeaders!.isNotEmpty)
            ? _normalizeHeaders(widget.initialHeaders!)
            : _defaultHeaders();
    final colIds = _normalizeColIds(headers, null);

    final rowModels = <_RowModel>[];

    if (widget.initialRows != null && widget.initialRows!.isNotEmpty) {
      for (final r in widget.initialRows!) {
        rowModels.add(
          _RowModel.fromCells(
            _normalizeRow(r, headers.length),
            id: _genStableId('r_'),
          ),
        );
      }
    } else {
      // 3 filas vac??as por defecto (mobile-friendly)
      for (int i = 0; i < 3; i++) {
        rowModels.add(_RowModel.empty(headers.length, id: _genStableId('r_')));
      }
    }

    return _SheetModel(
      headers: headers,
      colIds: colIds,
      rows: rowModels,
      name: _sheetName,
      savedAt: _lastSavedAt,
      columnOrder: _normalizeColumnOrder(colIds: colIds, incoming: null),
    );
  }

  String _genStableId(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = _idRand.nextInt(_kStableIdRandomMaxExclusive);
    return '$prefix$now$rand';
  }

  List<String> _defaultHeaders() {
    final h = List<String>.filled(kDefaultCols, '');
    if (h.isNotEmpty) h[h.length - 1] = kPhotosHeader;
    return h;
  }

  List<String> _normalizeHeaders(List<String> incoming) {
    final h = incoming.map((e) => e.trim()).toList();
    if (h.isEmpty) return _defaultHeaders();

    final target = math.max(kDefaultCols, h.length);
    if (h.length < target) {
      h.addAll(List<String>.filled(target - h.length, ''));
    }

    // Photos al final s?? o s??
    if (h.isNotEmpty) h[h.length - 1] = kPhotosHeader;
    return h;
  }

  List<String> _normalizeColIds(List<String> headers, List<String>? incoming) {
    final len = headers.length;
    final out = <String>[];
    for (int i = 0; i < len; i++) {
      final raw = (incoming != null && i < incoming.length) ? incoming[i] : '';
      final trimmed = raw.trim();
      out.add(trimmed.isEmpty ? _genStableId('c_') : trimmed);
    }
    if (len > 0) {
      out[len - 1] = kPhotosColId;
    }
    final seen = <String>{};
    for (int i = 0; i < out.length; i++) {
      var id = out[i].trim();
      if (id.isEmpty || seen.contains(id)) {
        id = (i == len - 1) ? kPhotosColId : _genStableId('c_');
      }
      seen.add(id);
      out[i] = id;
    }
    if (len > 0) {
      for (int i = 0; i < len - 1; i++) {
        if (out[i] == kPhotosColId) {
          out[i] = _genStableId('c_');
        }
      }
    }
    return out;
  }

  Map<String, _ColumnPrefs> _normalizeColumnPrefs({
    required List<String> colIds,
    required Map<String, _ColumnPrefs> incoming,
  }) {
    final out = <String, _ColumnPrefs>{};
    for (final colId in colIds) {
      if (colId == kPhotosColId) continue;
      final pref = incoming[colId];
      if (pref == null) continue;
      if (pref.type == _ColType.photos) continue;
      final sanitizedEnums = <String>[];
      for (final value in pref.enumValues) {
        final item = value.trim();
        if (item.isEmpty) continue;
        if (sanitizedEnums.any(
          (existing) => existing.toLowerCase() == item.toLowerCase(),
        )) {
          continue;
        }
        sanitizedEnums.add(item);
      }
      final regex = pref.regexPattern?.trim();
      final hasValidRegex = (() {
        final pattern = regex ?? '';
        if (pattern.isEmpty) return true;
        try {
          RegExp(pattern);
          return true;
        } catch (_) {
          return false;
        }
      })();
      final min = pref.numberMin;
      final max = pref.numberMax;
      final nextMin = (min != null && max != null && min > max) ? max : min;
      final nextMax = (min != null && max != null && min > max) ? min : max;
      final wrapLines = pref.wrapLines.clamp(1, 3);
      out[colId] = pref.copyWith(
        enumValues: sanitizedEnums,
        numberMin: nextMin,
        numberMax: nextMax,
        regexPattern: hasValidRegex ? regex : null,
        wrapLines: wrapLines,
      );
    }
    return out;
  }

  List<String> _normalizeColumnOrder({
    required List<String> colIds,
    required List<String>? incoming,
  }) {
    final dataColIds = <String>[
      for (final id in colIds)
        if (id != kPhotosColId) id,
    ];
    if (dataColIds.isEmpty) return const <String>[];
    final seen = <String>{};
    final out = <String>[];

    if (incoming != null) {
      for (final raw in incoming) {
        final id = raw.trim();
        if (id.isEmpty) continue;
        if (!dataColIds.contains(id)) continue;
        if (!seen.add(id)) continue;
        out.add(id);
      }
    }

    for (final id in dataColIds) {
      if (!seen.add(id)) continue;
      out.add(id);
    }
    return out;
  }

  String? _normalizeFrozenColId({
    required List<String> colIds,
    required String? requested,
  }) {
    final value = requested?.trim() ?? '';
    if (value.isEmpty || value == kPhotosColId) return null;
    if (!colIds.contains(value)) return null;
    return value;
  }

  // ??? Acepta List<String>, List<dynamic>, etc.
  List<String> _normalizeRow(Iterable<dynamic> incoming, int cols) {
    final r = incoming.map((e) => (e ?? '').toString()).toList();
    if (r.length < cols) r.addAll(List<String>.filled(cols - r.length, ''));
    if (r.length > cols) r.removeRange(cols, r.length);
    return r;
  }

  List<_RowModel> _normalizeRowModels(List<_RowModel> incoming, int cols) {
    if (incoming.isEmpty) return <_RowModel>[];
    final out = <_RowModel>[];
    final seen = <String>{};
    for (final row in incoming) {
      var id = row.id.trim();
      if (id.isEmpty || seen.contains(id)) {
        id = _genStableId('r_');
      }
      seen.add(id);
      out.add(
        _RowModel(
          id: id,
          cells: _normalizeRow(row.cells, cols),
          photos: row.photos,
          gpsLat: row.gpsLat,
          gpsLng: row.gpsLng,
          gpsAccuracyM: row.gpsAccuracyM,
          gpsTs: row.gpsTs,
          gpsIsLastKnown: row.gpsIsLastKnown,
        ),
      );
    }
    return out;
  }

  Map<String, CellMeta> _normalizeCellMeta(
    Map<String, CellMeta> incoming,
    List<_RowModel> rows,
    List<String> colIds,
  ) {
    if (incoming.isEmpty) return <String, CellMeta>{};
    final out = <String, CellMeta>{};
    final rowIdSet = rows.map((r) => r.id).toSet();
    final colIdSet = colIds.toSet();
    incoming.forEach((key, meta) {
      final ref = CellRef.fromKey(key, defaultSheetId: widget.sheetId);
      if (ref != null) {
        if (!rowIdSet.contains(ref.rowId)) return;
        if (!colIdSet.contains(ref.colId)) return;
        final normalized =
            ref.sheetId == widget.sheetId ? ref : ref.withSheet(widget.sheetId);
        out[normalized.key] = meta.copy();
        return;
      }
      final cell = CellKey.fromKey(key);
      if (cell == null) return;
      if (cell.row < 0 || cell.row >= rows.length) return;
      if (cell.col < 0 || cell.col >= colIds.length) return;
      final legacyRef = CellRef(
        sheetId: widget.sheetId,
        rowId: rows[cell.row].id,
        colId: colIds[cell.col],
      );
      out[legacyRef.key] = meta.copy();
    });
    return out;
  }

  Map<String, CellMeta> _migrateLegacyRowGps(
    Map<String, CellMeta> incoming,
    List<_RowModel> rows,
    List<String> colIds,
  ) {
    if (incoming.isNotEmpty) return incoming;
    final out = <String, CellMeta>{};
    if (colIds.isEmpty) return out;
    final lastDataCol = math.max(0, colIds.length - 1);
    final gpsPattern = RegExp(r'(-?\d+(?:\.\d+)?)[,\s]+(-?\d+(?:\.\d+)?)');

    for (int r = 0; r < rows.length; r++) {
      final row = rows[r];
      if (row.gpsLat == null || row.gpsLng == null) continue;

      int targetCol = -1;
      for (int c = 0; c < lastDataCol && c < row.cells.length; c++) {
        if (gpsPattern.hasMatch(row.cells[c])) {
          targetCol = c;
          break;
        }
      }
      if (targetCol < 0) targetCol = 0;

      final gps = GpsMeta(
        lat: row.gpsLat!,
        lng: row.gpsLng!,
        accuracyM: row.gpsAccuracyM ?? 0,
        timestamp: row.gpsTs ?? DateTime.now(),
        source: row.gpsIsLastKnown ? 'lastKnown' : 'current',
        provider: 'legacy-row',
      );
      final ref = CellRef(
        sheetId: widget.sheetId,
        rowId: row.id,
        colId: colIds[targetCol],
      );
      out[ref.key] = CellMeta(gps: gps);
    }

    return out;
  }

  Map<String, CellMeta> _migrateLegacyRowPhotos(
    Map<String, CellMeta> incoming,
    List<_RowModel> rows,
    List<String> colIds,
  ) {
    if (rows.isEmpty) return incoming;
    if (colIds.isEmpty) return incoming;

    final out = <String, CellMeta>{};
    out.addAll(incoming);
    final photosCol = colIds.length - 1;

    for (int r = 0; r < rows.length; r++) {
      final row = rows[r];
      if (row.photos.isEmpty) continue;

      final ref = CellRef(
        sheetId: widget.sheetId,
        rowId: row.id,
        colId: colIds[photosCol],
      );
      final key = ref.key;
      final current = out[key];
      final photos = <PhotoAttachment>[...?current?.photos];
      for (final photo in row.photos) {
        photos.add(_photoAttachmentFromRowPhoto(photo));
      }
      final next = CellMeta(
        gps: current?.gps,
        photos: photos,
        audios: current?.audios ?? const <AudioAttachment>[],
      );
      out[key] = next;

      row.photos.clear();
    }

    return out;
  }

  // ------------------------------ Local persistence -----------------------

  String get _prefsKey => 'bitflow:sheet:${widget.sheetId}';
  String get _prefsKeyBackup => '$_prefsKey:backup';
  String get _prefsKeyStaging => '$_prefsKey:staging';
  String get _backupListKey => '$_prefsKey:bk:list';
  String get _prefsRecentValuesKey => '$_prefsKey:recent_values.v1';
  String get _prefsEditorDefaultsKey => '$_prefsKey:defaults.v1';
  String get _prefsSavedViewsKey => '$_prefsKey:$_kPrefSavedViews';
  String get _prefsActiveViewKey => '$_prefsKey:active_saved_view.v1';
  String get _prefsHistoryKey => '$_prefsKey:$_kPrefHistoryLog';
  String _backupKey(DateTime ts) =>
      '$_prefsKey:bk:${ts.millisecondsSinceEpoch}';

  _SheetModel? _decodeSheetModelRaw(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = json.decode(trimmed);
      if (decoded is! Map) return null;
      return _SheetModel.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistModelAtomically(
    SharedPreferences prefs,
    _SheetModel model,
  ) async {
    final encoded = json.encode(model.toJson());
    if (_decodeSheetModelRaw(encoded) == null) {
      throw StateError('save_payload_invalid');
    }

    final wroteStaging = await prefs.setString(_prefsKeyStaging, encoded);
    if (!wroteStaging) {
      throw StateError('staging_write_failed');
    }

    final stagedRaw = prefs.getString(_prefsKeyStaging);
    if (stagedRaw == null || _decodeSheetModelRaw(stagedRaw) == null) {
      throw StateError('staging_write_invalid');
    }

    final wroteAtomicSnapshot = await _atomicSnapshotStore.writeSnapshot(
      sheetId: widget.sheetId,
      payload: stagedRaw,
    );
    if (_atomicSnapshotStore.isSupported && !wroteAtomicSnapshot) {
      debugPrint(
        '[EditorScreen] flow=save kind=storage op=io_atomic_snapshot_unavailable',
      );
    }

    final current = prefs.getString(_prefsKey);
    if (current != null && current.trim().isNotEmpty) {
      final wroteBackup = await prefs.setString(_prefsKeyBackup, current);
      if (!wroteBackup && kDebugMode) {
        debugPrint(
            '[EditorScreen] flow=save kind=storage op=backup_write_failed');
      }
    }

    final wrotePrimary = await prefs.setString(_prefsKey, stagedRaw);
    if (!wrotePrimary) {
      throw StateError('primary_write_failed');
    }

    final removedStaging = await prefs.remove(_prefsKeyStaging);
    if (!removedStaging && kDebugMode) {
      debugPrint(
          '[EditorScreen] flow=save kind=storage op=staging_cleanup_failed');
    }
  }

  void _showRecoveryNotice(String source) {
    debugPrint(
      '[EditorScreen] flow=load kind=recovery op=load_recovery source=$source',
    );
    _showActionSnack(
      'Se recupero la version guardada anterior.',
      isError: false,
      icon: Icons.history_rounded,
    );
  }

  Future<bool> _tryRestoreFromRaw(
    SharedPreferences prefs, {
    required String? raw,
    required String source,
    bool announceRecovery = false,
    bool syncAsCurrent = false,
  }) async {
    if (raw == null || raw.trim().isEmpty) return false;
    final loaded = _decodeSheetModelRaw(raw);
    if (loaded == null) return false;

    if (!mounted) return true;
    _lastBackup = _latestBackupFromPrefs(prefs);
    _applyLoadedModel(loaded);

    if (syncAsCurrent) {
      try {
        await prefs.setString(_prefsKey, raw);
        await prefs.remove(_prefsKeyStaging);
      } catch (_) {}
    }

    if (announceRecovery) {
      _showRecoveryNotice(source);
    }
    return true;
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentRaw = prefs.getString(_prefsKey);
      final stagingRaw = prefs.getString(_prefsKeyStaging);
      _setRecoveryStagingCandidate(stagingRaw);

      if (await _tryRestoreFromRaw(
        prefs,
        raw: currentRaw,
        source: 'prefs_current',
      )) {
        return;
      }

      if (await _tryRestoreFromRaw(
        prefs,
        raw: prefs.getString(_prefsKeyBackup),
        source: 'prefs_backup',
        announceRecovery: currentRaw != null && currentRaw.trim().isNotEmpty,
        syncAsCurrent: true,
      )) {
        return;
      }

      if (await _tryRestoreFromRaw(
        prefs,
        raw: await _atomicSnapshotStore.readSnapshot(widget.sheetId),
        source: 'io_atomic_snapshot',
        announceRecovery: true,
        syncAsCurrent: true,
      )) {
        return;
      }

      final loadedLegacy = await _loadLegacyFromSheetStore();
      if (!loadedLegacy &&
          currentRaw != null &&
          currentRaw.trim().isNotEmpty &&
          _decodeSheetModelRaw(currentRaw) == null) {
        _reportFlowErrorMessage(
          'local_payload_corrupted',
          flow: AppErrorFlow.load,
          operation: 'load_local_corrupted',
          icon: Icons.folder_off_rounded,
        );
      }
    } catch (e, st) {
      _reportFlowError(
        e,
        flow: AppErrorFlow.load,
        operation: 'load_local',
        stackTrace: st,
        icon: Icons.folder_off_rounded,
      );
    }
  }

  Future<bool> _loadLegacyFromSheetStore() async {
    try {
      final legacy = SheetStore.load(widget.sheetId);
      if (legacy == null) return false;

      final headers = _normalizeHeaders(legacy.headers);
      final colIds = _normalizeColIds(headers, null);
      final rows = legacy.rows
          .map(
            (r) => _RowModel.fromCells(
              _normalizeRow(r, headers.length),
              id: _genStableId('r_'),
            ),
          )
          .toList(growable: false);

      final model = _SheetModel(
        headers: headers,
        colIds: colIds,
        rows: rows,
        name: _sheetName,
        savedAt: legacy.savedAt,
      );

      if (!mounted) return true;
      _applyLoadedModel(model);
      return true;
    } catch (e, st) {
      _reportFlowError(
        e,
        flow: AppErrorFlow.load,
        operation: 'load_legacy_sheet_store',
        stackTrace: st,
        icon: Icons.folder_off_rounded,
      );
      return false;
    }
  }

  void _applyLoadedModel(_SheetModel loaded) {
    if (!mounted) return;

    final loadedHeaders = _normalizeHeaders(loaded.headers);
    final colIds = _normalizeColIds(loadedHeaders, loaded.colIds);
    final columnPrefs = _normalizeColumnPrefs(
      colIds: colIds,
      incoming: loaded.columnPrefsById,
    );
    final columnOrder = _normalizeColumnOrder(
      colIds: colIds,
      incoming: loaded.columnOrder,
    );
    final frozenColId = _normalizeFrozenColId(
      colIds: colIds,
      requested: loaded.frozenColId,
    );
    final normalizedRows = _normalizeRowModels(
      loaded.rows,
      loadedHeaders.length,
    );
    final migratedMeta = _migrateLegacyRowGps(
      loaded.cellMeta,
      normalizedRows,
      colIds,
    );
    final migratedPhotos = _migrateLegacyRowPhotos(
      migratedMeta,
      normalizedRows,
      colIds,
    );
    final normalizedMeta = _normalizeCellMeta(
      migratedPhotos,
      normalizedRows,
      colIds,
    );

    setState(() {
      _sheetName = (loaded.name?.trim().isNotEmpty ?? false)
          ? loaded.name!.trim()
          : _sheetName;
      _sheetTemplateKind = (loaded.templateKind ?? _sheetTemplateKind).trim();
      _headers = loadedHeaders;
      _colIds = colIds;
      _columnPrefsById = columnPrefs;
      _columnOrder = columnOrder;
      _frozenColId = frozenColId;
      _rows = normalizedRows.isNotEmpty
          ? normalizedRows
          : <_RowModel>[
              _RowModel.empty(_headers.length, id: _genStableId('r_')),
            ];
      _cellMeta
        ..clear()
        ..addAll(normalizedMeta);
      _selRow = _selRow.clamp(0, _rows.length - 1);
      _selCol = _selCol.clamp(0, _headers.length - 1);
      _isDirty = false;
      _lastSavedAt = loaded.savedAt;
      _lastSaveErrorMessage = null;

      _rev = 0;
      _lastSavedRev = 0;
      _savePending = false;
    });
    _pendingFormulaSeeds.clear();
    _refreshFormulaCaches();
    _syncRowVersionNotifiers();
    _updateSaveStatus();
    _syncSelectionController();

    _resetMobileRowCaches();
    _resetDraftsAndEditors();
    _scheduleValidationRecompute(immediate: true);

    if (!_nameFocus.hasFocus) {
      _nameEC.text = _sheetName;
    }

    _undo
      ..clear()
      ..add(_snapshot());
    _redo.clear();
    _seedRecentValuesFromRows();
  }

  void _seedRecentValuesFromRows() {
    final previous = <int, List<String>>{};
    _recentValuesByCol.forEach((col, values) {
      previous[col] = List<String>.from(values);
    });
    _recentValuesByCol.clear();
    if (_headers.length < 2) return;
    final dataCols = _headers.length - 1;
    for (int c = 0; c < dataCols; c++) {
      for (final row in _rows) {
        if (c < 0 || c >= row.cells.length) continue;
        _rememberValueForColumn(c, row.cells[c]);
      }
    }
    previous.forEach((col, values) {
      for (final value in values) {
        _rememberValueForColumn(col, value);
      }
    });
  }

  void _rememberValueForColumn(int c, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || c < 0) return;
    final list = _recentValuesByCol.putIfAbsent(c, () => <String>[]);
    final normalized = trimmed.toLowerCase();
    list.removeWhere((item) => item.trim().toLowerCase() == normalized);
    list.insert(0, trimmed);
    if (list.length > _maxRecentValuesPerColumn) {
      list.removeRange(_maxRecentValuesPerColumn, list.length);
    }
    _scheduleRecentValuesPersist();
  }

  List<String> _recentValuesForColumn(int c, {String? excluding}) {
    final list = _recentValuesByCol[c];
    if (list == null || list.isEmpty) return const <String>[];
    final excluded = (excluding ?? '').trim().toLowerCase();
    return list
        .where((item) => item.trim().toLowerCase() != excluded)
        .toList(growable: false);
  }

  _SheetModel _buildModelForSave(DateTime savedAt) {
    return _SheetModel(
      name: _sheetName,
      headers: List<String>.generate(
        _headers.length,
        (c) => _effectiveHeader(c),
        growable: false,
      ),
      colIds: List<String>.from(_colIds),
      rows: _rows.asMap().entries.map((entry) {
        final r = entry.key;
        final row = entry.value;
        return _RowModel(
          id: row.id,
          cells: List<String>.generate(
            _headers.length,
            (c) => _effectiveCell(r, c),
            growable: false,
          ),
          photos: row.photos.map((p) => p.copyWithoutThumb()).toList(
                growable: false,
              ),
          gpsLat: row.gpsLat,
          gpsLng: row.gpsLng,
          gpsAccuracyM: row.gpsAccuracyM,
          gpsTs: row.gpsTs,
          gpsIsLastKnown: row.gpsIsLastKnown,
        );
      }).toList(growable: false),
      cellMeta: _cloneCellMeta(_cellMeta),
      savedAt: savedAt,
      columnPrefsById: _cloneColumnPrefs(_columnPrefsById),
      columnOrder: List<String>.from(_columnOrder),
      frozenColId: _frozenColId,
      templateKind:
          _sheetTemplateKind.trim().isEmpty ? null : _sheetTemplateKind.trim(),
    );
  }

  DateTime _latestBackupFromPrefs(SharedPreferences prefs) {
    final list = prefs.getStringList(_backupListKey) ?? const <String>[];
    if (list.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    final tsRaw = list.first.split(':').last;
    final ms = int.tryParse(tsRaw) ?? 0;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  void _scheduleBackupCheck() {
    _backupTimer?.cancel();
    _backupTimer = Timer(_backupEvery, () {
      unawaited(_createBackupIfNeeded());
    });
  }

  Future<void> _createBackupIfNeeded() async {
    final now = DateTime.now();
    if (now.difference(_lastBackup) < _backupEvery) return;

    try {
      _syncActiveDrafts();
      final prefs = await SharedPreferences.getInstance();
      final latest = _latestBackupFromPrefs(prefs);
      if (now.difference(latest) < _backupEvery) {
        _lastBackup = latest;
        return;
      }

      final model = _buildModelForSave(now);
      final backupKey = _backupKey(now);
      final list = prefs.getStringList(_backupListKey) ?? const <String>[];
      final updated = <String>[backupKey, ...list];
      final trimmed = updated.length > _maxBackups
          ? updated.sublist(0, _maxBackups)
          : updated;

      await prefs.setString(backupKey, json.encode(model.toJson()));
      await prefs.setStringList(_backupListKey, trimmed);

      if (updated.length > trimmed.length) {
        for (final k in updated.sublist(_maxBackups)) {
          await prefs.remove(k);
        }
      }

      _lastBackup = now;
    } catch (e) {
      if (kDebugMode) debugPrint('[EditorScreen] backup failed: $e');
    }
  }

  Future<void> _saveNowFromUserAction() async {
    if (_saving) {
      _showActionSnack(
        AppStrings.infoSaveInProgress,
        isError: false,
        icon: Icons.sync_rounded,
      );
      return;
    }
    if (!_tryBeginLongOperation(
      message: AppStrings.progressSaving,
      cancellable: false,
    )) {
      return;
    }
    _saveHapticPending = true;
    try {
      await _saveLocalNow();
    } finally {
      _clearLongOperation();
    }
  }

  Future<void> _saveLocalNow() async {
    // ??? Si ya est??s guardando, marc?? pendiente y sal??.
    if (_saving) {
      _savePending = true;
      return;
    }

    _saveT?.cancel();
    _saving = true;
    _lastSaveSucceeded = false;
    _lastSaveErrorMessage = null;
    _savePending = false;
    _lastSaveStartedAt = DateTime.now();
    _updateSaveStatus();
    _syncActiveDrafts();

    final startRev = _rev;
    final savedAt = DateTime.now();

    if (mounted) setState(() {}); // refresca ???Saving??????

    try {
      final prefs = await SharedPreferences.getInstance();

      // ??? Captura consistente: copia headers + cells (evita mutaciones durante await).
      final model = _buildModelForSave(savedAt);

      await _persistModelAtomically(prefs, model);

      _lastSavedRev = startRev;
      _lastBackup = _latestBackupFromPrefs(prefs);
      _lastSaveSucceeded = true;
      _lastSaveErrorMessage = null;

      if (!mounted) return;
      setState(() {
        _lastSavedAt = savedAt;
        // ??? Solo limpio Dirty si no cambi?? mientras guardaba
        _isDirty = _rev != _lastSavedRev;
      });
      _updateSaveStatus();
      unawaited(BitFlowProductService.I.handleLocalSheetSaved(widget.sheetId));
      await _clearSavedEditPending();
      if (_saveHapticPending) {
        AppHaptics.success();
        _showActionSnack(
          'Cambios guardados.',
          isError: false,
          icon: Icons.check_circle_outline_rounded,
        );
      }
      await _createBackupIfNeeded();
    } catch (e, st) {
      _lastSaveSucceeded = false;
      _lastSaveErrorMessage =
          'No pudimos guardar los cambios. Revisa almacenamiento o conexion e intenta otra vez.';
      if (_pendingOfflineCount > 0 && mounted) {
        unawaited(_markOfflineSyncFailure('save_failed'));
      }
      _reportFlowError(
        e,
        flow: AppErrorFlow.save,
        operation: 'save_local',
        fallbackMessage:
            'No pudimos guardar los cambios. Revis\u00e1 tu conexi\u00f3n o almacenamiento local e intent\u00e1 otra vez.',
        stackTrace: st,
        icon: Icons.save_outlined,
      );
    } finally {
      _saving = false;
      if (mounted) {
        setState(() {}); // refresca ???Saved??????
        _updateSaveStatus();

        // ??? Si entraron cambios mientras guardabas, re-encol??.
        if (_savePending || _rev != _lastSavedRev) {
          _savePending = false;
          _queueSave();
        } else {
          _savePending = false;
        }
      } else {
        _savePending = false;
      }
      _saveHapticPending = false;
    }
  }

  void _queueSave() {
    _saveT?.cancel();
    _lastSaveErrorMessage = null;
    _updateSaveStatus();
    final sinceLastSave = DateTime.now().difference(_lastSaveStartedAt);
    final throttleRemaining = sinceLastSave >= _saveThrottle
        ? Duration.zero
        : _saveThrottle - sinceLastSave;
    final delay =
        throttleRemaining > _saveDebounce ? throttleRemaining : _saveDebounce;
    _saveT = Timer(delay, () {
      unawaited(_saveLocalNow());
    });
  }

  Future<void> _tickAutosavePulse() async {
    if (!mounted) return;
    if (_saving) return;
    if (_longOperation != null) return;
    if (!_isDirty && !_savePending) return;
    await _saveLocalNow();
  }

  Future<void> _allowSinglePopAndExit() async {
    if (!mounted) return;
    setState(() => _allowPopOnce = true);
    await Navigator.of(context).maybePop();
  }

  Future<void> _handleEditorPopGuard({
    required bool didPop,
  }) async {
    if (didPop) {
      if (_allowPopOnce && mounted) {
        setState(() => _allowPopOnce = false);
      }
      return;
    }
    if (_allowPopOnce) return;

    _syncActiveDrafts();
    final hasUnsaved = _hasUnsavedWork;
    if (!hasUnsaved) {
      await _allowSinglePopAndExit();
      return;
    }

    final action = await _askUnsavedExitAction();
    if (!mounted || action == _UnsavedExitAction.cancel) return;

    if (action == _UnsavedExitAction.save) {
      await _saveLocalNow();
      if (!mounted) return;
      final stillDirty = _hasUnsavedWork;
      if (stillDirty || !_lastSaveSucceeded) {
        _showActionSnack(
          'No pudimos cerrar porque el guardado fallo y todavia hay cambios pendientes.',
          isError: true,
          icon: Icons.warning_amber_rounded,
        );
        return;
      }
    }

    await _allowSinglePopAndExit();
  }

  // ------------------------------ Undo / Redo -----------------------------

  Map<String, CellMeta> _cloneCellMeta(Map<String, CellMeta> source) {
    if (source.isEmpty) return <String, CellMeta>{};
    final out = <String, CellMeta>{};
    source.forEach((key, meta) {
      out[key] = meta.copy();
    });
    return out;
  }

  Map<String, _ColumnPrefs> _cloneColumnPrefs(
    Map<String, _ColumnPrefs> source,
  ) {
    if (source.isEmpty) return <String, _ColumnPrefs>{};
    final out = <String, _ColumnPrefs>{};
    source.forEach((key, value) {
      out[key] = value.copyWith();
    });
    return out;
  }

  _SheetSnapshot _snapshot() => _SheetSnapshot(
        name: _sheetName,
        headers: List<String>.from(_headers),
        colIds: List<String>.from(_colIds),
        columnPrefsById: _cloneColumnPrefs(_columnPrefsById),
        columnOrder: List<String>.from(_columnOrder),
        frozenColId: _frozenColId,
        // ??? Undo incluye metadata de fotos SIN thumbs (revierte count/filas, sin lag).
        rowModels:
            _rows.map((r) => r.copyForSnapshot()).toList(growable: false),
        cellMeta: _cloneCellMeta(_cellMeta),
        selRow: _selRow,
        selCol: _selCol,
      );

  void _pushUndoSnapshot() {
    final seeds = _pendingFormulaSeeds.isEmpty
        ? null
        : Set<_CellRef>.from(_pendingFormulaSeeds);
    _refreshFormulaCaches(changedSeeds: seeds);
    _pendingFormulaSeeds.clear();
    _undo.add(_snapshot());
    if (_undo.length > kMaxUndo) _undo.removeAt(0);
    _redo.clear();
  }

  void _undoOnce() {
    if (_undo.length <= 1) {
      _showActionSnack(
        'No hay mas cambios para deshacer.',
        isError: false,
        icon: Icons.undo_rounded,
      );
      return;
    }
    final current = _undo.removeLast();
    _redo.add(current);

    final prev = _undo.last;
    final maxRow = math.max(0, _rows.length - 1);
    final maxCol = math.max(0, _headers.length - 1);

    setState(() {
      _sheetName = prev.name;
      _headers = List<String>.from(prev.headers);
      _colIds = List<String>.from(prev.colIds);
      _columnPrefsById = _normalizeColumnPrefs(
        colIds: _colIds,
        incoming: prev.columnPrefsById,
      );
      _columnOrder = _normalizeColumnOrder(
        colIds: _colIds,
        incoming: prev.columnOrder,
      );
      _frozenColId = _normalizeFrozenColId(
        colIds: _colIds,
        requested: prev.frozenColId,
      );
      _rows = prev.rowModels.map((r) => r.copyForSnapshot()).toList();
      _cellMeta
        ..clear()
        ..addAll(_cloneCellMeta(prev.cellMeta));
      _setSelection(prev.selRow.clamp(0, maxRow), prev.selCol.clamp(0, maxCol));

      _isDirty = true;
      _rev++;
    });
    _refreshFormulaCaches(notifyRows: true);
    _syncRowVersionNotifiers();
    _updateSaveStatus();
    _syncSelectionController();

    _resetMobileRowCaches();
    _resetDraftsAndEditors();

    if (!_nameFocus.hasFocus) {
      _nameEC.text = _sheetName;
    }

    _queueSave();
    AppHaptics.selection();
  }

  void _redoOnce() {
    if (_redo.isEmpty) {
      _showActionSnack(
        'No hay cambios para rehacer.',
        isError: false,
        icon: Icons.redo_rounded,
      );
      return;
    }
    final snap = _redo.removeLast();
    _undo.add(snap);
    final maxRow = math.max(0, _rows.length - 1);
    final maxCol = math.max(0, _headers.length - 1);

    setState(() {
      _sheetName = snap.name;
      _headers = List<String>.from(snap.headers);
      _colIds = List<String>.from(snap.colIds);
      _columnPrefsById = _normalizeColumnPrefs(
        colIds: _colIds,
        incoming: snap.columnPrefsById,
      );
      _columnOrder = _normalizeColumnOrder(
        colIds: _colIds,
        incoming: snap.columnOrder,
      );
      _frozenColId = _normalizeFrozenColId(
        colIds: _colIds,
        requested: snap.frozenColId,
      );
      _rows = snap.rowModels.map((r) => r.copyForSnapshot()).toList();
      _cellMeta
        ..clear()
        ..addAll(_cloneCellMeta(snap.cellMeta));
      _setSelection(snap.selRow.clamp(0, maxRow), snap.selCol.clamp(0, maxCol));

      _isDirty = true;
      _rev++;
    });
    _refreshFormulaCaches(notifyRows: true);
    _syncRowVersionNotifiers();
    _updateSaveStatus();
    _syncSelectionController();

    _resetMobileRowCaches();
    _resetDraftsAndEditors();

    if (!_nameFocus.hasFocus) {
      _nameEC.text = _sheetName;
    }

    _queueSave();
    AppHaptics.selection();
  }
  // ------------------------------ Tema / Paleta ---------------------------

  _SheetPalette _palette(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final hair = math.max(0.5, 1.0 / dpr);
    final app = AppTheme.of(context);
    return _SheetPalette.fromApp(app, hairline: hair);
  }

  // ??? FIX: si el tema viene controlado desde arriba, no ???doble toggles???.
  void _toggleTheme() {
    widget.onToggleTheme?.call();
    if (widget.isLight != null) return; // controlado por StartPage
    setState(() => _isLight = !_isLight);
  }

  void _setEditorState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  String _densityLabel(_GridDensity density) {
    switch (density) {
      case _GridDensity.compact:
        return 'Compacto';
      case _GridDensity.normal:
        return 'Normal';
      case _GridDensity.roomy:
        return 'Amplio';
    }
  }

  _GridDensity? _densityFromPref(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    for (final v in _GridDensity.values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  Future<void> _loadGridDensity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefGridDensity);
      final parsed = _densityFromPref(raw);
      if (!mounted) return;
      if (parsed != null) {
        setState(() {
          _gridDensity = parsed;
          _gridDensityExplicit = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _setGridDensity(_GridDensity density) async {
    if (_gridDensity == density && _gridDensityExplicit) return;
    if (mounted) {
      setState(() {
        _gridDensity = density;
        _gridDensityExplicit = true;
      });
    } else {
      _gridDensity = density;
      _gridDensityExplicit = true;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefGridDensity, density.name);
    } catch (_) {}
  }

  bool _isAutoIncrementColumn(int c) {
    if (c < 0 || c >= _headers.length - 1) return false;
    final h = _headerLabel(c).toLowerCase();
    return h.contains('progres') ||
        h.contains('codigo') ||
        h.contains('code') ||
        h.contains('folio') ||
        RegExp(r'(^|[^a-z])id([^a-z]|$)').hasMatch(h);
  }

  Future<void> _loadEditorDefaultsPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsEditorDefaultsKey);
      Map decoded = const <String, Object?>{};
      if (raw != null && raw.trim().isNotEmpty) {
        final parsed = jsonDecode(raw);
        if (parsed is Map) {
          decoded = parsed;
        }
      }
      final nextDate = (decoded['defaultDateTodayEnabled'] as bool?) ?? true;
      final nextStatus = (decoded['defaultStatusOkEnabled'] as bool?) ?? true;
      final nextAutoIncrement =
          (decoded['autoIncrementIdEnabled'] as bool?) ?? false;
      final nextInlinePreviews =
          (decoded['cellInlinePreviewsEnabled'] as bool?) ?? true;
      final nextMobileCompact = (decoded['mobileCompactModeEnabled']
              as bool?) ??
          (prefs.getBool(_kPrefMobileCompactMode) ?? _mobileCompactModeEnabled);
      final nextZenMode = (decoded['zenModeEnabled'] as bool?) ??
          (prefs.getBool(_kPrefZenMode) ?? _zenModeEnabled);
      final nextMobileFocusCellMode =
          (decoded['mobileFocusCellModeEnabled'] as bool?) ??
              (prefs.getBool(_kPrefMobileFocusCellMode) ??
                  _mobileFocusCellModeEnabled);
      final nextFlowBotUseLocalLlm = (decoded['flowBotUseLocalLlm'] as bool?) ??
          (prefs.getBool(_kPrefFlowBotUseLocalLlm) ?? _flowBotUseLocalLlm);
      final fromJsonModelPath =
          (decoded['flowBotLocalModelPath'] as String?)?.trim() ?? '';
      final fromPrefModelPath =
          (prefs.getString(_kPrefFlowBotLocalModelPath) ?? '').trim();
      final nextFlowBotLocalModelPath =
          fromJsonModelPath.isNotEmpty ? fromJsonModelPath : fromPrefModelPath;
      if (!mounted) {
        _defaultDateTodayEnabled = nextDate;
        _defaultStatusOkEnabled = nextStatus;
        _autoIncrementIdEnabled = nextAutoIncrement;
        _cellInlinePreviewsEnabled = nextInlinePreviews;
        _mobileCompactModeEnabled = nextMobileCompact;
        _zenModeEnabled = nextZenMode;
        _mobileFocusCellModeEnabled = nextMobileFocusCellMode;
        _mobileTopBarCollapsed = nextZenMode;
        _flowBotUseLocalLlm = nextFlowBotUseLocalLlm;
        _flowBotLocalModelPath = nextFlowBotLocalModelPath;
        return;
      }
      setState(() {
        _defaultDateTodayEnabled = nextDate;
        _defaultStatusOkEnabled = nextStatus;
        _autoIncrementIdEnabled = nextAutoIncrement;
        _cellInlinePreviewsEnabled = nextInlinePreviews;
        _mobileCompactModeEnabled = nextMobileCompact;
        _zenModeEnabled = nextZenMode;
        _mobileFocusCellModeEnabled = nextMobileFocusCellMode;
        _mobileTopBarCollapsed = nextZenMode;
        _flowBotUseLocalLlm = nextFlowBotUseLocalLlm;
        _flowBotLocalModelPath = nextFlowBotLocalModelPath;
      });
    } catch (_) {}
  }

  Future<void> _saveEditorDefaultsPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsEditorDefaultsKey,
        jsonEncode(<String, dynamic>{
          'defaultDateTodayEnabled': _defaultDateTodayEnabled,
          'defaultStatusOkEnabled': _defaultStatusOkEnabled,
          'autoIncrementIdEnabled': _autoIncrementIdEnabled,
          'cellInlinePreviewsEnabled': _cellInlinePreviewsEnabled,
          'mobileCompactModeEnabled': _mobileCompactModeEnabled,
          'zenModeEnabled': _zenModeEnabled,
          'mobileFocusCellModeEnabled': _mobileFocusCellModeEnabled,
          'flowBotUseLocalLlm': _flowBotUseLocalLlm,
          'flowBotLocalModelPath': _flowBotLocalModelPath,
        }),
      );
      await prefs.setBool(_kPrefMobileCompactMode, _mobileCompactModeEnabled);
      await prefs.setBool(_kPrefZenMode, _zenModeEnabled);
      await prefs.setBool(
          _kPrefMobileFocusCellMode, _mobileFocusCellModeEnabled);
      await prefs.setBool(_kPrefFlowBotUseLocalLlm, _flowBotUseLocalLlm);
      await prefs.setString(
        _kPrefFlowBotLocalModelPath,
        _flowBotLocalModelPath,
      );
    } catch (_) {}
  }

  Future<void> _setEditorDefaultRules({
    bool? defaultDateTodayEnabled,
    bool? defaultStatusOkEnabled,
    bool? autoIncrementIdEnabled,
    bool? cellInlinePreviewsEnabled,
    bool? mobileCompactModeEnabled,
    bool? zenModeEnabled,
    bool? mobileFocusCellModeEnabled,
    bool? flowBotUseLocalLlm,
    String? flowBotLocalModelPath,
  }) async {
    final nextDate = defaultDateTodayEnabled ?? _defaultDateTodayEnabled;
    final nextStatus = defaultStatusOkEnabled ?? _defaultStatusOkEnabled;
    final nextAutoIncrement = autoIncrementIdEnabled ?? _autoIncrementIdEnabled;
    final nextInlinePreviews =
        cellInlinePreviewsEnabled ?? _cellInlinePreviewsEnabled;
    final nextMobileCompact =
        mobileCompactModeEnabled ?? _mobileCompactModeEnabled;
    final nextZenMode = zenModeEnabled ?? _zenModeEnabled;
    final nextMobileFocusCellMode =
        mobileFocusCellModeEnabled ?? _mobileFocusCellModeEnabled;
    final nextFlowBotUseLocalLlm = flowBotUseLocalLlm ?? _flowBotUseLocalLlm;
    final nextFlowBotLocalModelPath =
        (flowBotLocalModelPath ?? _flowBotLocalModelPath).trim();
    if (nextDate == _defaultDateTodayEnabled &&
        nextStatus == _defaultStatusOkEnabled &&
        nextAutoIncrement == _autoIncrementIdEnabled &&
        nextInlinePreviews == _cellInlinePreviewsEnabled &&
        nextMobileCompact == _mobileCompactModeEnabled &&
        nextZenMode == _zenModeEnabled &&
        nextMobileFocusCellMode == _mobileFocusCellModeEnabled &&
        nextFlowBotUseLocalLlm == _flowBotUseLocalLlm &&
        nextFlowBotLocalModelPath == _flowBotLocalModelPath) {
      return;
    }
    if (mounted) {
      setState(() {
        _defaultDateTodayEnabled = nextDate;
        _defaultStatusOkEnabled = nextStatus;
        _autoIncrementIdEnabled = nextAutoIncrement;
        _cellInlinePreviewsEnabled = nextInlinePreviews;
        _mobileCompactModeEnabled = nextMobileCompact;
        _zenModeEnabled = nextZenMode;
        _mobileFocusCellModeEnabled = nextMobileFocusCellMode;
        _mobileTopBarCollapsed = nextZenMode;
        _flowBotUseLocalLlm = nextFlowBotUseLocalLlm;
        _flowBotLocalModelPath = nextFlowBotLocalModelPath;
      });
      _bumpGridVersion();
    } else {
      _defaultDateTodayEnabled = nextDate;
      _defaultStatusOkEnabled = nextStatus;
      _autoIncrementIdEnabled = nextAutoIncrement;
      _cellInlinePreviewsEnabled = nextInlinePreviews;
      _mobileCompactModeEnabled = nextMobileCompact;
      _zenModeEnabled = nextZenMode;
      _mobileFocusCellModeEnabled = nextMobileFocusCellMode;
      _mobileTopBarCollapsed = nextZenMode;
      _flowBotUseLocalLlm = nextFlowBotUseLocalLlm;
      _flowBotLocalModelPath = nextFlowBotLocalModelPath;
    }
    await _saveEditorDefaultsPrefs();
  }

  String _flowBotSheetContextKey() {
    final sheetId = widget.sheetId.trim();
    if (sheetId.isNotEmpty) return 'sheet:$sheetId';
    return 'sheet:${_sheetName.trim()}';
  }

  String? _flowBotTemplateContextKey() {
    final templateKind = _sheetTemplateKind.trim();
    if (templateKind.isEmpty) return null;
    return 'template:$templateKind';
  }

  String _flowBotPersistenceContextKey() {
    return _flowBotTemplateContextKey() ?? _flowBotSheetContextKey();
  }

  List<String> _flowBotFallbackContextKeys() {
    final ordered = <String>[
      if (_flowBotTemplateContextKey() != null) _flowBotTemplateContextKey()!,
      _flowBotSheetContextKey(),
    ];
    return LinkedHashSet<String>.from(ordered).toList(growable: false);
  }

  Future<void> _loadFlowBotHistoryPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefFlowBotRecentByContext) ?? '';
      final decoded = FlowBotQuickStore.decodeRecentByContext(
        raw,
        limit: _maxFlowBotHistoryItems,
      );
      final templateContextKey = _flowBotTemplateContextKey();
      final sheetContextKey = _flowBotSheetContextKey();
      List<String> cleaned = const <String>[];
      for (final contextKey in _flowBotFallbackContextKeys()) {
        final stored = decoded[contextKey] ?? const <String>[];
        if (stored.isNotEmpty) {
          cleaned = List<String>.from(stored);
          break;
        }
      }
      if (cleaned.isEmpty) {
        final legacyRaw = prefs.getString(_kPrefFlowBotHistory) ?? '';
        cleaned = FlowBotQuickStore.normalizeRecentCommands(
          legacyRaw.trim().isEmpty
              ? const <Object?>[]
              : (jsonDecode(legacyRaw) as List<Object?>),
          limit: _maxFlowBotHistoryItems,
        );
      }
      if (templateContextKey != null &&
          cleaned.isNotEmpty &&
          (decoded[templateContextKey] ?? const <String>[]).isEmpty &&
          (decoded[sheetContextKey] ?? const <String>[]).isNotEmpty) {
        decoded[templateContextKey] = List<String>.from(cleaned);
        await prefs.setString(
          _kPrefFlowBotRecentByContext,
          FlowBotQuickStore.encodeRecentByContext(
            decoded,
            limit: _maxFlowBotHistoryItems,
          ),
        );
      }
      if (!mounted) {
        _flowBotHistory
          ..clear()
          ..addAll(cleaned);
        return;
      }
      setState(() {
        _flowBotHistory
          ..clear()
          ..addAll(cleaned);
      });
    } catch (_) {}
  }

  Future<void> _saveFlowBotHistoryPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contextKey = _flowBotPersistenceContextKey();
      final raw = prefs.getString(_kPrefFlowBotRecentByContext) ?? '';
      final decoded = FlowBotQuickStore.decodeRecentByContext(
        raw,
        limit: _maxFlowBotHistoryItems,
      );
      decoded[contextKey] = List<String>.from(_flowBotHistory);
      await prefs.setString(
        _kPrefFlowBotRecentByContext,
        FlowBotQuickStore.encodeRecentByContext(
          decoded,
          limit: _maxFlowBotHistoryItems,
        ),
      );
    } catch (_) {}
  }

  Future<void> _rememberFlowBotHistory(String command) async {
    final next = FlowBotQuickStore.rememberRecent(
      _flowBotHistory,
      command,
      limit: _maxFlowBotHistoryItems,
    );
    if (listEquals(next, _flowBotHistory)) return;
    if (mounted) {
      setState(() {
        _flowBotHistory
          ..clear()
          ..addAll(next);
      });
    } else {
      _flowBotHistory
        ..clear()
        ..addAll(next);
    }
    await _saveFlowBotHistoryPrefs();
  }

  Future<void> _loadFlowBotFavoritesPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefFlowBotFavoritesByContext) ?? '';
      final decoded = FlowBotQuickStore.decodeFavoritesByContext(
        raw,
        limit: _maxFlowBotFavoriteItems,
      );
      final templateContextKey = _flowBotTemplateContextKey();
      final sheetContextKey = _flowBotSheetContextKey();
      List<FlowBotFavoriteShortcut> favorites =
          const <FlowBotFavoriteShortcut>[];
      for (final contextKey in _flowBotFallbackContextKeys()) {
        final stored = decoded[contextKey] ?? const <FlowBotFavoriteShortcut>[];
        if (stored.isNotEmpty) {
          favorites = List<FlowBotFavoriteShortcut>.from(stored);
          break;
        }
      }
      if (templateContextKey != null &&
          favorites.isNotEmpty &&
          (decoded[templateContextKey] ?? const <FlowBotFavoriteShortcut>[])
              .isEmpty &&
          (decoded[sheetContextKey] ?? const <FlowBotFavoriteShortcut>[])
              .isNotEmpty) {
        decoded[templateContextKey] =
            List<FlowBotFavoriteShortcut>.from(favorites);
        await prefs.setString(
          _kPrefFlowBotFavoritesByContext,
          FlowBotQuickStore.encodeFavoritesByContext(
            decoded,
            limit: _maxFlowBotFavoriteItems,
          ),
        );
      }
      if (!mounted) {
        _flowBotFavorites
          ..clear()
          ..addAll(favorites);
        return;
      }
      setState(() {
        _flowBotFavorites
          ..clear()
          ..addAll(favorites);
      });
    } catch (_) {}
  }

  Future<void> _saveFlowBotFavoritesPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contextKey = _flowBotPersistenceContextKey();
      final raw = prefs.getString(_kPrefFlowBotFavoritesByContext) ?? '';
      final decoded = FlowBotQuickStore.decodeFavoritesByContext(
        raw,
        limit: _maxFlowBotFavoriteItems,
      );
      decoded[contextKey] =
          List<FlowBotFavoriteShortcut>.from(_flowBotFavorites);
      await prefs.setString(
        _kPrefFlowBotFavoritesByContext,
        FlowBotQuickStore.encodeFavoritesByContext(
          decoded,
          limit: _maxFlowBotFavoriteItems,
        ),
      );
    } catch (_) {}
  }

  FlowBotFavoriteShortcut _flowBotFavoriteForCommand(String command) {
    return FlowBotFavoriteShortcut(
      kind: 'command',
      label: command.trim(),
      command: command.trim(),
    );
  }

  FlowBotFavoriteShortcut _flowBotFavoriteForAction(
    _FlowBotQuickActionSpec action,
  ) {
    return FlowBotFavoriteShortcut(
      kind: 'quick_action',
      label: action.label,
      quickActionId: action.id,
      requiresValuePrompt: action.requiresValue,
    );
  }

  bool _isFlowBotFavoriteCommand(String command) {
    return FlowBotQuickStore.containsFavorite(
      _flowBotFavorites,
      _flowBotFavoriteForCommand(command),
    );
  }

  bool _isFlowBotFavoriteAction(_FlowBotQuickActionSpec action) {
    return FlowBotQuickStore.containsFavorite(
      _flowBotFavorites,
      _flowBotFavoriteForAction(action),
    );
  }

  Future<bool> _toggleFlowBotFavoriteEntry(
    FlowBotFavoriteShortcut entry,
  ) async {
    final existed =
        FlowBotQuickStore.containsFavorite(_flowBotFavorites, entry);
    final next = FlowBotQuickStore.toggleFavorite(
      _flowBotFavorites,
      entry,
      limit: _maxFlowBotFavoriteItems,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (mounted) {
      setState(() {
        _flowBotFavorites
          ..clear()
          ..addAll(next);
      });
    } else {
      _flowBotFavorites
        ..clear()
        ..addAll(next);
    }
    await _saveFlowBotFavoritesPrefs();
    final label = entry.label.trim().isEmpty ? 'Favorito' : entry.label.trim();
    _showActionSnack(
      existed ? 'Favorito quitado: $label' : 'Favorito guardado: $label',
      isError: false,
      icon: existed ? Icons.star_border_rounded : Icons.star_rounded,
    );
    return !existed;
  }

  String _normalizeFlowBotScopeToken(String raw) {
    final normalized = _normalizeFlowBotToken(raw);
    if (normalized.contains('celda')) return 'celda';
    if (normalized.contains('fila')) return 'fila';
    if (normalized.contains('columna')) return 'columna';
    return 'seleccion';
  }

  Future<void> _loadFlowBotUiPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedScope = _normalizeFlowBotScopeToken(
          prefs.getString(_kPrefFlowBotLastScope) ?? '');
      final fieldMode = prefs.getBool(_kPrefFieldMode) ?? _fieldModeEnabled;
      final macrosRaw = prefs.getString(_kPrefFlowBotMacros);
      final macros = FlowBotMacroStore.decode(macrosRaw ?? '', maxItems: 24);
      if (!mounted) {
        _flowBotLastScope = savedScope;
        _fieldModeEnabled = fieldMode;
        _flowBotMacros
          ..clear()
          ..addAll(macros);
        return;
      }
      setState(() {
        _flowBotLastScope = savedScope;
        _fieldModeEnabled = fieldMode;
        _flowBotMacros
          ..clear()
          ..addAll(macros);
      });
    } catch (_) {}
  }

  Future<void> _saveFlowBotUiPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefFlowBotLastScope, _flowBotLastScope);
      await prefs.setBool(_kPrefFieldMode, _fieldModeEnabled);
      await prefs.setString(
        _kPrefFlowBotMacros,
        FlowBotMacroStore.encode(_flowBotMacros),
      );
    } catch (_) {}
  }

  Future<void> _setFlowBotLastScope(String scope) async {
    final next = _normalizeFlowBotScopeToken(scope);
    if (_flowBotLastScope == next) return;
    if (mounted) {
      setState(() => _flowBotLastScope = next);
    } else {
      _flowBotLastScope = next;
    }
    await _saveFlowBotUiPrefs();
  }

  Future<void> _toggleFieldMode() async {
    final next = !_fieldModeEnabled;
    if (mounted) {
      setState(() => _fieldModeEnabled = next);
    } else {
      _fieldModeEnabled = next;
    }
    await _setEditorDefaultRules(mobileCompactModeEnabled: true);
    await _setGridDensity(next ? _GridDensity.roomy : _GridDensity.normal);
    await _saveFlowBotUiPrefs();
    if (!mounted) return;
    _emitActionResult(
      _ActionResult(
        ok: true,
        message: next
            ? 'Modo campo activado: UI simplificada y movimiento reducido.'
            : 'Modo campo desactivado.',
      ),
      successIcon: Icons.terrain_rounded,
    );
  }

  List<FlowBotAction> _applyScopeToFlowBotActions(
    List<FlowBotAction> actions,
    String scope,
  ) {
    final normalizedScope = _normalizeFlowBotScopeToken(scope);
    return actions.map((action) {
      if (action.type == FlowBotActionType.setToday) {
        final value = switch (normalizedScope) {
          'celda' => 'celda activa',
          'fila' => 'fila',
          'columna' => 'columna completa',
          _ => 'seleccion',
        };
        return FlowBotAction(
          type: action.type,
          format: action.format,
          value: value,
          row: action.row,
          col: action.col,
          rowEnd: action.rowEnd,
          colEnd: action.colEnd,
          column: action.column,
          count: action.count,
          align: action.align,
          lines: action.lines,
          status: action.status,
          start: action.start,
          step: action.step,
          fromRow: action.fromRow,
          presetId: action.presetId,
        );
      }
      if (action.type == FlowBotActionType.clearSelection ||
          action.type == FlowBotActionType.clearRow) {
        return FlowBotAction(
          type: action.type,
          value: normalizedScope,
          row: action.row,
          col: action.col,
          rowEnd: action.rowEnd,
          colEnd: action.colEnd,
          column: action.column,
          count: action.count,
          align: action.align,
          lines: action.lines,
          status: action.status,
          format: action.format,
          start: action.start,
          step: action.step,
          fromRow: action.fromRow,
          presetId: action.presetId,
        );
      }
      return action;
    }).toList(growable: false);
  }

  bool _flowBotActionsSupportScope(List<FlowBotAction> actions) {
    for (final action in actions) {
      if (action.type == FlowBotActionType.setToday ||
          action.type == FlowBotActionType.clearSelection ||
          action.type == FlowBotActionType.clearRow) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _flowBotHasLocalModel() async {
    return _flowBotLocalModelManager.modelExists(_flowBotLocalModelPath);
  }

  Future<void> _downloadFlowBotLocalModel() async {
    if (_flowBotModelDownloading) return;
    if (!mounted) return;
    setState(() {
      _flowBotModelDownloading = true;
      _flowBotModelDownloadProgress = 0;
    });
    final result = await _flowBotLocalModelManager.downloadDefaultModel(
      onProgress: (progress) {
        if (!mounted) return;
        setState(() {
          _flowBotModelDownloadProgress = progress.clamp(0.0, 1.0);
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _flowBotModelDownloading = false;
      if (result.ok && (result.modelPath?.trim().isNotEmpty ?? false)) {
        _flowBotLocalModelPath = result.modelPath!.trim();
        _flowBotUseLocalLlm = true;
      }
    });
    await _saveEditorDefaultsPrefs();
    if (!mounted) return;
    _showActionSnack(
      result.ok
          ? 'Modelo local descargado (${_formatBytes(result.bytes)}).'
          : (result.error ?? 'No se pudo descargar el modelo local.'),
      isError: !result.ok,
      icon:
          result.ok ? Icons.download_done_rounded : Icons.error_outline_rounded,
    );
  }

  bool _isValidExportPreset(String preset) {
    return preset == 'pdf' || preset == 'xlsx' || preset == 'zip';
  }

  Future<void> _loadExportPresetPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_kPrefExportPreset) ?? '').trim();
      if (!_isValidExportPreset(raw)) return;
      if (!mounted) {
        _lastExportPreset = raw;
        return;
      }
      setState(() => _lastExportPreset = raw);
    } catch (_) {}
  }

  Future<void> _setExportPresetPref(String preset) async {
    if (!_isValidExportPreset(preset)) return;
    if (preset != _lastExportPreset) {
      if (mounted) {
        setState(() => _lastExportPreset = preset);
      } else {
        _lastExportPreset = preset;
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefExportPreset, preset);
    } catch (_) {}
  }

  Future<void> _loadRecentValuesFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsRecentValuesKey);
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((key, value) {
        final col = int.tryParse(key.toString());
        if (col == null || col < 0 || col >= _headers.length - 1) return;
        if (value is! List) return;
        final sanitized = <String>[];
        for (final item in value) {
          final text = item.toString().trim();
          if (text.isEmpty) continue;
          if (sanitized.any(
            (existing) => existing.toLowerCase() == text.toLowerCase(),
          )) {
            continue;
          }
          sanitized.add(text);
          if (sanitized.length >= _maxPersistedRecentValuesPerColumn) break;
        }
        if (sanitized.isEmpty) return;
        final current = _recentValuesByCol[col] ?? <String>[];
        final merged = <String>[...current];
        for (final entry in sanitized) {
          if (merged.any(
            (existing) => existing.toLowerCase() == entry.toLowerCase(),
          )) {
            continue;
          }
          merged.add(entry);
        }
        _recentValuesByCol[col] = merged;
      });
    } catch (_) {}
  }

  void _scheduleRecentValuesPersist() {
    _recentValuesSaveT?.cancel();
    _recentValuesSaveT = Timer(const Duration(milliseconds: 450), () {
      unawaited(_persistRecentValuesNow());
    });
  }

  Future<void> _persistRecentValuesNow() async {
    if (_recentValuesByCol.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefsRecentValuesKey);
      } catch (_) {}
      return;
    }
    try {
      final payload = <String, List<String>>{};
      _recentValuesByCol.forEach((col, items) {
        final cleaned = <String>[];
        for (final item in items) {
          final text = item.trim();
          if (text.isEmpty) continue;
          if (cleaned.any(
            (existing) => existing.toLowerCase() == text.toLowerCase(),
          )) {
            continue;
          }
          cleaned.add(text);
          if (cleaned.length >= _maxPersistedRecentValuesPerColumn) break;
        }
        if (cleaned.isEmpty) return;
        payload['$col'] = cleaned;
      });
      final prefs = await SharedPreferences.getInstance();
      if (payload.isEmpty) {
        await prefs.remove(_prefsRecentValuesKey);
      } else {
        await prefs.setString(_prefsRecentValuesKey, jsonEncode(payload));
      }
    } catch (_) {}
  }

  Future<void> _loadColumnTemplatesPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_kPrefColumnTemplates) ?? '').trim();
      if (raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final templates = <_ColumnTemplate>[];
      for (final item in decoded) {
        final parsed = _ColumnTemplate.fromJson(item);
        if (parsed == null) continue;
        templates.add(parsed);
      }
      templates.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      if (!mounted) {
        _columnTemplates
          ..clear()
          ..addAll(templates);
        return;
      }
      setState(() {
        _columnTemplates
          ..clear()
          ..addAll(templates);
      });
    } catch (_) {}
  }

  Future<void> _persistColumnTemplatesPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_columnTemplates.isEmpty) {
        await prefs.remove(_kPrefColumnTemplates);
        return;
      }
      final payload = _columnTemplates
          .map((entry) => entry.toJson())
          .toList(growable: false);
      await prefs.setString(_kPrefColumnTemplates, jsonEncode(payload));
    } catch (_) {}
  }

  Future<void> _loadSavedViewsPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_prefsSavedViewsKey) ?? '').trim();
      final activeRaw = (prefs.getString(_prefsActiveViewKey) ?? '').trim();
      final loaded = <_SavedView>[];
      if (raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            final parsed = _SavedView.fromJson(item);
            if (parsed == null) continue;
            loaded.add(parsed);
          }
        }
      }
      loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final activeId = activeRaw.isEmpty
          ? null
          : loaded.any((view) => view.id == activeRaw)
              ? activeRaw
              : null;

      if (!mounted) {
        _savedViews
          ..clear()
          ..addAll(loaded);
        _activeSavedViewId = activeId;
        _invalidateRowViewCache();
        return;
      }
      setState(() {
        _savedViews
          ..clear()
          ..addAll(loaded);
        _activeSavedViewId = activeId;
        _invalidateRowViewCache();
      });
      _applySavedViewColumns(activeId, announce: false, persistActive: false);
    } catch (_) {}
  }

  Future<void> _persistSavedViewsPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_savedViews.isEmpty) {
        await prefs.remove(_prefsSavedViewsKey);
      } else {
        final payload =
            _savedViews.map((entry) => entry.toJson()).toList(growable: false);
        await prefs.setString(_prefsSavedViewsKey, jsonEncode(payload));
      }
      final active = _activeSavedView;
      if (active == null) {
        await prefs.remove(_prefsActiveViewKey);
      } else {
        await prefs.setString(_prefsActiveViewKey, active.id);
      }
    } catch (_) {}
  }

  Future<void> _loadHistoryLogPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_prefsHistoryKey) ?? '').trim();
      if (raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final loaded = <HistoryEventRecord>[];
      for (final item in decoded) {
        final parsed = HistoryEventRecord.fromJson(item);
        if (parsed == null) continue;
        loaded.add(parsed);
      }
      final trimmed = HistoryEventRecord.trim(loaded);
      if (!mounted) {
        _historyEvents
          ..clear()
          ..addAll(trimmed);
        return;
      }
      setState(() {
        _historyEvents
          ..clear()
          ..addAll(trimmed);
      });
    } catch (_) {}
  }

  Future<void> _persistHistoryNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = HistoryEventRecord.trim(_historyEvents);
      if (trimmed.isEmpty) {
        await prefs.remove(_prefsHistoryKey);
        return;
      }
      await prefs.setString(
        _prefsHistoryKey,
        jsonEncode(
          trimmed.map((item) => item.toJson()).toList(growable: false),
        ),
      );
    } catch (_) {}
  }

  void _scheduleHistoryPersist() {
    _historyPersistT?.cancel();
    _historyPersistT = Timer(const Duration(milliseconds: 420), () {
      unawaited(_persistHistoryNow());
    });
  }

  void _addHistoryEvent({
    required String type,
    required String message,
    required String origin,
    int? row,
    int? col,
    String? beforeValue,
    String? afterValue,
  }) {
    final next = HistoryEventRecord(
      id: _genStableId('hist_'),
      at: DateTime.now(),
      type: type,
      message: message,
      origin: origin,
      row: row,
      col: col,
      beforeValue: beforeValue,
      afterValue: afterValue,
    );
    if (mounted) {
      setState(() {
        _historyEvents.insert(0, next);
        final trimmed = HistoryEventRecord.trim(_historyEvents);
        _historyEvents
          ..clear()
          ..addAll(trimmed);
      });
    } else {
      _historyEvents.insert(0, next);
      final trimmed = HistoryEventRecord.trim(_historyEvents);
      _historyEvents
        ..clear()
        ..addAll(trimmed);
    }
    _scheduleHistoryPersist();
  }

  _SavedView? get _activeSavedView {
    final id = _activeSavedViewId;
    if (id == null || id.isEmpty) return null;
    for (final view in _savedViews) {
      if (view.id == id) return view;
    }
    return null;
  }

  void _invalidateRowViewCache() {
    _rowViewCacheKey = '';
    _visibleRowIndexesCache = const <int>[];
    _displayRowToActualCache = const <int, int>{};
    _actualRowToDisplayCache = const <int, int>{};
    _visibleRowModelsCache = const <_RowModel>[];
  }

  _ColumnTemplate _buildColumnTemplate(String name) {
    final prefsByLabel = <String, _ColumnPrefs>{};
    for (int c = 0; c < _headers.length - 1; c++) {
      final label = _headerLabel(c);
      if (label.trim().isEmpty) continue;
      final colId = _colIds[c];
      final pref = _columnPrefsById[colId] ?? _defaultColumnPrefsFor(c);
      prefsByLabel[label] = pref.copyWith();
    }

    final orderLabels = <String>[];
    for (final colId in _normalizeColumnOrder(
      colIds: _colIds,
      incoming: _columnOrder,
    )) {
      final index = _colIds.indexOf(colId);
      if (index < 0 || index >= _headers.length - 1) continue;
      final label = _headerLabel(index).trim();
      if (label.isEmpty) continue;
      orderLabels.add(label);
    }

    String? frozenLabel;
    final frozenId = _normalizeFrozenColId(
      colIds: _colIds,
      requested: _frozenColId,
    );
    if (frozenId != null) {
      final frozenIndex = _colIds.indexOf(frozenId);
      if (frozenIndex >= 0 && frozenIndex < _headers.length - 1) {
        final label = _headerLabel(frozenIndex).trim();
        if (label.isNotEmpty) frozenLabel = label;
      }
    }

    return _ColumnTemplate(
      name: name.trim(),
      savedAt: DateTime.now(),
      prefsByLabel: prefsByLabel,
      orderLabels: orderLabels,
      frozenLabel: frozenLabel,
    );
  }

  Future<void> _saveCurrentColumnsAsTemplate() async {
    if (!mounted) return;
    final controller = TextEditingController(text: _sheetName.trim());
    final accepted = await showAppModal<bool>(
      context: context,
      title: 'Guardar columnas como plantilla',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nombre de plantilla'),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 1,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Ej: Checklist diario'),
          ),
        ],
      ),
      actions: [
        AppButton(
          label: AppStrings.cancel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: AppStrings.save,
          icon: Icons.bookmark_add_outlined,
          variant: AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
    final name = controller.text.trim();
    controller.dispose();
    if (accepted != true || name.isEmpty) return;

    final template = _buildColumnTemplate(name);
    setState(() {
      _columnTemplates.removeWhere(
        (item) => item.name.toLowerCase() == name.toLowerCase(),
      );
      _columnTemplates.insert(0, template);
    });
    await _persistColumnTemplatesPref();
    _showActionSnack(
      'Plantilla "$name" guardada.',
      isError: false,
      icon: Icons.bookmark_added_rounded,
    );
  }

  void _applyColumnTemplate(_ColumnTemplate template) {
    final labelToIndex = <String, int>{};
    for (int c = 0; c < _headers.length - 1; c++) {
      labelToIndex[_headerLabel(c).trim().toLowerCase()] = c;
    }

    final nextPrefs = _cloneColumnPrefs(_columnPrefsById);
    template.prefsByLabel.forEach((label, pref) {
      final colIndex = labelToIndex[label.trim().toLowerCase()];
      if (colIndex == null) return;
      final colId = _colIds[colIndex];
      nextPrefs[colId] = pref.copyWith();
    });

    final nextOrder = <String>[];
    final seen = <String>{};
    for (final label in template.orderLabels) {
      final colIndex = labelToIndex[label.trim().toLowerCase()];
      if (colIndex == null) continue;
      final colId = _colIds[colIndex];
      if (!seen.add(colId)) continue;
      nextOrder.add(colId);
    }
    for (int c = 0; c < _headers.length - 1; c++) {
      final colId = _colIds[c];
      if (!seen.add(colId)) continue;
      nextOrder.add(colId);
    }

    String? nextFrozen;
    if (template.frozenLabel != null) {
      final frozenIndex =
          labelToIndex[template.frozenLabel!.trim().toLowerCase()];
      if (frozenIndex != null) {
        nextFrozen = _colIds[frozenIndex];
      }
    }

    _applyColumnPrefsAndOrder(
      columnPrefsById: nextPrefs,
      columnOrder: nextOrder,
      frozenColId: nextFrozen,
    );
    _scheduleValidationRecompute(immediate: true);
    _showActionSnack(
      'Plantilla "${template.name}" aplicada.',
      isError: false,
      icon: Icons.auto_fix_high_rounded,
    );
  }

  Future<void> _openApplyColumnTemplateDialog() async {
    if (!mounted) return;
    if (_columnTemplates.isEmpty) {
      _showActionSnack(
        'No hay plantillas guardadas.',
        isError: false,
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    final selected = await showAppModal<_ColumnTemplate>(
      context: context,
      title: 'Aplicar plantilla de columnas',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _columnTemplates.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (ctx, index) {
            final template = _columnTemplates[index];
            final subtitle =
                '${template.prefsByLabel.length} columnas | ${_formatDateTimeShort(template.savedAt.toLocal())}';
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: _palette(ctx).hintBg,
              title: Text(template.name),
              subtitle: Text(subtitle),
              onTap: () => Navigator.of(context).pop(template),
            );
          },
        ),
      ),
      actions: [
        AppButton(
          label: AppStrings.close,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
    if (selected == null) return;
    _applyColumnTemplate(selected);
  }

  String _headerLabelByColId(String? colId) {
    final index = _columnIndexFromId(colId);
    if (index == null) return 'Sin columna';
    return _headerLabel(index);
  }

  String _savedViewSummary(_SavedView view) {
    final parts = <String>[];
    if ((view.statusValue ?? '').trim().isNotEmpty) {
      final label = _headerLabelByColId(view.statusColId);
      parts.add('$label = ${view.statusValue!.trim()}');
    }
    if ((view.textContains ?? '').trim().isNotEmpty) {
      final label = _headerLabelByColId(view.textColId);
      parts.add('$label contiene "${view.textContains!.trim()}"');
    }
    if (view.dateFrom != null || view.dateTo != null) {
      final label = _headerLabelByColId(view.dateColId);
      final fromLabel = view.dateFrom == null
          ? '--'
          : _formatDateTimeShort(view.dateFrom!.toLocal()).split(' ').first;
      final toLabel = view.dateTo == null
          ? '--'
          : _formatDateTimeShort(view.dateTo!.toLocal()).split(' ').first;
      parts.add('$label $fromLabel .. $toLabel');
    }
    if (view.sortColId != null) {
      final label = _headerLabelByColId(view.sortColId);
      parts.add(
        'Orden $label (${view.sortAscending ? 'ascendente' : 'descendente'})',
      );
    }
    if (parts.isEmpty) return 'Sin filtros';
    return parts.join(' | ');
  }

  void _applySavedViewColumns(
    String? id, {
    required bool announce,
    required bool persistActive,
  }) {
    final requestedId = (id ?? '').trim();
    _SavedView? view;
    if (requestedId.isNotEmpty) {
      for (final item in _savedViews) {
        if (item.id == requestedId) {
          view = item;
          break;
        }
      }
    }
    final nextActiveId = view?.id;
    final changed = _activeSavedViewId != nextActiveId;

    if (view != null) {
      _applyColumnPrefsAndOrder(
        columnPrefsById: view.columnPrefsById,
        columnOrder: view.columnOrder,
        frozenColId: view.frozenColId,
        snapshot: false,
      );
    }
    _activeSavedViewId = nextActiveId;
    _invalidateRowViewCache();
    final visibleRows = _visibleRowIndexes();
    if (visibleRows.isNotEmpty) {
      if (!visibleRows.contains(_selRow)) {
        _setSelection(visibleRows.first, _selCol, preserveRowSelection: false);
      } else {
        _selectedRows.removeWhere((row) => !visibleRows.contains(row));
      }
    }
    if (changed) {
      _bumpGridVersion();
      if (announce) {
        if (view == null) {
          _showActionSnack(
            'Vista base activa.',
            isError: false,
            icon: Icons.table_view_rounded,
          );
        } else {
          _showActionSnack(
            'Vista "${view.name}" aplicada.',
            isError: false,
            icon: Icons.visibility_rounded,
          );
        }
      }
      if (persistActive) {
        unawaited(_persistSavedViewsPref());
      }
    }
  }

  Future<void> _applySavedView(String? id) async {
    if (!mounted) return;
    setState(() {
      _applySavedViewColumns(id, announce: true, persistActive: false);
    });
    await _persistSavedViewsPref();
  }

  Future<void> _openSaveViewDialog({_SavedView? editView}) async {
    if (!mounted) return;
    final dataColumns = <({String id, String label, _ColType type})>[
      for (int c = 0; c < _headers.length - 1; c++)
        (id: _colIds[c], label: _headerLabel(c), type: _colType(c)),
    ];
    final statusColumns = dataColumns
        .where((entry) => entry.type == _ColType.status)
        .toList(growable: false);
    final dateColumns = dataColumns
        .where((entry) => entry.type == _ColType.date)
        .toList(growable: false);
    final textColumns = dataColumns
        .where(
          (entry) =>
              entry.type == _ColType.text ||
              entry.type == _ColType.status ||
              entry.type == _ColType.number ||
              entry.type == _ColType.date,
        )
        .toList(growable: false);

    final nameController = TextEditingController(
      text: editView?.name ?? 'Vista ${_savedViews.length + 1}',
    );
    final statusController = TextEditingController(
      text: editView?.statusValue ?? '',
    );
    final textController = TextEditingController(
      text: editView?.textContains ?? '',
    );
    final dateFromController = TextEditingController(
      text: editView?.dateFrom == null
          ? ''
          : _formatDateTimeShort(
              editView!.dateFrom!.toLocal(),
            ).split(' ').first,
    );
    final dateToController = TextEditingController(
      text: editView?.dateTo == null
          ? ''
          : _formatDateTimeShort(editView!.dateTo!.toLocal()).split(' ').first,
    );
    String? statusColId = editView?.statusColId ??
        (statusColumns.isNotEmpty ? statusColumns.first.id : null);
    String? textColId = editView?.textColId ??
        (textColumns.isNotEmpty ? textColumns.first.id : null);
    String? dateColId = editView?.dateColId ??
        (dateColumns.isNotEmpty ? dateColumns.first.id : null);
    String? sortColId = editView?.sortColId;
    bool sortAscending = editView?.sortAscending ?? true;
    bool saveResult = false;

    final accepted = await showAppModal<bool>(
      context: context,
      title: editView == null ? 'Guardar vista' : 'Editar vista',
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          final statusItems = <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Sin filtro de estado'),
            ),
            for (final column in statusColumns)
              DropdownMenuItem<String?>(
                value: column.id,
                child: Text(column.label),
              ),
          ];
          final textItems = <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Sin filtro de texto'),
            ),
            for (final column in textColumns)
              DropdownMenuItem<String?>(
                value: column.id,
                child: Text(column.label),
              ),
          ];
          final dateItems = <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Sin filtro de fecha'),
            ),
            for (final column in dateColumns)
              DropdownMenuItem<String?>(
                value: column.id,
                child: Text(column.label),
              ),
          ];
          final sortItems = <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Sin orden'),
            ),
            for (final column in dataColumns)
              DropdownMenuItem<String?>(
                value: column.id,
                child: Text(column.label),
              ),
          ];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                maxLines: 1,
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Nombre',
                  hintText: 'Ej: Revisi\u00f3n urgente',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: statusColId,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Filtro por estado',
                ),
                items: statusItems,
                onChanged: (value) => setModalState(() => statusColId = value),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: statusController,
                maxLines: 1,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Valor estado',
                  hintText: 'Ej: Urgente',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: textColId,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Filtro de texto',
                ),
                items: textItems,
                onChanged: (value) => setModalState(() => textColId = value),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                maxLines: 1,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Texto contiene',
                  hintText: 'Ej: bomba',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: dateColId,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Filtro de fecha',
                ),
                items: dateItems,
                onChanged: (value) => setModalState(() => dateColId = value),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dateFromController,
                      maxLines: 1,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Desde',
                        hintText: 'YYYY-MM-DD',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: dateToController,
                      maxLines: 1,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Hasta',
                        hintText: 'YYYY-MM-DD',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: sortColId,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Ordenar por',
                ),
                items: sortItems,
                onChanged: (value) => setModalState(() => sortColId = value),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Orden ascendente'),
                value: sortAscending,
                onChanged: sortColId == null
                    ? null
                    : (value) => setModalState(() => sortAscending = value),
              ),
            ],
          );
        },
      ),
      actions: [
        AppButton(
          label: AppStrings.cancel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: AppStrings.save,
          icon: Icons.bookmark_added_rounded,
          variant: AppButtonVariant.primary,
          onPressed: () {
            saveResult = true;
            Navigator.of(context).pop(true);
          },
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
    if (!mounted) {
      nameController.dispose();
      statusController.dispose();
      textController.dispose();
      dateFromController.dispose();
      dateToController.dispose();
      return;
    }

    final name = nameController.text.trim();
    final statusValue = statusController.text.trim();
    final textContains = textController.text.trim();
    final dateFromRaw = dateFromController.text.trim();
    final dateToRaw = dateToController.text.trim();
    final dateFrom = _parseDateCellValue(dateFromRaw);
    final dateTo = _parseDateCellValue(dateToRaw);
    nameController.dispose();
    statusController.dispose();
    textController.dispose();
    dateFromController.dispose();
    dateToController.dispose();

    if (accepted != true || !saveResult) return;
    if (name.isEmpty) {
      _showActionSnack(
        'Ingresa un nombre para la vista.',
        isError: true,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }
    if (dateFromRaw.isNotEmpty && dateFrom == null) {
      _showActionSnack(
        'Fecha "desde" invalida.',
        isError: true,
        icon: Icons.event_busy_rounded,
      );
      return;
    }
    if (dateToRaw.isNotEmpty && dateTo == null) {
      _showActionSnack(
        'Fecha "hasta" invalida.',
        isError: true,
        icon: Icons.event_busy_rounded,
      );
      return;
    }
    if (dateFrom != null &&
        dateTo != null &&
        _dateOnly(dateFrom).isAfter(_dateOnly(dateTo))) {
      _showActionSnack(
        'Rango de fecha invalido.',
        isError: true,
        icon: Icons.event_note_rounded,
      );
      return;
    }

    final now = DateTime.now();
    final next = _SavedView(
      id: editView?.id ?? _genStableId('view_'),
      name: name,
      createdAt: editView?.createdAt ?? now,
      statusColId: statusValue.isEmpty
          ? null
          : _columnIndexFromId(statusColId) == null
              ? null
              : statusColId,
      statusValue: statusValue.isEmpty ? null : statusValue,
      textColId: textContains.isEmpty
          ? null
          : _columnIndexFromId(textColId) == null
              ? null
              : textColId,
      textContains: textContains.isEmpty ? null : textContains,
      dateColId: (dateFrom == null && dateTo == null)
          ? null
          : _columnIndexFromId(dateColId) == null
              ? null
              : dateColId,
      dateFrom: dateFrom == null ? null : _dateOnly(dateFrom),
      dateTo: dateTo == null ? null : _dateOnly(dateTo),
      sortColId: _columnIndexFromId(sortColId) == null ? null : sortColId,
      sortAscending: sortAscending,
      columnPrefsById: _cloneColumnPrefs(_columnPrefsById),
      columnOrder: List<String>.from(_columnOrder),
      frozenColId: _frozenColId,
    );

    setState(() {
      _savedViews.removeWhere((view) => view.id == next.id);
      _savedViews.insert(0, next);
      _savedViews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _applySavedViewColumns(next.id, announce: false, persistActive: false);
    });
    await _persistSavedViewsPref();
    if (!mounted) return;
    _showActionSnack(
      'Vista "${next.name}" guardada.',
      isError: false,
      icon: Icons.visibility_rounded,
    );
  }

  Future<void> _renameSavedView(_SavedView view) async {
    if (!mounted) return;
    final controller = TextEditingController(text: view.name);
    final accepted = await showAppModal<bool>(
      context: context,
      title: 'Renombrar vista',
      child: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 1,
        decoration: const InputDecoration(isDense: true, labelText: 'Nombre'),
      ),
      actions: [
        AppButton(
          label: AppStrings.cancel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: AppStrings.save,
          variant: AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
    if (!mounted) {
      controller.dispose();
      return;
    }
    final nextName = controller.text.trim();
    controller.dispose();
    if (accepted != true || nextName.isEmpty) return;
    setState(() {
      final index = _savedViews.indexWhere((item) => item.id == view.id);
      if (index < 0) return;
      final current = _savedViews[index];
      _savedViews[index] = _SavedView(
        id: current.id,
        name: nextName,
        createdAt: current.createdAt,
        statusColId: current.statusColId,
        statusValue: current.statusValue,
        textColId: current.textColId,
        textContains: current.textContains,
        dateColId: current.dateColId,
        dateFrom: current.dateFrom,
        dateTo: current.dateTo,
        sortColId: current.sortColId,
        sortAscending: current.sortAscending,
        columnPrefsById: current.columnPrefsById,
        columnOrder: current.columnOrder,
        frozenColId: current.frozenColId,
      );
    });
    await _persistSavedViewsPref();
  }

  Future<void> _deleteSavedView(String id) async {
    _SavedView? removed;
    for (final view in _savedViews) {
      if (view.id == id) {
        removed = view;
        break;
      }
    }
    if (removed == null) return;
    setState(() {
      _savedViews.removeWhere((view) => view.id == id);
      if (_activeSavedViewId == id) {
        _applySavedViewColumns(null, announce: false, persistActive: false);
      }
    });
    await _persistSavedViewsPref();
    if (!mounted) return;
    _showActionSnack(
      'Vista "${removed.name}" eliminada.',
      isError: false,
      icon: Icons.delete_outline_rounded,
    );
  }

  Future<void> _openSavedViewsManager() async {
    if (!mounted) return;
    await showAppModal<void>(
      context: context,
      title: 'Vistas guardadas',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: _savedViews.isEmpty
            ? const Align(
                alignment: Alignment.centerLeft,
                child: Text('No hay vistas guardadas.'),
              )
            : StatefulBuilder(
                builder: (ctx, setModalState) {
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: _savedViews.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final view = _savedViews[index];
                      final isActive = view.id == _activeSavedViewId;
                      return ListTile(
                        tileColor: _palette(ctx).hintBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isActive
                                ? _palette(ctx).selectionBorder
                                : _palette(ctx).border,
                            width: _palette(ctx).hairline,
                          ),
                        ),
                        title: Text(view.name),
                        subtitle: Text(
                          _savedViewSummary(view),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          await _applySavedView(view.id);
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            switch (value) {
                              case 'apply':
                                Navigator.of(ctx).pop();
                                await _applySavedView(view.id);
                                break;
                              case 'edit':
                                Navigator.of(ctx).pop();
                                await _openSaveViewDialog(editView: view);
                                break;
                              case 'rename':
                                Navigator.of(ctx).pop();
                                await _renameSavedView(view);
                                break;
                              case 'delete':
                                Navigator.of(ctx).pop();
                                await _deleteSavedView(view.id);
                                break;
                            }
                            if (mounted) setModalState(() {});
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem<String>(
                              value: 'apply',
                              child: Text('Aplicar'),
                            ),
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Editar'),
                            ),
                            PopupMenuItem<String>(
                              value: 'rename',
                              child: Text('Renombrar'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
      ),
      actions: [
        AppButton(
          label: AppStrings.close,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
  }

  Future<void> _loadEditorTourPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(_kPrefEditorTourSeen) ?? false;
      final dismissed = prefs.getBool(_kPrefEditorTourDismissed) ?? false;
      final smartPasteInteracted =
          prefs.getBool(_kPrefSmartPasteInteracted) ?? false;
      final templateInteracted =
          prefs.getBool(_kPrefTemplateInteracted) ?? false;
      final shouldShow =
          !seen && !dismissed && !smartPasteInteracted && !templateInteracted;
      if (!mounted) {
        _editorTourDismissed = dismissed;
        _editorSmartPasteInteracted = smartPasteInteracted;
        _editorTemplateInteracted = templateInteracted;
        _editorTourVisible = shouldShow;
        return;
      }
      setState(() {
        _editorTourDismissed = dismissed;
        _editorSmartPasteInteracted = smartPasteInteracted;
        _editorTemplateInteracted = templateInteracted;
        _editorTourVisible = shouldShow;
      });
    } catch (_) {}
  }

  Future<void> _markSmartPasteInteracted() async {
    if (_editorSmartPasteInteracted) return;
    if (mounted) {
      setState(() {
        _editorSmartPasteInteracted = true;
        _editorTourVisible = false;
      });
    } else {
      _editorSmartPasteInteracted = true;
      _editorTourVisible = false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefSmartPasteInteracted, true);
      await prefs.setBool(_kPrefEditorTourSeen, true);
    } catch (_) {}
  }

  Future<void> _markTemplateInteracted() async {
    if (_editorTemplateInteracted) return;
    if (mounted) {
      setState(() {
        _editorTemplateInteracted = true;
        _editorTourVisible = false;
      });
    } else {
      _editorTemplateInteracted = true;
      _editorTourVisible = false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefTemplateInteracted, true);
      await prefs.setBool(_kPrefEditorTourSeen, true);
    } catch (_) {}
  }

  Future<void> _closeEditorTour({required bool dontShowAgain}) async {
    if (mounted) {
      setState(() {
        _editorTourVisible = false;
        if (dontShowAgain) _editorTourDismissed = true;
      });
    } else {
      _editorTourVisible = false;
      if (dontShowAgain) _editorTourDismissed = true;
    }
    AppHaptics.selection();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefEditorTourSeen, true);
      if (dontShowAgain) {
        await prefs.setBool(_kPrefEditorTourDismissed, true);
      }
    } catch (_) {}
  }

  void _reopenEditorTour() {
    if (_editorTourDismissed) {
      _showActionSnack(
        'El tour esta desactivado en este dispositivo.',
        isError: false,
        icon: Icons.info_outline_rounded,
      );
      return;
    }
    if (!mounted) return;
    setState(() => _editorTourVisible = true);
  }

  bool get _shouldShowAndroidInstallHelper {
    if (!kIsWeb) return false;
    if (!WebCapabilities.isAndroidChrome) return false;
    if (_androidInstallHelperDismissed || _androidInstallHelperHiddenSession) {
      return false;
    }
    if (WebCapabilities.isStandalone) return false;
    if (WebCapabilities.isInAppBrowser) return false;
    return true;
  }

  Future<void> _loadAndroidInstallHelperPref() async {
    if (!kIsWeb || !WebCapabilities.isAndroidChrome) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed =
          prefs.getBool(_kPrefAndroidInstallHelperDismissed) ?? false;
      if (!mounted) {
        _androidInstallHelperDismissed = dismissed;
        return;
      }
      setState(() => _androidInstallHelperDismissed = dismissed);
    } catch (_) {}
  }

  void _ackAndroidInstallHelper() {
    if (!mounted) return;
    setState(() => _androidInstallHelperHiddenSession = true);
  }

  Future<void> _dismissAndroidInstallHelperForever() async {
    if (mounted) {
      setState(() {
        _androidInstallHelperHiddenSession = true;
        _androidInstallHelperDismissed = true;
      });
    } else {
      _androidInstallHelperHiddenSession = true;
      _androidInstallHelperDismissed = true;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefAndroidInstallHelperDismissed, true);
    } catch (_) {}
  }

  void _setRecoveryStagingCandidate(String? raw) {
    final canRestore = _decodeSheetModelRaw(raw ?? '') != null;
    if (mounted) {
      setState(() {
        if (!canRestore) {
          _recoveryStagingRaw = null;
          _recoveryBannerVisible = false;
          return;
        }
        _recoveryStagingRaw = raw;
        _recoveryBannerVisible = true;
      });
      return;
    }
    if (!canRestore) {
      _recoveryStagingRaw = null;
      _recoveryBannerVisible = false;
    } else {
      _recoveryStagingRaw = raw;
      _recoveryBannerVisible = true;
    }
  }

  Future<void> _dismissRecoveryBanner({bool dropCandidate = false}) async {
    if (mounted) {
      setState(() => _recoveryBannerVisible = false);
    } else {
      _recoveryBannerVisible = false;
    }
    if (!dropCandidate) return;
    _recoveryStagingRaw = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeyStaging);
    } catch (_) {}
  }

  Future<void> _restoreStagingRecovery() async {
    final raw = _recoveryStagingRaw;
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final restored = await _tryRestoreFromRaw(
        prefs,
        raw: raw,
        source: 'prefs_staging',
        announceRecovery: true,
        syncAsCurrent: true,
      );
      if (!restored) {
        if (!mounted) return;
        _showActionSnack(
          'No se pudo restaurar la sesion previa.',
          isError: true,
          icon: Icons.history_toggle_off_rounded,
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _recoveryBannerVisible = false;
        _recoveryStagingRaw = null;
      });
      _showActionSnack(
        'Sesion previa restaurada.',
        isError: false,
        icon: Icons.history_rounded,
      );
      AppHaptics.light();
    } catch (e, st) {
      _reportFlowError(
        e,
        flow: AppErrorFlow.load,
        operation: 'restore_staging_recovery',
        stackTrace: st,
        icon: Icons.history_toggle_off_rounded,
      );
    }
  }

  // _showDensityPicker movido a dialogs/editor_dialogs.dart

  void _ensureDefaultDensity(bool isDesktop) {
    if (_gridDensityExplicit) return;
    final target = isDesktop ? _GridDensity.normal : _GridDensity.compact;
    if (_gridDensity == target) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _gridDensityExplicit) return;
      setState(() => _gridDensity = target);
    });
  }

  // ------------------------------ Utilidades UI ---------------------------

  bool _isMobileWeb() {
    if (!kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  bool get _isAndroidWeb =>
      kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _isIosWeb => kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  double _effectiveKeyboardInset(
    BuildContext context, {
    double? mediaQueryInset,
    double? controllerInset,
  }) {
    final mqInset = mediaQueryInset ?? MediaQuery.viewInsetsOf(context).bottom;
    if (!kIsWeb) return mqInset;

    final fallbackInset = math.max(mqInset, controllerInset ?? 0.0);
    return fallbackInset > 0.0 ? fallbackInset : 0.0;
  }

  bool _isDesktopUi(BuildContext context, double kbInset) {
    final size = MediaQuery.sizeOf(context);

    // Tel??fonos: SIEMPRE UI m??vil
    if (size.shortestSide < 600) return false;

    // Si el teclado est?? abierto, no uses overlay desktop
    if (kbInset > 0) return false;

    if (_isMobileWeb()) return false;

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
      return false;
    }

    final w = size.width;

    // En Web/Desktop, evitar depender de MouseTracker dentro de build: en modo debug puede
    // disparar asserts (mouse_tracker.dart: _debugDuringDeviceUpdate). El ancho es suficiente.
    return w >= 900;
  }

  void _blink(int r, int c) {
    _blinkT?.cancel();

    final ref = _CellRef(r, c);
    _blinkCell.value = ref;

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
      final now = DateTime.now();
      if (now.difference(_lastBlinkHapticAt) >=
          const Duration(milliseconds: 34)) {
        _lastBlinkHapticAt = now;
        try {
          if (defaultTargetPlatform == TargetPlatform.iOS) {
            HapticFeedback.lightImpact();
          } else {
            HapticFeedback.selectionClick();
          }
        } catch (_) {}
      }
    }

    _blinkT = Timer(_blinkDuration, () {
      if (!mounted) return;
      if (_blinkCell.value == ref) _blinkCell.value = null;
    });
  }

  void _markDirty({bool snapshot = true}) {
    if (snapshot && !_suspendUndoSnapshot) _pushUndoSnapshot();
    _rev++;

    if (mounted) {
      setState(() => _isDirty = true);
    } else {
      _isDirty = true;
    }
    _updateSaveStatus();
    unawaited(_enqueueEditPending());

    _queueSave();
    _scheduleBackupCheck();
    _scheduleValidationRecompute();
  }

  void _scheduleValidationRecompute({bool immediate = false}) {
    if (immediate) {
      _validationDebounceT?.cancel();
      _recomputeValidation();
      return;
    }
    _validationDebounceT?.cancel();
    _validationDebounceT = Timer(_validationDebounce, _recomputeValidation);
  }

  _ColType _inferColTypeFromHeader(String header) {
    final h = header.trim().toLowerCase();
    if (h.contains('check') || h.contains('bool') || h.contains('verif')) {
      return _ColType.checkbox;
    }
    if (h.contains('estado') || h.contains('status')) return _ColType.status;
    if (h.contains('fecha') || h.contains('date')) return _ColType.date;
    if (h.contains('hora') || h.contains('time')) return _ColType.date;
    if (h.contains('lat') || h.contains('lon') || h.contains('acc')) {
      return _ColType.number;
    }
    if (h.contains('progres') ||
        RegExp(r'(^|[^a-z])id([^a-z]|$)').hasMatch(h)) {
      return _ColType.number;
    }
    return _ColType.text;
  }

  _ColType _colType(int c) {
    if (c == _headers.length - 1) return _ColType.photos;
    if (c >= 0 && c < _colIds.length) {
      final colId = _colIds[c];
      final pref = _columnPrefsById[colId];
      if (pref != null) return pref.type;
    }
    return _inferColTypeFromHeader(_headerLabel(c));
  }

  int _defaultWrapLinesForType(_ColType type) {
    switch (type) {
      case _ColType.text:
      case _ColType.status:
        return 2;
      default:
        return 1;
    }
  }

  int _defaultWrapLinesForColumn(int c) {
    return _defaultWrapLinesForType(_colType(c));
  }

  _ColumnPrefs _defaultColumnPrefsFor(int c) {
    final type = _inferColTypeFromHeader(_headerLabel(c));
    return _ColumnPrefs(
      type: type,
      wrapLines: _defaultWrapLinesForType(type),
    );
  }

  int _colWrapLines(int c) {
    if (c >= 0 && c < _colIds.length) {
      final pref = _columnPrefsById[_colIds[c]];
      if (pref != null) {
        return pref.wrapLines.clamp(1, 3);
      }
    }
    return _defaultWrapLinesForColumn(c);
  }

  _GridTextAlignX _colTextAlign(int c) {
    if (c >= 0 && c < _colIds.length) {
      final pref = _columnPrefsById[_colIds[c]];
      if (pref != null) return pref.textAlign;
    }
    return _GridTextAlignX.left;
  }

  _GridTextAlignY _colVerticalAlign(int c) {
    if (c >= 0 && c < _colIds.length) {
      final pref = _columnPrefsById[_colIds[c]];
      if (pref != null) return pref.verticalAlign;
    }
    return _GridTextAlignY.middle;
  }

  List<String>? _statusOptionsForCol(int c) {
    if (_colType(c) != _ColType.status) return null;
    if (c >= 0 && c < _colIds.length) {
      final pref = _columnPrefsById[_colIds[c]];
      final enums = pref?.enumValues ?? const <String>[];
      if (enums.isNotEmpty) return enums;
    }
    return const <String>['OK', 'Obs', 'Urgente'];
  }

  DateTime? _parseDateCellValue(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final slash = RegExp(
      r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})(?:\s+(\d{1,2}):(\d{2}))?$',
    ).firstMatch(text);
    if (slash != null) {
      final d = int.tryParse(slash.group(1) ?? '');
      final m = int.tryParse(slash.group(2) ?? '');
      final y = int.tryParse(slash.group(3) ?? '');
      final hh = int.tryParse(slash.group(4) ?? '0') ?? 0;
      final mm = int.tryParse(slash.group(5) ?? '0') ?? 0;
      if (y != null && m != null && d != null) {
        final date = DateTime(y, m, d, hh, mm);
        if (date.year == y && date.month == m && date.day == d) {
          return date;
        }
        return null;
      }
    }
    final iso = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:\s+(\d{1,2}):(\d{2}))?$',
    ).firstMatch(text);
    if (iso != null) {
      final y = int.tryParse(iso.group(1) ?? '');
      final m = int.tryParse(iso.group(2) ?? '');
      final d = int.tryParse(iso.group(3) ?? '');
      final hh = int.tryParse(iso.group(4) ?? '0') ?? 0;
      final mm = int.tryParse(iso.group(5) ?? '0') ?? 0;
      if (y != null && m != null && d != null) {
        final date = DateTime(y, m, d, hh, mm);
        if (date.year == y && date.month == m && date.day == d) {
          return date;
        }
        return null;
      }
    }
    return DateTime.tryParse(text);
  }

  String _formatDateCellValue(DateTime value) {
    final local = value.toLocal();
    return '${_two(local.day)}/${_two(local.month)}/${local.year}';
  }

  double? _parseNumberCellValue(String raw) {
    final normalized = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String _formatNumberCellValue(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.0000001) {
      return rounded.toInt().toString();
    }
    final fixed = value.toStringAsFixed(6);
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  bool? _parseCheckboxCellValue(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;
    if (value == '1' ||
        value == 'true' ||
        value == 'si' ||
        value == 's\u00ed' ||
        value == 'ok' ||
        value == 'x') {
      return true;
    }
    if (value == '0' || value == 'false' || value == 'no' || value == 'off') {
      return false;
    }
    return null;
  }

  String _normalizeCellValueForColumn(int c, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    if (_isFormulaText(trimmed)) return trimmed;
    final type = _colType(c);
    switch (type) {
      case _ColType.status:
        final options = _statusOptionsForCol(c) ?? const <String>[];
        for (final item in options) {
          if (item.toLowerCase() == trimmed.toLowerCase()) {
            return item;
          }
        }
        return trimmed;
      case _ColType.date:
        final parsed = _parseDateCellValue(trimmed);
        if (parsed == null) return trimmed;
        return _formatDateCellValue(parsed);
      case _ColType.number:
        final parsed = _parseNumberCellValue(trimmed);
        if (parsed == null) return trimmed;
        return _formatNumberCellValue(parsed);
      case _ColType.checkbox:
        final parsed = _parseCheckboxCellValue(trimmed);
        if (parsed == null) return trimmed;
        return parsed ? '1' : '0';
      default:
        return trimmed;
    }
  }

  bool _isRequired(int c) {
    if (c >= 0 && c < _colIds.length) {
      final pref = _columnPrefsById[_colIds[c]];
      if (pref?.required == true) return true;
    }
    final h = _headerLabel(c).toLowerCase();
    return h.startsWith('fecha') || h.startsWith('actividad');
  }

  ColumnValidationRule _columnValidationRule(int col) {
    final type = _colType(col);
    final pref = (col >= 0 && col < _colIds.length)
        ? _columnPrefsById[_colIds[col]]
        : null;
    String ruleType;
    switch (type) {
      case _ColType.number:
        ruleType = 'number';
        break;
      case _ColType.date:
        ruleType = 'date';
        break;
      case _ColType.status:
        ruleType = 'status';
        break;
      default:
        ruleType = 'text';
        break;
    }
    return ColumnValidationRule(
      type: ruleType,
      required: _isRequired(col),
      numberMin: pref?.numberMin,
      numberMax: pref?.numberMax,
      enumValues: _statusOptionsForCol(col) ?? const <String>[],
      regexPattern: pref?.regexPattern,
    );
  }

  String? _validationMessageForValue({
    required int col,
    required String rawValue,
  }) {
    if (col < 0 || col >= _headers.length - 1) return null;
    if (_isFormulaText(rawValue)) {
      final parsed = _formulaEngine.tryParse(rawValue);
      return parsed == null ? 'Formula invalida' : null;
    }
    if (_colType(col) == _ColType.checkbox) {
      final value = rawValue.trim();
      if (value.isEmpty && _isRequired(col)) return 'Campo requerido';
      if (value.isEmpty) return null;
      return _parseCheckboxCellValue(value) == null
          ? 'Valor invalido (usa si/no, true/false, 1/0)'
          : null;
    }
    final rule = _columnValidationRule(col);
    return rule.validate(
      rawValue,
      parseDate: _parseDateCellValue,
      parseNumber: _parseNumberCellValue,
    );
  }

  String? _validationMessageForCell(int row, int col, {String? overrideValue}) {
    if (row < 0 || row >= _rows.length) return null;
    if (col < 0 || col >= _headers.length - 1) return null;
    final raw = overrideValue ?? _rows[row].cells[col];
    return _validationMessageForValue(col: col, rawValue: raw);
  }

  List<_ValidationIssue> _validationIssues() {
    if (_invalidCells.isEmpty) return const <_ValidationIssue>[];
    final list = <_ValidationIssue>[];
    for (final ref in _invalidCells) {
      if (ref.r < 0 || ref.r >= _rows.length) continue;
      if (ref.c < 0 || ref.c >= _headers.length - 1) continue;
      final message = _invalidCellMessages[ref] ?? 'Valor invalido';
      list.add(
        _ValidationIssue(
          ref: ref,
          label: _cellLabelRc(ref.r, ref.c),
          message: message,
        ),
      );
    }
    list.sort((a, b) {
      final rowCmp = a.ref.r.compareTo(b.ref.r);
      if (rowCmp != 0) return rowCmp;
      return a.ref.c.compareTo(b.ref.c);
    });
    return list;
  }

  int _sheetEvidenceCount() {
    var total = 0;
    for (final meta in _cellMeta.values) {
      total += meta.photos.length;
      total += meta.audios.length;
      if (meta.gps != null) total += 1;
    }
    return total;
  }

  String _sheetQualityHeadline(_SheetQualitySnapshot quality) {
    if (quality.rowsWithData <= 0) {
      return 'Sin registros cargados todavia.';
    }
    final requiredPct = quality.requiredCompletionPercent;
    final readyBase = math.max(quality.rowsWithData, quality.rowsTotal);
    if (quality.hasIssues) {
      return '${quality.statusLabel} | $requiredPct% de campos obligatorios completos | ${quality.rowsReady}/$readyBase filas listas';
    }
    return '${quality.statusLabel} | $requiredPct% de campos obligatorios completos | ${quality.rowsReady}/$readyBase filas listas';
  }

  String _sheetQualityDetail(
    _SheetQualitySnapshot quality, {
    int? evidenceCount,
  }) {
    final parts = <String>[];
    if (quality.invalidCells > 0) {
      parts.add('${quality.invalidCells} error(es)');
    }
    if (quality.pendingRequired > 0) {
      parts.add('${quality.pendingRequired} obligatorio(s) pendiente(s)');
    }
    if ((evidenceCount ?? 0) > 0) {
      parts.add('${evidenceCount!} evidencia(s)');
    }
    if (parts.isEmpty) {
      return quality.rowsWithData > 0
          ? 'La planilla esta lista para exportar o compartir.'
          : 'Empieza cargando filas para ver el estado operativo.';
    }
    return parts.join(' | ');
  }

  String get _sheetQualityHeaderLabel {
    final quality = _sheetQuality;
    if (quality.rowsWithData <= 0 && !quality.hasIssues) {
      return 'Sin carga';
    }
    return 'Calidad ${quality.requiredCompletionPercent}%';
  }

  String get _sheetQualityHeaderDetail {
    final quality = _sheetQuality;
    if (quality.rowsWithData <= 0) {
      return 'Sin filas cargadas todavia.';
    }
    final parts = <String>[
      '${quality.rowsReady}/${math.max(quality.rowsWithData, quality.rowsTotal)} filas listas',
    ];
    if (quality.invalidCells > 0) {
      parts.add('${quality.invalidCells} error(es)');
    }
    if (quality.pendingRequired > 0) {
      parts.add('${quality.pendingRequired} obligatorio(s) pendiente(s)');
    }
    return parts.join(' | ');
  }

  void _recomputeValidation() {
    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    if (kDebugMode) {
      developer.Timeline.startSync('editor.validation.recompute');
    }
    try {
      final invalid = <_CellRef>{};
      final messages = <_CellRef, String>{};
      int pending = 0;
      var rowsWithData = 0;
      var rowsReady = 0;
      var requiredCellsTotal = 0;
      var requiredCellsValid = 0;
      final dataCols = math.max(0, _headers.length - 1);
      final requiredByCol = List<bool>.generate(
        dataCols,
        (index) => _isRequired(index),
        growable: false,
      );

      for (int r = 0; r < _rows.length; r++) {
        var rowHasData = false;
        var rowHasInvalid = false;
        var rowRequiredOk = true;
        var rowHasRequiredColumns = false;
        for (int c = 0; c < _headers.length - 1; c++) {
          final v = _rows[r].cells[c];
          final ref = _CellRef(r, c);
          final trimmed = v.trim();
          if (trimmed.isNotEmpty) {
            rowHasData = true;
          }
          final message = _validationMessageForCell(r, c, overrideValue: v);
          if (message != null) {
            invalid.add(ref);
            messages[ref] = message;
            rowHasInvalid = true;
            if (message == 'Campo requerido') pending++;
          }
          if (c < requiredByCol.length && requiredByCol[c]) {
            rowHasRequiredColumns = true;
            requiredCellsTotal++;
            if (message == null && trimmed.isNotEmpty) {
              requiredCellsValid++;
            } else {
              rowRequiredOk = false;
            }
          }
        }
        if (rowHasData) {
          rowsWithData++;
        }
        if (rowHasData &&
            !rowHasInvalid &&
            (!rowHasRequiredColumns || rowRequiredOk)) {
          rowsReady++;
        }
      }

      final quality = _SheetQualitySnapshot(
        rowsTotal: _rows.length,
        rowsWithData: rowsWithData,
        rowsReady: rowsReady,
        invalidCells: invalid.length,
        pendingRequired: pending,
        requiredCellsTotal: requiredCellsTotal,
        requiredCellsValid: requiredCellsValid,
      );

      final hasChanges = _pendingRequired != pending ||
          _invalidCells.length != invalid.length ||
          !_invalidCells.containsAll(invalid) ||
          !mapEquals(_invalidCellMessages, messages) ||
          !_sheetQuality.sameAs(quality);
      if (!hasChanges) return;

      if (!mounted) {
        _invalidCells = invalid;
        _invalidCellMessages = messages;
        _pendingRequired = pending;
        _sheetQuality = quality;
        return;
      }
      setState(() {
        _invalidCells = invalid;
        _invalidCellMessages = messages;
        _pendingRequired = pending;
        _sheetQuality = quality;
        if (_invalidCells.isEmpty) {
          _errorsPanelOpen = false;
        }
      });
    } finally {
      if (kDebugMode) {
        developer.Timeline.finishSync();
        stopwatch?.stop();
        if (stopwatch != null &&
            stopwatch.elapsed >= _slowValidationThreshold) {
          debugPrint(
            '[editor_perf] validation ${stopwatch.elapsedMilliseconds}ms '
            '(rows=${_rows.length}, cols=${_headers.length})',
          );
        }
      }
    }
  }

  void _onTitleChangedDebounced(String v) {
    _nameDebounceT?.cancel();
    _nameDebounceT = Timer(const Duration(milliseconds: 420), () {
      final nv = v.trim();
      if (nv.isEmpty) return;
      _sheetName = nv;
      _markDirty(snapshot: false);
    });
  }

  void _bumpGridVersion() {
    _syncRowVersionNotifiers();
    _gridVersion.value = _gridVersion.value + 1;
  }

  ValueListenable<int> _rowVersionListenable(String rowId) {
    return _rowVersionById.putIfAbsent(rowId, () => ValueNotifier<int>(0));
  }

  void _bumpRowVersionById(String rowId) {
    final notifier = _rowVersionById.putIfAbsent(
      rowId,
      () => ValueNotifier<int>(0),
    );
    notifier.value = notifier.value + 1;
  }

  void _syncRowVersionNotifiers() {
    if (_rows.isEmpty) {
      if (_rowVersionById.isNotEmpty) {
        for (final notifier in _rowVersionById.values) {
          notifier.dispose();
        }
        _rowVersionById.clear();
      }
      _debugPendingInputLatencyByRow.clear();
      return;
    }

    final activeIds = _rows.map((row) => row.id).toSet();
    final stale = <String>[];
    for (final id in _rowVersionById.keys) {
      if (!activeIds.contains(id)) stale.add(id);
    }
    for (final id in stale) {
      _rowVersionById.remove(id)?.dispose();
      _debugPendingInputLatencyByRow.remove(id);
    }
    for (final id in activeIds) {
      _rowVersionById.putIfAbsent(id, () => ValueNotifier<int>(0));
    }
  }

  bool get _perfInstrumentationEnabled =>
      kDebugMode &&
      (_kEnableEditorPerfInstrumentation || _perfHarnessRequested);

  void _trackGridHostBuild(String surface) {
    if (!_perfInstrumentationEnabled) return;
    _debugGridBuilds++;
    _flushEditorPerfWindow(surface);
  }

  void _trackGridRowBuild(String rowId) {
    if (!_perfInstrumentationEnabled) return;
    _debugRowBuilds++;
    final pending = _debugPendingInputLatencyByRow.remove(rowId);
    if (pending != null) {
      pending.stop();
      final us = pending.elapsedMicroseconds;
      if (us > 0) {
        _debugInputLatencySamplesUs.add(us);
        if (_debugInputLatencySamplesUs.length > 180) {
          _debugInputLatencySamplesUs.removeAt(0);
        }
      }
    }
    _flushEditorPerfWindow('row');
  }

  void _trackGridCellBuild() {
    if (!_perfInstrumentationEnabled) return;
    _debugCellBuilds++;
  }

  void _trackDraftInputLatency(String rowId) {
    if (!_perfInstrumentationEnabled) return;
    _debugInputEvents++;
    _debugPendingInputLatencyByRow.remove(rowId)?.stop();
    _debugPendingInputLatencyByRow[rowId] = Stopwatch()..start();
  }

  void _flushEditorPerfWindow(String surface) {
    if (!_perfInstrumentationEnabled) return;
    final now = DateTime.now();
    final elapsed = now.difference(_debugGridBuildsWindowStart);
    if (elapsed < const Duration(seconds: 2)) return;

    final latencies = List<int>.from(_debugInputLatencySamplesUs);
    latencies.sort();
    final latencyCount = latencies.length;
    final avgUs = latencyCount == 0
        ? 0
        : latencies.fold<int>(0, (sum, us) => sum + us) ~/ latencyCount;
    final p95Us = latencyCount == 0
        ? 0
        : latencies[(latencyCount * 0.95).clamp(0.0, latencyCount - 1).floor()];
    final maxUs = latencyCount == 0 ? 0 : latencies.last;

    debugPrint(
      '[editor_perf] surface=$surface window=${elapsed.inMilliseconds}ms '
      'grid=$_debugGridBuilds row=$_debugRowBuilds cell=$_debugCellBuilds '
      'input=$_debugInputEvents latency(avg/p95/max)='
      '${(avgUs / 1000).toStringAsFixed(1)}/'
      '${(p95Us / 1000).toStringAsFixed(1)}/'
      '${(maxUs / 1000).toStringAsFixed(1)}ms',
    );

    _debugGridBuilds = 0;
    _debugRowBuilds = 0;
    _debugCellBuilds = 0;
    _debugInputEvents = 0;
    _debugInputLatencySamplesUs.clear();
    _debugGridBuildsWindowStart = now;
  }

  Map<String, Object?> _collectPerfReport() {
    final stats = PerfOptimizer.stats.value;
    return <String, Object?>{
      'mode': _perfHarnessRequested ? 'perf_harness' : 'editor',
      'sheetId': widget.sheetId,
      'rows': _rows.length,
      'cols': _headers.length,
      'grid_builds_window': _debugGridBuilds,
      'row_builds_window': _debugRowBuilds,
      'cell_builds_window': _debugCellBuilds,
      'input_events_window': _debugInputEvents,
      'thumb_cache_entries': _thumbDecodeCache.entryCount,
      'thumb_cache_bytes': _thumbDecodeCache.totalBytes,
      'thumb_cache_hits': _thumbDecodeCache.cacheHits,
      'thumb_cache_misses': _thumbDecodeCache.cacheMisses,
      'thumb_cache_evictions': _thumbDecodeCache.evictions,
      'perf_optimizer': stats.toJson(),
      if (_perfScenarioLastAt != null)
        'last_scenario_at': _perfScenarioLastAt!.toIso8601String(),
      'scenario_runs': _perfScenarioRuns,
    };
  }

  String _perfReportText() {
    return const JsonEncoder.withIndent('  ').convert(_collectPerfReport());
  }

  Future<void> _copyPerfReport() async {
    final payload = _perfReportText();
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    _showActionSnack(
      'Perf report copiado al portapapeles.',
      isError: false,
      icon: Icons.speed_rounded,
    );
  }

  Future<void> _runPerfScenario() async {
    if (_perfScenarioRunning) return;
    _perfScenarioRunning = true;
    setState(() {});
    try {
      PerfOptimizer.resetStats();
      _debugGridBuilds = 0;
      _debugRowBuilds = 0;
      _debugCellBuilds = 0;
      _debugInputEvents = 0;
      _debugInputLatencySamplesUs.clear();
      _debugGridBuildsWindowStart = DateTime.now();

      final maxRows = math.min(10, _rows.length);
      final maxCols = math.min(10, math.max(0, _headers.length - 1));
      for (int r = 0; r < maxRows; r++) {
        for (int c = 0; c < maxCols; c++) {
          _setCell(r, c, 'perf-${r + 1}-${c + 1}');
        }
        if (r.isEven) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      _setSelectionAndRefreshGrid(0, 0);
      if (_rows.isNotEmpty && _headers.length > 1) {
        const sample = 'abcdefghijklmnopqrst';
        for (int i = 0; i < sample.length; i++) {
          _setDraftCell(0, 0, sample.substring(0, i + 1));
          if (i % 4 == 3) {
            await Future<void>.delayed(Duration.zero);
          }
        }
        _commitDraftCell(0, 0);
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));

      if (_vScroll.hasClients) {
        final max = _vScroll.position.maxScrollExtent;
        _vScroll.jumpTo(math.min(max, 320.0));
      }
      if (_hScroll.hasClients) {
        final max = _hScroll.position.maxScrollExtent;
        _hScroll.jumpTo(math.min(max, 420.0));
      }

      if (mounted && _rows.isNotEmpty && _headers.isNotEmpty) {
        await _openAttachmentPanelForCell(0, math.max(0, _headers.length - 1));
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }

      _perfScenarioRuns += 1;
      _perfScenarioLastAt = DateTime.now();
    } finally {
      _perfScenarioRunning = false;
      if (mounted) setState(() {});
    }
  }

  String _effectiveHeader(int c) {
    if (c < 0 || c >= _headers.length) return '';
    return _draftHeaders[c] ?? _headers[c];
  }

  String _effectiveCell(int r, int c) {
    if (r < 0 || r >= _rows.length) return '';
    if (c < 0 || c >= _headers.length) return '';
    return _draftCells[_CellRef(r, c)] ?? _rows[r].cells[c];
  }

  bool _isFormulaText(String raw) => FormulaEngine.isFormula(raw);

  String _displayCellValue(int r, int c) {
    if (r < 0 || r >= _rows.length) return '';
    if (c < 0 || c >= _headers.length) return '';
    final ref = _CellRef(r, c);
    if (_draftCells.containsKey(ref)) {
      return _draftCells[ref] ?? '';
    }
    final raw = _rows[r].cells[c];
    if (!_isFormulaText(raw)) return raw;
    return _formulaDisplayValues[ref] ?? FormulaEngine.errorValue;
  }

  bool _isEditableCellAddress(FormulaCellAddress cell) {
    if (cell.row < 0 || cell.row >= _rows.length) return false;
    if (cell.col < 0 || cell.col >= _headers.length - 1) return false;
    return true;
  }

  bool _isEditableFormulaCellRef(_CellRef ref) {
    if (ref.r < 0 || ref.r >= _rows.length) return false;
    if (ref.c < 0 || ref.c >= _headers.length - 1) return false;
    return true;
  }

  bool _isTrackedFormulaCell(_CellRef ref) =>
      _formulaParsedByCell.containsKey(ref) ||
      _invalidFormulaCells.contains(ref);

  void _markFormulaGraphDirty() {
    _formulaGraphDirty = true;
  }

  void _rebuildFormulaGraph() {
    _formulaParsedByCell.clear();
    _invalidFormulaCells.clear();
    _formulaDependenciesByCell.clear();
    _formulaDependentsByCell.clear();

    for (int r = 0; r < _rows.length; r++) {
      for (int c = 0; c < _headers.length - 1; c++) {
        final ref = _CellRef(r, c);
        _syncFormulaGraphForCell(ref);
      }
    }
    _formulaGraphDirty = false;
  }

  void _syncFormulaGraphForSeeds(Set<_CellRef> changedSeeds) {
    for (final ref in changedSeeds) {
      _syncFormulaGraphForCell(ref);
    }
  }

  void _syncFormulaGraphForCell(_CellRef ref) {
    _removeFormulaNode(ref);
    if (!_isEditableFormulaCellRef(ref)) return;

    final raw = _rows[ref.r].cells[ref.c];
    if (!_isFormulaText(raw)) return;

    final parsed = _formulaEngine.tryParse(raw);
    if (parsed == null) {
      _invalidFormulaCells.add(ref);
      return;
    }

    _formulaParsedByCell[ref] = parsed;
    final dependencies = <_CellRef>{};
    for (final dependency in parsed.references) {
      if (!_isEditableCellAddress(dependency)) continue;
      final depRef = _CellRef(dependency.row, dependency.col);
      dependencies.add(depRef);
      _formulaDependentsByCell.putIfAbsent(depRef, () => <_CellRef>{}).add(ref);
    }
    _formulaDependenciesByCell[ref] = dependencies;
  }

  void _removeFormulaNode(_CellRef ref) {
    final previousDependencies = _formulaDependenciesByCell.remove(ref);
    if (previousDependencies != null) {
      for (final dependency in previousDependencies) {
        final dependents = _formulaDependentsByCell[dependency];
        if (dependents == null) continue;
        dependents.remove(ref);
        if (dependents.isEmpty) {
          _formulaDependentsByCell.remove(dependency);
        }
      }
    }
    _formulaParsedByCell.remove(ref);
    _invalidFormulaCells.remove(ref);
  }

  Set<_CellRef> _collectAffectedFormulaCells(Set<_CellRef>? changedSeeds) {
    final allFormulaCells = <_CellRef>{
      ..._formulaParsedByCell.keys,
      ..._invalidFormulaCells,
    };
    if (changedSeeds == null || changedSeeds.isEmpty) {
      return allFormulaCells;
    }

    final affected = <_CellRef>{};
    final queue = Queue<_CellRef>();
    final visited = <_CellRef>{};
    for (final seed in changedSeeds) {
      queue.add(seed);
      visited.add(seed);
    }

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (_isTrackedFormulaCell(current)) {
        affected.add(current);
      }
      final dependents = _formulaDependentsByCell[current];
      if (dependents == null || dependents.isEmpty) continue;
      for (final dependent in dependents) {
        affected.add(dependent);
        if (visited.add(dependent)) {
          queue.add(dependent);
        }
      }
    }

    return affected;
  }

  ({List<_CellRef> ordered, Set<_CellRef> cycles}) _formulaEvaluationOrder(
    Set<_CellRef> formulaCells,
  ) {
    if (formulaCells.isEmpty) {
      return (ordered: const <_CellRef>[], cycles: const <_CellRef>{});
    }

    final orderedCells = formulaCells.toList(growable: false)
      ..sort((a, b) {
        final byRow = a.r.compareTo(b.r);
        if (byRow != 0) return byRow;
        return a.c.compareTo(b.c);
      });

    final indegree = <_CellRef, int>{
      for (final ref in orderedCells) ref: 0,
    };
    for (final ref in orderedCells) {
      if (_invalidFormulaCells.contains(ref)) continue;
      final dependencies =
          _formulaDependenciesByCell[ref] ?? const <_CellRef>{};
      for (final dependency in dependencies) {
        if (!formulaCells.contains(dependency)) continue;
        if (!_isTrackedFormulaCell(dependency)) continue;
        indegree[ref] = (indegree[ref] ?? 0) + 1;
      }
    }

    final queue = Queue<_CellRef>();
    for (final ref in orderedCells) {
      if ((indegree[ref] ?? 0) == 0) {
        queue.add(ref);
      }
    }

    final ordered = <_CellRef>[];
    final processed = <_CellRef>{};
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (!processed.add(current)) continue;
      ordered.add(current);

      final dependents = _formulaDependentsByCell[current];
      if (dependents == null || dependents.isEmpty) continue;
      final sortedDependents = dependents.toList(growable: false)
        ..sort((a, b) {
          final byRow = a.r.compareTo(b.r);
          if (byRow != 0) return byRow;
          return a.c.compareTo(b.c);
        });
      for (final dependent in sortedDependents) {
        if (!formulaCells.contains(dependent)) continue;
        final nextInDegree = (indegree[dependent] ?? 0) - 1;
        indegree[dependent] = nextInDegree;
        if (nextInDegree == 0) {
          queue.add(dependent);
        }
      }
    }

    final cycles = formulaCells.difference(processed);
    return (ordered: ordered, cycles: cycles);
  }

  void _refreshFormulaCaches({
    Set<_CellRef>? changedSeeds,
    bool notifyRows = false,
  }) {
    final previousValues = Map<_CellRef, String>.from(_formulaDisplayValues);
    final requiresFullRefresh =
        _formulaGraphDirty || changedSeeds == null || changedSeeds.isEmpty;
    if (requiresFullRefresh) {
      _rebuildFormulaGraph();
      changedSeeds = null;
    } else {
      _syncFormulaGraphForSeeds(changedSeeds);
    }

    final allFormulaCells = <_CellRef>{
      ..._formulaParsedByCell.keys,
      ..._invalidFormulaCells,
    };
    final targetFormulaCells = _collectAffectedFormulaCells(changedSeeds);

    final nextValues = <_CellRef, String>{};
    for (final entry in previousValues.entries) {
      if (allFormulaCells.contains(entry.key)) {
        nextValues[entry.key] = entry.value;
      }
    }

    final evaluationOrder = _formulaEvaluationOrder(targetFormulaCells);
    final resolvedValues = <_CellRef, String>{};
    for (final cycle in evaluationOrder.cycles) {
      resolvedValues[cycle] = FormulaErrors.cycle;
    }

    for (final formulaCell in evaluationOrder.ordered) {
      if (_invalidFormulaCells.contains(formulaCell)) {
        resolvedValues[formulaCell] = FormulaEngine.errorValue;
        continue;
      }

      final parsed = _formulaParsedByCell[formulaCell];
      if (parsed == null) {
        resolvedValues[formulaCell] = FormulaEngine.errorValue;
        continue;
      }

      if (!BitFlowProductService.I.features.isFormulaAllowed(parsed.source)) {
        resolvedValues[formulaCell] = FormulaErrors.pro;
        continue;
      }

      final result = _formulaEngine.evaluateParsed(
        parsed,
        readCell: (cell) {
          if (!_isEditableCellAddress(cell)) return FormulaErrors.ref;
          final dependencyRef = _CellRef(cell.row, cell.col);
          final resolved = resolvedValues[dependencyRef];
          if (resolved != null) return resolved;
          if (_isTrackedFormulaCell(dependencyRef)) {
            return _formulaDisplayValues[dependencyRef] ??
                FormulaEngine.errorValue;
          }
          return _rows[cell.row].cells[cell.col];
        },
        isCellAvailable: _isEditableCellAddress,
      );
      resolvedValues[formulaCell] = result.hasError
          ? (result.error ?? FormulaEngine.errorValue)
          : _formulaEngine.formatValue(result.value);
    }

    for (final entry in resolvedValues.entries) {
      nextValues[entry.key] = entry.value;
    }

    _formulaDisplayValues
      ..clear()
      ..addAll(nextValues);

    if (!notifyRows) return;

    final changedRows = <String>{};
    final keys = <_CellRef>{
      ...previousValues.keys,
      ..._formulaDisplayValues.keys,
    };
    for (final key in keys) {
      if (previousValues[key] == _formulaDisplayValues[key]) continue;
      if (key.r < 0 || key.r >= _rows.length) continue;
      changedRows.add(_rows[key.r].id);
    }
    for (final rowId in changedRows) {
      _bumpRowVersionById(rowId);
    }
  }

  List<FormulaAutocompleteSuggestion> _formulaAutocompleteSuggestions(
    String raw,
  ) {
    return _formulaEngine.suggestFunctions(raw, limit: 8);
  }

  void _applyFormulaSuggestion(
    TextEditingController controller,
    FormulaAutocompleteSuggestion suggestion,
  ) {
    final nextText = suggestion.apply(controller.text);
    final offset = suggestion.selectionOffset.clamp(0, nextText.length);
    controller.value = controller.value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }

  void _setDraftHeader(int c, String value) {
    if (c < 0 || c >= _headers.length) return;
    if (c == _headers.length - 1) return;
    final hadPendingDrafts = _draftHeaders.isNotEmpty || _draftCells.isNotEmpty;

    final existing = _draftHeaders[c];
    if (existing == value) return;

    if (value == _headers[c]) {
      if (_draftHeaders.remove(c) != null) {
        _bumpGridVersion();
        _updateSaveStatus();
        _refreshPopScopeOnDraftToggle(hadPendingDrafts);
      }
      return;
    }

    _draftHeaders[c] = value;
    _bumpGridVersion();
    _updateSaveStatus();
    _refreshPopScopeOnDraftToggle(hadPendingDrafts);
  }

  void _setDraftCell(int r, int c, String value) {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    if (c == _headers.length - 1) return;
    final hadPendingDrafts = _draftHeaders.isNotEmpty || _draftCells.isNotEmpty;

    final rowId = _rows[r].id;
    final ref = _CellRef(r, c);
    final existing = _draftCells[ref];
    if (existing == value) return;

    if (value == _rows[r].cells[c]) {
      if (_draftCells.remove(ref) != null) {
        _trackDraftInputLatency(rowId);
        _bumpRowVersionById(rowId);
        _updateSaveStatus();
        _refreshPopScopeOnDraftToggle(hadPendingDrafts);
      }
      return;
    }

    _draftCells[ref] = value;
    _trackDraftInputLatency(rowId);
    _bumpRowVersionById(rowId);
    _updateSaveStatus();
    _refreshPopScopeOnDraftToggle(hadPendingDrafts);
  }

  void _commitDraftHeader(int c) {
    if (c < 0 || c >= _headers.length) return;
    if (c == _headers.length - 1) return;

    final draft = _draftHeaders[c];
    final next = (draft ?? _headers[c]).trim();
    if (next == _headers[c]) {
      if (_draftHeaders.remove(c) != null) {
        _bumpGridVersion();
        _updateSaveStatus();
      }
      return;
    }

    _headers[c] = next;
    _draftHeaders.remove(c);
    _markDirty(snapshot: true);
    _bumpGridVersion();
  }

  void _commitDraftCell(int r, int c) {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    if (c == _headers.length - 1) return;

    final rowId = _rows[r].id;
    final ref = _CellRef(r, c);
    final draft = _draftCells[ref];
    final next = _normalizeCellValueForColumn(c, draft ?? _rows[r].cells[c]);
    if (next == _rows[r].cells[c]) {
      if (_draftCells.remove(ref) != null) {
        _bumpRowVersionById(rowId);
        _updateSaveStatus();
      }
      return;
    }

    _rows[r].cells[c] = next;
    _draftCells.remove(ref);
    _pendingFormulaSeeds.add(ref);
    _markDirty(snapshot: true);
    _bumpRowVersionById(rowId);
  }

  void _clearDrafts() {
    if (_draftCells.isEmpty && _draftHeaders.isEmpty) return;
    final hadPendingDrafts = true;
    _draftCells.clear();
    _draftHeaders.clear();
    _bumpGridVersion();
    _updateSaveStatus();
    _refreshPopScopeOnDraftToggle(hadPendingDrafts);
  }

  void _resetDraftsAndEditors() {
    _clearDrafts();
    _removeCellEditor();
    if (_mobileEditorOpen) {
      _cancelMobileEdit();
    }
  }

  void _resetMobileRowCaches() {
    for (final controller in _mobileRowScrolls) {
      controller?.dispose();
    }
    _mobileRowScrolls
      ..clear()
      ..addAll(List<ScrollController?>.filled(_rows.length, null));
    _mobileRowKeys
      ..clear()
      ..addAll(List<GlobalKey?>.filled(_rows.length, null));
    _mobileSharedHorizontalOffset =
        _mobileHeaderScroll.hasClients ? _mobileHeaderScroll.offset : 0;
  }

  void _ensureMobileRowCachesLength() {
    while (_mobileRowScrolls.length < _rows.length) {
      _mobileRowScrolls.add(null);
      _mobileRowKeys.add(null);
    }
    while (_mobileRowScrolls.length > _rows.length) {
      final controller = _mobileRowScrolls.removeLast();
      controller?.dispose();
      _mobileRowKeys.removeLast();
    }
  }

  void _insertMobileRowCache(int index) {
    final idx = index.clamp(0, _mobileRowScrolls.length);
    _mobileRowScrolls.insert(idx, null);
    _mobileRowKeys.insert(idx, null);
  }

  void _removeMobileRowCache(int index) {
    if (_mobileRowScrolls.isEmpty) return;
    final idx = index.clamp(0, _mobileRowScrolls.length - 1);
    final controller = _mobileRowScrolls.removeAt(idx);
    controller?.dispose();
    _mobileRowKeys.removeAt(idx);
  }

  ScrollController _mobileRowScrollAt(int row) {
    _ensureMobileRowCachesLength();
    if (row < 0 || row >= _mobileRowScrolls.length) {
      return _mobileHeaderScroll;
    }
    final existing = _mobileRowScrolls[row];
    if (existing != null) return existing;
    final created = ScrollController(
      initialScrollOffset: _mobileSharedHorizontalOffset,
    );
    _mobileRowScrolls[row] = created;
    return created;
  }

  GlobalKey _mobileRowKeyAt(int row) {
    _ensureMobileRowCachesLength();
    if (row < 0 || row >= _mobileRowKeys.length) return GlobalKey();
    final existing = _mobileRowKeys[row];
    if (existing != null) return existing;
    final created = GlobalKey();
    _mobileRowKeys[row] = created;
    return created;
  }

  void _syncMobileHorizontal(double offset, bool isHeader, int row) {
    if (_mobileHSyncing) return;
    _mobileHSyncing = true;
    try {
      _mobileSharedHorizontalOffset = offset;
      void jumpTo(ScrollController controller) {
        if (!controller.hasClients) return;
        final min = controller.position.minScrollExtent;
        final max = controller.position.maxScrollExtent;
        final clamped = offset.clamp(min, max).toDouble();
        if ((controller.offset - clamped).abs() < 0.5) return;
        controller.jumpTo(clamped);
      }

      jumpTo(_mobileHeaderScroll);
      for (final controller in _mobileRowScrolls) {
        if (controller != null) {
          jumpTo(controller);
        }
      }
    } finally {
      _mobileHSyncing = false;
    }
  }

  bool _clearCellDrafts(Iterable<_CellRef> refs) {
    bool changed = false;
    for (final ref in refs) {
      if (_draftCells.remove(ref) != null) {
        changed = true;
      }
    }
    return changed;
  }

  void _syncActiveDrafts() {
    if (_mobileEditorOpen) {
      final v = _mobileEC.text;
      if (_mobileEditingHeader) {
        _setDraftHeader(_mobileCol, v);
      } else {
        _setDraftCell(_mobileRow, _mobileCol, v);
      }
    }

    if (_cellEditorEntry != null) {
      final headerCol = _editingHeaderCol;
      final cellRef = _editingCellRef;
      final v = _cellEC.text;
      if (headerCol != null) {
        _setDraftHeader(headerCol, v);
      } else if (cellRef != null) {
        _setDraftCell(cellRef.r, cellRef.c, v);
      }
    }
  }

  void _refreshPopScopeOnDraftToggle(bool hadPendingDrafts) {
    final hasPendingDrafts = _draftHeaders.isNotEmpty || _draftCells.isNotEmpty;
    if (hadPendingDrafts == hasPendingDrafts) return;
    if (!mounted) return;
    setState(() {});
  }

  void _attachCellDraftListener() {
    if (_cellDraftListener != null) return;
    _cellDraftListener = () {
      _cellDraftSyncT?.cancel();
      _cellDraftSyncT = Timer(_cellDraftSyncDebounce, _syncActiveDrafts);
    };
    _cellEC.addListener(_cellDraftListener!);
  }

  void _detachCellDraftListener() {
    _cellDraftSyncT?.cancel();
    final listener = _cellDraftListener;
    if (listener == null) return;
    _cellEC.removeListener(listener);
    _cellDraftListener = null;
  }

  void _attachMobileDraftListener() {
    if (_mobileDraftListener != null) return;
    _mobileDraftListener = () {};
    _mobileEC.addListener(_mobileDraftListener!);
  }

  void _detachMobileDraftListener() {
    final listener = _mobileDraftListener;
    if (listener == null) return;
    _mobileEC.removeListener(listener);
    _mobileDraftListener = null;
  }

  bool _isSmokeRequested() {
    final raw = Uri.base.queryParameters['smoke'];
    if (raw == null) return false;
    final v = raw.trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes';
  }

  bool _isPerfRequested() {
    final raw = Uri.base.queryParameters['perf'];
    if (raw == null) return false;
    final v = raw.trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes';
  }

  Future<void> _maybeRunSmoke() async {
    if (!_smokeRequested || _smokeRan) return;
    final base = _engineBaseResolved?.trim() ?? '';
    if (base.isEmpty || _engineBusy) return;
    _smokeRan = true;
    await _runSmokeTest();
  }

  bool _hasActiveEditorDraft() {
    if (_cellEditorEntry != null) {
      final headerCol = _editingHeaderCol;
      if (headerCol != null &&
          headerCol >= 0 &&
          headerCol < _headers.length - 1 &&
          _cellEC.text != _headers[headerCol]) {
        return true;
      }
      final cellRef = _editingCellRef;
      if (cellRef != null &&
          cellRef.r >= 0 &&
          cellRef.r < _rows.length &&
          cellRef.c >= 0 &&
          cellRef.c < _headers.length - 1 &&
          _cellEC.text != _rows[cellRef.r].cells[cellRef.c]) {
        return true;
      }
    }

    if (_mobileEditorOpen) {
      if (_mobileEditingHeader) {
        if (_mobileCol >= 0 &&
            _mobileCol < _headers.length - 1 &&
            _mobileEC.text != _headers[_mobileCol]) {
          return true;
        }
      } else if (_mobileRow >= 0 &&
          _mobileRow < _rows.length &&
          _mobileCol >= 0 &&
          _mobileCol < _headers.length - 1 &&
          _mobileEC.text != _rows[_mobileRow].cells[_mobileCol]) {
        return true;
      }
    }

    return false;
  }

  bool get _hasPendingDraftChanges =>
      _draftHeaders.isNotEmpty ||
      _draftCells.isNotEmpty ||
      _hasActiveEditorDraft();

  bool get _hasUnsavedWork =>
      _isDirty || _savePending || _saving || _hasPendingDraftChanges;

  void _updateSaveStatus() {
    final hasUnsavedWork = _isDirty || _savePending || _hasPendingDraftChanges;
    final hasSaveError = (_lastSaveErrorMessage ?? '').trim().isNotEmpty;
    final state = _saving
        ? EditorSaveState.saving
        : (hasSaveError
            ? EditorSaveState.error
            : (hasUnsavedWork
                ? EditorSaveState.dirty
                : (_lastSavedAt != null
                    ? EditorSaveState.saved
                    : EditorSaveState.idle)));
    _saveStatus.value = EditorSaveSnapshot(
      state: state,
      savedAt: _lastSavedAt,
      errorMessage:
          state == EditorSaveState.error ? _lastSaveErrorMessage : null,
    );
    if (_isDirty && mounted) {
      final hasPending = _editQueue.any(
        (entry) => entry.sheetId == widget.sheetId && entry.revision >= _rev,
      );
      if (!hasPending) {
        unawaited(_enqueueEditPending());
      }
    }
  }

  String _formatSmokeFailure(_EngineErrorDetails? details) {
    if (details == null) return 'Engine BLOQUEADO (error desconocido)';
    final parts = <String>[];
    if (details.isCors) parts.add('CORS');
    if (details.isTimeout) parts.add('timeout');
    if (details.statusCode != null) {
      parts.add('HTTP ${details.statusCode}');
    }
    final reason = parts.isEmpty ? 'error' : parts.join('/');
    final msg = details.message.trim();
    if (msg.isEmpty) return 'Engine BLOQUEADO ($reason)';
    return 'Engine BLOQUEADO ($reason): $msg';
  }

  Color _smokeBg(_SheetPalette pal) {
    if (_smokeOk == true) {
      return pal.successBg;
    }
    if (_smokeOk == false) {
      return pal.dangerBg;
    }
    return pal.statusBg;
  }

  Color _smokeFg(_SheetPalette pal) {
    if (_smokeOk == true) {
      return pal.successFg;
    }
    if (_smokeOk == false) {
      return pal.dangerFg;
    }
    return pal.statusFg;
  }

  Color _errorBg(_SheetPalette pal) {
    return pal.dangerBg;
  }

  Color _errorFg(_SheetPalette pal) {
    return pal.dangerFg;
  }

  void _maybeShowMobileStatusSnack(
    BuildContext context,
    _SheetPalette pal, {
    required String? message,
    required bool isError,
  }) {
    if (message == null || message.trim().isEmpty) return;
    if (message == _lastMobileSnack || _shouldCoalesceToast(message)) return;
    _lastMobileSnack = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppleToast.show(
        context,
        message: message,
        isError: isError,
        icon:
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
      );
    });
  }

  void _showSnack(String message, {required bool isError}) {
    if (!mounted || message.trim().isEmpty) return;
    if (_shouldCoalesceToast(message)) return;
    AppleToast.show(context, message: message, isError: isError);
  }

  bool _shouldCoalesceToast(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return true;
    final now = DateTime.now();
    final shouldCoalesce = _lastToastMessage == trimmed &&
        now.difference(_lastToastAt) <= _toastCoalesceWindow;
    _lastToastMessage = trimmed;
    _lastToastAt = now;
    return shouldCoalesce;
  }

  Future<FlowBotParseResult> _parseFlowBotCommand(String transcript) async {
    final text = transcript.trim();
    if (text.isEmpty) {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'rule_based',
        warning: 'Comando vacio.',
      );
    }

    final selectedRows = _batchTargetRows();
    final dataCols = math.max(0, _headers.length - 1);
    final headerLabels = dataCols <= 0
        ? const <String>[]
        : List<String>.generate(dataCols, _headerLabel);
    flowBotDebugLog(
      'Editor.parse command="$text" '
      'rows=${_rows.length} dataCols=$dataCols selection=(${_selRow + 1},${_selCol + 1})',
    );
    String? localWarning;
    final modelPath = _flowBotLocalModelPath.trim();
    if (_flowBotUseLocalLlm && modelPath.isNotEmpty) {
      final llmResult = await _flowBotLocalLlmEngine.parse(
        modelPath: modelPath,
        transcript: text,
        selectedRow: _selRow,
        selectedCol: _selCol,
        selectedRows: selectedRows,
      );
      if (llmResult.hasActions) {
        flowBotDebugLog(
          'Editor.parse result engine=${llmResult.engine} '
          'actions=${llmResult.actions.map((action) => action.type.name).join(',')}',
        );
        return llmResult;
      }
      localWarning = llmResult.warning;
    }

    final fallback = _flowBotRuleEngine.parse(
      text,
      selectedRow: _selRow,
      selectedCol: _selCol,
      selectedRows: selectedRows,
      maxRows: _rows.length.clamp(1, 50000),
      maxCols: dataCols.clamp(1, 200),
      headerLabels: headerLabels,
    );
    if ((localWarning ?? '').trim().isNotEmpty && !fallback.hasActions) {
      flowBotDebugLog(
        'Editor.parse result engine=${fallback.engine} '
        'actions=0 warning="${localWarning ?? ''}"',
      );
      return FlowBotParseResult(
        actions: fallback.actions,
        engine: fallback.engine,
        warning: localWarning,
      );
    }
    flowBotDebugLog(
      'Editor.parse result engine=${fallback.engine} '
      'actions=${fallback.actions.map((action) => action.type.name).join(',')} '
      'warning="${fallback.warning ?? ''}"',
    );
    return fallback;
  }

  String _flowBotDateText(String? format) {
    final now = DateTime.now();
    final token = (format ?? '').trim().toLowerCase();
    if (token == 'iso' || token == 'yyyy-mm-dd') {
      return '${now.year}-${_two(now.month)}-${_two(now.day)}';
    }
    if (token == 'datetime' ||
        token == 'iso_datetime' ||
        token == 'yyyy-mm-dd hh:mm') {
      return _formatDateTimeShort(now);
    }
    return _formatDateCellValue(now);
  }

  String _flowBotActionLabel(FlowBotAction action) {
    switch (action.type) {
      case FlowBotActionType.setCell:
        final row = (action.row ?? _selRow) + 1;
        final col = (action.col ?? _selCol) + 1;
        final value = action.value ?? '';
        return 'Set F$row/C$col = "$value"';
      case FlowBotActionType.fillRange:
        final row = (action.row ?? _selRow) + 1;
        final col = (action.col ?? _selCol) + 1;
        final count = action.count ?? 1;
        final value = action.value ?? '';
        return 'Rellenar desde F$row/C$col x$count = "$value"';
      case FlowBotActionType.addRow:
        final count = (action.count ?? 1).clamp(1, 500);
        final hasAssignments = (action.value ?? '').trim().isNotEmpty;
        if (hasAssignments) {
          return 'Nuevo registro ($count) + campos: ${action.value}';
        }
        return 'Nuevo registro $count fila(s)';
      case FlowBotActionType.clearSelection:
        return 'Limpiar seleccion';
      case FlowBotActionType.clearRow:
        return 'Limpiar fila activa';
      case FlowBotActionType.setColumnAlign:
        final col = (action.column ?? _selCol) + 1;
        final align = (action.align ?? 'left').toLowerCase();
        return 'Alinear columna C$col -> $align';
      case FlowBotActionType.setWrap:
        final col = (action.column ?? _selCol) + 1;
        final lines = (action.lines ?? 2).clamp(1, 3);
        return 'Wrap columna C$col -> $lines linea(s)';
      case FlowBotActionType.applyStatus:
        return 'Aplicar estado "${action.status ?? 'OK'}"';
      case FlowBotActionType.setToday:
        final scope = (action.value ?? 'seleccion').trim();
        return 'Set fecha de hoy ($scope)';
      case FlowBotActionType.autoId:
        final start = action.start ?? 1;
        final step = action.step ?? 1;
        return 'Autonumerar desde $start paso $step';
      case FlowBotActionType.copyGps:
        final row = (action.fromRow ?? _selRow) + 1;
        return 'Copiar GPS desde fila $row';
      case FlowBotActionType.duplicateRow:
        final row = (action.row ?? _selRow) + 1;
        final times = (action.count ?? 1).clamp(1, 100);
        return 'Duplicar fila $row x$times';
      case FlowBotActionType.deleteRow:
        final row = (action.row ?? _selRow) + 1;
        return 'Eliminar fila $row';
      case FlowBotActionType.addColumn:
        return 'Agregar columna "${action.value ?? 'Nueva columna'}"';
      case FlowBotActionType.renameColumn:
        final col = (action.column ?? _selCol)
            .clamp(
              0,
              math.max(0, _headers.length - 2),
            )
            .toInt();
        return 'Renombrar columna ${_headerLabel(col)} -> "${action.value ?? ''}"';
      case FlowBotActionType.fillBlanks:
        final col = (action.column ?? _selCol)
            .clamp(
              0,
              math.max(0, _headers.length - 2),
            )
            .toInt();
        return 'Completar vacios en ${_headerLabel(col)} con "${action.value ?? ''}"';
      case FlowBotActionType.copyFromPreviousRow:
        final row = (action.row ?? _selRow) + 1;
        final col = (action.col ?? _selCol)
            .clamp(
              0,
              math.max(0, _headers.length - 2),
            )
            .toInt();
        return 'Copiar fila ${math.max(1, row - 1)} -> ${_headerLabel(col)} en fila $row';
      case FlowBotActionType.attachPhotoToCell:
        final row = (action.row ?? _selRow) + 1;
        final col = (action.col ?? _selCol) + 1;
        return 'Adjuntar foto en F$row/C$col';
      case FlowBotActionType.exportXlsx:
        return 'Exportar XLSX';
      case FlowBotActionType.exportPdfPreset:
        return 'Exportar PDF (${action.presetId ?? 'default'})';
      case FlowBotActionType.pasteTable:
        return 'Pegar tabla inteligente desde portapapeles';
      case FlowBotActionType.exportBundle:
        return 'Exportar paquete completo';
    }
  }

  List<({int row, int col, String before, String after})>
      _flowBotPreviewPatches(
    List<FlowBotAction> actions,
  ) {
    final patches = <({int row, int col, String before, String after})>[];
    final dataCols = _headers.length - 1;
    if (dataCols <= 0) return patches;

    void addPatch(int row, int col, String after) {
      if (row < 0 || col < 0 || col >= dataCols) return;
      final before =
          row >= 0 && row < _rows.length ? _getCellText(row, col) : '';
      patches.add((row: row, col: col, before: before, after: after));
    }

    for (final action in actions) {
      switch (action.type) {
        case FlowBotActionType.setCell:
          addPatch(
              action.row ?? _selRow, action.col ?? _selCol, action.value ?? '');
          break;
        case FlowBotActionType.fillRange:
          final startRow = action.row ?? _selRow;
          final startCol = (action.col ?? _selCol).clamp(0, dataCols - 1);
          final count = (action.count ?? 1).clamp(1, 500);
          final endRow = action.rowEnd ?? (startRow + count - 1);
          final endCol = action.colEnd ?? startCol;
          for (int r = startRow; r <= endRow; r++) {
            for (int c = startCol; c <= endCol && c < dataCols; c++) {
              addPatch(r, c, action.value ?? '');
            }
          }
          break;
        case FlowBotActionType.setToday:
          final scope =
              _normalizeFlowBotScopeToken(action.value ?? _flowBotLastScope);
          final col = (_firstColumnByType(_ColType.date) ?? _selCol)
              .clamp(0, dataCols - 1);
          final after = _flowBotDateText(action.format);
          final rows = switch (scope) {
            'columna' => List<int>.generate(_rows.length, (index) => index),
            'fila' => <int>[_selRow],
            'celda' => <int>[_selRow],
            _ => _batchTargetRows(),
          };
          for (final r in rows) {
            addPatch(r, col, after);
          }
          break;
        case FlowBotActionType.clearSelection:
        case FlowBotActionType.clearRow:
          final scope =
              _normalizeFlowBotScopeToken(action.value ?? _flowBotLastScope);
          final rows = switch (scope) {
            'columna' => List<int>.generate(_rows.length, (index) => index),
            'fila' => <int>[_selRow],
            'celda' => <int>[_selRow],
            _ => _batchTargetRows(),
          };
          if (action.type == FlowBotActionType.clearRow || scope == 'fila') {
            for (final r in rows) {
              for (int c = 0; c < dataCols; c++) {
                addPatch(r, c, '');
              }
            }
          } else {
            final col = _selCol.clamp(0, dataCols - 1);
            for (final r in rows) {
              addPatch(r, col, '');
            }
          }
          break;
        case FlowBotActionType.addRow:
          final r = _rows.length;
          addPatch(r, _selCol.clamp(0, dataCols - 1), '(nueva fila)');
          break;
        case FlowBotActionType.autoId:
          final col = (action.column ??
                  _firstColumnMatchingFlowBotName('progresiva') ??
                  _selCol)
              .clamp(0, dataCols - 1);
          final start = action.start ?? 1;
          final step = action.step ?? 1;
          final rows = _batchTargetRows();
          for (int i = 0; i < rows.length; i++) {
            addPatch(rows[i], col, '${start + (i * step)}');
          }
          break;
        case FlowBotActionType.deleteRow:
          final row = (action.row ?? _selRow)
              .clamp(0, math.max(0, _rows.length - 1))
              .toInt();
          addPatch(
            row,
            _selCol.clamp(0, dataCols - 1).toInt(),
            '(fila eliminada)',
          );
          break;
        case FlowBotActionType.fillBlanks:
          final col = (action.column ?? _selCol).clamp(0, dataCols - 1);
          final after = action.value ?? '';
          for (int row = 0; row < _rows.length; row++) {
            if (_getCellText(row, col).trim().isNotEmpty) continue;
            addPatch(row, col, after);
          }
          break;
        case FlowBotActionType.copyFromPreviousRow:
          final row = (action.row ?? _selRow)
              .clamp(0, math.max(0, _rows.length - 1))
              .toInt();
          final col = (action.col ?? _selCol).clamp(0, dataCols - 1).toInt();
          if (row <= 0) break;
          addPatch(row, col, _getCellText(row - 1, col));
          break;
        case FlowBotActionType.setColumnAlign:
        case FlowBotActionType.setWrap:
        case FlowBotActionType.applyStatus:
        case FlowBotActionType.copyGps:
        case FlowBotActionType.duplicateRow:
        case FlowBotActionType.addColumn:
        case FlowBotActionType.renameColumn:
        case FlowBotActionType.attachPhotoToCell:
        case FlowBotActionType.exportXlsx:
        case FlowBotActionType.exportPdfPreset:
        case FlowBotActionType.pasteTable:
        case FlowBotActionType.exportBundle:
          break;
      }
    }
    return patches;
  }

  ({int cells, int rows, int cols}) _flowBotPreviewSummary(
    List<({int row, int col, String before, String after})> patches,
  ) {
    final rows = <int>{};
    final cols = <int>{};
    for (final patch in patches) {
      rows.add(patch.row);
      cols.add(patch.col);
    }
    return (cells: patches.length, rows: rows.length, cols: cols.length);
  }

  Widget _flowBotPreviewHeaderCell(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _flowBotContextChip({
    required String label,
    required IconData icon,
    required Color fg,
    required Color bg,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flowBotPreviewDataCell(
    String text,
    Color color, {
    bool highlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 2, 2, 2),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: highlighted ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }

  bool _flowBotCanApplyPreview({
    required List<FlowBotAction> preview,
    required bool parsing,
  }) {
    if (parsing) return false;
    return preview.isNotEmpty;
  }

  String _flowBotApplyDisabledReason({
    required List<FlowBotAction> preview,
    required bool parsing,
    required bool useLocalLlm,
    required bool localModelReady,
    required bool hasTranscript,
    String? parseWarning,
  }) {
    final normalizedWarning = (parseWarning ?? '').trim();
    if (parsing) return 'Analizando comando...';
    if (preview.isNotEmpty) return '';
    if (normalizedWarning.isNotEmpty) {
      return flowBotNoActionsReason(normalizedWarning);
    }
    if (!hasTranscript) {
      return 'Elegi una accion rapida o escribe una instruccion valida.';
    }
    if (useLocalLlm && !localModelReady) {
      return 'Elegi una accion rapida o escribe una instruccion valida.';
    }
    return 'Elegi una accion rapida o escribe una instruccion valida.';
  }

  String _flowBotStatusText({
    required List<FlowBotAction> preview,
    required bool parsing,
  }) {
    if (parsing) return 'Analizando...';
    if (preview.isEmpty) return 'No hay cambios listos';
    if (preview.length == 1) return '1 cambio listo';
    return '${preview.length} cambios listos';
  }

  Future<int> _applyFlowBotActions(List<FlowBotAction> actions) async {
    if (actions.isEmpty) return 0;
    final dataCols = _headers.length - 1;
    if (dataCols <= 0) return 0;
    var applied = 0;
    var lastRow = _selRow;
    var lastCol = _selCol.clamp(0, dataCols - 1);
    var changed = false;
    final previousUndoFlag = _suspendUndoSnapshot;
    _suspendUndoSnapshot = true;
    flowBotDebugLog(
      'Editor.apply start actions=${actions.map((action) => action.toJson()).join(', ')}',
    );

    try {
      for (final action in actions) {
        flowBotDebugLog('Editor.apply action=${action.toJson()}');
        switch (action.type) {
          case FlowBotActionType.setCell:
            final row = action.row ?? _selRow;
            final col = action.col ?? _selCol;
            if (col < 0 || col >= dataCols) continue;
            while (row >= _rows.length) {
              _insertRow(_rows.length);
              changed = true;
            }
            if (row < 0 || row >= _rows.length) continue;
            _setCell(row, col, action.value ?? '');
            applied += 1;
            changed = true;
            lastRow = row;
            lastCol = col;
            break;
          case FlowBotActionType.fillRange:
            final startRow = action.row ?? _selRow;
            final startCol = (action.col ?? _selCol).clamp(0, dataCols - 1);
            if (startRow < 0) continue;
            final count = (action.count ?? 1).clamp(1, 500);
            final endRow = (action.rowEnd == null)
                ? startRow + count - 1
                : math.max(startRow, action.rowEnd!);
            final endCol = action.colEnd == null
                ? startCol
                : (action.colEnd!).clamp(startCol, dataCols - 1);
            for (int rr = startRow; rr <= endRow; rr++) {
              while (rr >= _rows.length) {
                _insertRow(_rows.length);
                changed = true;
              }
              for (int cc = startCol; cc <= endCol; cc++) {
                _setCell(rr, cc, action.value ?? '');
                applied += 1;
                changed = true;
                lastRow = rr;
                lastCol = cc;
              }
            }
            break;
          case FlowBotActionType.addRow:
            final count = (action.count ?? 1).clamp(1, 500);
            for (int i = 0; i < count; i++) {
              _insertRow(_rows.length);
              final insertedRow = (_rows.length - 1).clamp(0, _rows.length - 1);
              applied += 1;
              changed = true;
              lastRow = insertedRow;
              final assignments = _parseFlowBotColumnAssignments(action.value);
              assignments.forEach((col, rawValue) {
                if (col < 0 || col >= dataCols) return;
                _setCell(insertedRow, col, rawValue);
                applied += 1;
                changed = true;
                lastCol = col;
              });
            }
            break;
          case FlowBotActionType.clearSelection:
            final scope = _normalizeFlowBotScopeToken(action.value ?? '');
            final rows = switch (scope) {
              'celda' => <int>[_selRow],
              'fila' => <int>[_selRow],
              'columna' => List<int>.generate(_rows.length, (index) => index),
              _ => _batchTargetRows(),
            };
            if (rows.isEmpty) continue;
            final col = _selCol.clamp(0, dataCols - 1);
            for (final row in rows) {
              if (row < 0 || row >= _rows.length) continue;
              if (scope == 'fila') {
                for (int c = 0; c < dataCols; c++) {
                  _setCell(row, c, '');
                  applied += 1;
                  changed = true;
                  lastCol = c;
                }
                lastRow = row;
              } else {
                _setCell(row, col, '');
                applied += 1;
                changed = true;
                lastRow = row;
                lastCol = col;
              }
            }
            break;
          case FlowBotActionType.clearRow:
            if (_rows.isEmpty) continue;
            final scope = _normalizeFlowBotScopeToken(action.value ?? 'fila');
            final targetRows = scope == 'seleccion'
                ? _batchTargetRows()
                : <int>[_selRow.clamp(0, _rows.length - 1)];
            for (final row in targetRows) {
              if (row < 0 || row >= _rows.length) continue;
              for (int col = 0; col < dataCols; col++) {
                _setCell(row, col, '');
                applied += 1;
                changed = true;
                lastCol = col;
              }
              lastRow = row;
            }
            break;
          case FlowBotActionType.setColumnAlign:
            final col = (action.column ?? _selCol).clamp(0, dataCols - 1);
            final align = _gridTextAlignXFromStorageName(action.align);
            _setColumnPresentationForIndex(
              col,
              textAlign: align,
              verticalAlign: _GridTextAlignY.middle,
            );
            applied += 1;
            changed = true;
            lastCol = col;
            break;
          case FlowBotActionType.setWrap:
            final col = (action.column ?? _selCol).clamp(0, dataCols - 1);
            _setColumnPresentationForIndex(
              col,
              wrapLines: (action.lines ?? 2).clamp(1, 3),
            );
            applied += 1;
            changed = true;
            lastCol = col;
            break;
          case FlowBotActionType.applyStatus:
            final targets = _batchTargetRows();
            final statusCol = _statusColumnForBatchActions() ??
                _selCol.clamp(0, dataCols - 1);
            final value = (action.status ?? '').trim();
            if (targets.isEmpty || value.isEmpty) continue;
            for (final row in targets) {
              if (row < 0 || row >= _rows.length) continue;
              _setCell(row, statusCol, value);
              applied += 1;
              changed = true;
              lastRow = row;
              lastCol = statusCol;
            }
            break;
          case FlowBotActionType.setToday:
            final scope = _normalizeFlowBotToken(action.value ?? '');
            final targets = scope.contains('columna')
                ? List<int>.generate(_rows.length, (index) => index)
                : scope.contains('celda activa')
                    ? <int>[_selRow]
                    : scope.contains('fila')
                        ? <int>[_selRow]
                        : _batchTargetRows();
            final dateCol = _firstColumnByType(_ColType.date) ??
                _selCol.clamp(0, dataCols - 1);
            final value = _flowBotDateText(action.format);
            for (final row in targets) {
              if (row < 0 || row >= _rows.length) continue;
              _setCell(row, dateCol, value);
              applied += 1;
              changed = true;
              lastRow = row;
              lastCol = dateCol;
            }
            break;
          case FlowBotActionType.autoId:
            final targets = (() {
              final explicitCount = action.count;
              if (explicitCount != null && explicitCount > 0) {
                final startRow =
                    _selRow.clamp(0, math.max(_rows.length, 1) - 1);
                final rows = <int>[];
                for (int i = 0; i < explicitCount; i++) {
                  rows.add(startRow + i);
                }
                return rows;
              }
              return _batchTargetRows();
            }());
            if (targets.isEmpty) continue;
            final detectedCol = action.column ??
                _firstColumnMatchingFlowBotName('progresiva') ??
                _selCol;
            final col = detectedCol.clamp(0, dataCols - 1);
            final base = action.start ?? 1;
            final step = (action.step ?? 1) == 0 ? 1 : (action.step ?? 1);
            var index = 0;
            for (final row in targets) {
              while (row >= _rows.length) {
                _insertRow(_rows.length);
                changed = true;
              }
              if (row < 0 || row >= _rows.length) continue;
              final value = (base + (index * step)).toString();
              _setCell(row, col, value);
              applied += 1;
              changed = true;
              lastRow = row;
              lastCol = col;
              index++;
            }
            break;
          case FlowBotActionType.copyGps:
            if (_rows.isEmpty) continue;
            final sourceRow =
                (action.fromRow ?? _selRow).clamp(0, _rows.length - 1);
            final sourceCol = _selCol.clamp(0, dataCols - 1);
            final meta = _cellMetaAt(sourceRow, sourceCol)?.gps;
            if (meta == null) continue;
            final fix = _GpsFix(
              lat: meta.lat,
              lng: meta.lng,
              accuracyM: meta.accuracyM,
              ts: meta.timestamp,
              source: meta.source,
              provider: meta.provider,
            );
            for (final row in _batchTargetRows()) {
              if (row < 0 || row >= _rows.length) continue;
              _applyGpsFixToCell(
                row,
                sourceCol,
                fix,
                writeText: true,
                announce: false,
              );
              applied += 1;
              changed = true;
              lastRow = row;
              lastCol = sourceCol;
            }
            break;
          case FlowBotActionType.duplicateRow:
            if (_rows.isEmpty) continue;
            final row = (action.row ?? _selRow).clamp(0, _rows.length - 1);
            final count = (action.count ?? 1).clamp(1, 100);
            _duplicateRowMultiple(row, times: count, announce: false);
            applied += count;
            changed = true;
            lastRow = (row + count).clamp(0, _rows.length - 1);
            break;
          case FlowBotActionType.deleteRow:
            if (_rows.isEmpty) continue;
            final row = (action.row ?? _selRow).clamp(0, _rows.length - 1);
            _deleteRow(row);
            applied += 1;
            changed = true;
            lastRow = row.clamp(0, _rows.length - 1);
            lastCol = _selCol.clamp(0, dataCols - 1);
            break;
          case FlowBotActionType.addColumn:
            final label = (action.value ?? '').trim();
            if (label.isEmpty) {
              throw StateError('FlowBot no recibio nombre para la columna.');
            }
            final insertedCol = _addFlowBotColumn(label);
            applied += 1;
            changed = true;
            lastCol = insertedCol.clamp(0, _headers.length - 2);
            lastRow = _selRow.clamp(0, math.max(0, _rows.length - 1));
            break;
          case FlowBotActionType.renameColumn:
            final col = action.column;
            final label = (action.value ?? '').trim();
            if (col == null || col < 0 || col >= dataCols) {
              throw StateError('FlowBot no encontro la columna a renombrar.');
            }
            if (label.isEmpty) {
              throw StateError(
                  'FlowBot necesita un nombre nuevo para la columna.');
            }
            _renameFlowBotColumn(col, label);
            applied += 1;
            changed = true;
            lastCol = col.clamp(0, _headers.length - 2);
            lastRow = _selRow.clamp(0, math.max(0, _rows.length - 1));
            break;
          case FlowBotActionType.fillBlanks:
            final col = (action.column ?? _selCol).clamp(0, dataCols - 1);
            final value = action.value ?? '';
            if (value.trim().isEmpty) continue;
            for (int row = 0; row < _rows.length; row++) {
              if (_getCellText(row, col).trim().isNotEmpty) continue;
              _setCell(row, col, value);
              applied += 1;
              changed = true;
              lastRow = row;
              lastCol = col;
            }
            break;
          case FlowBotActionType.copyFromPreviousRow:
            if (_rows.length <= 1) continue;
            final row = (action.row ?? _selRow).clamp(0, _rows.length - 1);
            final col = (action.col ?? _selCol).clamp(0, dataCols - 1);
            if (row <= 0) continue;
            _setCell(row, col, _getCellText(row - 1, col));
            applied += 1;
            changed = true;
            lastRow = row;
            lastCol = col;
            break;
          case FlowBotActionType.attachPhotoToCell:
            if (_rows.isEmpty) continue;
            final row = (action.row ?? _selRow).clamp(0, _rows.length - 1);
            final col = (action.col ?? _selCol).clamp(0, dataCols - 1);
            await _startPhotoFlowForCell(row, col);
            applied += 1;
            changed = true;
            lastRow = row;
            lastCol = col;
            break;
          case FlowBotActionType.exportXlsx:
            await _exportXlsxOnly(share: false);
            applied += 1;
            break;
          case FlowBotActionType.exportPdfPreset:
            final preset = (action.presetId ?? 'default').trim().toLowerCase();
            await _exportPdf(
              includeAttachments: preset != 'lite',
              share: false,
            );
            applied += 1;
            break;
          case FlowBotActionType.pasteTable:
            final pasteResult = await _pasteTableSmartFromClipboard(
              emitFeedback: false,
              interactivePreview: false,
            );
            if (pasteResult.ok && pasteResult.applied > 0) {
              applied += pasteResult.applied;
              changed = true;
              lastRow = _selRow;
              lastCol = _selCol;
            }
            break;
          case FlowBotActionType.exportBundle:
            await _exportZipBundle(share: false);
            applied += 1;
            break;
        }
      }
    } catch (e, st) {
      flowBotDebugLog('Editor.apply error: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    } finally {
      _suspendUndoSnapshot = previousUndoFlag;
    }

    if (changed) {
      _pushUndoSnapshot();
    }

    final finalDataCols = _headers.length - 1;
    if (_rows.isNotEmpty && finalDataCols > 0) {
      _setSelectionAndRefreshGrid(
        lastRow.clamp(0, _rows.length - 1),
        lastCol.clamp(0, finalDataCols - 1),
        preserveRowSelection: true,
      );
    }

    flowBotDebugLog(
      'Editor.apply done applied=$applied changed=$changed '
      'selection=(${lastRow + 1},${lastCol + 1})',
    );
    return applied;
  }

  _ActionResult _flowBotResultForAppliedChanges(int applied) {
    if (applied > 0) {
      return _ActionResult(
        ok: true,
        message: 'Aplicado: $applied cambio(s).',
        applied: applied,
        undoToken: 'flowbot_apply',
      );
    }
    return const _ActionResult(
      ok: false,
      message:
          'FlowBot no aplico cambios. Revisa seleccion/comando y vuelve a analizar.',
      applied: 0,
    );
  }

  Future<void> _openFlowBotSheet() async {
    if (!mounted) return;
    _commitActiveEditors();
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.wait<void>([
      _loadFlowBotHistoryPrefs(),
      _loadFlowBotFavoritesPrefs(),
    ]);
    if (!mounted) return;
    final transcriptEC = TextEditingController();
    final speech = SpeechService.I;

    final parsedActions = await showModalBottomSheet<List<FlowBotAction>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final pal = _palette(ctx);
        var preview = <FlowBotAction>[];
        var parsing = false;
        var listening = false;
        var warning = '';
        var level = 0.0;
        var chosenScope = _flowBotLastScope;
        var activeEngine = _flowBotUseLocalLlm ? 'local_llm' : 'rule_based';
        var localModelReady = _flowBotLocalModelPath.trim().isNotEmpty;
        var showAdvancedOptions = false;
        var previewSourceText = '';

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            Future<FlowBotParseResult> parseNow() async {
              final text = transcriptEC.text.trim();
              if (text.isEmpty) {
                if (modalCtx.mounted) {
                  setModalState(() {
                    preview = <FlowBotAction>[];
                    previewSourceText = '';
                    warning = _flowBotApplyDisabledReason(
                      preview: const <FlowBotAction>[],
                      parsing: false,
                      useLocalLlm: _flowBotUseLocalLlm,
                      localModelReady: localModelReady,
                      hasTranscript: false,
                    );
                  });
                }
                return const FlowBotParseResult(
                  actions: <FlowBotAction>[],
                  engine: 'rule_based',
                  warning: 'Escribe un cambio puntual antes de aplicar.',
                );
              }
              FocusManager.instance.primaryFocus?.unfocus();
              setModalState(() {
                parsing = true;
                warning = '';
              });
              try {
                final result = await _parseFlowBotCommand(text);
                if (!modalCtx.mounted) return result;
                setModalState(() {
                  preview = result.actions;
                  previewSourceText = text;
                  parsing = false;
                  warning = result.actions.isEmpty
                      ? flowBotNoActionsMessage(
                          reason: flowBotNoActionsReason(result.warning),
                          examples: flowBotPreferredExamples(
                            examples: _flowBotContextExamples(
                              _flowBotQuickContext(),
                            ),
                          ),
                        )
                      : result.warning ?? '';
                  activeEngine = result.engine;
                });
                if (result.actions.isNotEmpty) {
                  _lastFlowBotValidCommand = text;
                }
                return result;
              } catch (e, st) {
                flowBotDebugLog('Modal.parse error: $e');
                debugPrintStack(stackTrace: st);
                FlutterError.reportError(
                  FlutterErrorDetails(
                    exception: e,
                    stack: st,
                    library: 'flowbot',
                    context:
                        ErrorDescription('while analyzing a FlowBot command'),
                  ),
                );
                final failure = FlowBotParseResult(
                  actions: const <FlowBotAction>[],
                  engine: activeEngine,
                  warning: 'Error al analizar: $e',
                );
                if (!modalCtx.mounted) return failure;
                setModalState(() {
                  preview = <FlowBotAction>[];
                  previewSourceText = '';
                  parsing = false;
                  warning = failure.warning ?? '';
                });
                return failure;
              }
            }

            Future<void> confirmApply() async {
              final text = transcriptEC.text.trim();
              final initialScopedPreview = _applyScopeToFlowBotActions(
                preview,
                chosenScope,
              );

              if (parsing) {
                setModalState(() {
                  warning = _flowBotApplyDisabledReason(
                    preview: initialScopedPreview,
                    parsing: true,
                    useLocalLlm: _flowBotUseLocalLlm,
                    localModelReady: localModelReady,
                    hasTranscript: text.isNotEmpty,
                    parseWarning: warning,
                  );
                });
                return;
              }
              final canApply = _flowBotCanApplyPreview(
                preview: initialScopedPreview,
                parsing: parsing,
              );
              if (!canApply) {
                setModalState(() {
                  warning = _flowBotApplyDisabledReason(
                    preview: initialScopedPreview,
                    parsing: parsing,
                    useLocalLlm: _flowBotUseLocalLlm,
                    localModelReady: localModelReady,
                    hasTranscript: text.isNotEmpty,
                    parseWarning: warning,
                  );
                });
                return;
              }
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.of(modalCtx)
                  .pop(List<FlowBotAction>.from(initialScopedPreview));
            }

            Future<void> startListening() async {
              if (listening) {
                await speech.cancel();
                if (!modalCtx.mounted) return;
                setModalState(() => listening = false);
                return;
              }
              final ok = await speech.init(preferredLocale: 'es');
              if (!ok) {
                if (!modalCtx.mounted) return;
                setModalState(() {
                  warning = 'Voz no disponible en este dispositivo.';
                });
                return;
              }
              if (!modalCtx.mounted) return;
              setModalState(() {
                listening = true;
                warning = '';
              });
              final text = await speech.listenOnce(
                partial: (partial) {
                  transcriptEC.text = partial;
                  transcriptEC.selection = TextSelection.collapsed(
                    offset: transcriptEC.text.length,
                  );
                },
                level: (value) {
                  if (!modalCtx.mounted) return;
                  setModalState(() => level = value.clamp(0.0, 1.0));
                },
                autoTimeout: const Duration(seconds: 18),
              );
              if (!modalCtx.mounted) return;
              setModalState(() => listening = false);
              if (text != null && text.trim().isNotEmpty) {
                transcriptEC.text = text.trim();
                transcriptEC.selection = TextSelection.collapsed(
                  offset: transcriptEC.text.length,
                );
                await parseNow();
              }
            }

            final scopedPreview = _applyScopeToFlowBotActions(
              preview,
              chosenScope,
            );
            final previewPatches = _flowBotPreviewPatches(scopedPreview);
            final summary = _flowBotPreviewSummary(previewPatches);
            final statusText = _flowBotStatusText(
              preview: scopedPreview,
              parsing: parsing,
            );
            final canApply = _flowBotCanApplyPreview(
              preview: scopedPreview,
              parsing: parsing,
            );
            final applyDisabledReason = _flowBotApplyDisabledReason(
              preview: scopedPreview,
              parsing: parsing,
              useLocalLlm: _flowBotUseLocalLlm,
              localModelReady: localModelReady,
              hasTranscript: transcriptEC.text.trim().isNotEmpty,
              parseWarning: warning,
            );

            final media = MediaQuery.of(modalCtx);
            final compactSheet = media.size.width < 520;
            final ultraCompactSheet =
                media.size.width < 360 || media.size.height < 660;
            final bottomInset = media.viewInsets.bottom;
            final availableSheetHeight = media.size.height -
                media.padding.top -
                media.padding.bottom -
                20;
            final maxSheetHeight = math.max(
              320.0,
              math.min(
                availableSheetHeight,
                compactSheet ? 700.0 : 760.0,
              ),
            );
            final previewMaxHeight = compactSheet ? 188.0 : 230.0;
            final actionsMaxHeight = compactSheet ? 104.0 : 120.0;
            final historyChipMaxWidth = math.max(
              120.0,
              math.min(media.size.width - 72, compactSheet ? 216.0 : 300.0),
            );
            final flowBotContext = _flowBotQuickContext();
            final contextHelpExamples = flowBotPreferredExamples(
              examples: _flowBotContextExamples(flowBotContext),
            );
            final suggestedQuickActions =
                _flowBotSuggestedQuickActions(flowBotContext);
            final userFavoriteIdentityKeys = _flowBotFavorites
                .map((favorite) => favorite.identityKey)
                .toSet();
            final templateSuggestedFavorites =
                _flowBotTemplateSuggestedFavorites()
                    .where((favorite) => !userFavoriteIdentityKeys
                        .contains(favorite.identityKey))
                    .toList(growable: false);
            final templateSuggestedQuickActionIds = templateSuggestedFavorites
                .where((favorite) => favorite.isQuickAction)
                .map((favorite) => favorite.quickActionId)
                .toSet();
            final sectionSuggestedQuickActions = suggestedQuickActions
                .where((action) =>
                    !userFavoriteIdentityKeys.contains(
                      _flowBotFavoriteForAction(action).identityKey,
                    ) &&
                    !templateSuggestedQuickActionIds.contains(action.id))
                .toList(growable: false);
            final primaryQuickActions = sectionSuggestedQuickActions
                .take(compactSheet ? 4 : 6)
                .toList(growable: false);
            final recentCommands = _flowBotHistory
                .take(_maxFlowBotHistoryItems)
                .toList(growable: false);
            final favoriteShortcuts = _flowBotFavorites
                .take(_maxFlowBotFavoriteItems)
                .toList(growable: false);
            final exampleCommands = _flowBotContextExamples(flowBotContext);

            Widget buildVoiceControls() {
              if (compactSheet) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OverflowBar(
                      spacing: 8,
                      overflowSpacing: 8,
                      children: [
                        AppleButton(
                          key: const ValueKey('flowbot-voice'),
                          label: listening ? 'Detener' : 'Dictar',
                          icon: listening
                              ? Icons.stop_rounded
                              : Icons.mic_none_rounded,
                          dense: true,
                          variant: AppleButtonVariant.ghost,
                          onPressed: () => unawaited(startListening()),
                        ),
                        AppleButton(
                          key: const ValueKey('flowbot-analyze'),
                          label: parsing ? 'Analizando...' : 'Analizar',
                          icon: Icons.play_arrow_rounded,
                          dense: true,
                          variant: AppleButtonVariant.tonal,
                          onPressed: parsing
                              ? null
                              : () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  unawaited(parseNow());
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: listening ? level : 0,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(999),
                      backgroundColor: pal.cellText.withValues(alpha: 0.08),
                      color: pal.accent,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  AppleButton(
                    key: const ValueKey('flowbot-voice'),
                    label: listening ? 'Detener' : 'Dictar',
                    icon:
                        listening ? Icons.stop_rounded : Icons.mic_none_rounded,
                    dense: true,
                    variant: AppleButtonVariant.ghost,
                    onPressed: () => unawaited(startListening()),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: listening ? level : 0,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(999),
                      backgroundColor: pal.cellText.withValues(alpha: 0.08),
                      color: pal.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppleButton(
                    key: const ValueKey('flowbot-analyze'),
                    label: parsing ? 'Analizando...' : 'Analizar',
                    icon: Icons.play_arrow_rounded,
                    dense: true,
                    variant: AppleButtonVariant.tonal,
                    onPressed: parsing
                        ? null
                        : () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            unawaited(parseNow());
                          },
                  ),
                ],
              );
            }

            Future<void> toggleFlowBotEngine() async {
              final next = !_flowBotUseLocalLlm;
              await _setEditorDefaultRules(flowBotUseLocalLlm: next);
              if (!modalCtx.mounted) return;
              setModalState(() {
                activeEngine = next ? 'local_llm' : 'rule_based';
                preview = <FlowBotAction>[];
                previewSourceText = '';
                showAdvancedOptions = showAdvancedOptions || next;
                if (next && _flowBotLocalModelPath.trim().isEmpty) {
                  warning =
                      'Local LLM activo sin modelo: se usa parser offline.';
                } else {
                  warning = '';
                }
              });
            }

            Future<void> refreshLocalModelReady() async {
              await _downloadFlowBotLocalModel();
              if (!modalCtx.mounted) return;
              final ready = await _flowBotHasLocalModel();
              if (!modalCtx.mounted) return;
              setModalState(() {
                localModelReady = ready;
                showAdvancedOptions = !ready;
              });
            }

            void fillCommandText(String value) {
              transcriptEC.text = value;
              transcriptEC.selection = TextSelection.collapsed(
                offset: value.length,
              );
            }

            Future<String?> promptQuickActionValue(
              _FlowBotQuickActionSpec action,
            ) async {
              var draftValue = '';
              final result = await showAppModal<String>(
                context: modalCtx,
                title: action.promptTitle ?? 'Completa la accion',
                child: TextFormField(
                  key: ValueKey('flowbot-quick-input-${action.id}'),
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: action.promptLabel ?? 'Valor',
                    hintText: action.promptHint,
                  ),
                  onChanged: (value) => draftValue = value,
                  onFieldSubmitted: (value) =>
                      Navigator.of(modalCtx).pop(value.trim()),
                ),
                actions: [
                  AppButton(
                    label: AppStrings.cancel,
                    variant: AppButtonVariant.ghost,
                    onPressed: () => Navigator.of(modalCtx).pop(),
                  ),
                  AppButton(
                    label: 'Previsualizar',
                    variant: AppButtonVariant.primary,
                    onPressed: () =>
                        Navigator.of(modalCtx).pop(draftValue.trim()),
                  ),
                ],
                showClose: false,
                barrierDismissible: true,
              );
              final text = (result ?? '').trim();
              return text.isEmpty ? null : text;
            }

            Future<void> runQuickAction(_FlowBotQuickActionSpec action) async {
              String? promptValue;
              if (action.requiresValue) {
                promptValue = await promptQuickActionValue(action);
                if (promptValue == null || !modalCtx.mounted) return;
              }
              final command = action.buildCommand(promptValue).trim();
              if (command.isEmpty) return;
              fillCommandText(command);
              if (!modalCtx.mounted) return;
              setModalState(() {
                warning = '';
              });
              await parseNow();
            }

            Future<void> runSavedCommand(String command) async {
              fillCommandText(command);
              if (!modalCtx.mounted) return;
              setModalState(() {
                warning = '';
              });
              await parseNow();
            }

            _FlowBotQuickActionSpec? resolveFavoriteAction(
              FlowBotFavoriteShortcut favorite,
            ) {
              if (!favorite.isQuickAction) return null;
              for (final action in suggestedQuickActions) {
                if (action.id == favorite.quickActionId) {
                  return action;
                }
              }
              return null;
            }

            Future<void> runFavoriteShortcut(
              FlowBotFavoriteShortcut favorite,
            ) async {
              if (favorite.isQuickAction) {
                final action = resolveFavoriteAction(favorite);
                if (action == null) {
                  setModalState(() {
                    preview = <FlowBotAction>[];
                    previewSourceText = '';
                    warning =
                        'Este favorito no aplica a la hoja o seleccion actual.';
                  });
                  return;
                }
                await runQuickAction(action);
                return;
              }
              await runSavedCommand(favorite.command);
            }

            Future<void> toggleActionFavorite(
              _FlowBotQuickActionSpec action,
            ) async {
              await _toggleFlowBotFavoriteEntry(
                  _flowBotFavoriteForAction(action));
              if (!modalCtx.mounted) return;
              setModalState(() {});
            }

            Future<void> toggleCommandFavorite(String command) async {
              await _toggleFlowBotFavoriteEntry(
                _flowBotFavoriteForCommand(command),
              );
              if (!modalCtx.mounted) return;
              setModalState(() {});
            }

            Widget buildFavoritableChip({
              required Key pressKey,
              Key? favoriteKey,
              required String label,
              required IconData icon,
              required Future<void> Function() onRun,
              Future<void> Function()? onToggleFavorite,
              required bool isFavorite,
              bool invalid = false,
            }) {
              final fg = invalid ? pal.fgMuted : pal.fg;
              final bg = invalid
                  ? pal.mobileInputBg
                  : isFavorite
                      ? pal.accent.withValues(alpha: 0.12)
                      : pal.menuBg;
              final border = invalid
                  ? pal.border
                  : isFavorite
                      ? pal.accent.withValues(alpha: 0.26)
                      : pal.border;
              return Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: border, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Flexible(
                      child: InkWell(
                        key: pressKey,
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => unawaited(onRun()),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Icon(icon, size: 16, color: fg),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: TextStyle(
                                    color: fg,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (onToggleFavorite != null)
                      IconButton(
                        key: favoriteKey,
                        tooltip:
                            isFavorite ? 'Quitar favorito' : 'Guardar favorito',
                        onPressed: () => unawaited(onToggleFavorite()),
                        icon: Icon(
                          isFavorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 18,
                          color: isFavorite ? pal.accent : pal.fgMuted,
                        ),
                        visualDensity: VisualDensity.compact,
                        splashRadius: 16,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                  ],
                ),
              );
            }

            Widget buildActionChip(
              _FlowBotQuickActionSpec action, {
              bool compact = false,
            }) {
              if (compact) {
                return ActionChip(
                  key: ValueKey('flowbot-quick-primary-${action.id}'),
                  avatar: Icon(action.icon, size: 16, color: pal.fgMuted),
                  label: Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => unawaited(runQuickAction(action)),
                );
              }
              final isFavorite = _isFlowBotFavoriteAction(action);
              return buildFavoritableChip(
                pressKey: ValueKey('flowbot-quick-suggested-${action.id}'),
                favoriteKey:
                    ValueKey('flowbot-suggested-favorite-toggle-${action.id}'),
                label: action.label,
                icon: action.icon,
                onRun: () => runQuickAction(action),
                onToggleFavorite: () => toggleActionFavorite(action),
                isFavorite: isFavorite,
              );
            }

            Widget buildQuickActionStrip() {
              if (primaryQuickActions.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acciones rapidas',
                    style: TextStyle(
                      color: pal.fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final action in primaryQuickActions)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: historyChipMaxWidth,
                          ),
                          child: buildActionChip(action, compact: true),
                        ),
                    ],
                  ),
                ],
              );
            }

            Widget buildSuggestedActionsSection() {
              if (sectionSuggestedQuickActions.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sugeridas',
                    style: TextStyle(
                      color: pal.fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final action in sectionSuggestedQuickActions)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: historyChipMaxWidth,
                          ),
                          child: buildActionChip(action),
                        ),
                    ],
                  ),
                ],
              );
            }

            Widget buildTemplateSuggestedFavoritesSection() {
              if (templateSuggestedFavorites.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Favoritos recomendados',
                    style: TextStyle(
                      color: pal.fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (int index = 0;
                          index < templateSuggestedFavorites.length;
                          index++)
                        Builder(
                          builder: (_) {
                            final favorite = templateSuggestedFavorites[index];
                            final resolvedAction =
                                resolveFavoriteAction(favorite);
                            final label =
                                resolvedAction?.label ?? favorite.label;
                            final icon = resolvedAction?.icon ??
                                (favorite.isQuickAction
                                    ? Icons.auto_awesome_rounded
                                    : Icons.lightbulb_outline_rounded);
                            return ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: historyChipMaxWidth,
                              ),
                              child: buildFavoritableChip(
                                pressKey: ValueKey(
                                  'flowbot-template-favorite-chip-$index',
                                ),
                                favoriteKey: resolvedAction == null
                                    ? null
                                    : ValueKey(
                                        'flowbot-template-favorite-toggle-$index',
                                      ),
                                label: label,
                                icon: icon,
                                invalid: favorite.isQuickAction &&
                                    resolvedAction == null,
                                onRun: () => runFavoriteShortcut(favorite),
                                onToggleFavorite: resolvedAction == null
                                    ? null
                                    : () =>
                                        toggleActionFavorite(resolvedAction),
                                isFavorite: false,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ],
              );
            }

            Widget buildFavoritesSection() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Favoritos',
                    style: TextStyle(
                      color: pal.fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (favoriteShortcuts.isEmpty)
                    Text(
                      'Guarda accesos repetidos para usarlos en uno o dos toques.',
                      style: TextStyle(
                        color: pal.fgMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (int index = 0;
                            index < favoriteShortcuts.length;
                            index++)
                          Builder(
                            builder: (_) {
                              final favorite = favoriteShortcuts[index];
                              final resolvedAction =
                                  resolveFavoriteAction(favorite);
                              final label =
                                  resolvedAction?.label ?? favorite.label;
                              final icon = resolvedAction?.icon ??
                                  (favorite.isQuickAction
                                      ? Icons.auto_awesome_rounded
                                      : Icons.history_rounded);
                              return ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: historyChipMaxWidth,
                                ),
                                child: buildFavoritableChip(
                                  pressKey:
                                      ValueKey('flowbot-favorite-chip-$index'),
                                  favoriteKey: ValueKey(
                                    'flowbot-favorite-toggle-$index',
                                  ),
                                  label: label,
                                  icon: icon,
                                  invalid: favorite.isQuickAction &&
                                      resolvedAction == null,
                                  onRun: () => runFavoriteShortcut(favorite),
                                  onToggleFavorite: () async {
                                    await _toggleFlowBotFavoriteEntry(favorite);
                                    if (!modalCtx.mounted) return;
                                    setModalState(() {});
                                  },
                                  isFavorite: true,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                ],
              );
            }

            Widget buildCommandSection({
              required String title,
              required List<String> commands,
              required String keyPrefix,
              String? emptyLabel,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: pal.fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (commands.isEmpty &&
                          (emptyLabel ?? '').trim().isNotEmpty)
                        Text(
                          emptyLabel!,
                          style: TextStyle(
                            color: pal.fgMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      for (int index = 0; index < commands.length; index++)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: historyChipMaxWidth,
                          ),
                          child: buildFavoritableChip(
                            pressKey: ValueKey('$keyPrefix-$index'),
                            favoriteKey:
                                ValueKey('$keyPrefix-favorite-toggle-$index'),
                            label: commands[index],
                            icon: title == 'Ejemplos reales'
                                ? Icons.lightbulb_outline_rounded
                                : Icons.history_rounded,
                            onRun: () => runSavedCommand(commands[index]),
                            onToggleFavorite: title == 'Ejemplos reales'
                                ? null
                                : () => toggleCommandFavorite(commands[index]),
                            isFavorite: title == 'Ejemplos reales'
                                ? false
                                : _isFlowBotFavoriteCommand(commands[index]),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            }

            Widget buildNoActionsHelp() {
              if (scopedPreview.isNotEmpty || parsing) {
                return const SizedBox.shrink();
              }
              return Container(
                key: const ValueKey('flowbot-empty-help'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: pal.mobileInputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: pal.border,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Elegi una accion rapida o escribe una instruccion valida.',
                      style: TextStyle(
                        color: pal.fg,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (int index = 0;
                            index < contextHelpExamples.length;
                            index++)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: historyChipMaxWidth,
                            ),
                            child: buildFavoritableChip(
                              pressKey:
                                  ValueKey('flowbot-empty-help-chip-$index'),
                              label: contextHelpExamples[index],
                              icon: Icons.bolt_rounded,
                              onRun: () => runSavedCommand(
                                contextHelpExamples[index],
                              ),
                              isFavorite: false,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }

            Widget buildInputFallbackSection() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instruccion libre (opcional)',
                    style: TextStyle(
                      color: pal.fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Usala solo si no ves un atajo arriba.',
                    style: TextStyle(
                      color: pal.fgMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('flowbot-command-input'),
                    controller: transcriptEC,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    onChanged: (value) {
                      final trimmed = value.trim();
                      if (trimmed == previewSourceText) {
                        return;
                      }
                      setModalState(() {
                        preview = <FlowBotAction>[];
                        previewSourceText = '';
                        warning = '';
                      });
                    },
                    onSubmitted: (_) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      if (canApply) {
                        unawaited(confirmApply());
                      } else {
                        unawaited(parseNow());
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Ej: poner OK en ${flowBotContext.cellToken}',
                      filled: true,
                      fillColor: pal.mobileInputBg,
                    ),
                  ),
                  const SizedBox(height: 8),
                  buildVoiceControls(),
                ],
              );
            }

            Widget buildAdvancedPanel() {
              if (!(kDebugMode && _flowBotShowDebugTools)) {
                return const SizedBox.shrink();
              }
              if (!showAdvancedOptions) {
                return Align(
                  alignment: Alignment.centerRight,
                  child: AppleButton(
                    key: const ValueKey('flowbot-advanced-toggle'),
                    label: 'Opciones de modelo (debug)',
                    icon: Icons.science_outlined,
                    dense: true,
                    variant: AppleButtonVariant.ghost,
                    onPressed: () =>
                        setModalState(() => showAdvancedOptions = true),
                  ),
                );
              }
              return Container(
                key: const ValueKey('flowbot-advanced-panel'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: pal.mobileInputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: pal.border,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Opciones de modelo (debug)',
                                style: TextStyle(
                                  color: pal.fg,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppleButton(
                          key: const ValueKey('flowbot-advanced-toggle'),
                          label: 'Ocultar',
                          icon: Icons.expand_less_rounded,
                          dense: true,
                          variant: AppleButtonVariant.ghost,
                          onPressed: () =>
                              setModalState(() => showAdvancedOptions = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      activeEngine == 'local_llm'
                          ? (localModelReady
                              ? 'Motor activo: Local LLM listo.'
                              : 'Local LLM activo sin modelo local listo.')
                          : 'Motor activo: parser offline deterministico.',
                      style: TextStyle(
                        color: pal.fgMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppleButton(
                          label: _flowBotUseLocalLlm
                              ? 'Usar motor offline'
                              : 'Usar Local LLM',
                          icon: Icons.settings_suggest_rounded,
                          dense: true,
                          variant: AppleButtonVariant.ghost,
                          onPressed: () => unawaited(toggleFlowBotEngine()),
                        ),
                        AppleButton(
                          label: _flowBotModelDownloading
                              ? 'Descargando...'
                              : (localModelReady
                                  ? 'Actualizar modelo'
                                  : 'Descargar modelo'),
                          icon: _flowBotModelDownloading
                              ? Icons.downloading_rounded
                              : Icons.download_rounded,
                          dense: true,
                          variant: AppleButtonVariant.ghost,
                          onPressed: _flowBotModelDownloading
                              ? null
                              : () => unawaited(refreshLocalModelReady()),
                        ),
                      ],
                    ),
                    if (_flowBotModelDownloading) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _flowBotModelDownloadProgress > 0
                            ? _flowBotModelDownloadProgress
                            : null,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(999),
                        backgroundColor: pal.cellText.withValues(alpha: 0.08),
                        color: pal.accent,
                      ),
                    ],
                  ],
                ),
              );
            }

            Widget buildFooterActions() {
              if (compactSheet) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OverflowBar(
                      spacing: 8,
                      overflowSpacing: 8,
                      alignment: MainAxisAlignment.end,
                      children: [
                        AppleButton(
                          label: 'Cancelar',
                          dense: true,
                          variant: AppleButtonVariant.ghost,
                          onPressed: () => Navigator.of(modalCtx).pop(),
                        ),
                        AppleButton(
                          key: const ValueKey('flowbot-apply'),
                          label: 'Aplicar cambios',
                          icon: canApply
                              ? Icons.check_rounded
                              : Icons.block_rounded,
                          dense: true,
                          variant: canApply
                              ? AppleButtonVariant.filled
                              : AppleButtonVariant.ghost,
                          onPressed:
                              canApply ? () => unawaited(confirmApply()) : null,
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppleButton(
                    label: 'Cancelar',
                    dense: true,
                    variant: AppleButtonVariant.ghost,
                    onPressed: () => Navigator.of(modalCtx).pop(),
                  ),
                  const SizedBox(width: 8),
                  AppleButton(
                    key: const ValueKey('flowbot-apply'),
                    label: 'Aplicar cambios',
                    icon: canApply ? Icons.check_rounded : Icons.block_rounded,
                    dense: true,
                    variant: canApply
                        ? AppleButtonVariant.filled
                        : AppleButtonVariant.ghost,
                    onPressed:
                        canApply ? () => unawaited(confirmApply()) : null,
                  ),
                ],
              );
            }

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 720,
                    ),
                    child: SizedBox(
                      height: maxSheetHeight,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        padding: EdgeInsets.fromLTRB(
                          12,
                          10,
                          12,
                          compactSheet ? 10 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: pal.menuBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: pal.borderStrong, width: 1),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome_rounded, color: pal.fg),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'FlowBot',
                                    style: TextStyle(
                                      color: pal.fg,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  key: const ValueKey('flowbot-close'),
                                  tooltip: 'Cerrar',
                                  onPressed: () => Navigator.of(modalCtx).pop(),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: pal.fgMuted,
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Empieza por un favorito o una accion sugerida. Si no aparece, usa la instruccion libre.',
                                      style: TextStyle(
                                        color: pal.fgMuted,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: pal.mobileInputBg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: pal.border,
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              _flowBotContextChip(
                                                label: flowBotContext.sheetName,
                                                icon:
                                                    Icons.table_chart_outlined,
                                                fg: pal.fg,
                                                bg: pal.menuBg,
                                                border: pal.border,
                                              ),
                                              _flowBotContextChip(
                                                label:
                                                    'Celda ${flowBotContext.cellToken}',
                                                icon: Icons.crop_free_rounded,
                                                fg: pal.fg,
                                                bg: pal.menuBg,
                                                border: pal.border,
                                              ),
                                              _flowBotContextChip(
                                                label:
                                                    'Fila ${flowBotContext.rowNumber}',
                                                icon: Icons.table_rows_rounded,
                                                fg: pal.fg,
                                                bg: pal.menuBg,
                                                border: pal.border,
                                              ),
                                              _flowBotContextChip(
                                                label:
                                                    flowBotContext.columnLabel,
                                                icon:
                                                    Icons.view_column_outlined,
                                                fg: pal.fg,
                                                bg: pal.menuBg,
                                                border: pal.border,
                                              ),
                                            ],
                                          ),
                                          if (flowBotContext.visibleColumnLabels
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              'Columnas visibles: ${flowBotContext.visibleColumnLabels.join(' · ')}',
                                              style: TextStyle(
                                                color: pal.fgMuted,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    buildQuickActionStrip(),
                                    const SizedBox(height: 10),
                                    buildFavoritesSection(),
                                    const SizedBox(height: 10),
                                    buildTemplateSuggestedFavoritesSection(),
                                    if (templateSuggestedFavorites.isNotEmpty)
                                      const SizedBox(height: 10),
                                    buildSuggestedActionsSection(),
                                    const SizedBox(height: 10),
                                    buildCommandSection(
                                      title: 'Recientes',
                                      commands: recentCommands,
                                      keyPrefix: 'flowbot-history-chip',
                                      emptyLabel:
                                          'Todavia no usaste acciones recientes.',
                                    ),
                                    const SizedBox(height: 10),
                                    buildInputFallbackSection(),
                                    const SizedBox(height: 10),
                                    buildCommandSection(
                                      title: 'Ejemplos reales',
                                      commands: exampleCommands,
                                      keyPrefix: 'flowbot-example-chip',
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      key: const ValueKey('flowbot-status'),
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scopedPreview.isEmpty
                                            ? pal.mobileInputBg
                                            : pal.accent
                                                .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: scopedPreview.isEmpty
                                              ? pal.border
                                              : pal.accent
                                                  .withValues(alpha: 0.25),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          color: scopedPreview.isEmpty
                                              ? pal.fgMuted
                                              : pal.fg,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    buildNoActionsHelp(),
                                    if (warning.trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        key: const ValueKey('flowbot-warning'),
                                        warning,
                                        style: TextStyle(
                                          color: pal.fgMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Text(
                                      'Vista previa',
                                      style: TextStyle(
                                        color: pal.fg,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (previewPatches.isEmpty)
                                      Text(
                                        scopedPreview.isEmpty
                                            ? 'Sin preview de celdas.'
                                            : 'Sin preview de celdas para este cambio; revisa las acciones detectadas.',
                                        style: TextStyle(
                                          color: pal.fgMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    else if (compactSheet) ...[
                                      Text(
                                        'Resumen',
                                        style: TextStyle(
                                          color: pal.fg,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${summary.cells} celdas / ${summary.rows} filas / ${summary.cols} columnas',
                                        style: TextStyle(
                                          color: pal.fgMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ] else
                                      Row(
                                        children: [
                                          Text(
                                            'Resumen',
                                            style: TextStyle(
                                              color: pal.fg,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${summary.cells} celdas / ${summary.rows} filas / ${summary.cols} columnas',
                                              style: TextStyle(
                                                color: pal.fgMuted,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 6),
                                    if (_flowBotActionsSupportScope(preview))
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          for (final option in const <String>[
                                            'celda',
                                            'seleccion',
                                            'fila',
                                            'columna',
                                          ])
                                            ChoiceChip(
                                              label: Text(
                                                option == 'seleccion'
                                                    ? 'seleccion'
                                                    : option,
                                              ),
                                              selected: chosenScope == option,
                                              onSelected: (selected) {
                                                if (!selected) return;
                                                setModalState(
                                                  () => chosenScope = option,
                                                );
                                                unawaited(
                                                  _setFlowBotLastScope(option),
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                    if (_flowBotActionsSupportScope(preview))
                                      const SizedBox(height: 6),
                                    Container(
                                      constraints: BoxConstraints(
                                        maxHeight: previewMaxHeight,
                                      ),
                                      decoration: BoxDecoration(
                                        color: pal.mobileInputBg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: pal.border,
                                          width: 1,
                                        ),
                                      ),
                                      child: previewPatches.isEmpty
                                          ? Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: Text(
                                                scopedPreview.isEmpty
                                                    ? 'Analiza un comando para revisar las celdas que van a cambiar.'
                                                    : 'Esta propuesta no cambia celdas puntuales. Revisa la lista de acciones.',
                                                style: TextStyle(
                                                  color: pal.fgMuted,
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            )
                                          : SingleChildScrollView(
                                              padding: const EdgeInsets.all(8),
                                              child: Table(
                                                defaultVerticalAlignment:
                                                    TableCellVerticalAlignment
                                                        .middle,
                                                columnWidths: const <int,
                                                    TableColumnWidth>{
                                                  0: IntrinsicColumnWidth(),
                                                  1: IntrinsicColumnWidth(),
                                                  2: FlexColumnWidth(),
                                                  3: FlexColumnWidth(),
                                                },
                                                children: [
                                                  TableRow(
                                                    children: [
                                                      _flowBotPreviewHeaderCell(
                                                        'Fila',
                                                        pal.fgMuted,
                                                      ),
                                                      _flowBotPreviewHeaderCell(
                                                        'Col',
                                                        pal.fgMuted,
                                                      ),
                                                      _flowBotPreviewHeaderCell(
                                                        'Antes',
                                                        pal.fgMuted,
                                                      ),
                                                      _flowBotPreviewHeaderCell(
                                                        'Despues',
                                                        pal.fgMuted,
                                                      ),
                                                    ],
                                                  ),
                                                  for (final patch
                                                      in previewPatches.take(5))
                                                    TableRow(
                                                      children: [
                                                        _flowBotPreviewDataCell(
                                                          '${patch.row + 1}',
                                                          pal.fgMuted,
                                                        ),
                                                        _flowBotPreviewDataCell(
                                                          _headerLabel(
                                                            patch.col.clamp(
                                                              0,
                                                              math.max(
                                                                0,
                                                                _headers.length -
                                                                    2,
                                                              ),
                                                            ),
                                                          ),
                                                          pal.fgMuted,
                                                        ),
                                                        _flowBotPreviewDataCell(
                                                          patch.before.isEmpty
                                                              ? '""'
                                                              : patch.before,
                                                          pal.fgMuted,
                                                        ),
                                                        _flowBotPreviewDataCell(
                                                          patch.after.isEmpty
                                                              ? '""'
                                                              : patch.after,
                                                          pal.fg,
                                                          highlighted: true,
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Acciones detectadas',
                                      style: TextStyle(
                                        color: pal.fg,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (scopedPreview.isEmpty)
                                      Text(
                                        'No hay cambios listos.',
                                        style: TextStyle(
                                          color: pal.fgMuted,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    else
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxHeight: actionsMaxHeight,
                                        ),
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: scopedPreview.length,
                                          itemBuilder: (itemCtx, index) {
                                            final action = scopedPreview[index];
                                            return ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              leading: Icon(
                                                Icons.bolt_rounded,
                                                size: 16,
                                                color: pal.fgMuted,
                                              ),
                                              title: Text(
                                                _flowBotActionLabel(action),
                                                style: TextStyle(
                                                  color: pal.fg,
                                                  fontSize: 12.2,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    const SizedBox(height: 10),
                                    buildAdvancedPanel(),
                                    if (compactSheet && ultraCompactSheet) ...[
                                      const SizedBox(height: 10),
                                      buildFooterActions(),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (!compactSheet || !ultraCompactSheet) ...[
                              const SizedBox(height: 10),
                              buildFooterActions(),
                            ],
                            if (!canApply && !compactSheet) ...[
                              const SizedBox(height: 6),
                              Text(
                                applyDisabledReason,
                                style: TextStyle(
                                  color: pal.fgMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    await speech.cancel();
    if (!mounted || parsedActions == null) return;
    if (parsedActions.isEmpty) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message:
              'FlowBot no tiene cambios listos. Analiza un comando primero.',
        ),
        failureIcon: Icons.warning_amber_rounded,
      );
      return;
    }
    try {
      final appliedCommand = transcriptEC.text.trim();
      flowBotDebugLog(
        'Modal.apply actions=${parsedActions.map((action) => action.toJson()).join(', ')}',
      );
      final applied = await _applyFlowBotActions(parsedActions);
      if (!mounted) return;
      if (applied > 0 && appliedCommand.isNotEmpty) {
        await _rememberFlowBotHistory(appliedCommand);
        _lastFlowBotValidCommand = appliedCommand;
      }
      final result = _flowBotResultForAppliedChanges(applied);
      _emitActionResult(
        result,
        successIcon: Icons.auto_awesome_rounded,
        failureIcon: Icons.warning_amber_rounded,
        onUndo: _undoOnce,
      );
    } catch (e, st) {
      flowBotDebugLog('Modal.apply error: $e');
      debugPrintStack(stackTrace: st);
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'flowbot',
          context:
              ErrorDescription('while applying FlowBot actions from the sheet'),
        ),
      );
      if (!mounted) return;
      _emitActionResult(
        _ActionResult(ok: false, message: 'FlowBot fallo al aplicar: $e'),
        failureIcon: Icons.warning_amber_rounded,
      );
    }
  }

  Future<void> _runFlowBotCommandDirect(String command) async {
    final text = command.trim();
    if (text.isEmpty) {
      _emitActionResult(
        const _ActionResult(ok: false, message: 'Comando vacio.'),
        failureIcon: Icons.warning_amber_rounded,
      );
      return;
    }
    try {
      final parsed = await _parseFlowBotCommand(text);
      if (parsed.actions.isEmpty) {
        _emitActionResult(
          _ActionResult(
            ok: false,
            message:
                parsed.warning ?? 'FlowBot no detecto acciones aplicables.',
          ),
          failureIcon: Icons.warning_amber_rounded,
        );
        return;
      }
      final scoped =
          _applyScopeToFlowBotActions(parsed.actions, _flowBotLastScope);
      flowBotDebugLog(
        'Direct.apply actions=${scoped.map((action) => action.toJson()).join(', ')}',
      );
      final applied = await _applyFlowBotActions(scoped);
      if (!mounted) return;
      if (applied > 0) {
        await _rememberFlowBotHistory(text);
        _lastFlowBotValidCommand = text;
      }
      _emitActionResult(
        _flowBotResultForAppliedChanges(applied),
        successIcon: Icons.auto_awesome_rounded,
        failureIcon: Icons.warning_amber_rounded,
        onUndo: _undoOnce,
      );
    } catch (e, st) {
      flowBotDebugLog('Direct.apply error: $e');
      debugPrintStack(stackTrace: st);
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'flowbot',
          context: ErrorDescription('while running a direct FlowBot command'),
        ),
      );
      if (!mounted) return;
      _emitActionResult(
        _ActionResult(ok: false, message: 'FlowBot fallo al aplicar: $e'),
        failureIcon: Icons.warning_amber_rounded,
      );
    }
  }

  Future<void> _saveCurrentFlowBotMacro() async {
    final command = _lastFlowBotValidCommand.trim();
    if (command.isEmpty) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'Primero analiza/aplica un comando FlowBot valido.',
        ),
        failureIcon: Icons.info_outline_rounded,
      );
      return;
    }
    final nameEC = TextEditingController(
      text: 'Macro ${_flowBotMacros.length + 1}',
    );
    final accepted = await showAppModal<bool>(
      context: context,
      title: 'Guardar macro',
      child: TextField(
        controller: nameEC,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nombre de macro'),
      ),
      actions: [
        AppButton(
          label: AppStrings.cancel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: 'Guardar',
          icon: Icons.bookmark_add_rounded,
          variant: AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
    final name = nameEC.text.trim();
    nameEC.dispose();
    if (accepted != true || name.isEmpty) return;

    await _upsertFlowBotMacro(
      name: name,
      command: command,
      emitFeedback: true,
    );
  }

  Future<void> _upsertFlowBotMacro({
    required String name,
    required String command,
    required bool emitFeedback,
  }) async {
    final safeName = name.trim();
    final safeCommand = command.trim();
    if (safeName.isEmpty || safeCommand.isEmpty) return;
    final nextMacro = FlowBotMacroPreset(name: safeName, command: safeCommand);
    if (mounted) {
      setState(() {
        _flowBotMacros.removeWhere(
          (m) => m.name.toLowerCase() == safeName.toLowerCase(),
        );
        _flowBotMacros.insert(0, nextMacro);
        if (_flowBotMacros.length > 24) {
          _flowBotMacros.removeRange(24, _flowBotMacros.length);
        }
      });
    } else {
      _flowBotMacros.removeWhere(
        (m) => m.name.toLowerCase() == safeName.toLowerCase(),
      );
      _flowBotMacros.insert(0, nextMacro);
      if (_flowBotMacros.length > 24) {
        _flowBotMacros.removeRange(24, _flowBotMacros.length);
      }
    }
    await _saveFlowBotUiPrefs();
    if (emitFeedback && mounted) {
      _emitActionResult(
        _ActionResult(ok: true, message: 'Macro "$safeName" guardada.'),
        successIcon: Icons.bookmark_added_rounded,
      );
    }
  }

  Future<void> _removeFlowBotMacro(String name) async {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return;
    var removed = false;
    int indexOfMacro(List<FlowBotMacroPreset> source) {
      return source.indexWhere((m) => m.name.toLowerCase() == key);
    }

    if (mounted) {
      setState(() {
        final idx = indexOfMacro(_flowBotMacros);
        if (idx >= 0) {
          _flowBotMacros.removeAt(idx);
          removed = true;
        }
      });
    } else {
      final idx = indexOfMacro(_flowBotMacros);
      if (idx >= 0) {
        _flowBotMacros.removeAt(idx);
        removed = true;
      }
    }
    if (!removed) return;
    await _saveFlowBotUiPrefs();
    if (!mounted) return;
    _emitActionResult(
      _ActionResult(ok: true, message: 'Macro "$name" eliminada.'),
      successIcon: Icons.delete_outline_rounded,
    );
  }

  String _cellLabelRc(int r, int c) => 'R${r + 1}C${c + 1}';

  CellRef? _cellRefAt(int r, int c) {
    if (r < 0 || c < 0) return null;
    if (r >= _rows.length) return null;
    if (c >= _colIds.length) return null;
    return CellRef(
      sheetId: widget.sheetId,
      rowId: _rows[r].id,
      colId: _colIds[c],
    );
  }

  int? _rowIndexForId(String rowId) {
    for (int i = 0; i < _rows.length; i++) {
      if (_rows[i].id == rowId) return i;
    }
    return null;
  }

  int? _colIndexForId(String colId) {
    for (int i = 0; i < _colIds.length; i++) {
      if (_colIds[i] == colId) return i;
    }
    return null;
  }

  String _cellLabelForRef(CellRef? ref) {
    if (ref == null) return '';
    final r = _rowIndexForId(ref.rowId);
    final c = _colIndexForId(ref.colId);
    if (r == null || c == null) return ref.compactKey;
    return _cellLabelRc(r, c);
  }

  void _syncSelectionController() {
    final ref = _cellRefAt(_selRow, _selCol);
    _selection.update(rowIndex: _selRow, colIndex: _selCol, cellRef: ref);
  }

  bool _setSelection(
    int r,
    int c, {
    bool blink = false,
    bool preserveRowSelection = false,
  }) {
    if (_rows.isEmpty || _headers.isEmpty) {
      final changed = _selRow != 0 || _selCol != 0;
      _selRow = 0;
      _selCol = 0;
      _selectedRows.clear();
      _rowSelectionAnchor = null;
      _selection.clear();
      return changed;
    }
    final rr = r.clamp(0, _rows.length - 1);
    final cc = c.clamp(0, _headers.length - 1);
    final changed = _selRow != rr || _selCol != cc;
    _selRow = rr;
    _selCol = cc;
    if (!preserveRowSelection) {
      _selectedRows
        ..clear()
        ..add(rr);
      _rowSelectionAnchor = rr;
    } else if (_selectedRows.isEmpty) {
      _selectedRows.add(rr);
      _rowSelectionAnchor ??= rr;
    }
    _syncSelectionController();
    if (blink) _blink(rr, cc);
    return changed;
  }

  void _setSelectionAndRefreshGrid(
    int r,
    int c, {
    bool blink = false,
    bool preserveRowSelection = false,
  }) {
    if (_setSelection(
      r,
      c,
      blink: blink,
      preserveRowSelection: preserveRowSelection,
    )) {
      _bumpGridVersion();
    }
  }

  List<int> _selectedRowsSorted() {
    if (_selectedRows.isEmpty) return const <int>[];
    final out = _selectedRows
        .where((r) => r >= 0 && r < _rows.length)
        .toList(growable: false)
      ..sort();
    return out;
  }

  List<int> _batchTargetRows() {
    final selected = _selectedRowsSorted();
    if (selected.isNotEmpty) return selected;
    if (_selRow >= 0 && _selRow < _rows.length) return <int>[_selRow];
    return const <int>[];
  }

  int _resolveBatchTargetColumn() {
    if (_headers.length < 2) return 0;
    final lastDataCol = _headers.length - 2;
    if (_selCol >= 0 && _selCol <= lastDataCol) return _selCol;
    return _resolveQuickCaptureDateColumn().clamp(0, lastDataCol);
  }

  String _selectionLabelForQuickActions() {
    if (_selRow < 0 || _selCol < 0) return 'Sin seleccion';
    final col = _headerLabel(_selCol);
    return '$col | fila ${_selRow + 1}';
  }

  String _flowBotColumnToken(int col) {
    var current = col + 1;
    final out = StringBuffer();
    while (current > 0) {
      current -= 1;
      out.writeCharCode(65 + (current % 26));
      current ~/= 26;
    }
    return out.toString().split('').reversed.join();
  }

  String _flowBotCellToken(int row, int col) {
    return '${_flowBotColumnToken(col)}${row + 1}';
  }

  bool _flowBotColumnHasBlankCells(int col) {
    if (col < 0 || col >= _headers.length - 1) return false;
    for (final row in _rows) {
      if (col >= row.cells.length) return true;
      if (row.cells[col].trim().isEmpty) return true;
    }
    return false;
  }

  _FlowBotQuickContext _flowBotQuickContext() {
    final dataCols = math.max(0, _headers.length - 1);
    final targetCol =
        dataCols <= 0 ? 0 : _resolveBatchTargetColumn().clamp(0, dataCols - 1);
    final targetRow = _rows.isEmpty ? 0 : _selRow.clamp(0, _rows.length - 1);
    final visibleColumnLabels = _visibleDataColumnIndexes()
        .map(_headerLabel)
        .where((label) => label.trim().isNotEmpty)
        .take(6)
        .toList(growable: false);

    return _FlowBotQuickContext(
      sheetName: _sheetName.trim().isEmpty ? 'Planilla actual' : _sheetName,
      row: targetRow,
      col: targetCol,
      rowNumber: targetRow + 1,
      cellToken: _flowBotCellToken(targetRow, targetCol),
      columnLabel: dataCols <= 0 ? 'Columna actual' : _headerLabel(targetCol),
      visibleColumnLabels: visibleColumnLabels,
      hasRows: _rows.isNotEmpty,
      hasPreviousRow: targetRow > 0 && _rows.isNotEmpty,
      hasBlankCellsInColumn:
          dataCols > 0 && _flowBotColumnHasBlankCells(targetCol),
      canExport: _rows.isNotEmpty && dataCols > 0,
    );
  }

  List<String> _flowBotContextExamples(_FlowBotQuickContext context) {
    final examples = <String>[
      'poner OK en ${context.cellToken}',
      'rellenar columna ${context.columnLabel} con Pendiente',
      'agregar columna Observaciones',
    ];
    if (context.hasBlankCellsInColumn) {
      examples.insert(
        2,
        'completar vacios en columna ${context.columnLabel} con Pendiente',
      );
    }
    if (context.hasPreviousRow) {
      examples.insert(
        2,
        'copiar valor de la fila anterior en ${context.cellToken}',
      );
    }
    return examples.take(4).toList(growable: false);
  }

  List<_FlowBotQuickActionSpec> _flowBotSuggestedQuickActions(
    _FlowBotQuickContext context,
  ) {
    final actions = <_FlowBotQuickActionSpec>[];
    final hasEditableColumns = _headers.length > 1;
    if (hasEditableColumns) {
      actions.addAll(<_FlowBotQuickActionSpec>[
        _FlowBotQuickActionSpec(
          id: 'set-active-cell',
          label: 'Poner valor en ${context.cellToken}',
          icon: Icons.edit_note_rounded,
          requiresValue: true,
          promptTitle: 'Valor para ${context.cellToken}',
          promptLabel: 'Valor',
          promptHint: 'Ej: OK',
          buildCommand: (value) =>
              'poner ${value ?? ''} en ${context.cellToken}',
        ),
        _FlowBotQuickActionSpec(
          id: 'clear-active-cell',
          label: 'Borrar ${context.cellToken}',
          icon: Icons.backspace_outlined,
          buildCommand: (_) => 'borrar ${context.cellToken}',
        ),
        _FlowBotQuickActionSpec(
          id: 'duplicate-row',
          label: 'Duplicar fila ${context.rowNumber}',
          icon: Icons.copy_all_rounded,
          buildCommand: (_) => 'duplicar fila ${context.rowNumber}',
        ),
        _FlowBotQuickActionSpec(
          id: 'delete-row',
          label: 'Eliminar fila ${context.rowNumber}',
          icon: Icons.delete_outline_rounded,
          buildCommand: (_) => 'eliminar fila ${context.rowNumber}',
        ),
        _FlowBotQuickActionSpec(
          id: 'fill-current-column',
          label: 'Rellenar ${context.columnLabel}',
          icon: Icons.vertical_align_center_rounded,
          requiresValue: true,
          promptTitle: 'Rellenar columna ${context.columnLabel}',
          promptLabel: 'Valor para toda la columna',
          promptHint: 'Ej: Pendiente',
          buildCommand: (value) =>
              'rellenar columna ${context.columnLabel} con ${value ?? ''}',
        ),
        _FlowBotQuickActionSpec(
          id: 'add-column',
          label: 'Agregar columna',
          icon: Icons.add_box_outlined,
          requiresValue: true,
          promptTitle: 'Nueva columna',
          promptLabel: 'Nombre de columna',
          promptHint: 'Ej: Observaciones',
          buildCommand: (value) => 'agregar columna ${value ?? ''}',
        ),
        _FlowBotQuickActionSpec(
          id: 'rename-column',
          label: 'Renombrar ${context.columnLabel}',
          icon: Icons.drive_file_rename_outline_rounded,
          requiresValue: true,
          promptTitle: 'Renombrar columna ${context.columnLabel}',
          promptLabel: 'Nuevo nombre',
          promptHint: 'Ej: Progresiva',
          buildCommand: (value) =>
              'renombrar columna ${context.columnLabel} a ${value ?? ''}',
        ),
      ]);
      if (context.hasBlankCellsInColumn) {
        actions.add(
          _FlowBotQuickActionSpec(
            id: 'fill-blanks',
            label: 'Completar vacios',
            icon: Icons.playlist_add_check_circle_outlined,
            requiresValue: true,
            promptTitle: 'Completar vacios en ${context.columnLabel}',
            promptLabel: 'Valor para vacios',
            promptHint: 'Ej: Pendiente',
            buildCommand: (value) =>
                'completar vacios en columna ${context.columnLabel} con ${value ?? ''}',
          ),
        );
      }
      if (context.hasPreviousRow) {
        actions.add(
          _FlowBotQuickActionSpec(
            id: 'copy-previous-row',
            label: 'Copiar fila anterior',
            icon: Icons.arrow_upward_rounded,
            buildCommand: (_) =>
                'copiar valor de la fila anterior en ${context.cellToken}',
          ),
        );
      }
    }
    if (context.canExport) {
      actions.addAll(<_FlowBotQuickActionSpec>[
        _FlowBotQuickActionSpec(
          id: 'export-xlsx',
          label: 'Exportar XLSX',
          icon: Icons.grid_on_outlined,
          buildCommand: (_) => 'exportar xlsx',
        ),
        _FlowBotQuickActionSpec(
          id: 'export-pdf',
          label: 'Exportar PDF',
          icon: Icons.picture_as_pdf_outlined,
          buildCommand: (_) => 'exportar pdf',
        ),
      ]);
    }
    return actions;
  }

  List<FlowBotFavoriteShortcut> _flowBotTemplateSuggestedFavorites() {
    final templateKind = _sheetTemplateKind.trim().toLowerCase();
    if (templateKind.isEmpty) return const <FlowBotFavoriteShortcut>[];
    final catalog = <String, List<_FlowBotTemplateFavoriteSpec>>{
      'campo': const <_FlowBotTemplateFavoriteSpec>[
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'duplicate-row',
          label: 'Duplicar fila actual',
        ),
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'fill-blanks',
          label: 'Completar vacios',
        ),
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'copy-previous-row',
          label: 'Copiar fila anterior',
        ),
      ],
      'inventario': const <_FlowBotTemplateFavoriteSpec>[
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'set-active-cell',
          label: 'Poner valor en celda actual',
        ),
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'fill-current-column',
          label: 'Rellenar columna actual',
        ),
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'add-column',
          label: 'Agregar columna',
        ),
      ],
      'rendicion': const <_FlowBotTemplateFavoriteSpec>[
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'fill-blanks',
          label: 'Completar vacios',
        ),
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'copy-previous-row',
          label: 'Copiar fila anterior',
        ),
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'export-pdf',
          label: 'Exportar PDF',
        ),
      ],
      'gastos': const <_FlowBotTemplateFavoriteSpec>[
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'fill-current-column',
          label: 'Rellenar columna actual',
        ),
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'fill-blanks',
          label: 'Completar vacios',
        ),
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'export-xlsx',
          label: 'Exportar XLSX',
        ),
      ],
      'proyectos': const <_FlowBotTemplateFavoriteSpec>[
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'rename-column',
          label: 'Renombrar columna',
        ),
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'fill-current-column',
          label: 'Rellenar columna actual',
        ),
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'export-xlsx',
          label: 'Exportar XLSX',
        ),
      ],
      'mediciones': const <_FlowBotTemplateFavoriteSpec>[
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'copy-previous-row',
          label: 'Copiar fila anterior',
        ),
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'fill-blanks',
          label: 'Completar vacios',
        ),
        _FlowBotTemplateFavoriteSpec(
          quickActionId: 'export-pdf',
          label: 'Exportar PDF',
        ),
      ],
    };
    final specs =
        catalog[templateKind] ?? const <_FlowBotTemplateFavoriteSpec>[];
    return specs
        .map(
          (spec) => FlowBotFavoriteShortcut(
            kind: 'quick_action',
            label: spec.label,
            quickActionId: spec.quickActionId,
          ),
        )
        .toList(growable: false);
  }

  _FlowBotQuickActionSpec? _resolveFlowBotQuickActionFromFavorite(
    FlowBotFavoriteShortcut favorite,
    List<_FlowBotQuickActionSpec> suggestedActions,
  ) {
    if (!favorite.isQuickAction) return null;
    for (final action in suggestedActions) {
      if (action.id == favorite.quickActionId) return action;
    }
    return null;
  }

  List<_FlowBotInlineQuickActionView> _flowBotInlineQuickActions(
    _FlowBotQuickContext context,
  ) {
    final suggestedActions = _flowBotSuggestedQuickActions(context);
    if (suggestedActions.isEmpty) {
      return const <_FlowBotInlineQuickActionView>[];
    }

    final views = <_FlowBotInlineQuickActionView>[];
    final seen = <String>{};

    void addAction(
      _FlowBotQuickActionSpec action, {
      required String source,
    }) {
      if (!seen.add(action.id)) return;
      views.add(
        _FlowBotInlineQuickActionView(
          id: action.id,
          label: action.label,
          icon: action.icon,
          action: action,
          source: source,
        ),
      );
    }

    for (final favorite in _flowBotFavorites) {
      final resolved =
          _resolveFlowBotQuickActionFromFavorite(favorite, suggestedActions);
      if (resolved == null) continue;
      addAction(resolved, source: 'user');
      if (views.length >= 4) return views;
    }

    for (final favorite in _flowBotTemplateSuggestedFavorites()) {
      final resolved =
          _resolveFlowBotQuickActionFromFavorite(favorite, suggestedActions);
      if (resolved == null) continue;
      addAction(resolved, source: 'template');
      if (views.length >= 4) return views;
    }

    for (final action in suggestedActions) {
      addAction(action, source: 'context');
      if (views.length >= 4) break;
    }

    return views;
  }

  Future<String?> _promptFlowBotQuickActionValueInline(
    BuildContext context, {
    required _FlowBotQuickActionSpec action,
  }) async {
    var draftValue = '';
    final result = await showAppModal<String>(
      context: context,
      title: action.promptTitle ?? 'Completa la accion',
      child: TextFormField(
        key: ValueKey('flowbot-inline-input-${action.id}'),
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: action.promptLabel ?? 'Valor',
          hintText: action.promptHint,
        ),
        onChanged: (value) => draftValue = value,
        onFieldSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        AppButton(
          label: AppStrings.cancel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: 'Aplicar',
          variant: AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(draftValue.trim()),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
    final text = (result ?? '').trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _runInlineFlowBotQuickAction(
    BuildContext context,
    _FlowBotQuickActionSpec action,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    String? promptValue;
    if (action.requiresValue) {
      promptValue = await _promptFlowBotQuickActionValueInline(
        context,
        action: action,
      );
      if (promptValue == null || !mounted) return;
    }
    final command = action.buildCommand(promptValue).trim();
    if (command.isEmpty) return;
    await _runFlowBotCommandDirect(command);
  }

  int? _statusColumnForBatchActions() {
    final dataCols = _headers.length - 1;
    for (int c = 0; c < dataCols; c++) {
      if (_colType(c) == _ColType.status) return c;
    }
    return null;
  }

  Future<void> _applyStatusToSelectedRows(String status) async {
    final rows = _batchTargetRows();
    if (rows.isEmpty || _headers.length < 2) return;
    final statusCol = _statusColumnForBatchActions();
    if (statusCol == null) {
      _showActionSnack(
        'No se encontro columna Estado.',
        isError: true,
        icon: Icons.flag_outlined,
      );
      return;
    }

    final normalized = _normalizeCellValueForColumn(statusCol, status);
    _rememberValueForColumn(statusCol, normalized);
    final refsToClear = <_CellRef>[];
    var changed = 0;
    for (final r in rows) {
      if (r < 0 || r >= _rows.length) continue;
      if (_rows[r].cells[statusCol] == normalized) continue;
      _rows[r].cells[statusCol] = normalized;
      refsToClear.add(_CellRef(r, statusCol));
      changed++;
    }

    if (changed == 0) {
      _showActionSnack(
        'Sin cambios para aplicar.',
        isError: false,
        icon: Icons.flag_outlined,
      );
      return;
    }

    _clearCellDrafts(refsToClear);
    _setSelection(
      rows.first,
      statusCol,
      preserveRowSelection: true,
      blink: true,
    );
    _markDirty(snapshot: true);
    AppHaptics.light();
    _showActionSnack(
      'Estado "$normalized" aplicado a $changed fila(s).',
      isError: false,
      icon: Icons.flag_outlined,
    );
    _addHistoryEvent(
      type: 'batch_status',
      message: 'Aplicar Estado "$normalized" a $changed fila(s)',
      origin: 'quick_action',
      row: rows.first,
      col: statusCol,
      afterValue: normalized,
    );
  }

  String _reviewActorName() {
    if (kIsWeb) return 'Usuario web';
    return 'Usuario app';
  }

  Future<void> _setReviewedForRows(
    Iterable<int> rows, {
    required bool reviewed,
  }) async {
    final targets = rows
        .where((r) => r >= 0 && r < _rows.length)
        .toSet()
        .toList(growable: false)
      ..sort();
    if (targets.isEmpty) {
      _showActionSnack(
        'Selecciona al menos una fila.',
        isError: false,
        icon: Icons.info_outline_rounded,
      );
      return;
    }
    final now = DateTime.now();
    final actor = _reviewActorName();
    var changed = 0;
    final changedRowIds = <String>[];
    for (final r in targets) {
      final row = _rows[r];
      final nextBy = reviewed ? actor : null;
      final nextAt = reviewed ? now : null;
      if (row.reviewed == reviewed &&
          (row.reviewedBy ?? '') == (nextBy ?? '') &&
          (row.reviewedAt?.millisecondsSinceEpoch ?? -1) ==
              (nextAt?.millisecondsSinceEpoch ?? -1)) {
        continue;
      }
      _rows[r] = row.copyWithReview(
        reviewed: reviewed,
        reviewedBy: nextBy,
        reviewedAt: nextAt,
      );
      changedRowIds.add(row.id);
      changed++;
    }
    if (changed <= 0) {
      _showActionSnack(
        'Sin cambios para aplicar.',
        isError: false,
        icon: reviewed ? Icons.verified_rounded : Icons.pending_actions_rounded,
      );
      return;
    }
    _markDirty(snapshot: true);
    _invalidateRowViewCache();
    for (final rowId in changedRowIds) {
      _bumpRowVersionById(rowId);
    }
    if (_reviewFilterMode != _ReviewFilterMode.all) {
      _bumpGridVersion();
    }
    _showActionSnack(
      reviewed
          ? '$changed fila(s) marcadas como revisadas.'
          : '$changed fila(s) marcadas como pendientes.',
      isError: false,
      icon: reviewed ? Icons.verified_rounded : Icons.pending_actions_rounded,
    );
    _addHistoryEvent(
      type: reviewed ? 'review_signoff' : 'review_pending',
      message: reviewed
          ? 'Marcar revisado ($changed fila/s)'
          : 'Marcar pendiente ($changed fila/s)',
      origin: 'quick_action',
      row: targets.first,
    );
  }

  Future<void> _markSelectedRowsReviewed() =>
      _setReviewedForRows(_batchTargetRows(), reviewed: true);

  Future<void> _markSelectedRowsPendingReview() =>
      _setReviewedForRows(_batchTargetRows(), reviewed: false);

  void _setReviewFilterMode(_ReviewFilterMode mode) {
    if (_reviewFilterMode == mode) return;
    setState(() {
      _reviewFilterMode = mode;
      _invalidateRowViewCache();
    });
    _bumpGridVersion();
    switch (mode) {
      case _ReviewFilterMode.pending:
        _showActionSnack(
          'Vista pendiente de revision activa.',
          isError: false,
          icon: Icons.pending_actions_rounded,
        );
        break;
      case _ReviewFilterMode.reviewed:
        _showActionSnack(
          'Vista solo revisadas activa.',
          isError: false,
          icon: Icons.verified_rounded,
        );
        break;
      case _ReviewFilterMode.all:
        _showActionSnack(
          'Vista de revision limpia.',
          isError: false,
          icon: Icons.table_view_rounded,
        );
        break;
    }
  }

  void _togglePendingReviewView() {
    if (_reviewFilterMode == _ReviewFilterMode.pending) {
      _setReviewFilterMode(_ReviewFilterMode.all);
      return;
    }
    _setReviewFilterMode(_ReviewFilterMode.pending);
  }

  void _jumpToFirstValidationIssue() {
    final issues = _validationIssues();
    if (issues.isEmpty) {
      _showActionSnack(
        'No hay errores de validacion.',
        isError: false,
        icon: Icons.task_alt_rounded,
      );
      return;
    }
    _jumpToValidationIssue(issues.first);
  }

  Future<void> _activateUrgentViewShortcut() async {
    _SavedView? urgentView;
    for (final view in _savedViews) {
      if (view.name.toLowerCase().contains('urgente')) {
        urgentView = view;
        break;
      }
    }
    if (urgentView != null) {
      await _applySavedView(urgentView.id);
      return;
    }
    final statusCol = _statusColumnForBatchActions();
    if (statusCol == null) {
      _showActionSnack(
        'No se encontro columna Estado para vista urgente.',
        isError: true,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }
    final autoView = _SavedView(
      id: _genStableId('view_'),
      name: 'Vista Urgentes',
      createdAt: DateTime.now(),
      statusColId: _colIds[statusCol],
      statusValue: 'Urgente',
      columnPrefsById: _cloneColumnPrefs(_columnPrefsById),
      columnOrder: List<String>.from(_columnOrder),
      frozenColId: _frozenColId,
    );
    setState(() {
      _savedViews.insert(0, autoView);
      _applySavedViewColumns(
        autoView.id,
        announce: false,
        persistActive: false,
      );
    });
    await _persistSavedViewsPref();
    _showActionSnack(
      'Vista Urgentes activada.',
      isError: false,
      icon: Icons.priority_high_rounded,
    );
  }

  void _duplicateLastRowQuick() {
    if (_rows.isEmpty) {
      _insertRow(0);
      return;
    }
    _duplicateRow(_rows.length - 1);
  }

  void _applyAutoIdQuick() {
    if (_headers.length < 2 || _rows.isEmpty) {
      _showActionSnack(
        'No hay filas para autocompletar ID.',
        isError: false,
        icon: Icons.info_outline_rounded,
      );
      return;
    }
    int? targetCol;
    if (_selCol >= 0 &&
        _selCol < _headers.length - 1 &&
        _isAutoIncrementColumn(_selCol)) {
      targetCol = _selCol;
    } else {
      for (int c = 0; c < _headers.length - 1; c++) {
        if (_isAutoIncrementColumn(c)) {
          targetCol = c;
          break;
        }
      }
    }
    if (targetCol == null) {
      _showActionSnack(
        'No hay columna ID/Progresiva configurada.',
        isError: true,
        icon: Icons.tag_outlined,
      );
      return;
    }
    final rows = _batchTargetRows();
    if (rows.isEmpty) return;
    var changed = 0;
    for (final r in rows) {
      if (r < 0 || r >= _rows.length) continue;
      final current = _rows[r].cells[targetCol].trim();
      if (current.isNotEmpty) continue;
      _rows[r].cells[targetCol] = _nextAutoIncrementValueForColumn(targetCol);
      changed++;
    }
    if (changed <= 0) {
      _showActionSnack(
        'Las filas seleccionadas ya tienen ID.',
        isError: false,
        icon: Icons.tag_rounded,
      );
      return;
    }
    _markDirty(snapshot: true);
    _bumpGridVersion();
    _showActionSnack(
      'Auto-ID aplicado a $changed fila(s).',
      isError: false,
      icon: Icons.tag_rounded,
    );
  }

  void _useLastValueForSelectedCell() {
    if (!_hasActiveEditableCell(
      reason: 'Selecciona una celda editable para usar el ultimo valor.',
    )) {
      return;
    }
    final suggestions = _recentValuesForColumn(_selCol);
    if (suggestions.isEmpty) {
      _showActionSnack(
        'Sin historial para esta columna.',
        isError: false,
        icon: Icons.history_toggle_off_rounded,
      );
      return;
    }
    final current = _rows[_selRow].cells[_selCol].trim().toLowerCase();
    String? next;
    for (final candidate in suggestions) {
      if (candidate.trim().toLowerCase() == current) continue;
      next = candidate;
      break;
    }
    next ??= suggestions.first;
    _setCell(_selRow, _selCol, next);
    _bumpGridVersion();
    _showActionSnack(
      'Ultimo valor aplicado en ${_headerLabel(_selCol)}.',
      isError: false,
      icon: Icons.history_rounded,
    );
  }

  int? _resolveJumpIdColumn() {
    final dataCols = _headers.length - 1;
    if (dataCols <= 0) return null;
    for (int c = 0; c < dataCols; c++) {
      final h = _headerLabel(c).toLowerCase();
      if (h.contains('id') ||
          h.contains('progres') ||
          h.contains('codigo') ||
          h.contains('code') ||
          h.contains('ref')) {
        return c;
      }
    }
    return 0;
  }

  Future<void> _openJumpToDialog() async {
    if (!mounted) return;
    final rowCtrl = TextEditingController(
      text: _selRow >= 0 ? (_selRow + 1).toString() : '',
    );
    final idCtrl = TextEditingController();
    final idCol = _resolveJumpIdColumn();
    String? error;

    final targetRow = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              title: const Text('Ir a...'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: rowCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Fila (1-based)',
                      hintText: 'Ej: 42',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: idCtrl,
                    decoration: InputDecoration(
                      labelText: idCol == null
                          ? 'ID (no disponible)'
                          : 'ID / Progresiva',
                      hintText: idCol == null
                          ? 'No hay columna de ID'
                          : 'Buscar en ${_headerLabel(idCol)}',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: TextStyle(
                        color: _palette(ctx).selectionBorder,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final rowRaw = rowCtrl.text.trim();
                    final idRaw = idCtrl.text.trim();
                    if (rowRaw.isEmpty && idRaw.isEmpty) {
                      setModalState(() => error = 'Ingresa fila o ID.');
                      return;
                    }

                    if (rowRaw.isNotEmpty) {
                      final parsed = int.tryParse(rowRaw);
                      if (parsed == null ||
                          parsed <= 0 ||
                          parsed > _rows.length) {
                        setModalState(() => error = 'Fila fuera de rango.');
                        return;
                      }
                      Navigator.of(ctx).pop(parsed - 1);
                      return;
                    }

                    if (idCol == null) {
                      setModalState(
                        () => error = 'No hay columna para buscar ID.',
                      );
                      return;
                    }

                    final needle = idRaw.toLowerCase();
                    for (int r = 0; r < _rows.length; r++) {
                      final value = _effectiveCell(r, idCol).toLowerCase();
                      if (value.contains(needle)) {
                        Navigator.of(ctx).pop(r);
                        return;
                      }
                    }
                    setModalState(() => error = 'No se encontro "$idRaw".');
                  },
                  child: const Text('Ir'),
                ),
              ],
            );
          },
        );
      },
    );

    rowCtrl.dispose();
    idCtrl.dispose();
    if (!mounted || targetRow == null) return;

    final dataCols = _headers.length - 1;
    final targetCol = dataCols > 0 ? (_selCol.clamp(0, dataCols - 1)) : 0;
    _setSelectionAndRefreshGrid(
      targetRow.clamp(0, math.max(0, _rows.length - 1)),
      targetCol,
      blink: true,
    );
    AppHaptics.selection();
    _showActionSnack(
      'Foco en fila ${targetRow + 1}.',
      isError: false,
      icon: Icons.pin_drop_outlined,
    );
  }

  void _handleRowIndexTap(int row) {
    if (row < 0 || row >= _rows.length) return;
    final keyboard = HardwareKeyboard.instance;
    final isShift = keyboard.isShiftPressed;
    final isMod = keyboard.isControlPressed || keyboard.isMetaPressed;

    setState(() {
      if (isShift) {
        final anchor = _rowSelectionAnchor ?? _selRow;
        final start = math.min(anchor, row);
        final end = math.max(anchor, row);
        final next = isMod ? Set<int>.from(_selectedRows) : <int>{};
        for (int i = start; i <= end; i++) {
          next.add(i);
        }
        _selectedRows
          ..clear()
          ..addAll(next);
        _rowSelectionAnchor = anchor;
        _setSelection(row, _selCol, preserveRowSelection: true);
      } else if (isMod) {
        if (_selectedRows.contains(row) && _selectedRows.length > 1) {
          _selectedRows.remove(row);
        } else {
          _selectedRows.add(row);
        }
        _rowSelectionAnchor = row;
        _setSelection(row, _selCol, preserveRowSelection: true);
      } else {
        _selectedRows
          ..clear()
          ..add(row);
        _rowSelectionAnchor = row;
        _setSelection(row, _selCol, preserveRowSelection: true);
      }
      _blink(row, _selCol);
    });
  }

  Future<void> _openBatchActionsSheet() async {
    if (!mounted) return;
    final selected = _batchTargetRows();
    if (selected.isEmpty) {
      _showActionSnack(
        'No hay filas seleccionadas.',
        isError: true,
        icon: Icons.layers_clear_outlined,
      );
      return;
    }

    final count = selected.length;
    final targetCol = _resolveBatchTargetColumn();
    final columnLabel = _headerLabel(targetCol);
    final statusCol = _statusColumnForBatchActions();

    await showAppModal<void>(
      context: context,
      title: 'Acciones por lote',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count fila(s) seleccionadas - columna activa: $columnLabel',
            style: TextStyle(
              color: _palette(context).fgMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Aplicar mismo valor',
            icon: Icons.format_color_text_rounded,
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_promptBatchApplyValue());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label:
                'Auto GPS: ${_autoGpsBatchEnabled ? 'Activado' : 'Desactivado'}',
            icon: _autoGpsBatchEnabled
                ? Icons.toggle_on_rounded
                : Icons.toggle_off_outlined,
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_setAutoGpsBatchEnabled(!_autoGpsBatchEnabled));
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Aplicar GPS a seleccion',
            icon: Icons.my_location_rounded,
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_applyGpsToSelectedRows());
            },
          ),
          if (statusCol != null) ...[
            const SizedBox(height: 8),
            Text(
              'Marcar Estado',
              style: TextStyle(
                color: _palette(context).fgMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in const <String>['OK', 'Obs', 'Urgente'])
                  AppButton(
                    label: status,
                    icon: Icons.flag_outlined,
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.ghost,
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(_applyStatusToSelectedRows(status));
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          AppButton(
            label: 'Duplicar fila(s)',
            icon: Icons.copy_all_outlined,
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            onPressed: () {
              Navigator.of(context).pop();
              _duplicateSelectedRows();
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Marcar revisado',
            icon: Icons.verified_rounded,
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_markSelectedRowsReviewed());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Marcar pendiente',
            icon: Icons.pending_actions_rounded,
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_markSelectedRowsPendingReview());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: _reviewFilterMode == _ReviewFilterMode.pending
                ? 'Quitar vista pendientes'
                : 'Vista pendientes de revision',
            icon: _reviewFilterMode == _ReviewFilterMode.pending
                ? Icons.filter_alt_off_rounded
                : Icons.pending_actions_rounded,
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            onPressed: () {
              Navigator.of(context).pop();
              _togglePendingReviewView();
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Auto-ID en seleccion',
            icon: Icons.tag_rounded,
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            onPressed: () {
              Navigator.of(context).pop();
              _applyAutoIdQuick();
            },
          ),
        ],
      ),
      actions: [
        AppButton(
          label: AppStrings.close,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
  }

  Future<void> _promptBatchApplyValue() async {
    final rows = _batchTargetRows();
    if (rows.isEmpty || _headers.length < 2) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'Selecciona al menos una fila para aplicar el valor.',
        ),
        failureIcon: Icons.info_outline_rounded,
      );
      return;
    }
    final targetCol = _resolveBatchTargetColumn();
    final initial = _effectiveCell(rows.first, targetCol);
    final controller = TextEditingController(text: initial);
    final suggestions = _recentValuesForColumn(targetCol, excluding: initial);

    final value = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Aplicar valor (${rows.length} filas)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Columna: ${_headerLabel(targetCol)}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Valor para aplicar',
                ),
                onSubmitted: (v) => Navigator.of(ctx).pop(v),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Recientes', style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final item in suggestions.take(10))
                      ActionChip(
                        label: Text(item, overflow: TextOverflow.ellipsis),
                        onPressed: () {
                          controller.value = controller.value.copyWith(
                            text: item,
                            selection: TextSelection.collapsed(
                              offset: item.length,
                            ),
                            composing: TextRange.empty,
                          );
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Aplicar'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!mounted || value == null) return;

    final normalized = _normalizeCellValueForColumn(targetCol, value);
    _rememberValueForColumn(targetCol, normalized);
    final refsToClear = <_CellRef>[];
    var changed = 0;
    for (final r in rows) {
      if (r < 0 || r >= _rows.length) continue;
      if (_rows[r].cells[targetCol] == normalized) continue;
      _rows[r].cells[targetCol] = normalized;
      refsToClear.add(_CellRef(r, targetCol));
      changed++;
    }

    if (changed == 0) {
      _showActionSnack(
        'Sin cambios para aplicar.',
        isError: false,
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    _clearCellDrafts(refsToClear);
    _setSelection(
      rows.first,
      targetCol,
      preserveRowSelection: true,
      blink: true,
    );
    _markDirty(snapshot: true);
    _showActionSnack(
      'Valor aplicado a $changed fila(s).',
      isError: false,
      icon: Icons.done_all_rounded,
    );
  }

  Future<void> _applyGpsToSelectedRows() async {
    if (!_autoGpsBatchEnabled) {
      _showActionSnack(
        'Activa Auto GPS para aplicar coordenadas por lote.',
        isError: true,
        icon: Icons.gps_off_rounded,
      );
      return;
    }
    if (_guardInAppBrowser(DiagnosticActionType.gps)) return;
    if (_guardInsecureContext(DiagnosticActionType.gps)) return;
    if (kIsWeb && !WebCapabilities.geolocationAvailable) {
      _showActionSnack(
        'GPS no disponible en este navegador.',
        isError: true,
        icon: Icons.gps_off_rounded,
      );
      return;
    }

    final rows = _batchTargetRows();
    if (rows.isEmpty || _headers.length < 2) return;
    final targetCol = _resolveBatchTargetColumn();
    final targetLabel = _gpsBatchTargetLabel(rows.length, targetCol);
    final preflightOk = await _runGpsPreflight(targetLabel);
    if (!preflightOk) return;
    if (!_beginGpsRequest(targetLabel)) return;

    try {
      final outcome = await _getGpsFixWithFallback(
        timeout: const Duration(seconds: 12),
      );
      if (!mounted) return;
      if (!outcome.ok || outcome.fix == null) {
        _showGpsError(outcome, targetLabel: targetLabel);
        return;
      }
      final fix = outcome.fix!;
      final gpsMeta = _gpsMetaFromFix(fix);
      final shouldWriteText = _gpsWriteMode != _GpsWriteMode.metadataOnly;
      final text = _gpsTextForFix(fix);
      final refsToClear = <_CellRef>[];
      var applied = 0;

      for (final r in rows) {
        if (r < 0 || r >= _rows.length) continue;
        final ref = _cellRefAt(r, targetCol);
        if (ref == null) continue;
        final current = _cellMeta[ref.key];
        _cellMeta[ref.key] = CellMeta(
          gps: gpsMeta,
          photos: current?.photos ?? const <PhotoAttachment>[],
          audios: current?.audios ?? const <AudioAttachment>[],
        );
        if (shouldWriteText) {
          _rows[r].cells[targetCol] = text;
          refsToClear.add(_CellRef(r, targetCol));
        }
        applied++;
      }

      if (applied == 0) return;
      if (refsToClear.isNotEmpty) {
        _clearCellDrafts(refsToClear);
      }
      _setSelection(
        rows.first,
        targetCol,
        preserveRowSelection: true,
        blink: true,
      );
      _markDirty(snapshot: true);
      final msg = _gpsSavedMessage(
        fix: fix,
        targetLabel: _gpsBatchTargetLabel(applied, targetCol),
        wroteText: shouldWriteText,
      );
      _engineStatus = msg;
      _engineStatusIsError = false;
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.gps,
        ok: true,
        message:
            'gps_batch rows=$applied col=${_a1ColumnLabel(targetCol)} lat=${fix.lat} lng=${fix.lng} acc=${fix.accuracyM} source=${fix.source} provider=${fix.provider} wroteText=$shouldWriteText',
      );
      _showActionSnack(
        msg,
        isError: false,
        icon: Icons.my_location_rounded,
      );
    } finally {
      _endGpsRequest(targetLabel);
    }
  }

  void _duplicateSelectedRows() {
    final targets = _batchTargetRows();
    if (targets.isEmpty) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'Selecciona al menos una fila para duplicar.',
        ),
        failureIcon: Icons.info_outline_rounded,
      );
      return;
    }
    final ordered = targets.toList(growable: false)..sort();
    final insertAtList = <int>[];
    var offset = 0;

    setState(() {
      for (final original in ordered) {
        final srcIndex = original + offset;
        if (srcIndex < 0 || srcIndex >= _rows.length) continue;
        final src = _rows[srcIndex];
        final newId = _genStableId('r_');
        final copy = _RowModel(
          id: newId,
          cells: List<String>.from(src.cells),
          photos: src.photos.map((p) => p.copy()).toList(growable: false),
          gpsLat: src.gpsLat,
          gpsLng: src.gpsLng,
          gpsAccuracyM: src.gpsAccuracyM,
          gpsTs: src.gpsTs,
          gpsIsLastKnown: src.gpsIsLastKnown,
        );
        final insertAt = (srcIndex + 1).clamp(0, _rows.length);
        _duplicateCellMetaRow(src.id, newId);
        _rows.insert(insertAt, copy);
        insertAtList.add(insertAt);
        offset++;
      }
      if (insertAtList.isNotEmpty) {
        _selectedRows
          ..clear()
          ..addAll(insertAtList);
        _rowSelectionAnchor = insertAtList.first;
        _setSelection(insertAtList.first, _selCol, preserveRowSelection: true);
      }
    });

    if (insertAtList.isEmpty) return;
    for (final idx in insertAtList) {
      _insertMobileRowCache(idx);
    }
    _markDirty(snapshot: true);
    _showActionSnack(
      'Filas duplicadas: ${insertAtList.length}.',
      isError: false,
      icon: Icons.copy_all_outlined,
    );
  }

  _CellRef? _cellIndexForRef(CellRef ref) {
    final r = _rowIndexForId(ref.rowId);
    final c = _colIndexForId(ref.colId);
    if (r == null || c == null) return null;
    return _CellRef(r, c);
  }

  void _setCellMetaEntryRef(
    CellRef ref,
    CellMeta meta, {
    required bool markDirty,
  }) {
    if (meta.isEmpty) {
      _cellMeta.remove(ref.key);
    } else {
      _cellMeta[ref.key] = meta;
    }
    if (markDirty) {
      _markDirty(snapshot: true);
    } else {
      _bumpGridVersion();
    }
  }

  void _refreshCellAfterSaveRef(CellRef ref) {
    final idx = _cellIndexForRef(ref);
    if (idx == null) {
      _bumpGridVersion();
      return;
    }
    _refreshCellAfterSave(idx.r, idx.c);
  }

  void _showActionSnack(
    String message, {
    required bool isError,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!mounted || message.trim().isEmpty) return;
    if (_shouldCoalesceToast(message)) return;
    void showNow() {
      if (!mounted) return;
      if (ScaffoldMessenger.maybeOf(context) == null) return;
      AppleToast.show(
        context,
        message: message,
        isError: isError,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
      );
    }

    if (ScaffoldMessenger.maybeOf(context) != null) {
      showNow();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showNow();
    });
  }

  void _emitActionResult(
    _ActionResult result, {
    IconData successIcon = Icons.check_circle_rounded,
    IconData failureIcon = Icons.info_outline_rounded,
    VoidCallback? onUndo,
  }) {
    if (result.ok) {
      AppHaptics.light();
    } else {
      AppHaptics.error();
    }
    final undoLabel =
        result.undoToken?.trim().isNotEmpty == true ? 'Deshacer' : null;
    _showActionSnack(
      result.message,
      isError: !result.ok,
      icon: result.ok ? successIcon : failureIcon,
      actionLabel: undoLabel,
      onAction: undoLabel != null ? onUndo : null,
    );
  }

  bool _hasActiveEditableCell({String? reason}) {
    if (_rows.isEmpty || _headers.length <= 1) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'No hay celdas editables disponibles.',
        ),
        failureIcon: Icons.info_outline_rounded,
      );
      return false;
    }
    if (_selRow < 0 || _selRow >= _rows.length) {
      _emitActionResult(
        _ActionResult(
          ok: false,
          message: reason ?? 'Selecciona una fila valida para continuar.',
        ),
        failureIcon: Icons.info_outline_rounded,
      );
      return false;
    }
    if (_selCol < 0 || _selCol >= _headers.length - 1) {
      _emitActionResult(
        _ActionResult(
          ok: false,
          message: reason ?? 'Selecciona una celda editable para continuar.',
        ),
        failureIcon: Icons.info_outline_rounded,
      );
      return false;
    }
    return true;
  }

  bool _isNetworkOnline() => _lastOnlineState;

  int get _pendingQuickCaptureCount {
    var count = 0;
    for (final item in _quickCaptureQueue) {
      if (item.sheetId == widget.sheetId) count++;
    }
    return count;
  }

  int get _pendingEditCount {
    var count = 0;
    for (final item in _editQueue) {
      if (item.sheetId == widget.sheetId) count++;
    }
    return count;
  }

  int get _pendingOfflineCount => _pendingQuickCaptureCount + _pendingEditCount;

  OfflineSyncState _resolveOfflineSyncState() {
    if (!_lastOnlineState) return OfflineSyncState.offline;
    if (_offlineSyncing) return OfflineSyncState.syncing;
    if (_offlineLastError != null && _pendingOfflineCount > 0) {
      return OfflineSyncState.failed;
    }
    if (_pendingOfflineCount > 0) return OfflineSyncState.pending;
    return OfflineSyncState.synced;
  }

  String? _resolveOfflineStatusMessage(OfflineSyncState state) {
    switch (state) {
      case OfflineSyncState.offline:
        return 'Sin conexion';
      case OfflineSyncState.pending:
        return _pendingOfflineCount > 0
            ? 'Pendientes: $_pendingOfflineCount'
            : null;
      case OfflineSyncState.syncing:
        return 'Sincronizando...';
      case OfflineSyncState.synced:
        return 'Sincronizado';
      case OfflineSyncState.failed:
        final retry = _offlineRetryAt?.toLocal();
        if (retry == null) {
          return _offlineLastError ?? 'Fallo de sincronizacion';
        }
        return 'Reintento ${_two(retry.hour)}:${_two(retry.minute)}';
    }
  }

  void _updateOfflineStatus() {
    _offlineStatus.value = OfflineSyncSnapshot(
      state: _resolveOfflineSyncState(),
      pendingCount: _pendingOfflineCount,
      updatedAt: DateTime.now(),
      message: _resolveOfflineStatusMessage(_resolveOfflineSyncState()),
    );
  }

  Future<void> _refreshOutboxBadgeCounts() async {
    try {
      final counts = await _outboxStore.countsByStatus();
      final queued = counts[OutboxOp.statusQueued] ?? 0;
      final error = counts[OutboxOp.statusError] ?? 0;

      if (!mounted) {
        _outboxQueuedCount = queued;
        _outboxErrorCount = error;
        return;
      }

      if (_outboxQueuedCount == queued && _outboxErrorCount == error) {
        return;
      }

      setState(() {
        _outboxQueuedCount = queued;
        _outboxErrorCount = error;
      });
    } catch (_) {}
  }

  Future<bool> _refreshOnlineState() async {
    final prev = _lastOnlineState;
    bool online = prev;
    try {
      online = await _networkStatusService.isOnline(
        timeout: const Duration(seconds: 2),
      );
    } catch (_) {}
    if (online == prev) return false;
    _lastOnlineState = online;
    if (mounted) setState(() {});
    _updateOfflineStatus();
    return true;
  }

  List<_QuickCapturePending> _decodeQuickCaptureQueueRaw(String raw) {
    if (raw.trim().isEmpty) return const <_QuickCapturePending>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <_QuickCapturePending>[];
      final out = <_QuickCapturePending>[];
      for (final item in decoded) {
        final parsed = _QuickCapturePending.fromJson(item);
        if (parsed != null) out.add(parsed);
      }
      return out;
    } catch (_) {
      return const <_QuickCapturePending>[];
    }
  }

  ({List<_QuickCapturePending> quickCapture, List<_EditPending> editQueue})
      _decodeOfflineQueuePayload(String raw) {
    if (raw.trim().isEmpty) {
      return (
        quickCapture: const <_QuickCapturePending>[],
        editQueue: const <_EditPending>[],
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return (
          quickCapture: _decodeQuickCaptureQueueRaw(raw),
          editQueue: const <_EditPending>[],
        );
      }
      if (decoded is! Map) {
        return (
          quickCapture: const <_QuickCapturePending>[],
          editQueue: const <_EditPending>[],
        );
      }
      final quick = <_QuickCapturePending>[];
      final edits = <_EditPending>[];
      final quickRaw = decoded['quickCapture'];
      if (quickRaw is List) {
        for (final item in quickRaw) {
          final parsed = _QuickCapturePending.fromJson(item);
          if (parsed != null) quick.add(parsed);
        }
      }
      final editsRaw = decoded['editQueue'];
      if (editsRaw is List) {
        for (final item in editsRaw) {
          final parsed = _EditPending.fromJson(item);
          if (parsed != null) edits.add(parsed);
        }
      }
      return (quickCapture: quick, editQueue: edits);
    } catch (_) {
      return (
        quickCapture: const <_QuickCapturePending>[],
        editQueue: const <_EditPending>[],
      );
    }
  }

  Future<String?> _readLegacyQuickCaptureQueueForCurrentSheet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyRaw = prefs.getString(_kPrefQuickCaptureQueue) ?? '';
      final decoded = _decodeQuickCaptureQueueRaw(legacyRaw);
      if (decoded.isEmpty) return null;
      final mine = <_QuickCapturePending>[];
      final remaining = <_QuickCapturePending>[];
      for (final item in decoded) {
        if (item.sheetId == widget.sheetId) {
          mine.add(item);
        } else {
          remaining.add(item);
        }
      }
      if (mine.isEmpty) return null;
      await prefs.setString(
        _kPrefQuickCaptureQueue,
        jsonEncode(remaining.map((e) => e.toJson()).toList(growable: false)),
      );
      return jsonEncode(<String, dynamic>{
        'quickCapture': mine.map((e) => e.toJson()).toList(growable: false),
        'editQueue': const <Map<String, dynamic>>[],
      });
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadQuickCaptureQueue() async {
    try {
      var raw = await _offlineQueueStore.read(widget.sheetId);
      raw ??= await _readLegacyQuickCaptureQueueForCurrentSheet();
      final loaded = _decodeOfflineQueuePayload(raw ?? '');
      if (!mounted) return;
      setState(() {
        _quickCaptureQueue
          ..clear()
          ..addAll(loaded.quickCapture);
        _editQueue
          ..clear()
          ..addAll(loaded.editQueue);
      });
      _updateOfflineStatus();
      await _tickQuickCaptureSync();
    } catch (_) {}
  }

  Future<void> _saveQuickCaptureQueue() async {
    try {
      if (_quickCaptureQueue.isEmpty && _editQueue.isEmpty) {
        await _offlineQueueStore.delete(widget.sheetId);
        _updateOfflineStatus();
        return;
      }
      final payload = jsonEncode(<String, dynamic>{
        'quickCapture':
            _quickCaptureQueue.map((e) => e.toJson()).toList(growable: false),
        'editQueue': _editQueue.map((e) => e.toJson()).toList(growable: false),
      });
      await _offlineQueueStore.write(sheetId: widget.sheetId, payload: payload);
      _updateOfflineStatus();
    } catch (_) {}
  }

  Future<void> _enqueueQuickCapturePending(String rowId) async {
    for (final item in _quickCaptureQueue) {
      if (item.sheetId == widget.sheetId && item.rowId == rowId) return;
    }
    final entry = _QuickCapturePending(
      sheetId: widget.sheetId,
      rowId: rowId,
      queuedAt: DateTime.now().toUtc(),
    );
    if (!mounted) return;
    setState(() {
      _quickCaptureQueue.add(entry);
      _offlineLastError = null;
      _offlineRetryAt = null;
    });
    _updateOfflineStatus();
    await _saveQuickCaptureQueue();
  }

  Future<void> _enqueueEditPending() async {
    final next = _EditPending(
      sheetId: widget.sheetId,
      revision: _rev,
      queuedAt: DateTime.now().toUtc(),
    );
    if (!mounted) return;
    setState(() {
      final idx = _editQueue.indexWhere(
        (item) => item.sheetId == widget.sheetId,
      );
      if (idx >= 0) {
        _editQueue[idx] = next;
      } else {
        _editQueue.add(next);
      }
      _offlineLastError = null;
      _offlineRetryAt = null;
    });
    _updateOfflineStatus();
    await _saveQuickCaptureQueue();
  }

  Future<void> _clearSavedEditPending() async {
    if (!mounted) return;
    final before = _editQueue.length;
    setState(() {
      _editQueue.removeWhere(
        (entry) =>
            entry.sheetId == widget.sheetId && entry.revision <= _lastSavedRev,
      );
    });
    if (before != _editQueue.length) {
      _updateOfflineStatus();
      await _saveQuickCaptureQueue();
    }
  }

  Duration _offlineRetryBackoff(int attempts) {
    final safeAttempts = attempts < 1 ? 1 : attempts;
    final seconds = math.min(90, math.pow(2, safeAttempts + 1).toInt());
    return Duration(seconds: seconds);
  }

  Future<void> _markOfflineSyncFailure(String reason) async {
    final now = DateTime.now().toUtc();
    var maxAttempts = 1;
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < _quickCaptureQueue.length; i++) {
        final item = _quickCaptureQueue[i];
        if (item.sheetId != widget.sheetId) continue;
        final nextAttempts = item.attempts + 1;
        maxAttempts = math.max(maxAttempts, nextAttempts);
        _quickCaptureQueue[i] = item.copyWith(
          attempts: nextAttempts,
          nextRetryAt: now.add(_offlineRetryBackoff(nextAttempts)),
          lastError: reason,
        );
      }
      for (int i = 0; i < _editQueue.length; i++) {
        final item = _editQueue[i];
        if (item.sheetId != widget.sheetId) continue;
        final nextAttempts = item.attempts + 1;
        maxAttempts = math.max(maxAttempts, nextAttempts);
        _editQueue[i] = item.copyWith(
          attempts: nextAttempts,
          nextRetryAt: now.add(_offlineRetryBackoff(nextAttempts)),
          lastError: reason,
        );
      }
      _offlineLastError = reason;
      _offlineRetryAt = now.add(_offlineRetryBackoff(maxAttempts));
    });
    debugPrint('[offline_queue] sync failure: $reason');
    _updateOfflineStatus();
    await _saveQuickCaptureQueue();
  }

  Future<void> _syncQuickCaptureQueue({bool notify = true}) async {
    if (_offlineSyncing) return;
    await _refreshOnlineState();
    if (!_isNetworkOnline()) {
      _updateOfflineStatus();
      return;
    }
    if (_pendingOfflineCount <= 0) {
      _offlineLastError = null;
      _offlineRetryAt = null;
      _updateOfflineStatus();
      return;
    }
    final now = DateTime.now().toUtc();
    if (_offlineRetryAt != null && now.isBefore(_offlineRetryAt!)) {
      _updateOfflineStatus();
      return;
    }

    _offlineSyncing = true;
    _updateOfflineStatus();

    var syncedQuick = 0;
    var syncedEdits = 0;

    try {
      if (_isDirty && !_saving) {
        await _saveLocalNow();
      }

      final remainingQuick = <_QuickCapturePending>[];
      for (final entry in _quickCaptureQueue) {
        if (entry.sheetId != widget.sheetId) {
          remainingQuick.add(entry);
          continue;
        }
        if (entry.nextRetryAt != null && entry.nextRetryAt!.isAfter(now)) {
          remainingQuick.add(entry);
          continue;
        }
        final exists = _rows.any((row) => row.id == entry.rowId);
        if (!exists) continue;
        syncedQuick++;
      }

      final remainingEdit = <_EditPending>[];
      for (final entry in _editQueue) {
        if (entry.sheetId != widget.sheetId) {
          remainingEdit.add(entry);
          continue;
        }
        if (entry.nextRetryAt != null && entry.nextRetryAt!.isAfter(now)) {
          remainingEdit.add(entry);
          continue;
        }
        if (_isDirty && _rev > _lastSavedRev) {
          remainingEdit.add(entry);
          continue;
        }
        if (_lastSavedRev >= entry.revision) {
          syncedEdits++;
          continue;
        }
        remainingEdit.add(entry);
      }

      if (!mounted) return;
      setState(() {
        _quickCaptureQueue
          ..clear()
          ..addAll(remainingQuick);
        _editQueue
          ..clear()
          ..addAll(remainingEdit);
        _offlineLastError = null;
        _offlineRetryAt = null;
      });
      await _saveQuickCaptureQueue();

      if (notify && (syncedQuick > 0 || syncedEdits > 0)) {
        _showActionSnack(
          'Sync completado: ${syncedQuick + syncedEdits} pendiente(s).',
          isError: false,
          icon: Icons.cloud_done_outlined,
        );
      }
    } catch (e, st) {
      debugPrint('[offline_queue] sync exception: $e');
      debugPrint(st.toString());
      await _markOfflineSyncFailure('sync_error');
      if (notify) {
        _showActionSnack(
          'Fallo la sincronizacion. Reintenta desde Cola offline.',
          isError: true,
          icon: Icons.sync_problem_rounded,
        );
      }
    } finally {
      _offlineSyncing = false;
      _updateOfflineStatus();
    }
  }

  Future<void> _tickQuickCaptureSync({bool fromTimer = false}) async {
    final changed = await _refreshOnlineState();
    if (!_isNetworkOnline()) {
      _updateOfflineStatus();
      return;
    }
    if (_pendingOfflineCount <= 0) {
      _updateOfflineStatus();
      return;
    }
    final now = DateTime.now().toUtc();
    if (fromTimer &&
        _offlineRetryAt != null &&
        now.isBefore(_offlineRetryAt!)) {
      _updateOfflineStatus();
      return;
    }
    await _syncQuickCaptureQueue(notify: changed && !fromTimer);
  }

  Future<void> _clearOfflineQueueForCurrentSheet() async {
    if (!mounted) return;
    setState(() {
      _quickCaptureQueue.removeWhere((item) => item.sheetId == widget.sheetId);
      _editQueue.removeWhere((item) => item.sheetId == widget.sheetId);
      _offlineLastError = null;
      _offlineRetryAt = null;
    });
    await _saveQuickCaptureQueue();
    _updateOfflineStatus();
  }

  String _offlineErrorMessage(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return 'Sin detalle';
    switch (value) {
      case 'sync_error':
        return 'Fallo de sincronizacion';
      case 'save_failed':
        return 'No se pudo guardar localmente';
      case 'network_offline':
        return 'Sin conexion';
      default:
        return value;
    }
  }

  Future<void> _retryQuickItem(String rowId) async {
    if (rowId.trim().isEmpty) return;
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < _quickCaptureQueue.length; i++) {
        final item = _quickCaptureQueue[i];
        if (item.sheetId != widget.sheetId || item.rowId != rowId) continue;
        _quickCaptureQueue[i] = item.copyWith(
          clearRetry: true,
          clearError: true,
        );
      }
      _offlineLastError = null;
      _offlineRetryAt = null;
    });
    await _saveQuickCaptureQueue();
    await _syncQuickCaptureQueue(notify: true);
  }

  Future<void> _retryEditItem(int revision) async {
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < _editQueue.length; i++) {
        final item = _editQueue[i];
        if (item.sheetId != widget.sheetId || item.revision != revision) {
          continue;
        }
        _editQueue[i] = item.copyWith(clearRetry: true, clearError: true);
      }
      _offlineLastError = null;
      _offlineRetryAt = null;
    });
    await _saveQuickCaptureQueue();
    await _syncQuickCaptureQueue(notify: true);
  }

  Future<void> _retryAllOfflineQueueNow() async {
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < _quickCaptureQueue.length; i++) {
        final item = _quickCaptureQueue[i];
        if (item.sheetId != widget.sheetId) continue;
        _quickCaptureQueue[i] = item.copyWith(
          clearRetry: true,
          clearError: true,
        );
      }
      for (int i = 0; i < _editQueue.length; i++) {
        final item = _editQueue[i];
        if (item.sheetId != widget.sheetId) continue;
        _editQueue[i] = item.copyWith(clearRetry: true, clearError: true);
      }
      _offlineLastError = null;
      _offlineRetryAt = null;
    });
    await _saveQuickCaptureQueue();
    await _syncQuickCaptureQueue(notify: true);
  }

  Future<void> _exportOfflineQueueDiagnostics() async {
    final now = DateTime.now().toUtc();
    final quickForSheet = _quickCaptureQueue
        .where((item) => item.sheetId == widget.sheetId)
        .toList(growable: false);
    final editForSheet = _editQueue
        .where((item) => item.sheetId == widget.sheetId)
        .toList(growable: false);
    final payload = <String, dynamic>{
      'sheetId': widget.sheetId,
      'sheetName': _sheetName,
      'generatedAt': now.toIso8601String(),
      'offlineState': _resolveOfflineSyncState().name,
      'offlineMessage':
          _resolveOfflineStatusMessage(_resolveOfflineSyncState()) ?? 'N/A',
      'online': _isNetworkOnline(),
      'pendingQuickCapture': quickForSheet.length,
      'pendingEdits': editForSheet.length,
      'quickCaptureQueue':
          quickForSheet.map((item) => item.toJson()).toList(growable: false),
      'editQueue':
          editForSheet.map((item) => item.toJson()).toList(growable: false),
      'lastError': _offlineLastError,
      'nextRetryAt': _offlineRetryAt?.toIso8601String(),
    };
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    final name =
        'BitFlow_offline_diagnostic_${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}.json';
    try {
      await _saveExportBytes(
        name: name,
        mime: 'application/json',
        bytes: Uint8List.fromList(utf8.encode(encoded)),
        share: false,
      );
      if (!mounted) return;
      _showActionSnack(
        'Diagnostico de cola exportado.',
        isError: false,
        icon: Icons.bug_report_outlined,
      );
    } on _EditorLongOperationCancelled {
      if (!mounted) return;
      _showActionSnack(
        AppStrings.infoExportCancelled,
        isError: false,
        icon: Icons.info_outline_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      unawaited(_copyDiagnosticToClipboard(encoded));
    }
  }

  Future<void> _openOfflineQueueDialog() async {
    if (!mounted) return;
    final quickForSheet = _quickCaptureQueue
        .where((item) => item.sheetId == widget.sheetId)
        .toList(growable: false);
    final editForSheet = _editQueue
        .where((item) => item.sheetId == widget.sheetId)
        .toList(growable: false);
    final retryAt = _offlineRetryAt?.toLocal();
    final statusText =
        _resolveOfflineStatusMessage(_resolveOfflineSyncState()) ??
            'Sincronizado';

    await showAppModal<void>(
      context: context,
      title: 'Cola offline',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 340),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Estado: $statusText',
              style: TextStyle(
                color: _palette(context).fg,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_offlineLastError?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                'Ultimo error: ${_offlineErrorMessage(_offlineLastError)}',
                style: TextStyle(
                  color: _palette(context).fgMuted,
                  fontSize: 12,
                ),
              ),
            ],
            if (retryAt != null &&
                (quickForSheet.isNotEmpty || editForSheet.isNotEmpty)) ...[
              const SizedBox(height: 4),
              Text(
                'Proximo reintento: ${_formatDateTimeShort(retryAt)}',
                style: TextStyle(
                  color: _palette(context).fgMuted,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (quickForSheet.isEmpty && editForSheet.isEmpty)
              Text(
                'Sin pendientes.',
                style: TextStyle(color: _palette(context).fgMuted),
              ),
            for (final item in quickForSheet)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_a_photo_outlined),
                title: Text(
                  'Registro ${item.rowId.substring(0, math.min(8, item.rowId.length))}',
                ),
                subtitle: Text(
                  'Encolado ${_formatDateTimeShort(item.queuedAt.toLocal())}'
                  ' | intentos ${item.attempts}'
                  '${item.nextRetryAt != null ? ' | retry ${_formatDateTimeShort(item.nextRetryAt!.toLocal())}' : ''}'
                  '${item.lastError != null ? ' | ${_offlineErrorMessage(item.lastError)}' : ''}',
                ),
                trailing: IconButton(
                  tooltip: 'Reintentar item',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    Navigator.of(context).pop();
                    unawaited(_retryQuickItem(item.rowId));
                  },
                ),
              ),
            for (final item in editForSheet)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_note_rounded),
                title: Text('Cambios rev ${item.revision}'),
                subtitle: Text(
                  'Pendiente desde ${_formatDateTimeShort(item.queuedAt.toLocal())}'
                  ' | intentos ${item.attempts}'
                  '${item.nextRetryAt != null ? ' | retry ${_formatDateTimeShort(item.nextRetryAt!.toLocal())}' : ''}'
                  '${item.lastError != null ? ' | ${_offlineErrorMessage(item.lastError)}' : ''}',
                ),
                trailing: IconButton(
                  tooltip: 'Reintentar item',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    Navigator.of(context).pop();
                    unawaited(_retryEditItem(item.revision));
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: 'Diag',
          variant: AppButtonVariant.ghost,
          onPressed: () {
            Navigator.of(context).pop();
            unawaited(_exportOfflineQueueDiagnostics());
          },
        ),
        AppButton(
          label: 'Exportar ZIP',
          variant: AppButtonVariant.ghost,
          onPressed: () {
            Navigator.of(context).pop();
            unawaited(_exportZipBundle(share: false));
          },
        ),
        AppButton(
          label: 'Borrar',
          variant: AppButtonVariant.ghost,
          onPressed: () {
            Navigator.of(context).pop();
            unawaited(_clearOfflineQueueForCurrentSheet());
          },
        ),
        AppButton(
          label: 'Reintentar todo',
          variant: AppButtonVariant.secondary,
          onPressed: () {
            Navigator.of(context).pop();
            unawaited(_retryAllOfflineQueueNow());
          },
        ),
        AppButton(
          label: 'Cerrar',
          variant: AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
  }

  int? _findDataColumnByKeywords(List<String> keywords) {
    final dataCols = _headers.length - 1;
    if (dataCols <= 0) return null;
    for (int c = 0; c < dataCols; c++) {
      final label = _headerLabel(c).toLowerCase();
      for (final key in keywords) {
        if (label.contains(key)) return c;
      }
    }
    return null;
  }

  int _resolveQuickCaptureDateColumn() {
    final found = _findDataColumnByKeywords(const <String>[
      'fecha',
      'date',
      'hora',
      'time',
      'timestamp',
    ]);
    if (found != null) return found;
    if (_selCol >= 0 && _selCol < _headers.length - 1) return _selCol;
    return 0;
  }

  int? _resolveQuickCaptureNoteColumn(int dateCol) {
    final found = _findDataColumnByKeywords(const <String>[
      'nota',
      'observ',
      'coment',
      'detalle',
      'note',
    ]);
    if (found != null && found != dateCol) return found;
    final dataCols = _headers.length - 1;
    for (int c = 0; c < dataCols; c++) {
      if (c != dateCol) return c;
    }
    return null;
  }

  int _resolveQuickCaptureGpsColumn(int fallbackCol) {
    final found = _findDataColumnByKeywords(const <String>[
      'gps',
      'ubic',
      'coord',
      'lat',
      'lon',
    ]);
    return found ?? fallbackCol;
  }

  String _quickCaptureTimestampText(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)} ${_two(local.hour)}:${_two(local.minute)}';
  }

  Future<String?> _promptQuickCaptureNote() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Nota corta (opcional)'),
          content: TextField(
            controller: controller,
            maxLength: 140,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Ej: Inspeccion en poste 12',
            ),
            onSubmitted: (value) => Navigator.of(ctx).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(''),
              child: const Text('Omitir'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  ({int rowIndex, String rowId, CellRef? photoRef})? _appendQuickCaptureRow({
    required DateTime capturedAt,
    required String note,
    _GpsFix? gpsFix,
  }) {
    if (_headers.length < 2) return null;
    final dataCols = _headers.length - 1;
    if (dataCols <= 0) return null;

    final rowId = _genStableId('r_');
    final cells = List<String>.filled(_headers.length, '');
    final dateCol = _resolveQuickCaptureDateColumn().clamp(0, dataCols - 1);
    final noteCol = _resolveQuickCaptureNoteColumn(dateCol);
    final gpsCol = _resolveQuickCaptureGpsColumn(
      dateCol,
    ).clamp(0, dataCols - 1);

    cells[dateCol] = _quickCaptureTimestampText(capturedAt);
    if (note.trim().isNotEmpty && noteCol != null) {
      cells[noteCol] = note.trim();
    }
    if (gpsFix != null && gpsCol != dateCol) {
      cells[gpsCol] = _gpsTextForFix(gpsFix);
    }

    final row = _RowModel(id: rowId, cells: cells, photos: const <_RowPhoto>[]);
    final insertAt = _rows.length;
    final photoRef = CellRef(
      sheetId: widget.sheetId,
      rowId: rowId,
      colId: _colIds[_headers.length - 1],
    );

    final gpsRef = CellRef(
      sheetId: widget.sheetId,
      rowId: rowId,
      colId: _colIds[gpsCol],
    );

    setState(() {
      _rows.add(row);
      _setSelection(insertAt, dateCol);

      if (gpsFix != null) {
        _cellMeta[gpsRef.key] = CellMeta(
          gps: _gpsMetaFromFix(gpsFix),
        );
      }
    });
    _insertMobileRowCache(insertAt);
    _markDirty(snapshot: true);
    return (rowIndex: insertAt, rowId: rowId, photoRef: photoRef);
  }

  // Modo Campo: este flujo siempre crea una fila nueva y adjunta la foto en
  // la columna Photos de esa fila.
  Future<void> _startQuickCaptureFlow() async {
    if (_rows.isEmpty || _headers.length < 2) return;
    if (_guardInAppBrowser(DiagnosticActionType.photo)) return;

    final picked = await _showPhotoSourcePicker();
    if (!mounted || picked == null) return;

    final outcome = picked.outcome;
    if (!outcome.ok) {
      if (outcome.cancelled) return;
      _showActionSnack(
        outcome.error ?? 'No se pudo obtener la foto.',
        isError: true,
        icon: Icons.photo_camera_outlined,
      );
      return;
    }

    final note = await _promptQuickCaptureNote();
    if (!mounted) return;
    if (note == null) return;

    final gpsOutcome = await _getGpsFixWithFallback(
      timeout: const Duration(seconds: 10),
    );
    if (!mounted) return;

    final inserted = _appendQuickCaptureRow(
      capturedAt: DateTime.now(),
      note: note,
      gpsFix: gpsOutcome.fix,
    );
    if (inserted == null) return;
    _addHistoryEvent(
      type: 'quick_capture',
      message: 'Captura r\u00e1pida en fila ${inserted.rowIndex + 1}',
      origin: 'quick_capture',
      row: inserted.rowIndex,
    );

    if (inserted.photoRef != null) {
      await _processPhotoOutcome(
        outcome,
        inserted.photoRef!,
        fromCamera: picked.fromCamera,
      );
    }
    if (!mounted) return;

    await _refreshOnlineState();
    final online = _isNetworkOnline();
    if (!online) {
      await _enqueueQuickCapturePending(inserted.rowId);
      _showActionSnack(
        'Pendiente de sync. Se sincroniza automaticamente al volver la conexion.',
        isError: false,
        icon: Icons.cloud_off_outlined,
      );
    } else {
      await _syncQuickCaptureQueue(notify: false);
    }

    if (!gpsOutcome.ok) {
      _showActionSnack(
        'Guardamos el registro, pero sin GPS (sin permiso o sin senal en este momento).',
        isError: false,
        icon: Icons.gps_off_rounded,
      );
    }

    await _openRowFormMode(rowIndex: inserted.rowIndex);
    if (!mounted) return;

    _showActionSnack(
      'Registro creado en fila ${inserted.rowIndex + 1}.',
      isError: false,
      icon: Icons.add_task_rounded,
    );
  }

  void _beginLongOperation({
    required String message,
    required bool cancellable,
  }) {
    final next = _EditorLongOperationState(
      message: message,
      cancellable: cancellable,
    );
    if (!mounted) {
      _longOperation = next;
      return;
    }
    _setEditorState(() => _longOperation = next);
  }

  bool _tryBeginLongOperation({
    required String message,
    required bool cancellable,
  }) {
    final current = _longOperation;
    if (current != null && !current.cancelRequested) {
      _showActionSnack(
        'Ya hay una operaci\u00f3n en curso. Esper\u00e1 a que termine o cancelala.',
        isError: false,
        icon: Icons.hourglass_top_rounded,
      );
      return false;
    }
    _beginLongOperation(message: message, cancellable: cancellable);
    return true;
  }

  void _setLongOperationMessage(String message) {
    final current = _longOperation;
    if (current == null || current.message == message) return;
    final next = current.copyWith(message: message);
    if (!mounted) {
      _longOperation = next;
      return;
    }
    _setEditorState(() => _longOperation = next);
  }

  void _requestLongOperationCancel() {
    final current = _longOperation;
    if (current == null || !current.cancellable || current.cancelRequested) {
      return;
    }
    final next = current.copyWith(
      cancelRequested: true,
      message: AppStrings.progressCancelling,
    );
    if (!mounted) {
      _longOperation = next;
    } else {
      _setEditorState(() => _longOperation = next);
    }
    _showActionSnack(
      AppStrings.infoOperationCancelling,
      isError: false,
      icon: Icons.hourglass_bottom_rounded,
    );
  }

  void _clearLongOperation() {
    if (_longOperation == null) return;
    if (!mounted) {
      _longOperation = null;
      return;
    }
    _setEditorState(() => _longOperation = null);
  }

  bool _isLongOperationCancelled() {
    return _longOperation?.cancelRequested ?? false;
  }

  void _throwIfLongOperationCancelled() {
    if (_isLongOperationCancelled()) {
      throw const _EditorLongOperationCancelled();
    }
  }

  void _throwIfOperationCancelledBy(bool Function()? shouldCancel) {
    if (shouldCancel != null && shouldCancel()) {
      throw const _EditorLongOperationCancelled();
    }
  }

  void _reportFlowError(
    Object error, {
    required AppErrorFlow flow,
    required String operation,
    StackTrace? stackTrace,
    String? fallbackMessage,
    String? code,
    String? diagnosticDetails,
    IconData? icon,
    DiagnosticActionType? diagnosticType,
  }) {
    final appError = AppErrorMapper.from(
      error,
      flow: flow,
      fallbackMessage: fallbackMessage,
      code: code,
    );
    AppErrorReporter.I.record(
      appError,
      operation: operation,
      stackTrace: stackTrace,
    );
    debugPrint('[EditorScreen] ${appError.toLogLine(operation: operation)}');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
    if (diagnosticType != null) {
      DiagnosticsLog.I.record(
        type: diagnosticType,
        ok: false,
        message: 'app_error ${appError.toLogLine(operation: operation)}',
      );
    }
    _lastErrorFeedbackMessage = appError.userMessage;
    _showActionSnack(
      appError.userMessage,
      isError: true,
      icon: icon ?? Icons.error_outline_rounded,
      actionLabel: (diagnosticDetails ?? '').trim().isEmpty
          ? null
          : 'Ver detalle tecnico',
      onAction: (diagnosticDetails ?? '').trim().isEmpty
          ? null
          : () => unawaited(_copyDiagnosticToClipboard(diagnosticDetails!)),
    );
  }

  void _reportFlowErrorMessage(
    String? message, {
    required AppErrorFlow flow,
    required String operation,
    String? fallbackMessage,
    String? code,
    String? diagnosticDetails,
    IconData? icon,
    DiagnosticActionType? diagnosticType,
  }) {
    final appError = AppErrorMapper.fromMessage(
      message,
      flow: flow,
      fallbackMessage: fallbackMessage,
      code: code,
    );
    AppErrorReporter.I.record(appError, operation: operation);
    debugPrint('[EditorScreen] ${appError.toLogLine(operation: operation)}');
    if (diagnosticType != null) {
      DiagnosticsLog.I.record(
        type: diagnosticType,
        ok: false,
        message: 'app_error ${appError.toLogLine(operation: operation)}',
      );
    }
    _lastErrorFeedbackMessage = appError.userMessage;
    _showActionSnack(
      appError.userMessage,
      isError: true,
      icon: icon ?? Icons.error_outline_rounded,
      actionLabel: (diagnosticDetails ?? '').trim().isEmpty
          ? null
          : 'Ver detalle tecnico',
      onAction: (diagnosticDetails ?? '').trim().isEmpty
          ? null
          : () => unawaited(_copyDiagnosticToClipboard(diagnosticDetails!)),
    );
  }

  Future<void> _copyDiagnosticToClipboard(String payload) async {
    final text = payload.trim();
    if (text.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      _showActionSnack(
        'Diagnostico copiado.',
        isError: false,
        icon: Icons.content_copy_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      _showActionSnack(
        'No se pudo copiar el diagnostico.',
        isError: true,
        icon: Icons.copy_all_outlined,
      );
    }
  }

  bool _guardInAppBrowser(DiagnosticActionType type, {String? actionLabel}) {
    if (!_isInAppBrowser) return false;
    final label = actionLabel ?? _actionLabelForType(type);
    DiagnosticsLog.I.record(
      type: type,
      ok: false,
      message: 'blocked_in_app action=$label',
    );
    _showActionSnack(
      'Bloqueado en navegador embebido. Abri en Safari/Chrome.',
      isError: true,
      icon: Icons.lock_outline_rounded,
    );
    unawaited(_showInAppBlockingModal());
    return true;
  }

  bool _guardInsecureContext(DiagnosticActionType type, {String? actionLabel}) {
    if (_isSecureContext) return false;
    final label = actionLabel ?? _actionLabelForType(type);
    DiagnosticsLog.I.record(
      type: type,
      ok: false,
      message: 'blocked_insecure_context action=$label',
    );
    _showActionSnack(
      'Necesitas HTTPS para $label. Abri en Safari/Chrome.',
      isError: true,
      icon: Icons.lock_outline_rounded,
    );
    return true;
  }

  String _actionLabelForType(DiagnosticActionType type) {
    switch (type) {
      case DiagnosticActionType.gps:
        return 'GPS';
      case DiagnosticActionType.photo:
        return 'Camara/Fotos';
      case DiagnosticActionType.audio:
        return 'Microfono';
      case DiagnosticActionType.video:
        return 'Video';
      case DiagnosticActionType.file:
        return 'Archivo';
      case DiagnosticActionType.location:
        return 'Ubicacion';
    }
  }

  Future<void> _showInAppBlockingModal() async {
    if (!_isInAppBrowser || _inAppModalShown || !mounted) return;
    _inAppModalShown = true;
    final url = kIsWeb ? Uri.base.toString() : '';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final pal = _palette(ctx);
        return AlertDialog(
          backgroundColor: pal.menuBg,
          title: const Text('Abrir en Safari/Chrome'),
          content: const Text(
            'Para usar Camara/Mic/GPS abri en Safari/Chrome.\n\n'
            'Los navegadores embebidos (WhatsApp/Instagram) bloquean permisos y guardado.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (url.trim().isEmpty) return;
                try {
                  await Clipboard.setData(ClipboardData(text: url));
                } catch (_) {}
                if (mounted) {
                  _showActionSnack(
                    'Link copiado.',
                    isError: false,
                    icon: Icons.link_rounded,
                  );
                }
              },
              child: const Text('Copiar link'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                unawaited(_showInAppInstructions());
              },
              child: const Text('Instrucciones'),
            ),
            if (_isAndroidWeb)
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _tryOpenInChrome(url);
                },
                child: const Text('Abrir en Chrome'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showInAppInstructions() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final pal = _palette(ctx);
        return AlertDialog(
          backgroundColor: pal.menuBg,
          title: const Text('Como abrir en navegador'),
          content: const Text(
            'WhatsApp/Instagram:\n\n'
            '1) Toca el menu (tres puntos) o Compartir.\n'
            '2) Elegi "Abrir en navegador".\n'
            '3) Volve a intentar Camara/Mic/GPS.\n\n'
            'iOS: preferi Safari.\n'
            'Android: preferi Chrome.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _tryOpenInChrome(String url) async {
    if (url.trim().isEmpty) return;
    final uri = Uri.parse(url);
    final query = uri.query.isEmpty ? '' : '?${uri.query}';
    final intent =
        'intent://${uri.host}${uri.path}$query#Intent;scheme=${uri.scheme};package=com.android.chrome;end';
    try {
      final ok = await launchUrl(
        Uri.parse(intent),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  void _warnStorageFallbackOnce(
    String kindLabel, {
    String? reasonCode,
    String? storageLabel,
  }) {
    final labelLower = kindLabel.trim().toLowerCase();
    final isCapabilityWarning = labelLower.startsWith('modo temporal');
    final isAudioFallback = labelLower == 'audio';
    String? inferredStore;
    String? inferredReason;
    if (kIsWeb && !isCapabilityWarning) {
      inferredReason = WebBlobStore.I.lastSaveReason;
      try {
        final dynamic webStore = WebBlobStore.I;
        final candidate = webStore.lastSaveStore;
        if (candidate is String) {
          inferredStore = candidate;
        }
      } catch (_) {}
    }
    final effectiveReasonCode = (reasonCode ??
            (isAudioFallback ? 'unknown_storage_error' : inferredReason))
        ?.trim();
    final effectiveStore =
        (storageLabel ?? (isAudioFallback ? 'ram' : inferredStore))?.trim();
    final mapping = classifyEditorStorageFallbackReason(effectiveReasonCode);
    final reasonKey = mapping.storageVariant.trim().isEmpty
        ? 'generic'
        : mapping.storageVariant.trim();
    final storeKey = (effectiveStore ?? '').trim().toLowerCase().isEmpty
        ? 'unknown'
        : (effectiveStore ?? '').trim().toLowerCase();
    final warnKey = '$storeKey|$reasonKey';
    if (_storageWarnedReasons.contains(warnKey)) return;
    _storageWarnedReasons.add(warnKey);
    if (kDebugMode) {
      debugPrint(
        '[EditorScreen] storage_fallback kind=$kindLabel '
        'store=$storeKey reason=${effectiveReasonCode ?? 'null'} '
        'mapped=${mapping.storageVariant}',
      );
    }
    final storageMessage = switch (mapping.storageVariant) {
      'quota_exceeded' => 'Espacio local del navegador agotado',
      'storage_session_only' => 'Modo temporal/inc\u00f3gnito del navegador',
      'storage_blocked' => 'Guardado local bloqueado por el navegador',
      'unknown_storage_error' => 'Guardado local temporal',
      _ => 'Modo temporal del navegador',
    };
    final snackMessage = switch (mapping.snackVariant) {
      'quota_exceeded' =>
        'Espacio local agotado para $kindLabel. Export\u00e1 ZIP y liber\u00e1 almacenamiento del sitio antes de seguir.',
      'storage_session_only' =>
        'Guardado temporal para $kindLabel: el navegador est\u00e1 en modo temporal/inc\u00f3gnito. Export\u00e1 ZIP antes de cerrar.',
      'storage_blocked' =>
        'Guardado local bloqueado para $kindLabel. Revis\u00e1 permisos del sitio o export\u00e1 ZIP para conservar.',
      _ =>
        'Guardado temporal para $kindLabel: si cerr\u00e1s o recarg\u00e1s podr\u00edas perder adjuntos. Export\u00e1 ZIP para conservar.',
    };
    if (mounted) {
      setState(() {
        _storageOk = false;
        _storageMessage = storageMessage;
      });
    } else {
      _storageOk = false;
      _storageMessage = storageMessage;
    }
    _showActionSnack(
      snackMessage,
      isError: false,
      icon: Icons.warning_amber_rounded,
    );
  }

  void _refreshCellAfterSave(int r, int c) {
    _bumpGridVersion();
    _blink(r, c);
  }

  Widget _warningBanner(
    _SheetPalette pal, {
    required String text,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
    VoidCallback? onDismiss,
  }) {
    final t = AppTheme.of(context);
    final isMobileLayout = MediaQuery.sizeOf(context).width < 760;
    final borderColor = t.colors.warningFg.withValues(
      alpha: pal.isLight ? 0.35 : 0.5,
    );

    final mainRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: isMobileLayout ? 17 : 18, color: t.colors.warningFg),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: isMobileLayout ? 3 : null,
            overflow: isMobileLayout ? TextOverflow.ellipsis : null,
            style: TextStyle(
              color: t.colors.warningFg,
              fontWeight: FontWeight.w700,
              height: 1.2,
              fontSize: isMobileLayout ? 12.5 : 13,
            ),
          ),
        ),
        if (!isMobileLayout && actionLabel != null && onAction != null) ...[
          const SizedBox(width: 10),
          AppleButton(
            label: actionLabel,
            dense: true,
            variant: AppleButtonVariant.ghost,
            onPressed: onAction,
          ),
        ],
        if (onDismiss != null)
          IconButton(
            tooltip: 'Cerrar',
            onPressed: onDismiss,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: t.colors.warningFg.withValues(alpha: 0.74),
            ),
          ),
      ],
    );

    return Container(
      margin: EdgeInsets.fromLTRB(16, isMobileLayout ? 4 : 6, 16, 6),
      padding: EdgeInsets.symmetric(
        horizontal: isMobileLayout ? 10 : 12,
        vertical: isMobileLayout ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: t.colors.warningBg,
        borderRadius: BorderRadius.circular(isMobileLayout ? 10 : 12),
        border: Border.all(color: borderColor, width: pal.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          mainRow,
          if (isMobileLayout && actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: AppleButton(
                label: actionLabel,
                dense: true,
                variant: AppleButtonVariant.ghost,
                onPressed: onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPerfOverlay(
    _SheetPalette pal, {
    required bool isDesktop,
  }) {
    final topInset = isDesktop ? 18.0 : 72.0;
    final width = isDesktop ? 340.0 : 318.0;
    final bg = pal.editorBg.withValues(alpha: pal.isLight ? 0.95 : 0.94);

    return Positioned(
      right: 12,
      top: topInset,
      child: RepaintBoundary(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pal.borderStrong, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: pal.borderStrong.withValues(
                      alpha: pal.isLight ? 0.22 : 0.38,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: ValueListenableBuilder<PerfStats>(
                valueListenable: PerfOptimizer.stats,
                builder: (ctx, stats, __) {
                  final frameLabel =
                      '${stats.avgFrame.inMilliseconds}ms / p95 ${stats.p95Frame.inMilliseconds}ms';
                  final jankLabel =
                      '${stats.jankyFrames}/${stats.framesMeasured} (${stats.jankPercent.toStringAsFixed(1)}%)';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.speed_rounded, size: 16, color: pal.fg),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Perf Harness',
                              style: TextStyle(
                                color: pal.fg,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip:
                                _perfOverlayExpanded ? 'Colapsar' : 'Expandir',
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            onPressed: () => setState(() {
                              _perfOverlayExpanded = !_perfOverlayExpanded;
                            }),
                            icon: Icon(
                              _perfOverlayExpanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: pal.fgMuted,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'frame avg/p95: $frameLabel',
                        style: TextStyle(
                          color: pal.fgMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'jank: $jankLabel',
                        style: TextStyle(
                          color: pal.fgMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'grid/row/cell: $_debugGridBuilds / $_debugRowBuilds / $_debugCellBuilds',
                        style: TextStyle(
                          color: pal.fgMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'thumb cache: ${_thumbDecodeCache.entryCount} items | ${_formatBytes(_thumbDecodeCache.totalBytes)} | H:${_thumbDecodeCache.cacheHits} M:${_thumbDecodeCache.cacheMisses}',
                        style: TextStyle(
                          color: pal.fgMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_perfOverlayExpanded) ...[
                        const SizedBox(height: 8),
                        Text(
                          'scenario runs: $_perfScenarioRuns'
                          '${_perfScenarioLastAt == null ? '' : ' | last ${_perfScenarioLastAt!.toLocal().toIso8601String().substring(11, 19)}'}',
                          style: TextStyle(
                            color: pal.fgMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            AppleButton(
                              label: _perfScenarioRunning
                                  ? 'Running...'
                                  : 'Run scenario',
                              icon: Icons.play_arrow_rounded,
                              dense: true,
                              variant: AppleButtonVariant.tonal,
                              onPressed: _perfScenarioRunning
                                  ? null
                                  : () => unawaited(_runPerfScenario()),
                            ),
                            AppleButton(
                              label: 'Copy report',
                              icon: Icons.copy_all_rounded,
                              dense: true,
                              variant: AppleButtonVariant.ghost,
                              onPressed: () => unawaited(_copyPerfReport()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Route: /perf or ?perf=1',
                          style: TextStyle(
                            color: pal.fgMuted.withValues(alpha: 0.84),
                            fontSize: 10.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------ Build -----------------------------------

  @override
  Widget build(BuildContext context) {
    final pal = _palette(context);
    return ValueListenableBuilder<double>(
      valueListenable: _kbController.kbInsetDp,
      builder: (ctx, kbInset, _) {
        final mqInset = MediaQuery.viewInsetsOf(ctx).bottom;
        final keyboardInset = _effectiveKeyboardInset(
          ctx,
          mediaQueryInset: mqInset,
          controllerInset: kbInset,
        );
        final isDesktop = _isDesktopUi(ctx, keyboardInset);
        final sensorsEnabled = !_isInAppBrowser;
        _ensureDefaultDensity(isDesktop);
        final metrics = _gridMetricsFor(_gridDensity);

        if (!isDesktop && _mobileEditorOpen) {
          _scheduleMobileBarMeasure();
        }

        // Evitar escalados raros de texto (iOS / Web).
        final mq = MediaQuery.of(ctx);
        final bottomSafe = mq.viewPadding.bottom;
        final requestedScale = mq.textScaler.scale(14) / 14;
        final boundedScale = requestedScale.clamp(1.0, 1.2).toDouble();
        final fixedMq = mq.copyWith(
          textScaler: TextScaler.linear(boundedScale),
        );

        _kbController.reportMediaQueryInset(mqInset);
        final isMobile = !isDesktop;
        final editorActive = isMobile && _mobileEditorOpen;
        final desiredPanelH = _mobileEditorExpanded
            ? _kMobilePanelExpandedH
            : _kMobilePanelCompactH;
        final panelH = isDesktop
            ? 0.0
            : (editorActive
                ? (_mobileBarH > 0 && (_mobileBarH - desiredPanelH).abs() < 8)
                    ? _mobileBarH
                    : desiredPanelH
                : 0.0);
        final keyboardVisible = keyboardInset > 0.0;
        final route = ModalRoute.of(ctx);
        final modalRouteActive = route != null && !route.isCurrent;
        final hideMobileFab =
            _mobileEditorOpen || keyboardVisible || modalRouteActive;
        final mobileEditorBarH =
            keyboardVisible ? _kMobileInlineCompactBarH : panelH;
        final mobileEditorSafeBottom = keyboardVisible ? 0.0 : bottomSafe;
        final mobileBarBottomAnim = _mobileBarBottomDuration(keyboardInset);
        final requestedMobileGridInset = editorActive
            ? keyboardInset + mobileEditorBarH + mobileEditorSafeBottom + 8
            : bottomSafe + 12;
        final maxMobileGridInset = math.max(
          0.0,
          mq.size.height - _kMinMobileGridVisiblePx,
        );
        final mobileGridBottomInset = isDesktop
            ? 0.0
            : math.min(requestedMobileGridInset, maxMobileGridInset);
        final autoCollapsedTopChrome = isMobile && keyboardVisible;
        final collapseNonCriticalTopChrome = autoCollapsedTopChrome;
        final showSelectionQuickActions = !_mobileEditorOpen &&
            !keyboardVisible &&
            (_selRow >= 0 && _selCol >= 0);
        final showInlineFlowBotBar = showSelectionQuickActions &&
            mq.size.width >= 360 &&
            mq.size.height >= 700;
        final inlineFlowBotActions = showInlineFlowBotBar
            ? _flowBotInlineQuickActions(_flowBotQuickContext())
            : const <_FlowBotInlineQuickActionView>[];
        final canMarkSelectionStatus = _statusColumnForBatchActions() != null;
        final displayColumns = _displayColumnIndexes();
        final visibleRows = _visibleRowIndexes();
        final visibleRowModels = _visibleRowModels();
        final displayHeaders = List<String>.generate(
          displayColumns.length,
          (i) => _effectiveHeader(displayColumns[i]),
          growable: false,
        );
        final selectedDisplayCol = _displayColumnIndexForActual(
          _selCol,
          displayColumns,
        );
        final selectedDisplayRow = _displayRowForActual(_selRow, visibleRows);
        final selectedDisplayRows = _selectedDisplayRows(visibleRows);
        final showPremiumEmptyState = _shouldShowPremiumEmptyState();
        final canShowEditorTour = !collapseNonCriticalTopChrome &&
            _editorTourVisible &&
            _rows.length <= 40 &&
            !showPremiumEmptyState &&
            (isDesktop || mq.size.height > 860);
        if (kDebugMode && !_debugEditorFirstFrameLogged) {
          _debugEditorFirstFrameLogged = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            debugPrint(
              '[editor] first_frame mounted=$mounted rows=${_rows.length} cols=${_headers.length} '
              'mobile=$isMobile emptyState=$showPremiumEmptyState sel=($_selRow,$_selCol)',
            );
          });
        }

        if (isMobile) {
          if (!_suppressEngineUnavailableUx &&
              _engineFallbackMode &&
              _engineStatus != null) {
            _maybeShowMobileStatusSnack(
              ctx,
              pal,
              message: _engineStatus,
              isError: false,
            );
          } else if (!_suppressEngineUnavailableUx &&
              _engineStatusIsError &&
              _engineStatus != null) {
            _maybeShowMobileStatusSnack(
              ctx,
              pal,
              message: _engineStatus,
              isError: true,
            );
          } else if (_smokeOk == false && _smokeStatus != null) {
            _maybeShowMobileStatusSnack(
              ctx,
              pal,
              message: _smokeStatus,
              isError: true,
            );
          }
        }

        return MediaQuery(
          data: fixedMq,
          child: ScrollConfiguration(
            behavior: const _NoGlowScrollBehavior(),
            child: PopScope<void>(
              canPop: _allowPopOnce || !_hasUnsavedWork,
              onPopInvokedWithResult: (didPop, _) {
                unawaited(_handleEditorPopGuard(didPop: didPop));
              },
              child: AppScaffold(
                resizeToAvoidBottomInset: false, // clave iOS Web
                backgroundColor: pal.bg,
                appBar: null,
                body: SafeArea(
                  bottom: false,
                  child: Stack(
                    children: [
                      if (pal.isLight)
                        Positioned.fill(child: _WarmBackdrop(palette: pal)),
                      Padding(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            if (isDesktop)
                              (_zenModeEnabled
                                  ? const SizedBox.shrink()
                                  : RepaintBoundary(
                                      child: _PremiumAppleHeader(
                                        palette: pal,
                                        titleController: _nameEC,
                                        titleFocus: _nameFocus,
                                        controller: _controller,
                                        onTitleChanged:
                                            _onTitleChangedDebounced,
                                        onToggleTheme: _toggleTheme,
                                        onUndo: _undoOnce,
                                        onRedo: _redoOnce,
                                        onAddRow: () => unawaited(
                                          _createNewRecordAction(
                                            origin: 'toolbar',
                                          ),
                                        ),
                                        onQuickCapture: () =>
                                            unawaited(_startQuickCaptureFlow()),
                                        onForm: () => unawaited(
                                          _openRowFormMode(
                                            rowIndex: _selRow,
                                            createNew: false,
                                          ),
                                        ),
                                        onSearch: () =>
                                            unawaited(_openSearchDialog()),
                                        onSearchEverywhere: () => unawaited(
                                            _openSearchEverywhereDialog()),
                                        onJumpTo: () =>
                                            unawaited(_openJumpToDialog()),
                                        onColumns: () =>
                                            unawaited(_openColumnPanel()),
                                        onHistory: () =>
                                            unawaited(_openHistoryPanel()),
                                        onSaveView: () =>
                                            unawaited(_openSaveViewDialog()),
                                        onSelectView: (viewId) =>
                                            unawaited(_applySavedView(viewId)),
                                        onManageViews: () =>
                                            unawaited(_openSavedViewsManager()),
                                        onMarkReviewed: () => unawaited(
                                            _markSelectedRowsReviewed()),
                                        onTogglePendingReviewView:
                                            _togglePendingReviewView,
                                        onSave: () =>
                                            unawaited(_saveNowFromUserAction()),
                                        onExport: () =>
                                            unawaited(_openExportMenu()),
                                        onSmokeTest: () => unawaited(
                                            _runAttachmentSmokeTest()),
                                        onCompute: _engineBusy
                                            ? null
                                            : () => unawaited(_computeEngine()),
                                        onBatch: () =>
                                            unawaited(_openBatchActionsSheet()),
                                        onGps: () =>
                                            unawaited(_runGpsForSelection()),
                                        onPhoto: () =>
                                            unawaited(_runPhotoForSelection()),
                                        onVideo: () =>
                                            unawaited(_runVideoForSelection()),
                                        onAudio: () =>
                                            unawaited(_runAudioForSelection()),
                                        onFile: () =>
                                            unawaited(_runFileForSelection()),
                                        onAttachments: () => unawaited(
                                          _runOpenAttachmentsForSelection(),
                                        ),
                                        onShare: () => unawaited(
                                            _exportZipBundle(share: true)),
                                        onCollaborate: () => unawaited(
                                            _openCollaborateFlowDialog()),
                                        onPalette: () =>
                                            unawaited(_openCommandPalette()),
                                        onGpsMode: () =>
                                            unawaited(_showGpsModePicker()),
                                        onDensity: () =>
                                            unawaited(_showDensityPicker()),
                                        onOpenOfflineQueue:
                                            _openOfflineQueueDialog,
                                        lastLocalSavedAt: _lastSavedAt,
                                        sensorsEnabled: sensorsEnabled,
                                        selectedRow: _selRow,
                                        selectedCol: _selCol,
                                        selectedRowsCount: _selectedRows.length,
                                        pendingOfflineCount:
                                            _pendingOfflineCount,
                                        outboxPendingCount: _outboxQueuedCount,
                                        outboxErrorCount: _outboxErrorCount,
                                        errorsCount: _invalidCells.length,
                                        dataQualityLabel:
                                            _sheetQualityHeaderLabel,
                                        dataQualityDetail:
                                            _sheetQualityHeaderDetail,
                                        savedViews: _savedViews,
                                        activeViewId: _activeSavedViewId,
                                        pendingReviewViewActive:
                                            _reviewFilterMode ==
                                                _ReviewFilterMode.pending,
                                      ),
                                    ))
                            else
                              AnimatedCrossFade(
                                duration: AppMotion.quick,
                                firstCurve: AppMotion.standardOut,
                                secondCurve: AppMotion.standardIn,
                                sizeCurve: AppMotion.standardOut,
                                crossFadeState: _zenModeEnabled ||
                                        autoCollapsedTopChrome ||
                                        (_mobileCompactModeEnabled &&
                                            _mobileTopBarCollapsed)
                                    ? CrossFadeState.showSecond
                                    : CrossFadeState.showFirst,
                                firstChild: RepaintBoundary(
                                  child: _MobileCompactHeader(
                                    palette: pal,
                                    title: _sheetName,
                                    controller: _controller,
                                    pendingRequired: _invalidCells.length,
                                    pendingOfflineCount: _pendingOfflineCount,
                                    outboxPendingCount: _outboxQueuedCount,
                                    outboxErrorCount: _outboxErrorCount,
                                    dataQualityLabel: _sheetQualityHeaderLabel,
                                    dataQualityDetail:
                                        _sheetQualityHeaderDetail,
                                    selectedRow: _selRow,
                                    selectedCol: _selCol,
                                    onSave: () =>
                                        unawaited(_saveNowFromUserAction()),
                                    onExport: () =>
                                        unawaited(_openExportMenu()),
                                    onMenu: () =>
                                        _openMobileHeaderMenu(context, pal),
                                    onOpenOfflineQueue: _openOfflineQueueDialog,
                                    lastLocalSavedAt: _lastSavedAt,
                                  ),
                                ),
                                secondChild: RepaintBoundary(
                                  child: _MobileHeaderCollapsedPill(
                                    palette: pal,
                                    title: _sheetName,
                                    selectedRow: _selRow,
                                    selectedCol: _selCol,
                                    onMenu: () =>
                                        _openMobileHeaderMenu(context, pal),
                                  ),
                                ),
                              ),
                            if (!collapseNonCriticalTopChrome &&
                                _zenModeEnabled)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _InlineMetaChip(
                                    palette: pal,
                                    icon: Icons.visibility_rounded,
                                    label: 'Modo Zen activo | Mostrar barra',
                                    onTap: () => unawaited(_setZenMode(false)),
                                  ),
                                ),
                              ),
                            if (!collapseNonCriticalTopChrome &&
                                _isInAppBrowser)
                              _warningBanner(
                                pal,
                                text:
                                    'Estas usando un navegador embebido. Abri en Safari/Chrome para GPS, camara y microfono.',
                                icon: Icons.open_in_new_rounded,
                              ),
                            if (!collapseNonCriticalTopChrome &&
                                !_isSecureContext)
                              _warningBanner(
                                pal,
                                text:
                                    'Para GPS, camara y audio necesitas HTTPS o localhost. Abri esta pagina en Safari/Chrome.',
                                icon: Icons.lock_outline_rounded,
                              ),
                            if (!collapseNonCriticalTopChrome &&
                                _storageOk == false)
                              _warningBanner(
                                pal,
                                text:
                                    "Guardado temporal de adjuntos: ${_storageMessage ?? 'sin persistencia'}. Export\u00e1 ZIP para no perder evidencias.",
                                icon: Icons.warning_amber_rounded,
                                actionLabel: 'Exportar ZIP',
                                onAction: () =>
                                    unawaited(_exportZipBundle(share: false)),
                              ),
                            if (!collapseNonCriticalTopChrome &&
                                _recoveryBannerVisible &&
                                _recoveryStagingRaw != null)
                              _warningBanner(
                                pal,
                                text:
                                    'Se detecto una sesion previa sin flush completo. Puedes restaurar el estado local anterior.',
                                icon: Icons.history_rounded,
                                actionLabel: 'Restaurar',
                                onAction: () =>
                                    unawaited(_restoreStagingRecovery()),
                                onDismiss: () => unawaited(
                                  _dismissRecoveryBanner(dropCandidate: false),
                                ),
                              ),
                            if (!collapseNonCriticalTopChrome &&
                                _shouldShowAndroidInstallHelper)
                              _warningBanner(
                                pal,
                                text:
                                    'Instalar en Android/Chrome: menu del navegador -> Instalar aplicacion o Agregar a pantalla principal.',
                                icon: Icons.download_for_offline_rounded,
                                actionLabel: 'No mostrar mas',
                                onAction: () => unawaited(
                                  _dismissAndroidInstallHelperForever(),
                                ),
                                onDismiss: _ackAndroidInstallHelper,
                              ),
                            if (!collapseNonCriticalTopChrome &&
                                _pendingOfflineCount > 0)
                              _warningBanner(
                                pal,
                                text: _isNetworkOnline()
                                    ? 'Pendiente de sync: $_pendingOfflineCount item(s).'
                                    : 'Pendiente de sync: $_pendingOfflineCount item(s) (sin conexion).',
                                icon: _isNetworkOnline()
                                    ? Icons.cloud_upload_outlined
                                    : Icons.cloud_off_outlined,
                                actionLabel:
                                    _isNetworkOnline() ? 'Sincronizar' : 'Cola',
                                onAction: _isNetworkOnline()
                                    ? () => unawaited(
                                          _syncQuickCaptureQueue(notify: true),
                                        )
                                    : _openOfflineQueueDialog,
                              ),
                            if (!collapseNonCriticalTopChrome &&
                                _invalidCells.isNotEmpty)
                              _warningBanner(
                                pal,
                                text:
                                    'Validacion: ${_invalidCells.length} celda(s) con error.',
                                icon: Icons.rule_rounded,
                                actionLabel: _errorsPanelOpen
                                    ? 'Ocultar errores'
                                    : 'Ver errores',
                                onAction: () {
                                  setState(
                                    () => _errorsPanelOpen = !_errorsPanelOpen,
                                  );
                                },
                              ),
                            AnimatedSwitcher(
                              duration: AppMotion.medium,
                              switchInCurve: AppMotion.springOut,
                              switchOutCurve: AppMotion.standardIn,
                              transitionBuilder: (child, animation) {
                                return AppMotion.fadeSlide(
                                  animation: animation,
                                  begin: const Offset(0, -0.03),
                                  child: child,
                                );
                              },
                              child: canShowEditorTour
                                  ? KeyedSubtree(
                                      key: const ValueKey('editor-tour-open'),
                                      child: _EditorFirstRunTourBanner(
                                        palette: pal,
                                        onAcknowledge: () => unawaited(
                                          _closeEditorTour(
                                              dontShowAgain: false),
                                        ),
                                        onDismissForever: () => unawaited(
                                          _closeEditorTour(dontShowAgain: true),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('editor-tour-closed'),
                                    ),
                            ),
                            AnimatedSwitcher(
                              duration: AppMotion.quick,
                              switchInCurve: AppMotion.springOut,
                              switchOutCurve: AppMotion.standardIn,
                              transitionBuilder: (child, animation) {
                                return AppMotion.fadeSlide(
                                  animation: animation,
                                  begin: const Offset(0, -0.03),
                                  child: child,
                                );
                              },
                              child: (!collapseNonCriticalTopChrome &&
                                      _errorsPanelOpen &&
                                      _invalidCells.isNotEmpty)
                                  ? KeyedSubtree(
                                      key: const ValueKey(
                                        'validation-errors-open',
                                      ),
                                      child: _ValidationErrorsPanel(
                                        palette: pal,
                                        issues: _validationIssues(),
                                        onJump: _jumpToValidationIssue,
                                        onClose: () {
                                          setState(
                                            () => _errorsPanelOpen = false,
                                          );
                                        },
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('validation-errors-closed'),
                                    ),
                            ),
                            if (!collapseNonCriticalTopChrome &&
                                _photoFlowStatus != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: pal.statusBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: pal.border,
                                    width: pal.hairline,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: pal.border.withValues(alpha: 0.22),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _photoFlowStatus!,
                                        style: TextStyle(
                                          color: pal.statusFg,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (_photoFlowTarget != null)
                                      TextButton(
                                        onPressed: _photoFlowActive
                                            ? null
                                            : () async {
                                                final picked =
                                                    await _pickPhotoTargetDialog();
                                                if (!mounted) return;
                                                if (picked == null) return;
                                                final ref = _cellRefAt(
                                                  picked.row,
                                                  picked.col,
                                                );
                                                if (ref == null) return;
                                                _setSelectionAndRefreshGrid(
                                                  picked.row,
                                                  picked.col,
                                                );
                                                _updatePhotoFlowStatus(
                                                  'Destino ${_cellLabelForRef(ref)} - listo',
                                                  target: ref,
                                                );
                                              },
                                        child: const Text('Cambiar'),
                                      ),
                                  ],
                                ),
                              ),
                            AnimatedSwitcher(
                              duration: AppMotion.quick,
                              switchInCurve: AppMotion.springOut,
                              switchOutCurve: AppMotion.standardIn,
                              transitionBuilder: (child, animation) {
                                return AppMotion.fadeSlide(
                                  animation: animation,
                                  begin: const Offset(0, 0.08),
                                  curve: AppMotion.springOut,
                                  child: child,
                                );
                              },
                              child: _inlineSearchOpen
                                  ? KeyedSubtree(
                                      key: const ValueKey('inline-search-open'),
                                      child: _InlineSearchBar(
                                        palette: pal,
                                        controller: _inlineSearchEC,
                                        focusNode: _inlineSearchFocus,
                                        totalHits: _searchMatches.length,
                                        activeIndex: _searchMatchIndex < 0
                                            ? 0
                                            : _searchMatchIndex,
                                        scope: _inlineSearchScope,
                                        onScopeChanged: _setInlineSearchScope,
                                        onChanged: _onInlineSearchChanged,
                                        onPrev: () => _goToSearchHitDelta(-1),
                                        onNext: () => _goToSearchHitDelta(1),
                                        onClose: () => _closeInlineSearch(),
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('inline-search-closed'),
                                    ),
                            ),
                            AnimatedSwitcher(
                              duration: AppMotion.quick,
                              switchInCurve: AppMotion.springOut,
                              switchOutCurve: AppMotion.standardIn,
                              transitionBuilder: (child, animation) {
                                return AppMotion.fadeSlide(
                                  animation: animation,
                                  begin: const Offset(0, 0.08),
                                  curve: AppMotion.springOut,
                                  child: child,
                                );
                              },
                              child: showSelectionQuickActions
                                  ? KeyedSubtree(
                                      key: const ValueKey(
                                        'selection-quick-actions-open',
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _SelectionQuickActionsBar(
                                            palette: pal,
                                            selectionLabel:
                                                _selectionLabelForQuickActions(),
                                            selectedRowsCount:
                                                _batchTargetRows().length,
                                            canMarkStatus:
                                                canMarkSelectionStatus,
                                            onApplyValue: () => unawaited(
                                                _promptBatchApplyValue()),
                                            onFillDown: () => unawaited(
                                              _promptFillDown(
                                                context,
                                                _selRow,
                                                _selCol,
                                              ),
                                            ),
                                            onDuplicateRows:
                                                _duplicateSelectedRows,
                                            onAttachPhoto: () => unawaited(
                                              _startPhotoFlowForCell(
                                                _selRow,
                                                _selCol,
                                              ),
                                            ),
                                            onAttachGps: () => unawaited(
                                              _requestGpsForCell(
                                                _selRow,
                                                _selCol,
                                              ),
                                            ),
                                            onJumpTo: () =>
                                                unawaited(_openJumpToDialog()),
                                            onMarkStatus: (value) => unawaited(
                                              _applyStatusToSelectedRows(value),
                                            ),
                                          ),
                                          if (inlineFlowBotActions.isNotEmpty)
                                            _FlowBotInlineQuickBar(
                                              palette: pal,
                                              actions: inlineFlowBotActions,
                                              onRun: (action) => unawaited(
                                                _runInlineFlowBotQuickAction(
                                                  context,
                                                  action,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey(
                                        'selection-quick-actions-closed',
                                      ),
                                    ),
                            ),
                            if (isDesktop && _smokeStatus != null)
                              _StatusBar(
                                text: _smokeStatus!,
                                bg: _smokeBg(pal),
                                fg: _smokeFg(pal),
                              ),
                            if (isDesktop &&
                                !_suppressEngineUnavailableUx &&
                                _engineStatus != null)
                              _StatusBar(
                                text: _engineStatus!,
                                bg: _engineStatusIsError
                                    ? _errorBg(pal)
                                    : pal.statusBg,
                                fg: _engineStatusIsError
                                    ? _errorFg(pal)
                                    : pal.statusFg,
                                actionLabel: _engineFallbackMode
                                    ? (_engineHealthCheckInFlight
                                        ? 'Verificando...'
                                        : 'Reintentar')
                                    : null,
                                onAction: _engineFallbackMode &&
                                        !_engineHealthCheckInFlight
                                    ? () => unawaited(_retryEngineConnection())
                                    : null,
                              ),
                            Expanded(
                              child: showPremiumEmptyState
                                  ? Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        0,
                                        12,
                                        8,
                                      ),
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: SingleChildScrollView(
                                          child: _EditorPremiumEmptyStatePanel(
                                            palette: pal,
                                            onNewRecord: () => unawaited(
                                              _createNewRecordAction(
                                                origin: 'empty_state',
                                              ),
                                            ),
                                            onSmartPaste: () => unawaited(
                                              _pasteTableSmartFromClipboard(
                                                emitFeedback: true,
                                                interactivePreview: true,
                                              ),
                                            ),
                                            onUseTemplate: () => unawaited(
                                                _openDemoTemplateSheet()),
                                          ),
                                        ),
                                      ),
                                    )
                                  : isDesktop
                                      ? Focus(
                                          autofocus: true,
                                          onKeyEvent: _onKeyEvent,
                                          child: FocusTraversalOrder(
                                            order: const NumericFocusOrder(2.0),
                                            child: Semantics(
                                              key: const ValueKey(
                                                'editor-grid-root',
                                              ),
                                              container: true,
                                              label: 'Grilla de planilla',
                                              child: RepaintBoundary(
                                                child:
                                                    ValueListenableBuilder<int>(
                                                  valueListenable: _gridVersion,
                                                  builder: (ctx, _, __) {
                                                    _trackGridHostBuild(
                                                        'desktop');
                                                    return _GridView(
                                                      palette: pal,
                                                      metrics: metrics,
                                                      headers: displayHeaders,
                                                      rowModels:
                                                          visibleRowModels,
                                                      cellTextAt: (r, c) {
                                                        final actualRow =
                                                            _actualRowFromDisplay(
                                                          r,
                                                          visibleRows,
                                                        );
                                                        final actualCol =
                                                            _actualColumnFromDisplay(
                                                          c,
                                                          displayColumns,
                                                        );
                                                        return _displayCellValue(
                                                          actualRow,
                                                          actualCol,
                                                        );
                                                      },
                                                      cellHasGps: (r, c) {
                                                        final actualRow =
                                                            _actualRowFromDisplay(
                                                          r,
                                                          visibleRows,
                                                        );
                                                        final actualCol =
                                                            _actualColumnFromDisplay(
                                                          c,
                                                          displayColumns,
                                                        );
                                                        return _cellHasGps(
                                                          actualRow,
                                                          actualCol,
                                                        );
                                                      },
                                                      cellHasAudios: (r, c) {
                                                        final actualRow =
                                                            _actualRowFromDisplay(
                                                          r,
                                                          visibleRows,
                                                        );
                                                        final actualCol =
                                                            _actualColumnFromDisplay(
                                                          c,
                                                          displayColumns,
                                                        );
                                                        return _cellHasAudios(
                                                          actualRow,
                                                          actualCol,
                                                        );
                                                      },
                                                      cellPhotoThumb: (r, c) {
                                                        final actualRow =
                                                            _actualRowFromDisplay(
                                                          r,
                                                          visibleRows,
                                                        );
                                                        final actualCol =
                                                            _actualColumnFromDisplay(
                                                          c,
                                                          displayColumns,
                                                        );
                                                        return _cellPhotoThumb(
                                                          actualRow,
                                                          actualCol,
                                                        );
                                                      },
                                                      cellPhotoCount: (r, c) {
                                                        final actualRow =
                                                            _actualRowFromDisplay(
                                                          r,
                                                          visibleRows,
                                                        );
                                                        final actualCol =
                                                            _actualColumnFromDisplay(
                                                          c,
                                                          displayColumns,
                                                        );
                                                        return _cellPhotoCount(
                                                          actualRow,
                                                          actualCol,
                                                        );
                                                      },
                                                      cellInlinePreviewAt:
                                                          (r, c) {
                                                        final actualRow =
                                                            _actualRowFromDisplay(
                                                          r,
                                                          visibleRows,
                                                        );
                                                        final actualCol =
                                                            _actualColumnFromDisplay(
                                                          c,
                                                          displayColumns,
                                                        );
                                                        return _cellInlinePreviewAt(
                                                          actualRow,
                                                          actualCol,
                                                        );
                                                      },
                                                      columnWrapLines: (c) {
                                                        final actualCol =
                                                            _actualColumnFromDisplay(
                                                          c,
                                                          displayColumns,
                                                        );
                                                        return _colWrapLines(
                                                          actualCol,
                                                        );
                                                      },
                                                      columnTextAlign: (c) {
                                                        final actualCol =
                                                            _actualColumnFromDisplay(
                                                          c,
                                                          displayColumns,
                                                        );
                                                        return _colTextAlign(
                                                          actualCol,
                                                        );
                                                      },
                                                      columnVerticalAlign: (c) {
                                                        final actualCol =
                                                            _actualColumnFromDisplay(
                                                          c,
                                                          displayColumns,
                                                        );
                                                        return _colVerticalAlign(
                                                          actualCol,
                                                        );
                                                      },
                                                      isAttachmentProcessing:
                                                          (r, c) {
                                                        final actualRow =
                                                            _actualRowFromDisplay(
                                                          r,
                                                          visibleRows,
                                                        );
                                                        final actualCol =
                                                            _actualColumnFromDisplay(
                                                          c,
                                                          displayColumns,
                                                        );
                                                        return _cellIsAttachmentProcessing(
                                                          actualRow,
                                                          actualCol,
                                                        );
                                                      },
                                                      decodeThumb:
                                                          _decodeThumbCached,
                                                      isInvalid: (r, c) {
                                                        final actualRow =
                                                            _actualRowFromDisplay(
                                                          r,
                                                          visibleRows,
                                                        );
                                                        final actualCol =
                                                            _actualColumnFromDisplay(
                                                          c,
                                                          displayColumns,
                                                        );
                                                        return _invalidCells
                                                            .contains(
                                                          _CellRef(
                                                            actualRow,
                                                            actualCol,
                                                          ),
                                                        );
                                                      },
                                                      isSearchHit: (r, c) {
                                                        final actualRow =
                                                            _actualRowFromDisplay(
                                                          r,
                                                          visibleRows,
                                                        );
                                                        final actualCol =
                                                            _actualColumnFromDisplay(
                                                          c,
                                                          displayColumns,
                                                        );
                                                        return _isSearchHit(
                                                          actualRow,
                                                          actualCol,
                                                        );
                                                      },
                                                      vScroll: _vScroll,
                                                      hScroll: _hScroll,
                                                      selRow:
                                                          selectedDisplayRow,
                                                      selCol:
                                                          selectedDisplayCol,
                                                      selectedRows:
                                                          selectedDisplayRows,
                                                      blink: _blinkCell,
                                                      editorLink: _editorLink,
                                                      overlayTargetCell:
                                                          _overlayTargetCell ==
                                                                  null
                                                              ? null
                                                              : _CellRef(
                                                                  _overlayTargetCell!
                                                                      .r,
                                                                  _displayColumnIndexForActual(
                                                                    _overlayTargetCell!
                                                                        .c,
                                                                    displayColumns,
                                                                  ),
                                                                ),
                                                      overlayTargetHeaderCol:
                                                          _overlayTargetHeaderCol ==
                                                                  null
                                                              ? null
                                                              : _displayColumnIndexForActual(
                                                                  _overlayTargetHeaderCol!,
                                                                  displayColumns,
                                                                ),
                                                      onSelect: (r, c) {
                                                        final actualRow =
                                                            _actualRowFromDisplay(
                                                          r,
                                                          visibleRows,
                                                        );
                                                        final actualCol =
                                                            _actualColumnFromDisplay(
                                                          c,
                                                          displayColumns,
                                                        );
                                                        _setSelectionAndRefreshGrid(
                                                          actualRow,
                                                          actualCol,
                                                          blink: true,
                                                        );
                                                      },
                                                      onRowIndexTap: (r) =>
                                                          _handleRowIndexTap(
                                                        _actualRowFromDisplay(
                                                          r,
                                                          visibleRows,
                                                        ),
                                                      ),
                                                      onEditRequested:
                                                          (r, c, w) {
                                                        final actualRow =
                                                            _actualRowFromDisplay(
                                                          r,
                                                          visibleRows,
                                                        );
                                                        final actualCol =
                                                            _actualColumnFromDisplay(
                                                          c,
                                                          displayColumns,
                                                        );
                                                        return _beginEditCell(
                                                          context,
                                                          pal,
                                                          actualRow,
                                                          actualCol,
                                                          w,
                                                        );
                                                      },
                                                      onHeaderEditRequested:
                                                          (c, w) {
                                                        final actualCol =
                                                            _actualColumnFromDisplay(
                                                          c,
                                                          displayColumns,
                                                        );
                                                        return _beginEditHeader(
                                                          context,
                                                          pal,
                                                          actualCol,
                                                          w,
                                                        );
                                                      },
                                                      onContextMenu: (pos, r, c,
                                                          isHeader) {
                                                        final actualRow = isHeader
                                                            ? r
                                                            : _actualRowFromDisplay(
                                                                r,
                                                                visibleRows,
                                                              );
                                                        final actualCol =
                                                            _actualColumnFromDisplay(
                                                          c,
                                                          displayColumns,
                                                        );
                                                        unawaited(
                                                          _openContextMenu(
                                                            context,
                                                            pal,
                                                            pos,
                                                            actualRow,
                                                            actualCol,
                                                            isHeader,
                                                          ),
                                                        );
                                                      },
                                                      onDeleteRow: (r) =>
                                                          _deleteRow(
                                                        _actualRowFromDisplay(
                                                          r,
                                                          visibleRows,
                                                        ),
                                                      ),
                                                      onPickPhoto: (r) =>
                                                          _startPhotoFlowForCell(
                                                        _actualRowFromDisplay(
                                                          r,
                                                          visibleRows,
                                                        ),
                                                        _headers.length - 1,
                                                      ),
                                                      onOpenAttachments: (r,
                                                              c) =>
                                                          _openAttachmentPanelForCell(
                                                        _actualRowFromDisplay(
                                                          r,
                                                          visibleRows,
                                                        ),
                                                        _actualColumnFromDisplay(
                                                          c,
                                                          displayColumns,
                                                        ),
                                                      ),
                                                      rowVersionListenable:
                                                          _rowVersionListenable,
                                                      onRowBuild:
                                                          _trackGridRowBuild,
                                                      onCellBuild:
                                                          _trackGridCellBuild,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : RepaintBoundary(
                                          child: KeyedSubtree(
                                            key: const ValueKey(
                                              'editor-grid-root',
                                            ),
                                            child: ValueListenableBuilder<int>(
                                              valueListenable: _gridVersion,
                                              builder: (ctx, _, __) {
                                                _ensureMobileRowCachesLength();
                                                final cardW =
                                                    _mobileCardWidthForScreen(
                                                  MediaQuery.of(ctx).size.width,
                                                );
                                                _trackGridHostBuild('mobile');
                                                return _MobileNotesGrid(
                                                  palette: pal,
                                                  density: _gridDensity,
                                                  headers: displayHeaders,
                                                  rowModels: visibleRowModels,
                                                  cellTextAt: (r, c) {
                                                    final actualRow =
                                                        _actualRowFromDisplay(
                                                      r,
                                                      visibleRows,
                                                    );
                                                    final actualCol =
                                                        _actualColumnFromDisplay(
                                                      c,
                                                      displayColumns,
                                                    );
                                                    return _displayCellValue(
                                                      actualRow,
                                                      actualCol,
                                                    );
                                                  },
                                                  cellHasGps: (r, c) {
                                                    final actualRow =
                                                        _actualRowFromDisplay(
                                                      r,
                                                      visibleRows,
                                                    );
                                                    final actualCol =
                                                        _actualColumnFromDisplay(
                                                      c,
                                                      displayColumns,
                                                    );
                                                    return _cellHasGps(
                                                      actualRow,
                                                      actualCol,
                                                    );
                                                  },
                                                  cellHasAudios: (r, c) {
                                                    final actualRow =
                                                        _actualRowFromDisplay(
                                                      r,
                                                      visibleRows,
                                                    );
                                                    final actualCol =
                                                        _actualColumnFromDisplay(
                                                      c,
                                                      displayColumns,
                                                    );
                                                    return _cellHasAudios(
                                                      actualRow,
                                                      actualCol,
                                                    );
                                                  },
                                                  cellPhotoThumb: (r, c) {
                                                    final actualRow =
                                                        _actualRowFromDisplay(
                                                      r,
                                                      visibleRows,
                                                    );
                                                    final actualCol =
                                                        _actualColumnFromDisplay(
                                                      c,
                                                      displayColumns,
                                                    );
                                                    return _cellPhotoThumb(
                                                      actualRow,
                                                      actualCol,
                                                    );
                                                  },
                                                  cellPhotoCount: (r, c) {
                                                    final actualRow =
                                                        _actualRowFromDisplay(
                                                      r,
                                                      visibleRows,
                                                    );
                                                    final actualCol =
                                                        _actualColumnFromDisplay(
                                                      c,
                                                      displayColumns,
                                                    );
                                                    return _cellPhotoCount(
                                                      actualRow,
                                                      actualCol,
                                                    );
                                                  },
                                                  cellInlinePreviewAt: (r, c) {
                                                    final actualRow =
                                                        _actualRowFromDisplay(
                                                      r,
                                                      visibleRows,
                                                    );
                                                    final actualCol =
                                                        _actualColumnFromDisplay(
                                                      c,
                                                      displayColumns,
                                                    );
                                                    return _cellInlinePreviewAt(
                                                      actualRow,
                                                      actualCol,
                                                    );
                                                  },
                                                  columnWrapLines: (c) {
                                                    final actualCol =
                                                        _actualColumnFromDisplay(
                                                      c,
                                                      displayColumns,
                                                    );
                                                    return _colWrapLines(
                                                        actualCol);
                                                  },
                                                  columnTextAlign: (c) {
                                                    final actualCol =
                                                        _actualColumnFromDisplay(
                                                      c,
                                                      displayColumns,
                                                    );
                                                    return _colTextAlign(
                                                        actualCol);
                                                  },
                                                  columnVerticalAlign: (c) {
                                                    final actualCol =
                                                        _actualColumnFromDisplay(
                                                      c,
                                                      displayColumns,
                                                    );
                                                    return _colVerticalAlign(
                                                        actualCol);
                                                  },
                                                  isAttachmentProcessing:
                                                      (r, c) {
                                                    final actualRow =
                                                        _actualRowFromDisplay(
                                                      r,
                                                      visibleRows,
                                                    );
                                                    final actualCol =
                                                        _actualColumnFromDisplay(
                                                      c,
                                                      displayColumns,
                                                    );
                                                    return _cellIsAttachmentProcessing(
                                                      actualRow,
                                                      actualCol,
                                                    );
                                                  },
                                                  decodeThumb:
                                                      _decodeThumbCached,
                                                  verticalController: _vScroll,
                                                  headerScrollController:
                                                      _mobileHeaderScroll,
                                                  rowScrollControllerFor:
                                                      _mobileRowScrollAt,
                                                  headerKey: _mobileHeaderKey,
                                                  rowKeyFor: _mobileRowKeyAt,
                                                  selectedRow:
                                                      selectedDisplayRow,
                                                  selectedCol:
                                                      selectedDisplayCol,
                                                  activeRow: _mobileEditorOpen &&
                                                          !_mobileEditingHeader
                                                      ? _displayRowForActual(
                                                          _mobileRow,
                                                          visibleRows,
                                                        )
                                                      : -1,
                                                  activeCol: _mobileEditorOpen
                                                      ? _displayColumnIndexForActual(
                                                          _mobileCol,
                                                          displayColumns,
                                                        )
                                                      : -1,
                                                  activeIsHeader:
                                                      _mobileEditorOpen &&
                                                          _mobileEditingHeader,
                                                  activeController: _mobileEC,
                                                  overlayBottomInset:
                                                      mobileGridBottomInset,
                                                  onHorizontalScroll:
                                                      _syncMobileHorizontal,
                                                  onCellTap: (cellCtx, r, c) =>
                                                      _beginEditCell(
                                                    cellCtx,
                                                    pal,
                                                    _actualRowFromDisplay(
                                                      r,
                                                      visibleRows,
                                                    ),
                                                    _actualColumnFromDisplay(
                                                      c,
                                                      displayColumns,
                                                    ),
                                                    cardW,
                                                  ),
                                                  onHeaderTap: (cellCtx, c) =>
                                                      _beginEditHeader(
                                                    cellCtx,
                                                    pal,
                                                    _actualColumnFromDisplay(
                                                      c,
                                                      displayColumns,
                                                    ),
                                                    cardW,
                                                  ),
                                                  onContextMenu:
                                                      (pos, r, c, isHeader) =>
                                                          _openContextMenu(
                                                    ctx,
                                                    pal,
                                                    pos,
                                                    isHeader
                                                        ? r
                                                        : _actualRowFromDisplay(
                                                            r,
                                                            visibleRows,
                                                          ),
                                                    _actualColumnFromDisplay(
                                                      c,
                                                      displayColumns,
                                                    ),
                                                    isHeader,
                                                  ),
                                                  onDeleteRow: (r) =>
                                                      _deleteRow(
                                                    _actualRowFromDisplay(
                                                      r,
                                                      visibleRows,
                                                    ),
                                                  ),
                                                  onPickPhoto: (r) =>
                                                      _startPhotoFlowForCell(
                                                    _actualRowFromDisplay(
                                                      r,
                                                      visibleRows,
                                                    ),
                                                    _headers.length - 1,
                                                  ),
                                                  onOpenAttachments: (r, c) =>
                                                      _openAttachmentPanelForCell(
                                                    _actualRowFromDisplay(
                                                      r,
                                                      visibleRows,
                                                    ),
                                                    _actualColumnFromDisplay(
                                                      c,
                                                      displayColumns,
                                                    ),
                                                  ),
                                                  onVerticalUserScroll:
                                                      _handleMobileGridScrollDirection,
                                                  onRowBuild:
                                                      _trackGridRowBuild,
                                                  onCellBuild:
                                                      _trackGridCellBuild,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                            ),
                          ],
                        ),
                      ),

                      // ??? SIEMPRE montado (iPhone estable). Solo se anima/inhabilita.
                      if (!isDesktop)
                        _MobileInlineEditorBar(
                          palette: pal,
                          density: _gridDensity,
                          barKey: _mobileBarKey,
                          fieldKey: _mobileFieldKey,
                          keyboardInset: keyboardInset,
                          bottomAnimationDuration: mobileBarBottomAnim,
                          isOpen: _mobileEditorOpen,
                          title: _mobileTitle,
                          validationHint: _mobileValidationHint,
                          controller: _mobileEC,
                          focusNode: _mobileFocus,
                          actions: _mobileActions,
                          panelHeight: panelH,
                          isExpanded: _mobileEditorExpanded,
                          canCopyPaste:
                              _mobileEditorOpen && !_mobileEditingHeader,
                          onGpsRow: _canMobileGps
                              ? () => unawaited(_captureGpsForRow(_mobileRow))
                              : null,
                          onPrev: _canMobileNav ? _mobileMovePrev : null,
                          onNext: _canMobileNav ? _mobileMoveNext : null,
                          onCopy: _copyActiveMobileCell,
                          onPaste: _pasteIntoActiveMobileCell,
                          onOverflow: _openMobileOverflowSheet,
                          onToggleExpanded: _toggleMobileEditorExpanded,
                          onCancel: _cancelMobileEdit,
                          onDone: _commitMobileEdit,
                        ),
                      if (!isDesktop)
                        _MobileExpandableFabMenu(
                          palette: pal,
                          isOpen: !hideMobileFab && _mobileFabMenuOpen,
                          hidden: hideMobileFab,
                          forceReducedMotion: _fieldModeEnabled,
                          bottomOffset: _mobileEditorOpen
                              ? (panelH + keyboardInset + 10)
                              : (bottomSafe + 12),
                          onMainTap: () {
                            AppHaptics.light();
                            if (hideMobileFab) return;
                            setState(
                              () => _mobileFabMenuOpen = !_mobileFabMenuOpen,
                            );
                          },
                          onDismiss: () {
                            if (!_mobileFabMenuOpen) return;
                            setState(() => _mobileFabMenuOpen = false);
                          },
                          actions: _fieldModeEnabled
                              ? [
                                  _MobileFabAction(
                                    key: const ValueKey(
                                        'mobile-fab-action-new-record'),
                                    icon: Icons.add_box_outlined,
                                    label: 'Nuevo registro',
                                    onTap: () => unawaited(
                                      _createNewRecordAction(
                                          origin: 'mobile_fab'),
                                    ),
                                  ),
                                  _MobileFabAction(
                                    key: const ValueKey(
                                        'mobile-fab-action-flowbot'),
                                    icon: Icons.auto_awesome_rounded,
                                    label: 'FlowBot',
                                    onTap: () => unawaited(_openFlowBotSheet()),
                                  ),
                                  _MobileFabAction(
                                    key: const ValueKey(
                                        'mobile-fab-action-smart-paste'),
                                    icon: Icons.table_chart_rounded,
                                    label: 'Pegar tabla',
                                    onTap: () => unawaited(
                                      _pasteTableSmartFromClipboard(
                                        emitFeedback: true,
                                        interactivePreview: true,
                                      ),
                                    ),
                                  ),
                                  _MobileFabAction(
                                    key: const ValueKey(
                                        'mobile-fab-action-field-mode'),
                                    icon: Icons.terrain_rounded,
                                    label: 'Salir modo campo',
                                    onTap: () => unawaited(_toggleFieldMode()),
                                  ),
                                ]
                              : [
                                  _MobileFabAction(
                                    key: const ValueKey(
                                        'mobile-fab-action-new-record'),
                                    icon: Icons.add_box_outlined,
                                    label: 'Nuevo registro',
                                    onTap: () => unawaited(
                                      _createNewRecordAction(
                                          origin: 'mobile_fab'),
                                    ),
                                  ),
                                  _MobileFabAction(
                                    key: const ValueKey(
                                      'mobile-fab-action-smart-paste',
                                    ),
                                    icon: Icons.table_chart_rounded,
                                    label: 'Pegar tabla',
                                    onTap: () => unawaited(
                                      _pasteTableSmartFromClipboard(
                                        emitFeedback: true,
                                        interactivePreview: true,
                                      ),
                                    ),
                                  ),
                                  _MobileFabAction(
                                    key: const ValueKey(
                                        'mobile-fab-action-export'),
                                    icon: Icons.ios_share_rounded,
                                    label: 'Exportar',
                                    onTap: () => unawaited(_openExportMenu()),
                                  ),
                                  _MobileFabAction(
                                    key: const ValueKey(
                                        'mobile-fab-action-templates'),
                                    icon: Icons.grid_view_rounded,
                                    label: 'Plantillas',
                                    onTap: () =>
                                        unawaited(_openDemoTemplateSheet()),
                                  ),
                                  _MobileFabAction(
                                    key: const ValueKey(
                                        'mobile-fab-action-undo'),
                                    icon: Icons.undo_rounded,
                                    label: 'Deshacer',
                                    onTap: _undoOnce,
                                  ),
                                  _MobileFabAction(
                                    key: const ValueKey(
                                        'mobile-fab-action-field-mode'),
                                    icon: Icons.landscape_rounded,
                                    label: 'Modo campo',
                                    onTap: () => unawaited(_toggleFieldMode()),
                                  ),
                                ],
                        ),
                      if (_perfHarnessRequested && kDebugMode)
                        _buildPerfOverlay(
                          pal,
                          isDesktop: isDesktop,
                        ),
                      if (_longOperation != null)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .scrim
                                  .withValues(
                                    alpha: pal.isLight ? 0.18 : 0.34,
                                  ),
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 360),
                                child: LoadingState(
                                  message: _longOperation!.message,
                                  onCancel: (_longOperation!.cancellable &&
                                          !_longOperation!.cancelRequested)
                                      ? _requestLongOperationCancel
                                      : null,
                                  cancelLabel: AppStrings.cancel,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------ Teclado Desktop -------------------------
  // Movido a lib/features/editor/actions/editor_shortcuts.dart

  void _moveSel({int dRow = 0, int dCol = 0}) {
    final nr = (_selRow + dRow).clamp(0, _rows.length - 1).toInt();
    var nc = _selCol.clamp(0, math.max(0, _headers.length - 1)).toInt();
    if (dCol != 0) {
      final displayColumns = _displayColumnIndexes();
      if (displayColumns.isNotEmpty) {
        var displayIndex = displayColumns.indexOf(nc);
        if (displayIndex < 0) {
          displayIndex = _displayColumnIndexForActual(nc, displayColumns);
        }
        final nextDisplay =
            (displayIndex + dCol).clamp(0, displayColumns.length - 1).toInt();
        nc = displayColumns[nextDisplay];
      } else {
        nc = (nc + dCol).clamp(0, _headers.length - 1).toInt();
      }
    }
    _setSelectionAndRefreshGrid(nr, nc, blink: true);
  }

  void _moveSelectionFast({required bool forward, required bool vertical}) {
    final editableCols = _visibleDataColumnIndexes();
    if (editableCols.isEmpty || _rows.isEmpty) return;
    var row = _selRow.clamp(0, _rows.length - 1);
    var col = _selCol;
    var colIndex = editableCols.indexOf(col);
    if (colIndex < 0) {
      colIndex = 0;
      col = editableCols.first;
    }

    if (vertical) {
      row += forward ? 1 : -1;
      if (row < 0) return;
      if (row >= _rows.length) {
        _insertRow(_rows.length);
        row = _rows.length - 1;
      }
    } else {
      if (forward) {
        if (colIndex < editableCols.length - 1) {
          colIndex++;
        } else {
          row++;
          colIndex = 0;
        }
      } else {
        if (colIndex > 0) {
          colIndex--;
        } else {
          row--;
          colIndex = editableCols.length - 1;
        }
      }
      if (row < 0) return;
      if (row >= _rows.length) {
        _insertRow(_rows.length);
        row = _rows.length - 1;
      }
      col = editableCols[colIndex];
    }

    _setSelectionAndRefreshGrid(row, col, blink: true);
  }

  // ------------------------------ Edici??n Header --------------------------

  void _beginEditHeader(
    BuildContext context,
    _SheetPalette pal,
    int c,
    double headerWidth,
  ) {
    if (c < 0 || c >= _headers.length) return;
    if (c == _headers.length - 1) return; // Photos no editable

    _removeCellEditor();
    _blink(-1, c);

    final isDesktop = _isDesktopUi(
      context,
      _effectiveKeyboardInset(
        context,
        controllerInset: _kbController.kbInsetDp.value,
      ),
    );
    if (!isDesktop) {
      _openMobileInlineEditor(
        isHeader: true,
        row: -1,
        col: c,
        title: 'Encabezado ${c + 1}',
        initial: _effectiveHeader(c),
        actions: const [],
      );
      return;
    }

    _scheduleOverlayAtHeader(
      col: c,
      width: headerWidth,
      context: context,
      pal: pal,
      initial: _effectiveHeader(c),
      onCommit: (v) {
        _setDraftHeader(c, v);
        _commitDraftHeader(c);
      },
    );
  }

  void _scheduleOverlayAtHeader({
    required int col,
    required double width,
    required BuildContext context,
    required _SheetPalette pal,
    required String initial,
    required ValueChanged<String> onCommit,
  }) {
    setState(() {
      _overlayTargetCell = null;
      _overlayTargetHeaderCol = col;
      _overlayTargetWidth = width;
      _editingCellRef = null;
      _editingHeaderCol = col;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showOverlayEditor(
        context: context,
        pal: pal,
        initial: initial,
        width: width,
        onCommit: onCommit,
      );
    });
  }

  // ------------------------------ Edici??n Celda ---------------------------

  void _beginEditCell(
    BuildContext context,
    _SheetPalette pal,
    int r,
    int c,
    double cellWidth, {
    String? initialOverride,
  }) {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;

    if (_tryConsumePendingGps(r, c)) {
      if (_selRow != r || _selCol != c) {
        _setSelectionAndRefreshGrid(r, c);
      }
      _blink(r, c);
      return;
    }

    if (_selRow != r || _selCol != c) {
      _setSelectionAndRefreshGrid(r, c);
    }

    _removeCellEditor();
    _blink(r, c);

    // Photos => pick
    if (c == _headers.length - 1) {
      _handlePhotosCellTap(r, c);
      return;
    }

    final statusOptions = _statusOptionsForCol(c);
    if (initialOverride == null &&
        statusOptions != null &&
        statusOptions.isNotEmpty) {
      unawaited(_pickStatusForCell(context, pal, r, c, statusOptions));
      return;
    }

    final isDesktop = _isDesktopUi(
      context,
      _effectiveKeyboardInset(
        context,
        controllerInset: _kbController.kbInsetDp.value,
      ),
    );
    if (!isDesktop) {
      _openMobileInlineEditor(
        isHeader: false,
        row: r,
        col: c,
        title: _mobileCellLabel(r, c),
        initial: _effectiveCell(r, c),
        actions: _mobileActionsForCell(r, c),
      );
      return;
    }

    _scheduleOverlayAtCell(
      row: r,
      col: c,
      width: cellWidth,
      context: context,
      pal: pal,
      initial: initialOverride ?? _effectiveCell(r, c),
      onCommit: (v) {
        _setDraftCell(r, c, v);
        _commitDraftCell(r, c);
      },
    );
  }

  void _scheduleOverlayAtCell({
    required int row,
    required int col,
    required double width,
    required BuildContext context,
    required _SheetPalette pal,
    required String initial,
    required ValueChanged<String> onCommit,
  }) {
    final ref = _CellRef(row, col);

    setState(() {
      _setSelection(row, col);
      _overlayTargetCell = ref;
      _overlayTargetHeaderCol = null;
      _overlayTargetWidth = width;
      _editingCellRef = ref;
      _editingHeaderCol = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_overlayTargetCell != ref) return;

      _showOverlayEditor(
        context: context,
        pal: pal,
        initial: initial,
        width: width,
        onCommit: onCommit,
      );
    });
  }

  Future<void> _pickStatusForCell(
    BuildContext context,
    _SheetPalette pal,
    int r,
    int c,
    List<String> options,
  ) async {
    if (options.isEmpty) return;
    final current = _effectiveCell(r, c).trim();
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: pal.menuBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pal.border, width: pal.hairline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune_rounded, color: pal.fg),
                    const SizedBox(width: 8),
                    Text(
                      'Estado',
                      style: TextStyle(
                        color: pal.fg,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: Icon(Icons.close_rounded, color: pal.fgMuted),
                    ),
                  ],
                ),
                for (final option in options)
                  ListTile(
                    leading: Icon(
                      current.toLowerCase() == option.toLowerCase()
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: pal.fgMuted,
                    ),
                    title: Text(option),
                    onTap: () => Navigator.of(ctx).pop(option),
                  ),
                ListTile(
                  leading: Icon(Icons.clear_rounded, color: pal.fgMuted),
                  title: const Text('Limpiar'),
                  onTap: () => Navigator.of(ctx).pop(''),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || picked == null) return;
    _setCell(r, c, picked);
  }

  String _headerLabel(int c) {
    final t = _effectiveHeader(c).trim();
    if (t.isNotEmpty) return t;
    if (c == _headers.length - 1) return kPhotosHeader;
    return 'Col ${c + 1}';
  }

  List<int> _orderedDataColumnIndexes() {
    if (_headers.length <= 1) return const <int>[];
    final dataColIds = <String>[
      for (final id in _colIds)
        if (id != kPhotosColId) id,
    ];
    final normalizedOrder = _normalizeColumnOrder(
      colIds: _colIds,
      incoming: _columnOrder,
    );
    if (!listEquals(normalizedOrder, _columnOrder)) {
      _columnOrder = normalizedOrder;
    }

    final seen = <String>{};
    final orderedIds = <String>[];
    final frozen = _normalizeFrozenColId(
      colIds: _colIds,
      requested: _frozenColId,
    );
    if (frozen != null && seen.add(frozen)) {
      orderedIds.add(frozen);
    }
    for (final id in normalizedOrder) {
      if (!dataColIds.contains(id)) continue;
      if (!seen.add(id)) continue;
      orderedIds.add(id);
    }
    for (final id in dataColIds) {
      if (!seen.add(id)) continue;
      orderedIds.add(id);
    }

    final out = <int>[];
    for (final id in orderedIds) {
      final index = _colIds.indexOf(id);
      if (index < 0 || index >= _headers.length - 1) continue;
      out.add(index);
    }
    return out;
  }

  bool _isColumnHidden(int col) {
    if (col < 0 || col >= _colIds.length) return false;
    final colId = _colIds[col];
    if (colId == kPhotosColId) return false;
    return _columnPrefsById[colId]?.hidden ?? false;
  }

  List<int> _visibleDataColumnIndexes() {
    final ordered = _orderedDataColumnIndexes();
    final visible = <int>[];
    for (final c in ordered) {
      if (_isColumnHidden(c)) continue;
      visible.add(c);
    }
    if (visible.isEmpty && ordered.isNotEmpty) {
      visible.add(ordered.first);
    }
    return visible;
  }

  String _displayColumnsLayoutKey() {
    final dataColCount = math.max(0, _headers.length - 1);
    final sb = StringBuffer()
      ..write(_headers.length)
      ..write('|')
      ..write(_colIds.length)
      ..write('|')
      ..write(_frozenColId ?? '')
      ..write('|');
    if (_columnOrder.isNotEmpty) {
      sb.writeAll(_columnOrder, ',');
    }
    sb.write('|');
    final limit = math.min(_colIds.length, dataColCount);
    for (int i = 0; i < limit; i++) {
      final colId = _colIds[i];
      final pref = _columnPrefsById[colId];
      sb
        ..write(colId)
        ..write(':')
        ..write(pref?.hidden == true ? '1' : '0')
        ..write(':')
        ..write(pref?.type.name ?? '')
        ..write(':')
        ..write(pref?.required == true ? '1' : '0')
        ..write(':')
        ..write((pref?.enumValues ?? const <String>[]).join('~'))
        ..write(';');
    }
    return sb.toString();
  }

  List<int> _displayColumnIndexes() {
    if (_headers.isEmpty) {
      _displayColumnsCacheKey = '';
      _displayColumnsCache = const <int>[];
      _displayIndexByActualCache = const <int, int>{};
      return _displayColumnsCache;
    }
    final nextCacheKey = _displayColumnsLayoutKey();
    if (nextCacheKey == _displayColumnsCacheKey &&
        _displayColumnsCache.isNotEmpty) {
      return _displayColumnsCache;
    }
    final visible = _visibleDataColumnIndexes();
    final photosCol = _headers.length - 1;
    final computed = <int>[...visible, photosCol];
    final indexByActual = <int, int>{};
    for (int i = 0; i < computed.length; i++) {
      indexByActual[computed[i]] = i;
    }
    _displayColumnsCacheKey = nextCacheKey;
    _displayColumnsCache = List<int>.unmodifiable(computed);
    _displayIndexByActualCache = Map<int, int>.unmodifiable(indexByActual);
    return _displayColumnsCache;
  }

  int _displayColumnIndexForActual(int actualCol, List<int> displayColumns) {
    if (displayColumns.isEmpty) return 0;
    final cachedIndex = identical(displayColumns, _displayColumnsCache)
        ? _displayIndexByActualCache[actualCol]
        : null;
    if (cachedIndex != null) return cachedIndex;
    for (int i = 0; i < displayColumns.length; i++) {
      if (displayColumns[i] == actualCol) return i;
    }
    final photosIndex = displayColumns.length - 1;
    if (actualCol >= _headers.length - 1) return photosIndex;
    return 0;
  }

  int _actualColumnFromDisplay(int displayCol, List<int> displayColumns) {
    if (displayColumns.isEmpty) return _selCol;
    final safe = displayCol.clamp(0, displayColumns.length - 1);
    return displayColumns[safe];
  }

  int? _columnIndexFromId(String? colId) {
    if (colId == null || colId.trim().isEmpty) return null;
    final index = _colIds.indexOf(colId.trim());
    if (index < 0 || index >= _headers.length - 1) return null;
    return index;
  }

  int? _firstTextLikeColumn() {
    for (int c = 0; c < _headers.length - 1; c++) {
      switch (_colType(c)) {
        case _ColType.text:
        case _ColType.status:
        case _ColType.number:
        case _ColType.date:
          return c;
        default:
          break;
      }
    }
    return null;
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _rowViewCacheToken() {
    final active = _activeSavedView;
    final activeToken = active == null
        ? ''
        : [
            active.id,
            active.statusColId ?? '',
            active.statusValue ?? '',
            active.textColId ?? '',
            active.textContains ?? '',
            active.dateColId ?? '',
            active.dateFrom?.millisecondsSinceEpoch.toString() ?? '',
            active.dateTo?.millisecondsSinceEpoch.toString() ?? '',
            active.sortColId ?? '',
            active.sortAscending ? '1' : '0',
            active.columnOrder.length.toString(),
            active.columnPrefsById.length.toString(),
            active.frozenColId ?? '',
          ].join('|');
    return 'rev=$_rev|rows=${_rows.length}|view=$activeToken|review=${_reviewFilterMode.name}';
  }

  List<int> _visibleRowIndexes() {
    if (_rows.isEmpty) {
      _invalidateRowViewCache();
      return const <int>[];
    }
    final nextToken = _rowViewCacheToken();
    if (nextToken == _rowViewCacheKey) {
      return _visibleRowIndexesCache;
    }

    final active = _activeSavedView;
    final result = <int>[];
    final statusFilter = (active?.statusValue ?? '').trim();
    final textFilter = (active?.textContains ?? '').trim().toLowerCase();
    final dateFrom = active?.dateFrom;
    final dateTo = active?.dateTo;
    final statusCol = _columnIndexFromId(active?.statusColId) ??
        (statusFilter.isNotEmpty ? _firstColumnByType(_ColType.status) : null);
    final textCol = _columnIndexFromId(active?.textColId) ??
        (textFilter.isNotEmpty ? _firstTextLikeColumn() : null);
    final dateCol = _columnIndexFromId(active?.dateColId) ??
        ((dateFrom != null || dateTo != null)
            ? _firstColumnByType(_ColType.date)
            : null);

    for (int r = 0; r < _rows.length; r++) {
      if (_reviewFilterMode == _ReviewFilterMode.pending && _rows[r].reviewed) {
        continue;
      }
      if (_reviewFilterMode == _ReviewFilterMode.reviewed &&
          !_rows[r].reviewed) {
        continue;
      }
      if (statusCol != null && statusFilter.isNotEmpty) {
        final value = (statusCol < _rows[r].cells.length)
            ? _rows[r].cells[statusCol].trim().toLowerCase()
            : '';
        if (value != statusFilter.toLowerCase()) continue;
      }
      if (textCol != null && textFilter.isNotEmpty) {
        final value = (textCol < _rows[r].cells.length)
            ? _rows[r].cells[textCol].trim().toLowerCase()
            : '';
        if (!value.contains(textFilter)) continue;
      }
      if (dateCol != null && (dateFrom != null || dateTo != null)) {
        final raw =
            (dateCol < _rows[r].cells.length) ? _rows[r].cells[dateCol] : '';
        final parsed = _parseDateCellValue(raw);
        if (parsed == null) continue;
        final dateValue = _dateOnly(parsed);
        if (dateFrom != null && dateValue.isBefore(dateFrom)) continue;
        if (dateTo != null && dateValue.isAfter(dateTo)) continue;
      }
      result.add(r);
    }

    final sortCol = _columnIndexFromId(active?.sortColId);
    if (active != null && sortCol != null) {
      result.sort((left, right) {
        final a = (sortCol < _rows[left].cells.length)
            ? _rows[left].cells[sortCol]
            : '';
        final b = (sortCol < _rows[right].cells.length)
            ? _rows[right].cells[sortCol]
            : '';
        final base = _compareCellValuesForColumn(sortCol, a, b);
        if (base == 0) return left.compareTo(right);
        return active.sortAscending ? base : -base;
      });
    }

    final displayToActual = <int, int>{};
    final actualToDisplay = <int, int>{};
    final visibleRows = <_RowModel>[];
    for (int i = 0; i < result.length; i++) {
      final actual = result[i];
      displayToActual[i] = actual;
      actualToDisplay[actual] = i;
      visibleRows.add(_rows[actual]);
    }

    _rowViewCacheKey = nextToken;
    _visibleRowIndexesCache = List<int>.unmodifiable(result);
    _displayRowToActualCache = Map<int, int>.unmodifiable(displayToActual);
    _actualRowToDisplayCache = Map<int, int>.unmodifiable(actualToDisplay);
    _visibleRowModelsCache = List<_RowModel>.unmodifiable(visibleRows);
    return _visibleRowIndexesCache;
  }

  List<_RowModel> _visibleRowModels() {
    _visibleRowIndexes();
    return _visibleRowModelsCache;
  }

  int _actualRowFromDisplay(int displayRow, List<int> visibleRows) {
    final cached = identical(visibleRows, _visibleRowIndexesCache)
        ? _displayRowToActualCache[displayRow]
        : null;
    if (cached != null) return cached;
    if (displayRow < 0 || displayRow >= visibleRows.length) return _selRow;
    return visibleRows[displayRow];
  }

  int _displayRowForActual(int actualRow, List<int> visibleRows) {
    final cached = identical(visibleRows, _visibleRowIndexesCache)
        ? _actualRowToDisplayCache[actualRow]
        : null;
    if (cached != null) return cached;
    for (int i = 0; i < visibleRows.length; i++) {
      if (visibleRows[i] == actualRow) return i;
    }
    return -1;
  }

  Set<int> _selectedDisplayRows(List<int> visibleRows) {
    final out = <int>{};
    for (final actual in _selectedRows) {
      final display = _displayRowForActual(actual, visibleRows);
      if (display >= 0) out.add(display);
    }
    return out;
  }

  void _applyColumnPrefsAndOrder({
    required Map<String, _ColumnPrefs> columnPrefsById,
    required List<String> columnOrder,
    required String? frozenColId,
    bool snapshot = true,
  }) {
    _columnPrefsById = _normalizeColumnPrefs(
      colIds: _colIds,
      incoming: columnPrefsById,
    );
    _columnOrder = _normalizeColumnOrder(
      colIds: _colIds,
      incoming: columnOrder,
    );
    _frozenColId = _normalizeFrozenColId(
      colIds: _colIds,
      requested: frozenColId,
    );
    final displayColumns = _displayColumnIndexes();
    if (displayColumns.isNotEmpty && !displayColumns.contains(_selCol)) {
      _setSelection(_selRow, displayColumns.first, preserveRowSelection: true);
    }
    _markDirty(snapshot: snapshot);
    _bumpGridVersion();
  }

  void _setColumnTypeForIndex(int col, _ColType type) {
    if (col < 0 || col >= _headers.length - 1) return;
    if (type == _ColType.photos) return;
    final colId = _colIds[col];
    final current = _columnPrefsById[colId];
    if (current != null && current.type == type) return;
    final next = _cloneColumnPrefs(_columnPrefsById);
    final hidden = current?.hidden ?? false;
    next[colId] = _ColumnPrefs(
      type: type,
      hidden: hidden,
      required: current?.required ?? _isRequired(col),
      enumValues: current?.enumValues ?? const <String>[],
      numberMin: current?.numberMin,
      numberMax: current?.numberMax,
      regexPattern: current?.regexPattern,
      wrapLines: current?.wrapLines ?? _defaultWrapLinesForColumn(col),
      textAlign: current?.textAlign ?? _GridTextAlignX.left,
      verticalAlign: current?.verticalAlign ?? _GridTextAlignY.middle,
    );
    _applyColumnPrefsAndOrder(
      columnPrefsById: next,
      columnOrder: _columnOrder,
      frozenColId: _frozenColId,
    );
    _scheduleValidationRecompute(immediate: true);
  }

  void _setColumnHidden(int col, bool hidden) {
    if (col < 0 || col >= _headers.length - 1) return;
    final colId = _colIds[col];
    final current = _columnPrefsById[colId];
    final currentHidden = current?.hidden ?? false;
    if (currentHidden == hidden) return;
    final visibleBefore = _visibleDataColumnIndexes();
    if (hidden && visibleBefore.length <= 1 && visibleBefore.contains(col)) {
      _showActionSnack(
        'Debe quedar al menos una columna visible.',
        isError: false,
        icon: Icons.view_column_rounded,
      );
      return;
    }

    final next = _cloneColumnPrefs(_columnPrefsById);
    final type = current?.type ?? _colType(col);
    next[colId] = _ColumnPrefs(
      type: type,
      hidden: hidden,
      required: current?.required ?? _isRequired(col),
      enumValues: current?.enumValues ?? const <String>[],
      numberMin: current?.numberMin,
      numberMax: current?.numberMax,
      regexPattern: current?.regexPattern,
      wrapLines: current?.wrapLines ?? _defaultWrapLinesForColumn(col),
      textAlign: current?.textAlign ?? _GridTextAlignX.left,
      verticalAlign: current?.verticalAlign ?? _GridTextAlignY.middle,
    );
    final nextFrozen = (_frozenColId == colId && hidden) ? null : _frozenColId;
    _applyColumnPrefsAndOrder(
      columnPrefsById: next,
      columnOrder: _columnOrder,
      frozenColId: nextFrozen,
    );
  }

  void _setFrozenColumnByIndex(int? col) {
    if (col == null || col < 0 || col >= _headers.length - 1) {
      if (_frozenColId == null) return;
      _applyColumnPrefsAndOrder(
        columnPrefsById: _columnPrefsById,
        columnOrder: _columnOrder,
        frozenColId: null,
      );
      return;
    }
    final colId = _colIds[col];
    if (_frozenColId == colId) return;
    final nextPrefs = _cloneColumnPrefs(_columnPrefsById);
    final pref = nextPrefs[colId] ?? _ColumnPrefs(type: _colType(col));
    nextPrefs[colId] = pref.copyWith(hidden: false);
    _applyColumnPrefsAndOrder(
      columnPrefsById: nextPrefs,
      columnOrder: _columnOrder,
      frozenColId: colId,
    );
  }

  void _setColumnPresentationForIndex(
    int col, {
    int? wrapLines,
    _GridTextAlignX? textAlign,
    _GridTextAlignY? verticalAlign,
    bool snapshot = true,
  }) {
    if (col < 0 || col >= _headers.length - 1) return;
    final colId = _colIds[col];
    final current = _columnPrefsById[colId];
    final nextWrap =
        (wrapLines ?? current?.wrapLines ?? _defaultWrapLinesForColumn(col))
            .clamp(1, 3);
    final nextTextAlign =
        textAlign ?? current?.textAlign ?? _GridTextAlignX.left;
    final nextVerticalAlign =
        verticalAlign ?? current?.verticalAlign ?? _GridTextAlignY.middle;
    final nextPrefs = _cloneColumnPrefs(_columnPrefsById);
    nextPrefs[colId] = _ColumnPrefs(
      type: current?.type ?? _colType(col),
      hidden: current?.hidden ?? false,
      required: current?.required ?? _isRequired(col),
      enumValues: current?.enumValues ?? const <String>[],
      numberMin: current?.numberMin,
      numberMax: current?.numberMax,
      regexPattern: current?.regexPattern,
      wrapLines: nextWrap,
      textAlign: nextTextAlign,
      verticalAlign: nextVerticalAlign,
    );
    _applyColumnPrefsAndOrder(
      columnPrefsById: nextPrefs,
      columnOrder: _columnOrder,
      frozenColId: _frozenColId,
      snapshot: snapshot,
    );
  }

  int _compareCellValuesForColumn(int col, String leftRaw, String rightRaw) {
    final type = _colType(col);
    final left = leftRaw.trim();
    final right = rightRaw.trim();
    if (left.isEmpty && right.isEmpty) return 0;
    if (left.isEmpty) return 1;
    if (right.isEmpty) return -1;
    switch (type) {
      case _ColType.number:
        final ln = _parseNumberCellValue(left);
        final rn = _parseNumberCellValue(right);
        if (ln == null && rn == null) return left.compareTo(right);
        if (ln == null) return 1;
        if (rn == null) return -1;
        return ln.compareTo(rn);
      case _ColType.date:
        final ld = _parseDateCellValue(left);
        final rd = _parseDateCellValue(right);
        if (ld == null && rd == null) return left.compareTo(right);
        if (ld == null) return 1;
        if (rd == null) return -1;
        return ld.compareTo(rd);
      case _ColType.checkbox:
        final lb = _parseCheckboxCellValue(left);
        final rb = _parseCheckboxCellValue(right);
        if (lb == null && rb == null) return left.compareTo(right);
        if (lb == null) return 1;
        if (rb == null) return -1;
        return lb == rb ? 0 : (lb ? -1 : 1);
      default:
        return left.toLowerCase().compareTo(right.toLowerCase());
    }
  }

  void _sortRowsByColumn(int col, {required bool ascending}) {
    if (col < 0 || col >= _headers.length - 1) return;
    if (_rows.isEmpty) return;
    final currentSelId =
        (_selRow >= 0 && _selRow < _rows.length) ? _rows[_selRow].id : null;

    _rows.sort((a, b) {
      final av = (col < a.cells.length) ? a.cells[col] : '';
      final bv = (col < b.cells.length) ? b.cells[col] : '';
      final base = _compareCellValuesForColumn(col, av, bv);
      if (base == 0) return a.id.compareTo(b.id);
      return ascending ? base : -base;
    });

    if (currentSelId != null) {
      final nextSel = _rows.indexWhere((row) => row.id == currentSelId);
      if (nextSel >= 0) {
        _setSelection(nextSel, _selCol, preserveRowSelection: false);
      }
    }
    _markDirty(snapshot: true);
    _bumpGridVersion();
  }

  String _mobileCellLabel(int r, int c) {
    final rowLabel = 'Fila ${r + 1}';
    final colLabel = _headerLabel(c);
    return '$rowLabel - $colLabel';
  }

  void _setCell(int r, int c, String value) {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    if (c == _headers.length - 1) return;

    final prev = _rows[r].cells[c];
    final next = _normalizeCellValueForColumn(c, value);
    if (_rows[r].cells[c] == next) return;

    _rows[r].cells[c] = next;
    _pendingFormulaSeeds.add(_CellRef(r, c));
    _bumpRowVersionById(_rows[r].id);
    _rememberValueForColumn(c, next);
    _markDirty(snapshot: true);
    _addHistoryEvent(
      type: 'edit_cell',
      message: 'Editar ${_cellLabelRc(r, c)}',
      origin: 'manual',
      row: r,
      col: c,
      beforeValue: prev,
      afterValue: next,
    );
  }

  // ------------------------- Mobile inline editor -------------------------

  void _commitMobileDraftKeepingKeyboard() {
    if (!_mobileEditorOpen) return;
    final v = _mobileEC.text;

    if (_mobileEditingHeader) {
      final c = _mobileCol;
      if (c >= 0 && c < _headers.length - 1) {
        _setDraftHeader(c, v);
        _commitDraftHeader(c);
      }
      return;
    }

    final r = _mobileRow;
    final c = _mobileCol;
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    if (c == _headers.length - 1) return;
    _setDraftCell(r, c, v);
    _commitDraftCell(r, c);
  }

  // ??? iOS/Web: foco sin async gaps + sin ???invisible input???
  void _openMobileInlineEditor({
    required bool isHeader,
    required int row,
    required int col,
    required String title,
    required String initial,
    required List<_MobileAction> actions,
  }) {
    final wasOpen = _mobileEditorOpen;

    // Si ya estaba abierto: commitea el draft y segu?? (sin cerrar teclado).
    if (wasOpen) {
      _commitMobileDraftKeepingKeyboard();
    }

    _mobileTopBarCollapsed = false;
    _mobileFabMenuOpen = false;
    _mobileEditingHeader = isHeader;
    _mobileRow = row;
    _mobileCol = col;
    _mobileTitle = title;
    _mobileEditorExpanded = false;
    _mobileActions = actions;

    _detachMobileDraftListener();
    _mobileEC.text = initial;
    _mobileEC.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _mobileEC.text.length,
    );
    _attachMobileDraftListener();

    if (!_mobileEditorOpen) {
      setState(() {
        _mobileEditorOpen = true;
        _mobilePhase = _MobileEditPhase.opening;
      });
    } else {
      setState(() => _mobilePhase = _MobileEditPhase.switching);
    }

    _kbController.beginFocusProbe();
    _requestMobileFocusWithRetry();

    if (_mobileFocusCellModeEnabled && (row >= 0 || isHeader)) {
      _scheduleEnsureRowVisiblePostFrame(row);
      _scheduleEnsureRowVisibleLate(row);
    }
  }

  List<_MobileAction> _mobileActionsForCell(int r, int c) {
    if (c == _headers.length - 1) return const [];
    return [
      _MobileAction(
        icon: Icons.schedule_rounded,
        label: 'Ahora',
        onTap: () => _insertNowInCell(r, c),
      ),
      _MobileAction(
        icon: Icons.vertical_align_bottom_rounded,
        label: 'Rellenar',
        onTap: () => _fillDownColumn(r, c, count: _fillDownCount),
      ),
      _MobileAction(
        icon: Icons.exposure_plus_1_rounded,
        label: 'Incrementar',
        onTap: () => _incrementDownColumn(
          r,
          c,
          count: _incrementCount,
          step: _incrementStep,
        ),
      ),
      _MobileAction(
        icon: Icons.calculate_outlined,
        label: 'Calc',
        onTap: () => _applyCalcToCell(r, c),
      ),
      _MobileAction(
        icon: Icons.photo_camera_outlined,
        label: 'Foto',
        onTap: () => _startPhotoFlowForCell(r, c),
      ),
      _MobileAction(
        icon: Icons.videocam_outlined,
        label: 'Video',
        onTap: () => unawaited(_attachVideoForCell(r, c)),
      ),
      _MobileAction(
        icon: Icons.attach_file_rounded,
        label: 'Archivo',
        onTap: () => unawaited(_attachDocumentForCell(r, c)),
      ),
      _MobileAction(
        icon: _audioRecording
            ? Icons.stop_circle_outlined
            : Icons.mic_none_rounded,
        label: _audioRecording ? 'Detener audio' : 'Grabar audio',
        onTap: () {
          if (_audioRecording) {
            unawaited(_stopAudioRecording());
          } else {
            unawaited(_startAudioRecordingForCell(r, c));
          }
        },
      ),
      _MobileAction(
        icon: Icons.my_location_outlined,
        label: 'GPS -> Pegar',
        onTap: () => unawaited(_requestGpsForCell(r, c, forceWriteText: true)),
      ),
      _MobileAction(
        icon: Icons.map_outlined,
        label: 'Mapa',
        onTap: () => unawaited(_openMapsForCell(r, c)),
      ),
    ];
  }

  void _handleMobileFocusChange() {
    if (!_mobileFocus.hasFocus) return;
    if (!_mobileEditorOpen) return;
    if (!_mobileEditingHeader && _mobileRow < 0) return;
    _kbController.beginFocusProbe();
    final targetRow = _mobileEditingHeader ? -1 : _mobileRow;
    _scheduleEnsureRowVisiblePostFrame(targetRow);
    _scheduleEnsureRowVisibleLate(targetRow);
  }

  void _requestMobileFocusWithRetry() {
    if (!_mobileEditorOpen) return;
    _kbController.beginFocusProbe();
    _mobileFocus.requestFocus();
    try {
      SystemChannels.textInput.invokeMethod('TextInput.show');
    } catch (_) {}

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mobileEditorOpen) return;
      if (!_mobileFocus.hasFocus) {
        _mobileFocus.requestFocus();
        try {
          SystemChannels.textInput.invokeMethod('TextInput.show');
        } catch (_) {}
      }
      if (_mobilePhase == _MobileEditPhase.opening ||
          _mobilePhase == _MobileEditPhase.switching) {
        setState(() => _mobilePhase = _MobileEditPhase.open);
      }
    });

    _mobileFocusRetryT?.cancel();
    _mobileFocusRetryT = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || !_mobileEditorOpen) return;
      if (!_mobileFocus.hasFocus) {
        _mobileFocus.requestFocus();
        try {
          SystemChannels.textInput.invokeMethod('TextInput.show');
        } catch (_) {}
      }
      if (_mobilePhase == _MobileEditPhase.opening ||
          _mobilePhase == _MobileEditPhase.switching) {
        setState(() => _mobilePhase = _MobileEditPhase.open);
      }
    });
  }

  void _scheduleMobileBarMeasure() {
    if (_mobileBarMeasureScheduled) return;
    _mobileBarMeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mobileBarMeasureScheduled = false;
      if (!mounted) return;
      final ctx = _mobileBarKey.currentContext;
      if (ctx == null) return;
      final render = ctx.findRenderObject();
      if (render is RenderBox && render.hasSize) {
        final h = render.size.height;
        if ((h - _mobileBarH).abs() >= 0.5) {
          setState(() => _mobileBarH = h);
        }
      }
    });
  }

  Duration _mobileBarBottomDuration(double keyboardInset) {
    return const Duration(milliseconds: 180);
  }

  void _scheduleEnsureRowVisiblePostFrame(int row) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mobileEditorOpen) return;
      _ensureRowVisibleForKeyboard(row);
    });
  }

  void _scheduleEnsureRowVisibleLate(int row) {
    _mobileEnsureLateT?.cancel();
    _mobileEnsureLateT = Timer(const Duration(milliseconds: 320), () {
      if (!mounted || !_mobileEditorOpen) return;
      _ensureRowVisibleForKeyboard(row);
    });
  }

  void _debouncedEnsureRowVisible(int row) {
    if (!_mobileFocusCellModeEnabled) return;
    _kbEnsureDebounceT?.cancel();
    _kbEnsureDebounceT = Timer(const Duration(milliseconds: 80), () {
      if (!mounted || !_mobileEditorOpen) return;
      _ensureRowVisibleForKeyboard(row);
    });
  }

  void _toggleMobileEditorExpanded() {
    if (!_mobileEditorOpen) return;
    setState(() => _mobileEditorExpanded = !_mobileEditorExpanded);

    if (!_mobileFocusCellModeEnabled) return;
    final targetRow = _mobileEditingHeader ? -1 : _mobileRow;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mobileEditorOpen) return;
      _ensureRowVisibleForKeyboard(targetRow);
    });
  }

  Future<void> _openMobileOverflowSheet() async {
    if (!_mobileEditorOpen) return;
    final pal = _palette(context);
    final actions = List<_MobileAction>.from(_mobileActions);
    final canCopy = _mobileEditorOpen && !_mobileEditingHeader;
    final canPaste = canCopy;
    final row = _mobileRow;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: pal.menuBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.check_rounded),
                title: const Text('Listo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _commitMobileEdit();
                },
              ),
              ListTile(
                leading: Icon(
                  _mobileEditorExpanded
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                ),
                title: Text(
                  _mobileEditorExpanded
                      ? 'Compactar editor'
                      : 'Expandir editor',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleMobileEditorExpanded();
                },
              ),
              if (canCopy)
                ListTile(
                  leading: const Icon(Icons.content_copy_rounded),
                  title: const Text('Copiar'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _copyActiveMobileCell();
                  },
                ),
              if (canPaste)
                ListTile(
                  leading: const Icon(Icons.content_paste_rounded),
                  title: const Text('Pegar'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pasteIntoActiveMobileCell();
                  },
                ),
              if (row >= 0)
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Fotos de esta celda'),
                  onTap: () {
                    _startCellPhotoPickFromSheet(row, _mobileCol);
                  },
                ),
              if (row >= 0)
                ListTile(
                  leading: const Icon(Icons.videocam_outlined),
                  title: const Text('Adjuntar video'),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(_attachVideoForCell(row, _mobileCol));
                  },
                ),
              if (row >= 0)
                ListTile(
                  leading: const Icon(Icons.attach_file_rounded),
                  title: const Text('Adjuntar archivo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(_attachDocumentForCell(row, _mobileCol));
                  },
                ),
              if (row >= 0)
                ListTile(
                  leading: Icon(
                    _audioRecording
                        ? Icons.stop_circle_outlined
                        : Icons.mic_none_rounded,
                  ),
                  title: Text(
                    _audioRecording
                        ? 'Detener grabacion'
                        : 'Grabar audio en esta celda',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (_audioRecording) {
                      unawaited(_stopAudioRecording());
                    } else {
                      unawaited(_startAudioRecordingForCell(row, _mobileCol));
                    }
                  },
                ),
              if (row >= 0 && _cellHasAudios(row, _mobileCol))
                ListTile(
                  leading: const Icon(Icons.graphic_eq_rounded),
                  title: const Text('Audios de esta celda'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openAudiosSheetForCell(row, _mobileCol);
                  },
                ),
              if (row >= 0)
                ListTile(
                  leading: const Icon(Icons.my_location_outlined),
                  title: const Text('GPS -> Pegar en esta celda'),
                  onTap: () {
                    unawaited(
                      _requestGpsForCell(row, _mobileCol, forceWriteText: true),
                    );
                    Navigator.pop(ctx);
                  },
                ),
              if (row >= 0)
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('Modo GPS...'),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(_showGpsModePicker());
                  },
                ),
              if (actions.isNotEmpty) const Divider(height: 1),
              for (final a in actions)
                ListTile(
                  leading: Icon(a.icon),
                  title: Text(a.label),
                  onTap: () {
                    Navigator.pop(ctx);
                    a.onTap();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _cancelMobileEnsureTimers() {
    _kbEnsureDebounceT?.cancel();
    _mobileEnsureLateT?.cancel();
    _mobileFocusRetryT?.cancel();
  }

  static const double _kMobilePanelCompactH = 56.0;
  static const double _kMobilePanelExpandedH = 172.0;
  void _ensureRowVisibleForKeyboard(int row) {
    if (!mounted) return;
    if (!_vScroll.hasClients) return;
    _debugMobileEnsureVisibleCalls++;
    final panelMargin = _mobileBarH > 0 ? _mobileBarH + 16 : 120.0;
    const alignCenter = 0.40;
    if (_mobileEditingHeader || row < 0) {
      final ctx = _mobileHeaderKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: AppMotion.medium,
          curve: AppMotion.standardOut,
          alignment: alignCenter,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
      } else {
        _vScroll.animateTo(
          _vScroll.position.minScrollExtent,
          duration: AppMotion.medium,
          curve: AppMotion.standardOut,
        );
      }
      _ensureColumnVisibleForMobile();
      return;
    }

    if (row >= _mobileRowKeys.length) return;
    final rowCtx = _mobileRowKeyAt(row).currentContext;
    if (rowCtx != null) {
      Scrollable.ensureVisible(
        rowCtx,
        duration: AppMotion.medium,
        curve: AppMotion.standardOut,
        alignment: alignCenter,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    } else {
      final target = _mobileRowOffsetFor(row);
      final viewport = _vScroll.position.viewportDimension;
      final centered =
          target - (viewport * alignCenter) + _mobileRowH(_gridDensity) / 2;
      final centeredClamped = centered.clamp(
        _vScroll.position.minScrollExtent,
        _vScroll.position.maxScrollExtent,
      );
      _vScroll.animateTo(
        math.max(
          _vScroll.position.minScrollExtent,
          centeredClamped.toDouble() - panelMargin,
        ),
        duration: AppMotion.medium,
        curve: AppMotion.standardOut,
      );
    }

    _ensureColumnVisibleForMobile();
  }

  double _mobileRowOffsetFor(int row) {
    return _mobileHeaderRowH(_gridDensity) + (row * _mobileRowH(_gridDensity));
  }

  void _ensureColumnVisibleForMobile() {
    if (!_mobileEditorOpen) return;
    if (_mobileCol < 0 || _mobileCol >= _headers.length) return;

    final controller = _mobileEditingHeader || _mobileRow < 0
        ? _mobileHeaderScroll
        : (_mobileRow < _mobileRowScrolls.length
            ? _mobileRowScrollAt(_mobileRow)
            : null);
    if (controller == null || !controller.hasClients) return;

    final cardW = _mobileCardWidthForScreen(MediaQuery.of(context).size.width);
    final stride = cardW + _mobileCardGap(_gridDensity);
    final displayColumns = _displayColumnIndexes();
    final col = _displayColumnIndexForActual(_mobileCol, displayColumns);
    final cardLeft = _mobileRowPadH(_gridDensity) + (col * stride);
    final cardRight = cardLeft + cardW;

    final viewport = controller.position.viewportDimension;
    final visibleLeft = controller.offset;
    final visibleRight = visibleLeft + viewport;
    const pad = 12.0;

    double? target;
    if (cardLeft - pad < visibleLeft) {
      target = cardLeft - pad;
    } else if (cardRight + pad > visibleRight) {
      target = cardRight + pad - viewport;
    }

    if (target == null) return;

    final clamped = target.clamp(
      controller.position.minScrollExtent,
      controller.position.maxScrollExtent,
    );
    if ((clamped - controller.offset).abs() < 6.0) return;
    controller.animateTo(
      clamped.toDouble(),
      duration: AppMotion.medium,
      curve: AppMotion.standardOut,
    );
  }

  bool get _canMobileNav {
    return _mobileEditorOpen &&
        !_mobileEditingHeader &&
        _visibleDataColumnIndexes().isNotEmpty;
  }

  bool get _canMobileGps {
    return _mobileEditorOpen && !_mobileEditingHeader && _mobileRow >= 0;
  }

  String? get _mobileValidationHint {
    if (!_mobileEditorOpen || _mobileEditingHeader) return null;
    if (_mobileRow < 0 || _mobileRow >= _rows.length) return null;
    if (_mobileCol < 0 || _mobileCol >= _headers.length - 1) return null;
    return _validationMessageForCell(
      _mobileRow,
      _mobileCol,
      overrideValue: _mobileEC.text,
    );
  }

  void _mobileCommitDraftToModel() {
    if (!_mobileEditorOpen) return;

    final v = _mobileEC.text;
    if (_mobileEditingHeader) return;

    if (_mobileRow < 0 || _mobileRow >= _rows.length) return;
    if (_mobileCol < 0 || _mobileCol >= _headers.length) return;
    if (_mobileCol == _headers.length - 1) return;
    _setDraftCell(_mobileRow, _mobileCol, v);
    _commitDraftCell(_mobileRow, _mobileCol);
  }

  void _mobileMoveNext() {
    if (!_canMobileNav) return;

    _mobileCommitDraftToModel();

    final editableCols = _visibleDataColumnIndexes();
    if (editableCols.isEmpty) return;

    int r = _mobileRow;
    final currentIndex = editableCols.indexOf(_mobileCol);
    int cIndex = currentIndex < 0 ? 0 : currentIndex;

    if (cIndex < editableCols.length - 1) {
      cIndex += 1;
    } else {
      r += 1;
      cIndex = 0;
      if (r >= _rows.length) {
        _insertRow(_rows.length);
      }
      if (r >= _rows.length) return;
    }
    final c = editableCols[cIndex];

    setState(() {
      _setSelection(r, c);
      _mobileEditingHeader = false;
      _mobileRow = r;
      _mobileCol = c;
      _mobileTitle = _headerLabel(c);
      _mobileEditorExpanded = false;
      _mobileActions = _mobileActionsForCell(r, c);
      _mobileEditorOpen = true;
      _mobilePhase = _MobileEditPhase.switching;
    });

    _blink(r, c);

    _mobileEC.text = _effectiveCell(r, c);
    _mobileEC.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _mobileEC.text.length,
    );

    _requestMobileFocusWithRetry();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mobileEditorOpen) return;
      _ensureRowVisibleForKeyboard(r);
    });
    _scheduleEnsureRowVisibleLate(r);
  }

  void _mobileMovePrev() {
    if (!_canMobileNav) return;

    _mobileCommitDraftToModel();

    final editableCols = _visibleDataColumnIndexes();
    if (editableCols.isEmpty) return;

    int r = _mobileRow;
    final currentIndex = editableCols.indexOf(_mobileCol);
    int cIndex = currentIndex < 0 ? 0 : currentIndex;

    if (r <= 0 && cIndex <= 0) return;

    if (cIndex > 0) {
      cIndex -= 1;
    } else {
      r -= 1;
      if (r < 0) return;
      cIndex = editableCols.length - 1;
    }
    final c = editableCols[cIndex];

    setState(() {
      _setSelection(r, c);
      _mobileEditingHeader = false;
      _mobileRow = r;
      _mobileCol = c;
      _mobileTitle = _headerLabel(c);
      _mobileEditorExpanded = false;
      _mobileActions = _mobileActionsForCell(r, c);
      _mobileEditorOpen = true;
      _mobilePhase = _MobileEditPhase.switching;
    });

    _blink(r, c);

    _mobileEC.text = _effectiveCell(r, c);
    _mobileEC.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _mobileEC.text.length,
    );

    _requestMobileFocusWithRetry();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mobileEditorOpen) return;
      _ensureRowVisibleForKeyboard(r);
    });
    _scheduleEnsureRowVisibleLate(r);
  }

  void _cancelMobileEdit() {
    _cancelMobileEnsureTimers();
    _detachMobileDraftListener();

    bool cleared = false;
    if (_mobileEditingHeader) {
      if (_draftHeaders.remove(_mobileCol) != null) {
        cleared = true;
      }
    } else if (_mobileRow >= 0 && _mobileCol >= 0) {
      if (_draftCells.remove(_CellRef(_mobileRow, _mobileCol)) != null) {
        cleared = true;
      }
    }
    if (cleared) _bumpGridVersion();

    setState(() {
      _mobileEditorOpen = false;
      _mobileEditorExpanded = false;
      _mobilePhase = _MobileEditPhase.closing;
    });
    _mobileEditingHeader = false;
    _mobileRow = -1;
    _mobileCol = 0;
    _mobileTitle = '';
    _mobileActions = const [];

    try {
      _mobileFocus.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    } catch (_) {}

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_mobilePhase != _MobileEditPhase.closing) return;
      setState(() => _mobilePhase = _MobileEditPhase.closed);
    });
  }

  void _commitMobileEdit() {
    if (!_mobileEditorOpen) return;
    _commitActiveEditors();
  }

  void _closeMobileEditor() {
    _cancelMobileEnsureTimers();
    _detachMobileDraftListener();
    setState(() {
      _mobileEditorOpen = false;
      _mobileEditorExpanded = false;
      _mobilePhase = _MobileEditPhase.closing;
    });
    _mobileEditingHeader = false;
    _mobileRow = -1;
    _mobileCol = 0;
    _mobileTitle = '';
    _mobileActions = const [];

    try {
      _mobileFocus.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    } catch (_) {}

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_mobilePhase != _MobileEditPhase.closing) return;
      setState(() => _mobilePhase = _MobileEditPhase.closed);
    });
  }

  // ------------------------------ Overlay Editor (Desktop) ----------------

  void _overlayCommitAndNavigate({
    required BuildContext context,
    required _SheetPalette pal,
    required ValueChanged<String> onCommit,
    required _OverlayMove move,
  }) {
    final currentHeader = _overlayTargetHeaderCol;
    final currentCell = _overlayTargetCell;
    final width = _overlayTargetWidth;

    // Commit primero.
    onCommit(_cellEC.text);

    // Cerramos overlay actual.
    _removeCellEditor();

    if (!mounted) return;
    if (move == _OverlayMove.none) return;

    // Header: Tab -> next/prev header. Enter -> baja a row 0 misma col.
    if (currentHeader != null) {
      final editableCols = _visibleDataColumnIndexes();
      if (editableCols.isEmpty) return;
      final currentIndex = editableCols.indexOf(currentHeader);
      var nextIndex = currentIndex < 0 ? 0 : currentIndex;

      if (move == _OverlayMove.next) {
        nextIndex = (nextIndex + 1).clamp(0, editableCols.length - 1);
      }
      if (move == _OverlayMove.prev) {
        nextIndex = (nextIndex - 1).clamp(0, editableCols.length - 1);
      }
      final nextC = editableCols[nextIndex];

      if (move == _OverlayMove.down) {
        if (_rows.isEmpty) {
          _rows.add(_RowModel.empty(_headers.length, id: _genStableId('r_')));
          _ensureMobileRowCachesLength();
        }
        final targetCol = currentIndex < 0 ? nextC : currentHeader;
        _beginEditCell(context, pal, 0, targetCol, width);
        return;
      }

      if (move == _OverlayMove.next || move == _OverlayMove.prev) {
        if (nextC == currentHeader) return;
        _beginEditHeader(context, pal, nextC, width);
        return;
      }

      return;
    }

    // Celda normal.
    if (currentCell == null) return;
    final editableCols = _visibleDataColumnIndexes();
    if (editableCols.isEmpty) return;
    int r = currentCell.r;
    int c = currentCell.c;
    var cIndex = editableCols.indexOf(c);
    if (cIndex < 0) {
      cIndex = 0;
      c = editableCols.first;
    }

    if (move == _OverlayMove.next) {
      if (cIndex < editableCols.length - 1) {
        cIndex += 1;
      } else {
        r += 1;
        cIndex = 0;
      }
    } else if (move == _OverlayMove.prev) {
      if (cIndex > 0) {
        cIndex -= 1;
      } else {
        r -= 1;
        cIndex = editableCols.length - 1;
      }
    } else if (move == _OverlayMove.down) {
      r += 1;
    } else if (move == _OverlayMove.up) {
      r -= 1;
    }

    if (r < 0) return;

    if (r >= _rows.length) {
      _insertRow(_rows.length);
      r = math.min(r, _rows.length - 1);
    }

    r = r.clamp(0, _rows.length - 1);
    c = editableCols[cIndex.clamp(0, editableCols.length - 1)];

    _beginEditCell(context, pal, r, c, width);
  }

  void _showOverlayEditor({
    required BuildContext context,
    required _SheetPalette pal,
    required String initial,
    required double width,
    required ValueChanged<String> onCommit,
  }) {
    _removeCellEditor();

    _detachCellDraftListener();
    _cellEC.text = initial;
    _cellEC.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _cellEC.text.length,
    );
    _attachCellDraftListener();

    final metrics = _gridMetricsFor(_gridDensity);
    final editorFont = (metrics.cellFontSize + 2).clamp(13.0, 17.0);
    final activeRow = _overlayTargetCell?.r;
    final activeCol = _overlayTargetCell?.c ?? _overlayTargetHeaderCol;
    final hintText =
        activeCol == null ? 'Escribir' : 'Editar ${_headerLabel(activeCol)}';
    final valueSuggestions = activeCol == null
        ? const <String>[]
        : _recentValuesForColumn(
            activeCol,
            excluding: initial,
          ).take(10).toList(growable: false);
    final overlay = Overlay.of(context, rootOverlay: true);
    var committed = false;

    void commitAndDismiss() {
      if (committed) return;
      committed = true;
      onCommit(_cellEC.text);
      _removeCellEditor();
    }

    void commitAndNavigate(_OverlayMove move) {
      if (committed) return;
      committed = true;
      _overlayCommitAndNavigate(
        context: context,
        pal: pal,
        onCommit: onCommit,
        move: move,
      );
    }

    _cellEditorEntry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: commitAndDismiss,
              ),
            ),
            CompositedTransformFollower(
              link: _editorLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 0),
              child: Material(
                color: Colors.transparent,
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;

                    final isShift = HardwareKeyboard.instance.isShiftPressed;
                    final isCmd = HardwareKeyboard.instance.isMetaPressed;
                    final isCtrl = HardwareKeyboard.instance.isControlPressed;
                    final isMod = isCmd || isCtrl;

                    if (event.logicalKey == LogicalKeyboardKey.escape) {
                      _removeCellEditor(); // cancelar sin commit
                      return KeyEventResult.handled;
                    }

                    // Cmd/Ctrl+Enter => commit y cerrar.
                    if (event.logicalKey == LogicalKeyboardKey.enter && isMod) {
                      commitAndDismiss();
                      return KeyEventResult.handled;
                    }

                    // Tab / Shift+Tab => commit + mover.
                    if (event.logicalKey == LogicalKeyboardKey.tab) {
                      commitAndNavigate(
                        isShift ? _OverlayMove.prev : _OverlayMove.next,
                      );
                      return KeyEventResult.handled;
                    }

                    // Enter / Shift+Enter => commit + bajar/subir.
                    if (event.logicalKey == LogicalKeyboardKey.enter) {
                      commitAndNavigate(
                        isShift ? _OverlayMove.up : _OverlayMove.down,
                      );
                      return KeyEventResult.handled;
                    }

                    return KeyEventResult.ignored;
                  },
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) {
                      final clamped = t.clamp(0.0, 1.0);
                      final scale = 0.985 + (0.015 * clamped);
                      return Opacity(
                        opacity: clamped,
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.topLeft,
                          child: child,
                        ),
                      );
                    },
                    child: RepaintBoundary(
                      child: Container(
                        width: width,
                        padding: metrics.cellPadding,
                        decoration: BoxDecoration(
                          // Evita blur en tiempo real para no penalizar typing/caret.
                          color: pal.editorBg.withValues(
                            alpha: pal.isLight ? 0.96 : 0.92,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: pal.borderStrong.withValues(
                              alpha: pal.isLight ? 0.65 : 0.84,
                            ),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: pal.borderStrong.withValues(
                                alpha: pal.isLight ? 0.22 : 0.42,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _cellEC,
                                    focusNode: _cellFocus,
                                    autofocus: true,
                                    minLines: 1,
                                    maxLines: 2,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    textInputAction: TextInputAction.done,
                                    style: TextStyle(
                                      color: pal.fg,
                                      fontSize: editorFont,
                                      height: 1.08,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                    cursorColor: pal.accent,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: hintText,
                                      hintStyle: TextStyle(color: pal.fgMuted),
                                      border: InputBorder.none,
                                    ),
                                    onSubmitted: (_) => commitAndDismiss(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: commitAndDismiss,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      color: pal.fg,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (activeRow != null && activeCol != null)
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _cellEC,
                                builder: (context, value, _) {
                                  final message = _validationMessageForCell(
                                    activeRow,
                                    activeCol,
                                    overrideValue: value.text,
                                  );
                                  if (message == null) {
                                    return const SizedBox(height: 4);
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      message,
                                      style: TextStyle(
                                        color: pal.fgMuted,
                                        fontSize: 11.2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _cellEC,
                              builder: (context, value, _) {
                                final formulaSuggestions =
                                    _formulaAutocompleteSuggestions(value.text);
                                final showFormulaSuggestions =
                                    formulaSuggestions.isNotEmpty;
                                final showValueSuggestions =
                                    !showFormulaSuggestions &&
                                        valueSuggestions.isNotEmpty;
                                if (!showFormulaSuggestions &&
                                    !showValueSuggestions) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        if (showFormulaSuggestions)
                                          for (final suggestion
                                              in formulaSuggestions) ...[
                                            ActionChip(
                                              label: Text(
                                                suggestion.name,
                                                style: TextStyle(
                                                  color: pal.fg,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              onPressed: () {
                                                _applyFormulaSuggestion(
                                                  _cellEC,
                                                  suggestion,
                                                );
                                                _cellFocus.requestFocus();
                                              },
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                        if (showValueSuggestions)
                                          for (final suggestion
                                              in valueSuggestions) ...[
                                            ActionChip(
                                              label: Text(
                                                suggestion,
                                                style: TextStyle(
                                                  color: pal.fg,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              onPressed: () {
                                                _cellEC.value =
                                                    _cellEC.value.copyWith(
                                                  text: suggestion,
                                                  selection:
                                                      TextSelection.collapsed(
                                                    offset: suggestion.length,
                                                  ),
                                                  composing: TextRange.empty,
                                                );
                                                _cellFocus.requestFocus();
                                              },
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_cellEditorEntry!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cellFocus.requestFocus();
    });
  }

  void _removeCellEditor({bool notifyState = true}) {
    _cellEditorEntry?.remove();
    _cellEditorEntry = null;
    _detachCellDraftListener();

    bool cleared = false;
    final headerCol = _editingHeaderCol;
    final cellRef = _editingCellRef;
    if (headerCol != null) {
      if (_draftHeaders.remove(headerCol) != null) {
        cleared = true;
      }
    }
    if (cellRef != null) {
      if (_draftCells.remove(cellRef) != null) {
        cleared = true;
      }
    }
    if (cleared) _bumpGridVersion();

    _editingHeaderCol = null;
    _editingCellRef = null;

    if (!notifyState) return;
    if (!mounted) return;
    if (_isDisposing) return;

    if (_overlayTargetCell != null || _overlayTargetHeaderCol != null) {
      setState(() {
        _overlayTargetCell = null;
        _overlayTargetHeaderCol = null;
      });
    }
  }

  String _columnTypeLabel(_ColType type) {
    switch (type) {
      case _ColType.text:
        return 'Texto';
      case _ColType.number:
        return 'Numero';
      case _ColType.date:
        return 'Fecha';
      case _ColType.status:
        return 'Estado';
      case _ColType.checkbox:
        return 'Checkbox';
      case _ColType.photos:
        return 'Adjuntos';
    }
  }

  Future<void> _openColumnTypePicker(int col) async {
    if (col < 0 || col >= _headers.length - 1) return;
    final current = _colType(col);
    final picked = await showModalBottomSheet<_ColType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final pal = _palette(ctx);
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: pal.menuBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pal.border, width: pal.hairline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.category_outlined, color: pal.fg),
                    const SizedBox(width: 8),
                    Text(
                      'Tipo de columna',
                      style: TextStyle(
                        color: pal.fg,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: Icon(Icons.close_rounded, color: pal.fgMuted),
                    ),
                  ],
                ),
                for (final type in const <_ColType>[
                  _ColType.text,
                  _ColType.number,
                  _ColType.date,
                  _ColType.status,
                  _ColType.checkbox,
                ])
                  ListTile(
                    leading: Icon(
                      current == type
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: pal.fgMuted,
                    ),
                    title: Text(_columnTypeLabel(type)),
                    onTap: () => Navigator.of(ctx).pop(type),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || picked == null) return;
    _setColumnTypeForIndex(col, picked);
  }

  Future<void> _openColumnPanel() async {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final dataOrder = List<String>.from(
      _normalizeColumnOrder(colIds: _colIds, incoming: _columnOrder),
    );
    var draftOrder = List<String>.from(dataOrder);
    var draftPrefs = _cloneColumnPrefs(_columnPrefsById);
    String? draftFrozen = _frozenColId;

    final applied = await showAppModal<bool>(
      context: context,
      title: 'Columnas',
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          List<int> orderedIndexes() {
            final out = <int>[];
            for (final colId in draftOrder) {
              final index = _colIds.indexOf(colId);
              if (index < 0 || index >= _headers.length - 1) continue;
              out.add(index);
            }
            return out;
          }

          void swapOrder(int i, int j) {
            if (i < 0 ||
                j < 0 ||
                i >= draftOrder.length ||
                j >= draftOrder.length) {
              return;
            }
            final next = List<String>.from(draftOrder);
            final temp = next[i];
            next[i] = next[j];
            next[j] = temp;
            setModalState(() => draftOrder = next);
          }

          final ordered = orderedIndexes();
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: ordered.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (itemCtx, index) {
                if (index == 0) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppButton(
                        label: 'Restaurar columnas por defecto',
                        icon: Icons.restart_alt_rounded,
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.ghost,
                        onPressed: () {
                          setModalState(() {
                            draftOrder = _normalizeColumnOrder(
                              colIds: _colIds,
                              incoming: null,
                            );
                            draftPrefs = <String, _ColumnPrefs>{};
                            for (int c = 0; c < _headers.length - 1; c++) {
                              draftPrefs[_colIds[c]] = _defaultColumnPrefsFor(
                                c,
                              );
                            }
                            draftFrozen = null;
                          });
                        },
                      ),
                      AppButton(
                        label: 'Guardar como plantilla',
                        icon: Icons.bookmark_add_outlined,
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.ghost,
                        onPressed: () async {
                          Navigator.of(context).pop(false);
                          await _saveCurrentColumnsAsTemplate();
                        },
                      ),
                      AppButton(
                        label: 'Aplicar plantilla',
                        icon: Icons.auto_fix_high_rounded,
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.ghost,
                        onPressed: () async {
                          Navigator.of(context).pop(false);
                          await _openApplyColumnTemplateDialog();
                        },
                      ),
                      AppButton(
                        label: 'Mostrar todas',
                        icon: Icons.visibility_rounded,
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.ghost,
                        onPressed: () {
                          setModalState(() {
                            final next = _cloneColumnPrefs(draftPrefs);
                            for (final colId in draftOrder) {
                              final idx = _colIds.indexOf(colId);
                              final type = idx >= 0
                                  ? _inferColTypeFromHeader(_headerLabel(idx))
                                  : _ColType.text;
                              final current = next[colId];
                              next[colId] = _ColumnPrefs(
                                type: current?.type ?? type,
                                hidden: false,
                                required: current?.required ?? false,
                                enumValues:
                                    current?.enumValues ?? const <String>[],
                                numberMin: current?.numberMin,
                                numberMax: current?.numberMax,
                                regexPattern: current?.regexPattern,
                                wrapLines: current?.wrapLines ??
                                    _defaultWrapLinesForType(
                                      current?.type ?? type,
                                    ),
                                textAlign:
                                    current?.textAlign ?? _GridTextAlignX.left,
                                verticalAlign: current?.verticalAlign ??
                                    _GridTextAlignY.middle,
                              );
                            }
                            draftPrefs = next;
                          });
                        },
                      ),
                    ],
                  );
                }

                final col = ordered[index - 1];
                final colId = _colIds[col];
                final header = _headerLabel(col);
                final pref = draftPrefs[colId];
                final type = pref?.type ?? _inferColTypeFromHeader(header);
                final hidden = pref?.hidden ?? false;
                final required = pref?.required ?? _isRequired(col);
                final enumValues = pref?.enumValues ?? const <String>[];
                final numberMin = pref?.numberMin;
                final numberMax = pref?.numberMax;
                final regexPattern = pref?.regexPattern;
                final wrapLines =
                    (pref?.wrapLines ?? _defaultWrapLinesForColumn(col))
                        .clamp(1, 3);
                final textAlignPref = pref?.textAlign ?? _GridTextAlignX.left;
                final verticalAlignPref =
                    pref?.verticalAlign ?? _GridTextAlignY.middle;
                final orderIndex = draftOrder.indexOf(colId);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _palette(itemCtx).menuBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _palette(itemCtx).border,
                      width: _palette(itemCtx).hairline,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              header,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _palette(itemCtx).fg,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Mover arriba',
                            onPressed: orderIndex > 0
                                ? () => swapOrder(orderIndex, orderIndex - 1)
                                : null,
                            icon: const Icon(Icons.arrow_upward_rounded),
                          ),
                          IconButton(
                            tooltip: 'Mover abajo',
                            onPressed: orderIndex >= 0 &&
                                    orderIndex < draftOrder.length - 1
                                ? () => swapOrder(orderIndex, orderIndex + 1)
                                : null,
                            icon: const Icon(Icons.arrow_downward_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<_ColType>(
                              initialValue: type,
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: 'Tipo',
                              ),
                              items: const <_ColType>[
                                _ColType.text,
                                _ColType.number,
                                _ColType.date,
                                _ColType.status,
                                _ColType.checkbox,
                              ].map((entry) {
                                return DropdownMenuItem<_ColType>(
                                  value: entry,
                                  child: Text(_columnTypeLabel(entry)),
                                );
                              }).toList(growable: false),
                              onChanged: (nextType) {
                                if (nextType == null) return;
                                setModalState(() {
                                  draftPrefs = _cloneColumnPrefs(draftPrefs)
                                    ..[colId] = _ColumnPrefs(
                                      type: nextType,
                                      hidden: hidden,
                                      required: required,
                                      enumValues: enumValues,
                                      numberMin: numberMin,
                                      numberMax: numberMax,
                                      regexPattern: regexPattern,
                                      wrapLines: wrapLines,
                                      textAlign: textAlignPref,
                                      verticalAlign: verticalAlignPref,
                                    );
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SwitchListTile.adaptive(
                              value: !hidden,
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Visible',
                                style: TextStyle(fontSize: 12),
                              ),
                              onChanged: (visible) {
                                setModalState(() {
                                  draftPrefs = _cloneColumnPrefs(draftPrefs)
                                    ..[colId] = _ColumnPrefs(
                                      type: type,
                                      hidden: !visible,
                                      required: required,
                                      enumValues: enumValues,
                                      numberMin: numberMin,
                                      numberMax: numberMax,
                                      regexPattern: regexPattern,
                                      wrapLines: wrapLines,
                                      textAlign: textAlignPref,
                                      verticalAlign: verticalAlignPref,
                                    );
                                  if (!visible && draftFrozen == colId) {
                                    draftFrozen = null;
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SwitchListTile.adaptive(
                              value: draftFrozen == colId,
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Fijada',
                                style: TextStyle(fontSize: 12),
                              ),
                              onChanged: hidden
                                  ? null
                                  : (enabled) {
                                      setModalState(() {
                                        draftFrozen = enabled ? colId : null;
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: SwitchListTile.adaptive(
                              value: required,
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Requerido',
                                style: TextStyle(fontSize: 12),
                              ),
                              onChanged: (enabled) {
                                setModalState(() {
                                  draftPrefs = _cloneColumnPrefs(draftPrefs)
                                    ..[colId] = _ColumnPrefs(
                                      type: type,
                                      hidden: hidden,
                                      required: enabled,
                                      enumValues: enumValues,
                                      numberMin: numberMin,
                                      numberMax: numberMax,
                                      regexPattern: regexPattern,
                                      wrapLines: wrapLines,
                                      textAlign: textAlignPref,
                                      verticalAlign: verticalAlignPref,
                                    );
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: wrapLines,
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: 'Wrap',
                              ),
                              items: const <int>[1, 2, 3].map((lines) {
                                final label =
                                    lines == 1 ? '1 linea' : '$lines lineas';
                                return DropdownMenuItem<int>(
                                  value: lines,
                                  child: Text(label),
                                );
                              }).toList(growable: false),
                              onChanged: (nextLines) {
                                if (nextLines == null) return;
                                setModalState(() {
                                  draftPrefs = _cloneColumnPrefs(draftPrefs)
                                    ..[colId] = _ColumnPrefs(
                                      type: type,
                                      hidden: hidden,
                                      required: required,
                                      enumValues: enumValues,
                                      numberMin: numberMin,
                                      numberMax: numberMax,
                                      regexPattern: regexPattern,
                                      wrapLines: nextLines.clamp(1, 3),
                                      textAlign: textAlignPref,
                                      verticalAlign: verticalAlignPref,
                                    );
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<_GridTextAlignX>(
                              initialValue: textAlignPref,
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: 'Alineacion',
                              ),
                              items: const <_GridTextAlignX>[
                                _GridTextAlignX.left,
                                _GridTextAlignX.center,
                                _GridTextAlignX.right,
                              ].map((entry) {
                                final label = switch (entry) {
                                  _GridTextAlignX.left => 'Izquierda',
                                  _GridTextAlignX.center => 'Centro',
                                  _GridTextAlignX.right => 'Derecha',
                                };
                                return DropdownMenuItem<_GridTextAlignX>(
                                  value: entry,
                                  child: Text(label),
                                );
                              }).toList(growable: false),
                              onChanged: (nextAlign) {
                                if (nextAlign == null) return;
                                setModalState(() {
                                  draftPrefs = _cloneColumnPrefs(draftPrefs)
                                    ..[colId] = _ColumnPrefs(
                                      type: type,
                                      hidden: hidden,
                                      required: required,
                                      enumValues: enumValues,
                                      numberMin: numberMin,
                                      numberMax: numberMax,
                                      regexPattern: regexPattern,
                                      wrapLines: wrapLines,
                                      textAlign: nextAlign,
                                      verticalAlign: verticalAlignPref,
                                    );
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<_GridTextAlignY>(
                        initialValue: verticalAlignPref,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Alineacion vertical',
                        ),
                        items: const <_GridTextAlignY>[
                          _GridTextAlignY.top,
                          _GridTextAlignY.middle,
                          _GridTextAlignY.bottom,
                        ].map((entry) {
                          final label = switch (entry) {
                            _GridTextAlignY.top => 'Arriba',
                            _GridTextAlignY.middle => 'Centro',
                            _GridTextAlignY.bottom => 'Abajo',
                          };
                          return DropdownMenuItem<_GridTextAlignY>(
                            value: entry,
                            child: Text(label),
                          );
                        }).toList(growable: false),
                        onChanged: (nextAlign) {
                          if (nextAlign == null) return;
                          setModalState(() {
                            draftPrefs = _cloneColumnPrefs(draftPrefs)
                              ..[colId] = _ColumnPrefs(
                                type: type,
                                hidden: hidden,
                                required: required,
                                enumValues: enumValues,
                                numberMin: numberMin,
                                numberMax: numberMax,
                                regexPattern: regexPattern,
                                wrapLines: wrapLines,
                                textAlign: textAlignPref,
                                verticalAlign: nextAlign,
                              );
                          });
                        },
                      ),
                      if (type == _ColType.status) ...[
                        const SizedBox(height: 4),
                        TextFormField(
                          key: ValueKey('enum-$colId'),
                          initialValue: enumValues.join(', '),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Enum (separado por coma)',
                            hintText: 'OK, Obs, Urgente',
                          ),
                          onChanged: (raw) {
                            final values = raw
                                .split(',')
                                .map((item) => item.trim())
                                .where((item) => item.isNotEmpty)
                                .toSet()
                                .toList(growable: false);
                            setModalState(() {
                              draftPrefs = _cloneColumnPrefs(draftPrefs)
                                ..[colId] = _ColumnPrefs(
                                  type: type,
                                  hidden: hidden,
                                  required: required,
                                  enumValues: values,
                                  numberMin: numberMin,
                                  numberMax: numberMax,
                                  regexPattern: regexPattern,
                                  wrapLines: wrapLines,
                                  textAlign: textAlignPref,
                                  verticalAlign: verticalAlignPref,
                                );
                            });
                          },
                        ),
                      ],
                      if (type == _ColType.number) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('num-min-$colId'),
                                initialValue: numberMin?.toString() ?? '',
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'Min',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                                onChanged: (raw) {
                                  final parsed = double.tryParse(
                                    raw.trim().replaceAll(',', '.'),
                                  );
                                  setModalState(() {
                                    draftPrefs = _cloneColumnPrefs(draftPrefs)
                                      ..[colId] = _ColumnPrefs(
                                        type: type,
                                        hidden: hidden,
                                        required: required,
                                        enumValues: enumValues,
                                        numberMin: parsed,
                                        numberMax: numberMax,
                                        regexPattern: regexPattern,
                                        wrapLines: wrapLines,
                                        textAlign: textAlignPref,
                                        verticalAlign: verticalAlignPref,
                                      );
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('num-max-$colId'),
                                initialValue: numberMax?.toString() ?? '',
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'Max',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                                onChanged: (raw) {
                                  final parsed = double.tryParse(
                                    raw.trim().replaceAll(',', '.'),
                                  );
                                  setModalState(() {
                                    draftPrefs = _cloneColumnPrefs(draftPrefs)
                                      ..[colId] = _ColumnPrefs(
                                        type: type,
                                        hidden: hidden,
                                        required: required,
                                        enumValues: enumValues,
                                        numberMin: numberMin,
                                        numberMax: parsed,
                                        regexPattern: regexPattern,
                                        wrapLines: wrapLines,
                                        textAlign: textAlignPref,
                                        verticalAlign: verticalAlignPref,
                                      );
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      TextFormField(
                        key: ValueKey('regex-$colId'),
                        initialValue: regexPattern ?? '',
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Regex (opcional)',
                          hintText: r'Ej: ^[A-Z]{3}-\d{4}$',
                        ),
                        onChanged: (raw) {
                          final nextRegex =
                              raw.trim().isEmpty ? null : raw.trim();
                          setModalState(() {
                            draftPrefs = _cloneColumnPrefs(draftPrefs)
                              ..[colId] = _ColumnPrefs(
                                type: type,
                                hidden: hidden,
                                required: required,
                                enumValues: enumValues,
                                numberMin: numberMin,
                                numberMax: numberMax,
                                regexPattern: nextRegex,
                                wrapLines: wrapLines,
                                textAlign: textAlignPref,
                                verticalAlign: verticalAlignPref,
                              );
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
      actions: [
        AppButton(
          label: AppStrings.close,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: AppStrings.save,
          variant: AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );

    if (applied != true || !mounted) return;
    var visibleCount = 0;
    for (final colId in draftOrder) {
      final hidden = draftPrefs[colId]?.hidden ?? false;
      if (!hidden) visibleCount++;
    }
    if (visibleCount <= 0) {
      _showActionSnack(
        'Debe quedar al menos una columna visible.',
        isError: false,
        icon: Icons.view_column_rounded,
      );
      return;
    }
    _applyColumnPrefsAndOrder(
      columnPrefsById: draftPrefs,
      columnOrder: draftOrder,
      frozenColId: draftFrozen,
    );
    _scheduleValidationRecompute(immediate: true);
  }

  // ------------------------------ Context Menu ----------------------------

  Future<void> _openContextMenu(
    BuildContext context,
    _SheetPalette pal,
    Offset globalPos,
    int r,
    int c,
    bool isHeader,
  ) async {
    _removeCellEditor();

    final actions = <_CtxAction>[];

    if (isHeader) {
      if (c >= 0 && c < _headers.length - 1) {
        final colType = _colType(c);
        final hidden = _isColumnHidden(c);
        final frozen = _frozenColId == _colIds[c];
        final currentWrap = _colWrapLines(c);
        final currentAlign = _colTextAlign(c);
        actions.add(
          _CtxAction(
            'Editar encabezado',
            Icons.edit_outlined,
            () => _beginEditHeader(context, pal, c, 220),
          ),
        );
        actions.add(
          _CtxAction(
            'Renombrar columna',
            Icons.drive_file_rename_outline,
            () => _beginEditHeader(context, pal, c, 240),
          ),
        );
        actions.add(
          _CtxAction('Limpiar encabezado', Icons.clear_rounded, () {
            if (_headers[c].isEmpty) return;
            _headers[c] = '';
            _markDirty(snapshot: true);
          }),
        );
        actions.add(
          _CtxAction(
            'Tipo: ${_columnTypeLabel(colType)}',
            Icons.category_outlined,
            () => unawaited(_openColumnTypePicker(c)),
            runOnTap: true,
          ),
        );
        actions.add(
          _CtxAction(
            currentAlign == _GridTextAlignX.center
                ? 'Alinear izquierda'
                : 'Centrar columna',
            currentAlign == _GridTextAlignX.center
                ? Icons.format_align_left_rounded
                : Icons.format_align_center_rounded,
            () => _setColumnPresentationForIndex(
              c,
              textAlign: currentAlign == _GridTextAlignX.center
                  ? _GridTextAlignX.left
                  : _GridTextAlignX.center,
              verticalAlign: _GridTextAlignY.middle,
            ),
          ),
        );
        actions.add(
          _CtxAction(
            'Wrap ${currentWrap == 1 ? '2 lineas' : currentWrap == 2 ? '3 lineas' : '1 linea'}',
            Icons.wrap_text_rounded,
            () => _setColumnPresentationForIndex(
              c,
              wrapLines: currentWrap == 1 ? 2 : (currentWrap == 2 ? 3 : 1),
            ),
          ),
        );
        actions.add(
          _CtxAction(
            'Ordenar ascendente',
            Icons.arrow_upward_rounded,
            () => _sortRowsByColumn(c, ascending: true),
          ),
        );
        actions.add(
          _CtxAction(
            'Ordenar descendente',
            Icons.arrow_downward_rounded,
            () => _sortRowsByColumn(c, ascending: false),
          ),
        );
        actions.add(
          _CtxAction(
            frozen ? 'Desfijar columna' : 'Fijar columna',
            frozen ? Icons.push_pin : Icons.push_pin_outlined,
            () => _setFrozenColumnByIndex(frozen ? null : c),
          ),
        );
        actions.add(
          _CtxAction(
            hidden ? 'Mostrar columna' : 'Ocultar columna',
            hidden ? Icons.visibility_rounded : Icons.visibility_off_outlined,
            () => _setColumnHidden(c, !hidden),
          ),
        );
        actions.add(
          _CtxAction(
            'Panel Columnas',
            Icons.view_column_rounded,
            () => unawaited(_openColumnPanel()),
            runOnTap: true,
          ),
        );
      }
    } else {
      actions.add(
        _CtxAction(
          'Copiar',
          Icons.copy_rounded,
          () => unawaited(_copySelectionToClipboard()),
        ),
      );
      actions.add(
        _CtxAction(
          'Pegar',
          Icons.paste_rounded,
          () => unawaited(_pasteFromClipboard()),
        ),
      );
      actions.add(
        _CtxAction(
          'Duplicar fila',
          Icons.copy_all_outlined,
          () => _duplicateRow(r),
        ),
      );
      actions.add(
        _CtxAction(
          'Duplicar N veces',
          Icons.copy_all_rounded,
          () => unawaited(_promptDuplicateRowCount(r)),
        ),
      );
      actions.add(
        _CtxAction(
          'Marcar revisado',
          Icons.verified_rounded,
          () => unawaited(_setReviewedForRows(<int>[r], reviewed: true)),
        ),
      );
      actions.add(
        _CtxAction(
          'Marcar pendiente',
          Icons.pending_actions_rounded,
          () => unawaited(_setReviewedForRows(<int>[r], reviewed: false)),
        ),
      );

      if (_batchTargetRows().length > 1) {
        actions.add(
          _CtxAction(
            'Aplicar valor a seleccion',
            Icons.format_color_text_rounded,
            () => unawaited(_promptBatchApplyValue()),
          ),
        );
      }
      actions.add(
        _CtxAction(
          'Fecha hoy en seleccion',
          Icons.today_rounded,
          _applyDateTodayToSelection,
        ),
      );
      actions.add(
        _CtxAction(
          'Autonumerar progresiva',
          Icons.auto_mode_rounded,
          () => unawaited(_runAutonumberProgressiveAction()),
        ),
      );

      actions.add(
        _CtxAction(
          'Adjuntar foto',
          Icons.add_photo_alternate_outlined,
          () => unawaited(_startPhotoFlowForCell(r, c)),
          runOnTap: true,
        ),
      );
      if (c != _headers.length - 1) {
        actions.add(
          _CtxAction(
            'Adjuntar GPS',
            Icons.my_location_rounded,
            () => unawaited(_requestGpsForCell(r, c)),
            runOnTap: true,
          ),
        );
      }

      final hasAttachments = _cellMetaAt(r, c)?.isEmpty == false;
      if (hasAttachments) {
        actions.add(
          _CtxAction(
            'Ver adjuntos',
            Icons.attach_file_rounded,
            () => unawaited(_openAttachmentPanelForCell(r, c)),
          ),
        );
      }
    }

    if (actions.isEmpty) return;

    final overlay = Overlay.of(context);
    final size = overlay.context.size;
    if (size == null) return;

    final res = await showMenu<int>(
      context: context,
      color: pal.menuBg,
      elevation: 14,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: pal.gridBorder,
          width: math.max(pal.hairline, 1).toDouble(),
        ),
      ),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        size.width - globalPos.dx,
        size.height - globalPos.dy,
      ),
      items: [
        for (int i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            onTap: actions[i].runOnTap ? actions[i].run : null,
            height: 42,
            child: Row(
              children: [
                Icon(actions[i].icon, size: 18, color: pal.cellText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    actions[i].label,
                    style: TextStyle(
                      color: pal.cellText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (res == null) return;
    final action = actions[res];
    if (action.runOnTap) return;
    action.run();
  }

  // ------------------------------ Automatizaciones ------------------------

  void _duplicateRow(int r, {bool announce = true}) {
    _duplicateRowMultiple(r, times: 1, announce: announce);
  }

  void _duplicateRowMultiple(
    int r, {
    required int times,
    bool announce = true,
  }) {
    if (r < 0 || r >= _rows.length) {
      if (announce) {
        _emitActionResult(
          const _ActionResult(
            ok: false,
            message: 'Selecciona una fila valida para duplicar.',
          ),
          failureIcon: Icons.info_outline_rounded,
        );
      }
      return;
    }
    if (times <= 0) {
      if (announce) {
        _emitActionResult(
          const _ActionResult(
            ok: false,
            message: 'La cantidad de copias debe ser mayor a cero.',
          ),
          failureIcon: Icons.info_outline_rounded,
        );
      }
      return;
    }
    final safeTimes = times.clamp(1, 100);
    final src = _rows[r];
    final copies = <_RowModel>[];
    for (int i = 0; i < safeTimes; i++) {
      final newId = _genStableId('r_');
      final copy = _RowModel(
        id: newId,
        cells: List<String>.from(src.cells),
        photos: src.photos.map((p) => p.copy()).toList(),
        gpsLat: src.gpsLat,
        gpsLng: src.gpsLng,
        gpsAccuracyM: src.gpsAccuracyM,
        gpsTs: src.gpsTs,
        gpsIsLastKnown: src.gpsIsLastKnown,
      );
      _duplicateCellMetaRow(src.id, newId);
      copies.add(copy);
    }
    final insertAt = (r + 1).clamp(0, _rows.length);
    setState(() {
      _rows.insertAll(insertAt, copies);
      _setSelection(insertAt, _selCol);
      _isDirty = true;
      _rev++;
    });
    _updateSaveStatus();
    for (int i = 0; i < copies.length; i++) {
      _insertMobileRowCache(insertAt + i);
    }
    _pushUndoSnapshot();
    _queueSave();
    if (announce) {
      _emitActionResult(
        _ActionResult(
          ok: true,
          message: 'Fila duplicada en $safeTimes copia(s).',
          applied: safeTimes,
          undoToken: 'duplicate_row',
        ),
        successIcon: Icons.copy_all_outlined,
        onUndo: _undoOnce,
      );
    }
  }

  Future<void> _promptDuplicateRowCount(int row) async {
    if (row < 0 || row >= _rows.length) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'Selecciona una fila valida para duplicar.',
        ),
        failureIcon: Icons.info_outline_rounded,
      );
      return;
    }
    final controller = TextEditingController(text: '2');
    final count = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Duplicar fila'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Cantidad de copias',
              helperText: 'Min 1, max 100',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                Navigator.of(ctx).pop(parsed);
              },
              child: const Text('Duplicar'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!mounted || count == null) return;
    final safe = count.clamp(1, 100);
    _duplicateRowMultiple(row, times: safe);
  }

  void _insertNowInCell(int r, int c) {
    if (c < 0 || c >= _headers.length - 1) return;
    final now = DateTime.now();
    final stamp =
        '${now.year}-${_two(now.month)}-${_two(now.day)} ${_two(now.hour)}:${_two(now.minute)}';
    if (_mobileEditorOpen && _mobileRow == r && _mobileCol == c) {
      _mobileEC.value = _mobileEC.value.copyWith(
        text: stamp,
        selection: TextSelection.collapsed(offset: stamp.length),
        composing: TextRange.empty,
      );
      _requestMobileFocusWithRetry();
    } else {
      _setCell(r, c, stamp);
    }
  }

  Future<void> _promptFillDown(BuildContext context, int r, int c) async {
    if (c < 0 || c >= _headers.length - 1) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'Selecciona una celda editable para rellenar.',
        ),
        failureIcon: Icons.info_outline_rounded,
      );
      return;
    }
    final controller = TextEditingController(text: _fillDownCount.toString());
    final count = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Rellenar hacia abajo'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cantidad'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final v = int.tryParse(controller.text.trim());
                Navigator.of(ctx).pop(v);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!mounted) return;
    if (count == null || count <= 0) return;
    _fillDownCount = count;
    _fillDownColumn(r, c, count: count);
  }

  void _fillDownColumn(int r, int c, {required int count}) {
    if (c < 0 || c >= _headers.length - 1) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'Selecciona una celda editable para rellenar.',
        ),
        failureIcon: Icons.info_outline_rounded,
      );
      return;
    }
    if (r < 0 || r >= _rows.length) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'Selecciona una fila valida para rellenar.',
        ),
        failureIcon: Icons.info_outline_rounded,
      );
      return;
    }
    final value = (_mobileEditorOpen &&
            _mobileRow == r &&
            _mobileCol == c &&
            !_mobileEditingHeader)
        ? _mobileEC.text
        : _effectiveCell(r, c);
    if (count <= 0) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'La cantidad para rellenar debe ser mayor a cero.',
        ),
        failureIcon: Icons.info_outline_rounded,
      );
      return;
    }

    final targetRows = r + count;
    if (targetRows >= _rows.length) {
      final add = targetRows - _rows.length + 1;
      for (int i = 0; i < add; i++) {
        _rows.add(_RowModel.empty(_headers.length, id: _genStableId('r_')));
      }
      _ensureMobileRowCachesLength();
    }

    for (int rr = r + 1; rr <= r + count; rr++) {
      if (rr < 0 || rr >= _rows.length) continue;
      _rows[rr].cells[c] = value;
    }

    _markDirty(snapshot: true);
    _emitActionResult(
      _ActionResult(
        ok: true,
        message: 'Rellenado aplicado en $count fila(s).',
        applied: count,
        undoToken: 'fill_down',
      ),
      successIcon: Icons.vertical_align_bottom_rounded,
      onUndo: _undoOnce,
    );
  }

  void _incrementDownColumn(
    int r,
    int c, {
    required int count,
    required int step,
  }) {
    if (c < 0 || c >= _headers.length - 1) return;
    if (r < 0 || r >= _rows.length) return;
    final baseRaw = (_mobileEditorOpen &&
            _mobileRow == r &&
            _mobileCol == c &&
            !_mobileEditingHeader)
        ? _mobileEC.text
        : _effectiveCell(r, c);
    final base = _parseNumberCellValue(baseRaw);
    if (base == null) return;
    if (count <= 0) return;

    final targetRows = r + count;
    if (targetRows >= _rows.length) {
      final add = targetRows - _rows.length + 1;
      for (int i = 0; i < add; i++) {
        _rows.add(_RowModel.empty(_headers.length, id: _genStableId('r_')));
      }
      _ensureMobileRowCachesLength();
    }

    for (int i = 0; i <= count; i++) {
      final rr = r + i;
      if (rr < 0 || rr >= _rows.length) continue;
      final v = base + (i * step);
      _rows[rr].cells[c] = _formatNumber(v);
    }
    _markDirty(snapshot: true);
  }

  void _applyCalcToCell(int r, int c) {
    if (c < 0 || c >= _headers.length - 1) return;
    final raw = (_mobileEditorOpen &&
            _mobileRow == r &&
            _mobileCol == c &&
            !_mobileEditingHeader)
        ? _mobileEC.text
        : _effectiveCell(r, c);
    final res = _evalExpression(raw);
    if (res == null) return;
    final out = _formatNumber(res);
    if (_mobileEditorOpen && _mobileRow == r && _mobileCol == c) {
      _mobileEC.value = _mobileEC.value.copyWith(
        text: out,
        selection: TextSelection.collapsed(offset: out.length),
        composing: TextRange.empty,
      );
      _requestMobileFocusWithRetry();
    } else {
      _setCell(r, c, out);
    }
  }

  String _a1ColumnLabel(int col) {
    if (col < 0) return 'A';
    var n = col;
    final out = StringBuffer();
    while (n >= 0) {
      out.writeCharCode(65 + (n % 26));
      n = (n ~/ 26) - 1;
    }
    return out.toString().split('').reversed.join();
  }

  String _buildColumnSumFormula({
    required int col,
    required int startRowInclusive,
    required int endRowInclusive,
  }) {
    final letter = _a1ColumnLabel(col);
    final start = math.max(1, startRowInclusive + 1);
    final end = math.max(1, endRowInclusive + 1);
    return '=SUM($letter$start:$letter$end)';
  }

  String _buildSafeColumnAggregateFormula({
    required String functionName,
    required int col,
    required int excludingRow,
  }) {
    if (_rows.isEmpty) return '=$functionName(0)';
    var start = 1;
    var end = _rows.length;
    final selfRow = excludingRow + 1;
    if (_rows.length > 1 && selfRow >= start && selfRow <= end) {
      if (selfRow == end) {
        end -= 1;
      } else {
        start += 1;
      }
    }
    if (end < start) return '=$functionName(0)';
    final letter = _a1ColumnLabel(col);
    return '=$functionName($letter$start:$letter$end)';
  }

  Future<void> _suggestFormulaForSelection() async {
    if (!_hasActiveEditableCell(
      reason: 'Selecciona una celda editable para sugerir formulas.',
    )) {
      return;
    }
    if (!mounted) return;

    final col = _selCol.clamp(0, _headers.length - 2);
    final refRow = _selRow > 0 ? _selRow - 1 : _selRow;
    final refA1 = '${_a1ColumnLabel(col)}${refRow + 1}';
    final options = <({String label, String subtitle, String formula})>[
      (
        label: 'SUM columna',
        subtitle: 'Suma rapida para la columna activa',
        formula: _buildSafeColumnAggregateFormula(
          functionName: 'SUM',
          col: col,
          excludingRow: _selRow,
        ),
      ),
      (
        label: 'AVERAGE columna',
        subtitle: 'Promedio de la columna activa',
        formula: _buildSafeColumnAggregateFormula(
          functionName: 'AVERAGE',
          col: col,
          excludingRow: _selRow,
        ),
      ),
      (
        label: 'MAX columna',
        subtitle: 'Maximo en la columna activa',
        formula: _buildSafeColumnAggregateFormula(
          functionName: 'MAX',
          col: col,
          excludingRow: _selRow,
        ),
      ),
      (
        label: 'IF estado',
        subtitle: 'Chequeo rapido con umbral',
        formula: '=IF($refA1 > 10, "OK", "CHECK")',
      ),
      (
        label: 'ROUND',
        subtitle: 'Redondeo a 2 decimales',
        formula: '=ROUND($refA1, 2)',
      ),
      (
        label: 'NOW',
        subtitle: 'Timestamp de actualizacion',
        formula: '=NOW()',
      ),
    ];

    final picked = await showAppModal<String>(
      context: context,
      title: 'Sugerir funciones',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aplica una formula lista para la celda activa.',
            style: TextStyle(color: _palette(context).fgMuted),
          ),
          const SizedBox(height: 10),
          for (final item in options)
            ListTile(
              leading: const Icon(Icons.functions_rounded),
              title: Text(item.label),
              subtitle: Text('${item.subtitle}\n${item.formula}'),
              isThreeLine: true,
              onTap: () => Navigator.of(context).pop(item.formula),
            ),
        ],
      ),
      actions: [
        AppButton(
          label: AppStrings.cancel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
    if (picked == null || picked.trim().isEmpty) return;

    _setCell(_selRow, _selCol, picked);
    _emitActionResult(
      const _ActionResult(
        ok: true,
        message: 'Formula sugerida aplicada.',
        applied: 1,
        undoToken: 'suggest_formula',
      ),
      successIcon: Icons.lightbulb_outline_rounded,
      onUndo: _undoOnce,
    );
  }

  void _applyAutoSumForSelection() {
    if (!_hasActiveEditableCell(
      reason: 'Selecciona una celda editable para autosuma.',
    )) {
      return;
    }
    if (_selRow <= 0) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'Autosuma requiere al menos una fila previa.',
        ),
        failureIcon: Icons.info_outline_rounded,
      );
      return;
    }

    final formula = _buildColumnSumFormula(
      col: _selCol,
      startRowInclusive: 0,
      endRowInclusive: _selRow - 1,
    );
    _setCell(_selRow, _selCol, formula);
    _emitActionResult(
      const _ActionResult(
        ok: true,
        message: 'Autosuma aplicada en celda activa.',
        applied: 1,
        undoToken: 'auto_sum',
      ),
      successIcon: Icons.calculate_rounded,
      onUndo: _undoOnce,
    );
  }

  void _insertTotalsRowAutomation() {
    if (_headers.length <= 1) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'No hay columnas editables para generar totales.',
        ),
        failureIcon: Icons.info_outline_rounded,
      );
      return;
    }

    final dataCols = _headers.length - 1;
    final numericCols = <int>[];
    for (int c = 0; c < dataCols; c++) {
      final typedNumber = _colType(c) == _ColType.number;
      final hasNumericData = _rows.any(
        (row) =>
            c < row.cells.length && _parseNumberCellValue(row.cells[c]) != null,
      );
      if (typedNumber || hasNumericData) {
        numericCols.add(c);
      }
    }

    if (numericCols.isEmpty) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'No se detectaron columnas numericas para totalizar.',
        ),
        failureIcon: Icons.info_outline_rounded,
      );
      return;
    }

    final sourceRows = _rows.length;
    final row = _RowModel.empty(_headers.length, id: _genStableId('r_'));
    var labelCol = 0;
    for (int c = 0; c < dataCols; c++) {
      if (_colType(c) != _ColType.number) {
        labelCol = c;
        break;
      }
    }
    row.cells[labelCol] = 'TOTAL';
    for (final col in numericCols) {
      if (sourceRows <= 0) continue;
      row.cells[col] = _buildColumnSumFormula(
        col: col,
        startRowInclusive: 0,
        endRowInclusive: sourceRows - 1,
      );
    }

    final insertAt = _rows.length;
    _rows.add(row);
    _insertMobileRowCache(insertAt);
    _markFormulaGraphDirty();
    for (final col in numericCols) {
      _pendingFormulaSeeds.add(_CellRef(insertAt, col));
    }
    _markDirty(snapshot: true);
    _setSelectionAndRefreshGrid(
      insertAt,
      labelCol,
      preserveRowSelection: false,
    );
    _emitActionResult(
      _ActionResult(
        ok: true,
        message: 'Fila de totales creada (${numericCols.length} formulas).',
        applied: numericCols.length,
        undoToken: 'totals_row',
      ),
      successIcon: Icons.functions_rounded,
      onUndo: _undoOnce,
    );
  }

  String _formatNumber(num v) {
    if (v is int) return v.toString();
    final s = v.toStringAsFixed(6);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  double? _evalExpression(String raw) => evalExpression(raw);

  // ------------------------------ Filas -----------------------------------

  void _duplicateCellMetaRow(String fromRowId, String insertRowId) {
    if (_cellMeta.isEmpty) return;
    final updates = <String, CellMeta>{};
    _cellMeta.forEach((key, meta) {
      final ref = CellRef.fromKey(key, defaultSheetId: widget.sheetId);
      if (ref == null) return;
      if (ref.rowId != fromRowId) return;
      final nextRef = CellRef(
        sheetId: widget.sheetId,
        rowId: insertRowId,
        colId: ref.colId,
      );
      updates[nextRef.key] = meta.copy();
    });
    if (updates.isEmpty) return;
    _cellMeta.addAll(updates);
  }

  String _nextAutoIncrementValueForColumn(int c) {
    if (c < 0 || c >= _headers.length - 1) return '';
    String? seed;
    for (int r = _rows.length - 1; r >= 0; r--) {
      final value = _rows[r].cells[c].trim();
      if (value.isEmpty) continue;
      seed = value;
      break;
    }
    if (seed != null) {
      final match = RegExp(r'^(.*?)(\d+)$').firstMatch(seed);
      if (match != null) {
        final prefix = match.group(1) ?? '';
        final digits = match.group(2) ?? '';
        final parsed = int.tryParse(digits);
        if (parsed != null) {
          final next = (parsed + 1).toString().padLeft(digits.length, '0');
          return '$prefix$next';
        }
      }
      final asInt = int.tryParse(seed);
      if (asInt != null) return (asInt + 1).toString();
    }

    var maxParsed = 0;
    var foundAny = false;
    for (final row in _rows) {
      final value = row.cells[c].trim();
      if (value.isEmpty) continue;
      final match = RegExp(r'(\d+)$').firstMatch(value);
      final parsed = int.tryParse(match?.group(1) ?? '');
      if (parsed == null) continue;
      foundAny = true;
      if (parsed > maxParsed) maxParsed = parsed;
    }
    if (foundAny) return (maxParsed + 1).toString();
    return (_rows.length + 1).toString();
  }

  _RowModel _buildSmartDefaultRow() {
    final row = _RowModel.empty(_headers.length, id: _genStableId('r_'));
    final dataCols = _headers.length - 1;
    if (dataCols <= 0) return row;

    final dateValue = _formatDateCellValue(DateTime.now());
    for (int c = 0; c < dataCols; c++) {
      if (_defaultDateTodayEnabled && _colType(c) == _ColType.date) {
        row.cells[c] = dateValue;
      }
      if (_defaultStatusOkEnabled && _colType(c) == _ColType.status) {
        row.cells[c] = 'OK';
      }
      if (_autoIncrementIdEnabled && _isAutoIncrementColumn(c)) {
        row.cells[c] = _nextAutoIncrementValueForColumn(c);
      }
      if (row.cells[c].trim().isNotEmpty) {
        _rememberValueForColumn(c, row.cells[c]);
      }
    }
    return row;
  }

  int _firstEditableColumnIndex() {
    final visible = _visibleDataColumnIndexes();
    if (visible.isNotEmpty) return visible.first;
    return 0;
  }

  String _newRecordDefaultsSummary() {
    final defaults = <String>[];
    if (_defaultDateTodayEnabled) defaults.add('fecha hoy');
    if (_autoIncrementIdEnabled) defaults.add('progresiva auto');
    if (_defaultStatusOkEnabled) defaults.add('estado OK');
    if (defaults.isEmpty) return 'sin defaults';
    return defaults.join(', ');
  }

  bool _rowHasMetaForRow(String rowId) {
    for (final key in _cellMeta.keys) {
      final ref = CellRef.fromKey(key, defaultSheetId: widget.sheetId);
      if (ref == null) continue;
      if (ref.rowId == rowId) return true;
    }
    return false;
  }

  bool _shouldShowPremiumEmptyState() {
    return _rows.isEmpty;
  }

  Future<void> _openDemoTemplateSheet() async {
    if (!mounted) return;
    final picked = await showAppModal<DemoTemplateSpec>(
      context: context,
      title: 'Plantillas',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Elige una plantilla profesional para iniciar en segundos.',
            style: TextStyle(color: _palette(context).fgMuted),
          ),
          const SizedBox(height: 10),
          for (final spec in kDemoTemplateSpecs)
            ListTile(
              key: ValueKey('template-item-${spec.slug}'),
              leading: const Icon(Icons.grid_view_rounded),
              title: Text(spec.name),
              subtitle: Text(
                '${spec.headers.length} columnas | ${spec.rows.length} filas demo',
              ),
              onTap: () => Navigator.of(context).pop(spec),
            ),
        ],
      ),
      actions: [
        AppButton(
          label: AppStrings.cancel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
    if (picked == null || !mounted) return;
    _applyDemoTemplate(picked);
  }

  void _applyDemoTemplate(DemoTemplateSpec spec) {
    final headers = _normalizeHeaders(spec.headers);
    final rows = <_RowModel>[];
    for (final raw in spec.rows) {
      rows.add(
        _RowModel.fromCells(
          _normalizeRow(raw, headers.length),
          id: _genStableId('r_'),
        ),
      );
    }
    if (rows.isEmpty) {
      rows.add(_RowModel.empty(headers.length, id: _genStableId('r_')));
    }
    _sheetName = spec.sheetName;
    _nameEC.text = _sheetName;
    _headers = headers;
    _colIds = _normalizeColIds(headers, null);
    _columnPrefsById = _normalizeColumnPrefs(
      colIds: _colIds,
      incoming: const <String, _ColumnPrefs>{},
    );
    _columnOrder = _normalizeColumnOrder(colIds: _colIds, incoming: null);
    _frozenColId = null;
    _rows = rows;
    _selectedRows.clear();
    _rowSelectionAnchor = null;
    _selRow = 0;
    _selCol = 0;
    _draftCells.clear();
    _draftHeaders.clear();
    _markDirty(snapshot: true);
    _setSelectionAndRefreshGrid(0, 0, preserveRowSelection: false);
    unawaited(_markTemplateInteracted());
    _emitActionResult(
      _ActionResult(
        ok: true,
        message: 'Plantilla "${spec.name}" aplicada.',
        applied: spec.rows.length,
        undoToken: 'template_apply',
      ),
      successIcon: Icons.grid_view_rounded,
      onUndo: _undoOnce,
    );
  }

  void _applyDateTodayToSelection() {
    if (!_hasActiveEditableCell(
      reason: 'Selecciona una celda editable para aplicar fecha.',
    )) {
      return;
    }
    final rows = _batchTargetRows();
    if (rows.isEmpty) {
      _emitActionResult(
        const _ActionResult(ok: false, message: 'No hay filas seleccionadas.'),
        failureIcon: Icons.info_outline_rounded,
      );
      return;
    }
    final col = _selCol.clamp(0, _headers.length - 2);
    final value = formatDateTodayYmd(DateTime.now());
    var applied = 0;
    for (final row in rows) {
      if (row < 0 || row >= _rows.length) continue;
      _rows[row].cells[col] = value;
      applied++;
    }
    if (applied <= 0) return;
    _markDirty(snapshot: true);
    _emitActionResult(
      _ActionResult(
        ok: true,
        message: 'Fecha de hoy aplicada ($applied celdas).',
        applied: applied,
        undoToken: 'date_today',
      ),
      successIcon: Icons.today_rounded,
      onUndo: _undoOnce,
    );
  }

  Future<void> _runAutonumberProgressiveAction() async {
    if (!_hasActiveEditableCell(
      reason: 'Selecciona una celda editable para autonumerar.',
    )) {
      return;
    }
    final rows = _batchTargetRows();
    if (rows.isEmpty) {
      _emitActionResult(
        const _ActionResult(ok: false, message: 'No hay filas seleccionadas.'),
        failureIcon: Icons.info_outline_rounded,
      );
      return;
    }
    final stepController = TextEditingController(
      text: _progressiveAutoStep.toString(),
    );
    final step = await showAppModal<int>(
      context: context,
      title: 'Autonumerar progresiva',
      child: TextField(
        controller: stepController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Incremento (default 10)'),
      ),
      actions: [
        AppButton(
          label: AppStrings.cancel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: 'Aplicar',
          variant: AppButtonVariant.primary,
          onPressed: () => Navigator.of(context)
              .pop(int.tryParse(stepController.text.trim())),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
    stepController.dispose();
    if (step == null || step <= 0) return;
    _progressiveAutoStep = step;
    final col = _selCol.clamp(0, _headers.length - 2);
    final base = int.tryParse(_effectiveCell(_selRow, col).trim()) ?? step;
    final series = buildProgressiveSeries(
      start: base,
      step: step,
      count: rows.length,
    );
    var applied = 0;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row < 0 || row >= _rows.length) continue;
      _rows[row].cells[col] = series[i].toString();
      applied++;
    }
    if (applied <= 0) return;
    _markDirty(snapshot: true);
    _emitActionResult(
      _ActionResult(
        ok: true,
        message: 'Autonumerado aplicado ($applied celdas).',
        applied: applied,
        undoToken: 'autonumber_progressive',
      ),
      successIcon: Icons.auto_mode_rounded,
      onUndo: _undoOnce,
    );
  }

  bool _newRecordWasEdited(
    _RowModel row, {
    required List<String> baselineCells,
  }) {
    if (row.cells.length != baselineCells.length) return true;
    for (int i = 0; i < row.cells.length; i++) {
      if (row.cells[i] != baselineCells[i]) return true;
    }
    if (row.photos.isNotEmpty) return true;
    if (row.gpsLat != null || row.gpsLng != null) return true;
    if (row.reviewed) return true;
    if (_rowHasMetaForRow(row.id)) return true;
    return false;
  }

  Future<bool> _confirmUndoEditedNewRecord() async {
    if (!mounted) return false;
    final accepted = await showAppModal<bool>(
      context: context,
      title: 'Deshacer nuevo registro',
      child: const Text(
        'La fila fue modificada despues de crearla. Quieres eliminarla igual?',
      ),
      actions: [
        AppButton(
          label: AppStrings.cancel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: 'Eliminar fila',
          icon: Icons.delete_outline_rounded,
          variant: AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
    return accepted == true;
  }

  Future<void> _undoNewRecordById(
    String rowId, {
    required List<String> baselineCells,
  }) async {
    final rowIndex = _rows.indexWhere((row) => row.id == rowId);
    if (rowIndex < 0 || rowIndex >= _rows.length) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'No se pudo deshacer: la fila ya no existe.',
        ),
        failureIcon: Icons.info_outline_rounded,
      );
      return;
    }
    final row = _rows[rowIndex];
    final edited = _newRecordWasEdited(row, baselineCells: baselineCells);
    if (edited) {
      final accepted = await _confirmUndoEditedNewRecord();
      if (!accepted) {
        _emitActionResult(
          const _ActionResult(
            ok: false,
            message: 'Se mantuvo la fila creada.',
          ),
          failureIcon: Icons.info_outline_rounded,
        );
        return;
      }
    }

    _deleteRow(rowIndex);
    _emitActionResult(
      const _ActionResult(
        ok: true,
        message: 'Nuevo registro revertido.',
        applied: 1,
      ),
      successIcon: Icons.undo_rounded,
    );
  }

  Future<_ActionResult> _createNewRecordAction({
    bool emitFeedback = true,
    String origin = 'manual',
  }) async {
    if (_headers.length <= 1) {
      final result = const _ActionResult(
        ok: false,
        message: 'No hay columnas editables para crear un registro.',
      );
      if (emitFeedback) {
        _emitActionResult(
          result,
          failureIcon: Icons.info_outline_rounded,
        );
      }
      return result;
    }

    final insertAt = _rows.length;
    final targetCol = _firstEditableColumnIndex();
    final row = _buildSmartDefaultRow();
    final rowId = row.id;
    final baselineCells = List<String>.from(row.cells, growable: false);
    setState(() {
      _rows.insert(insertAt, row);
      _setSelection(insertAt, targetCol);
      _isDirty = true;
      _rev++;
    });
    _updateSaveStatus();
    _insertMobileRowCache(insertAt);
    _pushUndoSnapshot();
    _queueSave();
    _addHistoryEvent(
      type: 'new_record',
      message: 'Nuevo registro ${insertAt + 1}',
      origin: origin,
      row: insertAt,
      col: targetCol,
    );

    _setSelectionAndRefreshGrid(
      insertAt,
      targetCol,
      blink: true,
      preserveRowSelection: true,
    );

    final result = _ActionResult(
      ok: true,
      message: 'Nuevo registro listo (${_newRecordDefaultsSummary()}).',
      applied: 1,
      undoToken: 'new_record',
    );
    if (emitFeedback) {
      _emitActionResult(
        result,
        successIcon: Icons.add_box_outlined,
        onUndo: () => unawaited(
          _undoNewRecordById(
            rowId,
            baselineCells: baselineCells,
          ),
        ),
      );
    }
    return result;
  }

  void _insertRow(int index) {
    final idx = index.clamp(0, _rows.length);
    final row = _buildSmartDefaultRow();
    setState(() {
      _rows.insert(idx, row);
      _setSelection(idx, _selCol);
      _isDirty = true;
      _rev++;
    });
    _updateSaveStatus();
    _insertMobileRowCache(idx);
    if (!_suspendUndoSnapshot) {
      _pushUndoSnapshot();
    }
    _queueSave();
    _addHistoryEvent(
      type: 'insert_row',
      message: 'Insertar fila ${idx + 1}',
      origin: 'manual',
      row: idx,
    );
  }

  int _resolveFormRowIndex({int? rowIndex, required bool createNew}) {
    if (_rows.isEmpty) {
      _rows.add(_buildSmartDefaultRow());
      _insertMobileRowCache(0);
    }
    if (createNew) {
      final insertAt = _rows.length;
      _insertRow(insertAt);
      return insertAt.clamp(0, _rows.length - 1);
    }
    if (rowIndex != null) {
      return rowIndex.clamp(0, _rows.length - 1);
    }
    return _selRow.clamp(0, _rows.length - 1);
  }

  int? _firstColumnByType(_ColType type) {
    for (int c = 0; c < _headers.length - 1; c++) {
      if (_colType(c) == type) return c;
    }
    return null;
  }

  String _normalizeFlowBotToken(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.isEmpty) return '';
    final map = <String, String>{
      'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡': 'a',
      'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©': 'e',
      'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­': 'i',
      'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³': 'o',
      'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âº': 'u',
      'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¼': 'u',
      'ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â±': 'n',
    };
    final sb = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      sb.write(map[ch] ?? ch);
    }
    return sb.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  int? _firstColumnMatchingFlowBotName(String name) {
    final query = _normalizeFlowBotToken(name);
    if (query.isEmpty) return null;
    for (int c = 0; c < _headers.length - 1; c++) {
      final label = _normalizeFlowBotToken(_headerLabel(c));
      if (label == query || label.contains(query) || query.contains(label)) {
        return c;
      }
    }
    return null;
  }

  Map<int, String> _parseFlowBotColumnAssignments(String? raw) {
    final out = <int, String>{};
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return out;
    for (final chunk in text.split(',')) {
      final pair = chunk.trim();
      if (pair.isEmpty) continue;
      final separator = pair.indexOf('=');
      if (separator <= 0 || separator >= pair.length - 1) continue;
      final key = pair.substring(0, separator).trim();
      final value = pair.substring(separator + 1).trim();
      if (key.isEmpty) continue;
      final col = _firstColumnMatchingFlowBotName(key);
      if (col == null) continue;
      out[col] = value;
    }
    return out;
  }

  int _addFlowBotColumn(String label) {
    final cleaned = label.trim();
    if (cleaned.isEmpty) {
      throw StateError('FlowBot necesita un nombre de columna valido.');
    }
    final insertAt = math.max(0, _headers.length - 1);
    final colId = _genStableId('c_');
    _headers.insert(insertAt, cleaned);
    _colIds.insert(insertAt, colId);
    for (final row in _rows) {
      final safeInsertAt = insertAt.clamp(0, row.cells.length);
      row.cells.insert(safeInsertAt, '');
    }
    _columnPrefsById[colId] = const _ColumnPrefs(type: _ColType.text);
    if (!_columnOrder.contains(colId)) {
      _columnOrder.add(colId);
    }
    _columnPrefsById = _normalizeColumnPrefs(
      colIds: _colIds,
      incoming: _columnPrefsById,
    );
    _columnOrder = _normalizeColumnOrder(
      colIds: _colIds,
      incoming: _columnOrder,
    );
    _frozenColId = _normalizeFrozenColId(
      colIds: _colIds,
      requested: _frozenColId,
    );
    _markDirty(snapshot: true);
    _bumpGridVersion();
    _addHistoryEvent(
      type: 'add_column',
      message: 'Agregar columna $cleaned',
      origin: 'flowbot',
      col: insertAt,
    );
    return insertAt;
  }

  void _renameFlowBotColumn(int col, String label) {
    if (col < 0 || col >= _headers.length - 1) {
      throw StateError('FlowBot no encontro la columna a renombrar.');
    }
    final cleaned = label.trim();
    if (cleaned.isEmpty) {
      throw StateError('FlowBot necesita un nombre de columna valido.');
    }
    final previous = _headers[col];
    if (previous == cleaned) return;
    _headers[col] = cleaned;
    _markDirty(snapshot: true);
    _bumpGridVersion();
    _addHistoryEvent(
      type: 'rename_column',
      message:
          'Renombrar columna ${previous.trim().isEmpty ? col + 1 : previous}',
      origin: 'flowbot',
      col: col,
      beforeValue: previous,
      afterValue: cleaned,
    );
  }

  Future<void> _openRowFormMode({int? rowIndex, bool createNew = false}) async {
    if (!mounted || _headers.length <= 1) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final targetRow = _resolveFormRowIndex(
      rowIndex: rowIndex,
      createNew: createNew,
    );
    if (targetRow < 0 || targetRow >= _rows.length) return;

    final orderedCols = _orderedDataColumnIndexes();
    if (orderedCols.isEmpty) return;

    final controllers = <int, TextEditingController>{};
    for (final col in orderedCols) {
      final value = col < _rows[targetRow].cells.length
          ? _rows[targetRow].cells[col]
          : '';
      controllers[col] = TextEditingController(text: value);
    }

    final dateCol = _firstColumnByType(_ColType.date);
    final gpsCol = (_resolveQuickCaptureGpsColumn(
      dateCol ?? 0,
    )).clamp(0, _headers.length - 2);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final pal = _palette(ctx);
        var saving = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final formIssues = <int, String>{};
            var pendingRequired = 0;
            for (final col in orderedCols) {
              final message = _validationMessageForValue(
                col: col,
                rawValue: controllers[col]!.text,
              );
              if (message == null) continue;
              formIssues[col] = message;
              if (message == 'Campo requerido') {
                pendingRequired++;
              }
            }
            final canSaveForm = !saving && formIssues.isEmpty;

            Future<void> runPhoto() async {
              setModalState(() => saving = true);
              await _startPhotoFlowForCell(targetRow, _headers.length - 1);
              if (!ctx.mounted) return;
              setModalState(() => saving = false);
            }

            Future<void> runGps() async {
              setModalState(() => saving = true);
              await _requestGpsForCell(targetRow, gpsCol);
              if (!ctx.mounted) return;
              setModalState(() => saving = false);
            }

            void applyTimestampNow() {
              final now = DateTime.now();
              final text = dateCol != null
                  ? _formatDateCellValue(now)
                  : _quickCaptureTimestampText(now);
              final targetCol = dateCol ?? orderedCols.first;
              final ctrl = controllers[targetCol];
              if (ctrl == null) return;
              ctrl.value = ctrl.value.copyWith(
                text: text,
                selection: TextSelection.collapsed(offset: text.length),
                composing: TextRange.empty,
              );
            }

            return SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 12,
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom + 12,
                ),
                decoration: BoxDecoration(
                  color: pal.menuBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: pal.border, width: pal.hairline),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Formulario - fila ${targetRow + 1}',
                            style: TextStyle(
                              color: pal.fg,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed:
                              saving ? null : () => Navigator.of(ctx).pop(),
                          icon: Icon(Icons.close_rounded, color: pal.fgMuted),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppButton(
                          label: 'Adjuntar foto',
                          icon: Icons.photo_camera_outlined,
                          size: AppButtonSize.sm,
                          variant: AppButtonVariant.secondary,
                          onPressed: saving ? null : runPhoto,
                        ),
                        AppButton(
                          label: 'Adjuntar GPS',
                          icon: Icons.my_location_rounded,
                          size: AppButtonSize.sm,
                          variant: AppButtonVariant.secondary,
                          onPressed: saving ? null : runGps,
                        ),
                        AppButton(
                          label: 'Timestamp',
                          icon: Icons.schedule_rounded,
                          size: AppButtonSize.sm,
                          variant: AppButtonVariant.ghost,
                          onPressed: saving ? null : applyTimestampNow,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      key: const ValueKey('row-form-quality'),
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: formIssues.isEmpty
                            ? pal.hintBg
                            : Theme.of(ctx)
                                .colorScheme
                                .errorContainer
                                .withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: formIssues.isEmpty
                              ? pal.border
                              : Theme.of(ctx)
                                  .colorScheme
                                  .error
                                  .withValues(alpha: 0.35),
                          width: pal.hairline,
                        ),
                      ),
                      child: Text(
                        formIssues.isEmpty
                            ? 'Formulario listo para guardar.'
                            : pendingRequired > 0
                                ? '$pendingRequired campo(s) obligatorio(s) pendiente(s) y ${formIssues.length} validacion(es) por corregir.'
                                : '${formIssues.length} validacion(es) por corregir antes de guardar.',
                        style: TextStyle(
                          color: formIssues.isEmpty
                              ? pal.fgMuted
                              : Theme.of(ctx).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final col in orderedCols)
                              _buildFormFieldForColumn(
                                context: ctx,
                                palette: pal,
                                col: col,
                                controller: controllers[col]!,
                                setModalState: setModalState,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: AppStrings.cancel,
                            variant: AppButtonVariant.ghost,
                            onPressed:
                                saving ? null : () => Navigator.of(ctx).pop(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            key: const ValueKey('row-form-save'),
                            label: AppStrings.save,
                            icon: Icons.check_rounded,
                            variant: AppButtonVariant.primary,
                            onPressed: canSaveForm
                                ? () {
                                    final refsToClear = <_CellRef>[];
                                    var changed = false;
                                    for (final col in orderedCols) {
                                      final next = _normalizeCellValueForColumn(
                                        col,
                                        controllers[col]!.text,
                                      );
                                      if (_rows[targetRow].cells[col] == next) {
                                        continue;
                                      }
                                      _rows[targetRow].cells[col] = next;
                                      _rememberValueForColumn(col, next);
                                      refsToClear.add(_CellRef(targetRow, col));
                                      changed = true;
                                    }
                                    if (changed) {
                                      _clearCellDrafts(refsToClear);
                                      _setSelection(
                                        targetRow,
                                        _selCol.clamp(0, _headers.length - 1),
                                      );
                                      _markDirty(snapshot: true);
                                    }
                                    Navigator.of(ctx).pop();
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  Widget _buildFormFieldForColumn({
    required BuildContext context,
    required _SheetPalette palette,
    required int col,
    required TextEditingController controller,
    required StateSetter setModalState,
  }) {
    final type = _colType(col);
    final label = _headerLabel(col);
    final validationMessage = _validationMessageForValue(
      col: col,
      rawValue: controller.text,
    );
    final required = _isRequired(col);
    final errorColor = Theme.of(context).colorScheme.error;
    final border = Border.all(
      color: validationMessage == null ? palette.border : errorColor,
      width: palette.hairline,
    );

    Widget field;
    switch (type) {
      case _ColType.status:
        final current = controller.text.trim();
        final options =
            _statusOptionsForCol(col) ?? const <String>['OK', 'Obs', 'Urgente'];
        field = Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final status in options)
              ChoiceChip(
                label: Text(status),
                selected: current.toLowerCase() == status.toLowerCase(),
                onSelected: (_) {
                  controller.value = controller.value.copyWith(
                    text: status,
                    selection: TextSelection.collapsed(offset: status.length),
                    composing: TextRange.empty,
                  );
                  setModalState(() {});
                },
              ),
          ],
        );
        break;
      case _ColType.checkbox:
        final value = _parseCheckboxCellValue(controller.text) ?? false;
        field = SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: value,
          title: Text(value ? 'Marcado' : 'Sin marcar'),
          onChanged: (next) {
            controller.text = next ? '1' : '0';
            setModalState(() {});
          },
        );
        break;
      case _ColType.number:
        field = TextField(
          key: ValueKey('row-form-field-$col'),
          controller: controller,
          onChanged: (_) => setModalState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'Numero (acepta , y .)',
            border: InputBorder.none,
            isDense: true,
          ),
        );
        break;
      case _ColType.date:
        field = TextField(
          key: ValueKey('row-form-field-$col'),
          controller: controller,
          onChanged: (_) => setModalState(() {}),
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(
            hintText: 'dd/MM/yyyy',
            border: InputBorder.none,
            isDense: true,
          ),
        );
        break;
      default:
        field = TextField(
          key: ValueKey('row-form-field-$col'),
          controller: controller,
          onChanged: (_) => setModalState(() {}),
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            hintText: 'Escribir...',
            border: InputBorder.none,
            isDense: true,
          ),
        );
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: palette.hintBg,
          borderRadius: BorderRadius.circular(12),
          border: border,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: palette.fgMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                if (required)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: palette.menuBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: palette.border,
                        width: palette.hairline,
                      ),
                    ),
                    child: Text(
                      'Obligatorio',
                      style: TextStyle(
                        color: palette.fgMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            if (validationMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                validationMessage,
                style: TextStyle(
                  color: errorColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ],
            const SizedBox(height: 4),
            field,
          ],
        ),
      ),
    );
  }

  void _deleteRow(int r) {
    if (_rows.isEmpty) return;
    final idx = r.clamp(0, _rows.length - 1);
    final rowId = _rows[idx].id;

    final toDelete = List<_RowPhoto>.from(_rows[idx].photos);
    final metaPhotos = <PhotoAttachment>[];
    final metaAudios = <AudioAttachment>[];
    final keysToRemove = <String>[];
    _cellMeta.forEach((key, meta) {
      final ref = CellRef.fromKey(key, defaultSheetId: widget.sheetId);
      if (ref == null) return;
      if (ref.rowId != rowId) return;
      keysToRemove.add(key);
      metaPhotos.addAll(meta.photos);
      metaAudios.addAll(meta.audios);
    });
    for (final k in keysToRemove) {
      _cellMeta.remove(k);
    }

    setState(() {
      _rows.removeAt(idx);
      if (_rows.isEmpty) {
        _rows.add(_RowModel.empty(_headers.length, id: _genStableId('r_')));
      }
      _setSelection(_selRow, _selCol);
      _isDirty = true;
      _rev++;
    });
    _updateSaveStatus();

    for (final p in toDelete) {
      if (p.path.trim().isNotEmpty) {
        unawaited(_attachmentStore.delete(p.path));
      }
    }
    for (final p in metaPhotos) {
      if (p.storedRef.trim().isNotEmpty) {
        unawaited(_attachmentStore.delete(p.storedRef));
      }
    }
    for (final a in metaAudios) {
      final keyRef = _audioKeyFromRef(a.storedRef);
      if (keyRef.trim().isNotEmpty) {
        unawaited(_audioStore.deleteAudio(keyRef));
      }
    }
    _removeMobileRowCache(idx);
    _ensureMobileRowCachesLength();
    if (!_suspendUndoSnapshot) {
      _pushUndoSnapshot();
    }
    _queueSave();
    _addHistoryEvent(
      type: 'delete_row',
      message: 'Eliminar fila ${idx + 1}',
      origin: 'manual',
      row: idx,
    );
  }

  // ------------------------------ Clipboard -------------------------------

  Future<void> _copySelectionToClipboard() async {
    if (!_hasActiveEditableCell(
      reason: 'Selecciona una celda editable para copiar.',
    )) {
      return;
    }
    final txt = _getCellText(_selRow, _selCol);
    try {
      await Clipboard.setData(ClipboardData(text: txt));
      _emitActionResult(
        _ActionResult(
          ok: true,
          message:
              txt.trim().isEmpty ? 'Celda vacia copiada.' : 'Celda copiada.',
          applied: 1,
        ),
        successIcon: Icons.copy_rounded,
      );
    } catch (_) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'No se pudo copiar la celda activa.',
        ),
        failureIcon: Icons.copy_all_outlined,
      );
    }
  }

  Future<void> _copyActiveMobileCell() async {
    if (!_mobileEditorOpen) return;
    if (_mobileEditingHeader) return;
    final txt = _mobileEC.text;
    try {
      await Clipboard.setData(ClipboardData(text: txt));
      _emitActionResult(
        _ActionResult(
          ok: true,
          message:
              txt.trim().isEmpty ? 'Celda vacia copiada.' : 'Celda copiada.',
          applied: 1,
        ),
        successIcon: Icons.copy_rounded,
      );
    } catch (_) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'No se pudo copiar la celda activa.',
        ),
        failureIcon: Icons.copy_all_outlined,
      );
    }
  }

  Future<void> _pasteIntoActiveMobileCell() async {
    if (!_mobileEditorOpen) return;
    if (_mobileEditingHeader) return;
    String raw = '';
    try {
      final data = await Clipboard.getData('text/plain');
      raw = data?.text ?? '';
    } catch (_) {}
    if (raw.isEmpty) return;

    _mobileEC.value = _mobileEC.value.copyWith(
      text: raw,
      selection: TextSelection.collapsed(offset: raw.length),
      composing: TextRange.empty,
    );
    _requestMobileFocusWithRetry();
  }

  String _getCellText(int r, int c) {
    if (r < 0 || r >= _rows.length) return '';
    if (c < 0 || c >= _headers.length) return '';
    if (c == _headers.length - 1) return '';
    return _rows[r].cells[c];
  }

  String _smartTableDelimiterLabel(SmartTableDelimiter delimiter) {
    switch (delimiter) {
      case SmartTableDelimiter.tab:
        return 'TSV';
      case SmartTableDelimiter.comma:
        return 'CSV';
      case SmartTableDelimiter.semicolon:
        return 'CSV ;';
      case SmartTableDelimiter.singleValue:
        return 'texto';
    }
  }

  String _smartPasteModeLabel(_SmartPasteMode mode) {
    switch (mode) {
      case _SmartPasteMode.insertRows:
        return 'Insertar filas';
      case _SmartPasteMode.replaceFromActive:
        return 'Reemplazar desde celda activa';
    }
  }

  String _smartPasteCountLabel(int count, String singular, String plural) {
    final safe = math.max(0, count);
    final label = safe == 1 ? singular : plural;
    return '$safe $label';
  }

  String _smartPasteDetectedMessage(SmartTableParseResult parsed) {
    return 'Bloque detectado: '
        '${_smartPasteCountLabel(parsed.rowCount, 'fila', 'filas')} x '
        '${_smartPasteCountLabel(parsed.columnCount, 'columna', 'columnas')} '
        '(${_smartTableDelimiterLabel(parsed.delimiter)}).';
  }

  String _smartPasteResultMessage({
    required SmartTableParseResult parsed,
    required bool usedHeaders,
    required int changedCells,
    required int changedHeaders,
    required int addedRows,
    required int addedColumns,
  }) {
    final lines = <String>[_smartPasteDetectedMessage(parsed)];
    if (usedHeaders) {
      lines.add('Se usó la primera fila como encabezados.');
    }
    if (addedRows > 0 || addedColumns > 0) {
      final additions = <String>[];
      if (addedRows > 0) {
        additions.add(_smartPasteCountLabel(addedRows, 'fila', 'filas'));
      }
      if (addedColumns > 0) {
        additions.add(
          _smartPasteCountLabel(addedColumns, 'columna', 'columnas'),
        );
      }
      lines.add('Se agregaron ${additions.join(' y ')}.');
    }
    if (changedHeaders > 0 && changedCells > 0) {
      lines.add(
        'Se actualizaron '
        '${_smartPasteCountLabel(changedHeaders, 'encabezado', 'encabezados')} '
        'y ${_smartPasteCountLabel(changedCells, 'celda', 'celdas')}.',
      );
    } else if (changedHeaders > 0) {
      lines.add(
        'Se actualizaron '
        '${_smartPasteCountLabel(changedHeaders, 'encabezado', 'encabezados')}.',
      );
    } else if (changedCells > 0) {
      lines.add(
        'Se actualizaron '
        '${_smartPasteCountLabel(changedCells, 'celda', 'celdas')}.',
      );
    } else if (addedRows > 0 || addedColumns > 0) {
      lines.add('El bloque quedó listo para editar.');
    }
    return lines.join('\n');
  }

  String _smartPasteProgressMessage({
    required int rows,
    required int cols,
    required int processed,
    required int total,
  }) {
    final safeTotal = total <= 0 ? 1 : total;
    final pct = ((processed / safeTotal) * 100).round().clamp(0, 100);
    return 'Pegando tabla ${rows}x$cols... $pct% ($processed/$safeTotal)';
  }

  List<List<String>> _smartPastePreviewRows(
    SmartTableParseResult parsed, {
    int maxRows = 3,
  }) {
    if (parsed.cells.isEmpty) return const <List<String>>[];
    return parsed.cells.take(maxRows).toList(growable: false);
  }

  ({int addedColumns, List<_SmartPasteUndoColumn> columns})
      _ensureSmartPasteEditableColumns({
    required int startCol,
    required int requiredColumns,
  }) {
    final expansion = planSmartTableExpansion(
      existingEditableColumns: math.max(0, _headers.length - 1),
      startCol: startCol,
      requiredColumns: requiredColumns,
    );
    final addedColumns = expansion.addedColumns;
    if (addedColumns <= 0) {
      return (
        addedColumns: 0,
        columns: const <_SmartPasteUndoColumn>[],
      );
    }

    final added = <_SmartPasteUndoColumn>[];
    for (int i = 0; i < addedColumns; i++) {
      final insertAt = math.max(0, _headers.length - 1);
      final colId = _genStableId('c_');
      _headers.insert(insertAt, '');
      _colIds.insert(insertAt, colId);
      for (final row in _rows) {
        final safeInsertAt = insertAt.clamp(0, row.cells.length);
        row.cells.insert(safeInsertAt, '');
      }
      _columnPrefsById[colId] = const _ColumnPrefs(type: _ColType.text);
      if (!_columnOrder.contains(colId)) {
        _columnOrder.add(colId);
      }
      added.add(_SmartPasteUndoColumn(colId: colId));
    }

    _columnPrefsById = _normalizeColumnPrefs(
      colIds: _colIds,
      incoming: _columnPrefsById,
    );
    _columnOrder = _normalizeColumnOrder(
      colIds: _colIds,
      incoming: _columnOrder,
    );
    _frozenColId = _normalizeFrozenColId(
      colIds: _colIds,
      requested: _frozenColId,
    );

    return (
      addedColumns: addedColumns,
      columns: List<_SmartPasteUndoColumn>.unmodifiable(added),
    );
  }

  Future<_SmartPasteUserChoice?> _showSmartPasteOptionsSheet(
    SmartTableParseResult parsed,
  ) async {
    if (!mounted) return null;
    var mode = _SmartPasteMode.replaceFromActive;
    var firstRowIsHeader = parsed.rowCount > 1 && parsed.columnCount > 1;
    final previewRows = _smartPastePreviewRows(parsed);
    final extraRows = parsed.rowCount > previewRows.length
        ? parsed.rowCount - previewRows.length
        : 0;
    return showModalBottomSheet<_SmartPasteUserChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final pal = _palette(ctx);
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              top: false,
              child: Container(
                key: const Key('smart_paste_sheet'),
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: pal.menuBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: pal.border, width: pal.hairline),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _smartPasteDetectedMessage(parsed),
                      key: const Key('smart_paste_detect_label'),
                      style: TextStyle(
                        color: pal.fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Preview (primeras ${previewRows.length} fila(s))',
                      style: TextStyle(
                        color: pal.fgMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 156),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: pal.hintBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: pal.border,
                          width: pal.hairline,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int i = 0; i < previewRows.length; i++)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: i == previewRows.length - 1 ? 0 : 6,
                                ),
                                child: Text(
                                  previewRows[i]
                                      .map((cell) => cell.isEmpty ? '-' : cell)
                                      .join(' | '),
                                  style: TextStyle(
                                    color: pal.fg,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (extraRows > 0)
                              Text(
                                '+$extraRows fila(s) mas',
                                style: TextStyle(
                                  color: pal.fgMuted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<_SmartPasteMode>(
                      groupValue: mode,
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() => mode = value);
                      },
                      child: Column(
                        children: [
                          RadioListTile<_SmartPasteMode>(
                            key: const Key('smart_paste_mode_replace'),
                            value: _SmartPasteMode.replaceFromActive,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Reemplazar desde celda activa'),
                          ),
                          RadioListTile<_SmartPasteMode>(
                            key: const Key('smart_paste_mode_insert'),
                            value: _SmartPasteMode.insertRows,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Insertar filas'),
                          ),
                        ],
                      ),
                    ),
                    SwitchListTile.adaptive(
                      key: const Key('smart_paste_toggle_header'),
                      value: firstRowIsHeader,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Usar primera fila como encabezados'),
                      subtitle: firstRowIsHeader
                          ? const Text(
                              'La primera fila renombra columnas; el resto se pega como datos.',
                            )
                          : const Text(
                              'Todo el bloque se pega como datos.',
                            ),
                      onChanged: (value) =>
                          setModalState(() => firstRowIsHeader = value),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: AppStrings.cancel,
                            variant: AppButtonVariant.ghost,
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            key: const Key('smart_paste_apply'),
                            label: 'Aplicar',
                            icon: Icons.check_rounded,
                            variant: AppButtonVariant.primary,
                            onPressed: () {
                              Navigator.of(ctx).pop(
                                _SmartPasteUserChoice(
                                  mode: mode,
                                  firstRowIsHeader: firstRowIsHeader,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _undoSmartPasteSnapshot(_SmartPasteUndoSnapshot snapshot) async {
    final refsToClear = <_CellRef>[];
    final changedRowIds = <String>{};
    final removedIndexes = <int>[];
    var removedColumns = false;

    for (int i = snapshot.insertedRowIds.length - 1; i >= 0; i--) {
      final rowId = snapshot.insertedRowIds[i];
      final index = _rows.indexWhere((row) => row.id == rowId);
      if (index < 0 || index >= _rows.length) continue;
      _rows.removeAt(index);
      removedIndexes.add(index);
    }
    for (final index in removedIndexes) {
      _removeMobileRowCache(index);
    }
    _ensureMobileRowCachesLength();

    for (final header in snapshot.headers) {
      if (header.col < 0 || header.col >= _headers.length - 1) continue;
      _headers[header.col] = header.previousValue;
    }

    for (final cell in snapshot.cells) {
      final rowIndex = _rows.indexWhere((row) => row.id == cell.rowId);
      if (rowIndex < 0 || rowIndex >= _rows.length) continue;
      if (cell.col < 0 || cell.col >= _headers.length - 1) continue;
      if (_rows[rowIndex].cells[cell.col] == cell.previousValue) continue;
      _rows[rowIndex].cells[cell.col] = cell.previousValue;
      refsToClear.add(_CellRef(rowIndex, cell.col));
      changedRowIds.add(cell.rowId);
    }

    if (snapshot.columns.isNotEmpty) {
      final removedColIds = <String>{
        for (final column in snapshot.columns) column.colId,
      };
      final cellMetaKeysToRemove = <String>[];
      for (int i = snapshot.columns.length - 1; i >= 0; i--) {
        final colId = snapshot.columns[i].colId;
        final colIndex = _colIds.indexOf(colId);
        if (colIndex < 0 || colIndex >= _headers.length - 1) continue;
        _headers.removeAt(colIndex);
        _colIds.removeAt(colIndex);
        _columnPrefsById.remove(colId);
        _columnOrder.removeWhere((entry) => entry == colId);
        for (final row in _rows) {
          if (colIndex >= 0 && colIndex < row.cells.length) {
            row.cells.removeAt(colIndex);
          }
        }
        removedColumns = true;
      }
      _frozenColId = _normalizeFrozenColId(
        colIds: _colIds,
        requested: _frozenColId,
      );
      _cellMeta.forEach((key, _) {
        final ref = CellRef.fromKey(key, defaultSheetId: widget.sheetId);
        if (ref == null) return;
        if (removedColIds.contains(ref.colId)) {
          cellMetaKeysToRemove.add(key);
        }
      });
      for (final key in cellMetaKeysToRemove) {
        _cellMeta.remove(key);
      }
    }

    if (removedIndexes.isEmpty &&
        refsToClear.isEmpty &&
        snapshot.headers.isEmpty &&
        !removedColumns) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'No se pudo deshacer el pegado.',
        ),
        failureIcon: Icons.info_outline_rounded,
      );
      return;
    }

    if (_rows.isEmpty) {
      _rows.add(_RowModel.empty(_headers.length, id: _genStableId('r_')));
      _insertMobileRowCache(0);
    }

    if (refsToClear.isNotEmpty) {
      _clearCellDrafts(refsToClear);
    }
    for (final rowId in changedRowIds) {
      _bumpRowVersionById(rowId);
    }
    if (removedIndexes.isNotEmpty ||
        snapshot.headers.isNotEmpty ||
        removedColumns) {
      _bumpGridVersion();
    }

    final maxRow = math.max(0, _rows.length - 1);
    final maxCol = math.max(0, _headers.length - 2);
    _setSelection(
      snapshot.previousSelRow.clamp(0, maxRow),
      snapshot.previousSelCol.clamp(0, maxCol),
      preserveRowSelection: true,
    );
    _markDirty(snapshot: true);
    _addHistoryEvent(
      type: 'smart_paste_undo',
      message: 'Deshacer pegado inteligente',
      origin: 'manual',
      row: _selRow,
      col: _selCol,
    );
    _emitActionResult(
      const _ActionResult(
        ok: true,
        message: 'Pegado inteligente revertido.',
        applied: 1,
      ),
      successIcon: Icons.undo_rounded,
    );
  }

  Future<_ActionResult> _pasteTableSmartFromRaw(
    String raw, {
    bool emitFeedback = true,
    bool interactivePreview = true,
    _SmartPasteUserChoice? forcedChoice,
  }) async {
    _ActionResult fail(String message) {
      final result = _ActionResult(ok: false, message: message);
      if (emitFeedback) {
        _emitActionResult(
          result,
          failureIcon: Icons.warning_amber_rounded,
        );
      }
      return result;
    }

    if (_rows.isEmpty || _headers.length <= 1) {
      return fail('No hay filas ni columnas editables para pegar.');
    }
    if (_selRow < 0 || _selRow >= _rows.length) {
      return fail('Selecciona una fila valida para pegar.');
    }
    if (_selCol < 0 || _selCol >= _headers.length - 1) {
      return fail('Selecciona una celda editable para pegar.');
    }
    if (raw.trim().isEmpty) {
      return fail('Portapapeles vacio. Copia una tabla TSV/CSV y reintenta.');
    }

    final parsed = parseSmartTable(raw);
    if (parsed.hasError) {
      return fail(parsed.errorMessage!);
    }
    if (parsed.isEmpty) {
      return fail('No se detecto una tabla valida para pegar.');
    }
    if (parsed.looksLikeTable) {
      unawaited(_markSmartPasteInteracted());
    }

    final startR = _selRow;
    final startC = math.min(_selCol, _headers.length - 2);
    final selectedRows = _batchTargetRows();

    var mode = forcedChoice?.mode ?? _SmartPasteMode.replaceFromActive;
    var firstRowIsHeader = forcedChoice?.firstRowIsHeader ?? false;
    if (forcedChoice == null && interactivePreview && parsed.looksLikeTable) {
      final picked = await _showSmartPasteOptionsSheet(parsed);
      if (picked == null) return fail('Pegado cancelado.');
      mode = picked.mode;
      firstRowIsHeader = picked.firstRowIsHeader;
    }

    final previousSelRow = _selRow;
    final previousSelCol = _selCol;
    final columnExpansion = _ensureSmartPasteEditableColumns(
      startCol: startC,
      requiredColumns: parsed.columnCount,
    );
    final addedColumns = columnExpansion.addedColumns;
    final addedColumnSnapshots = columnExpansion.columns;
    void rollbackAddedColumns() {
      if (addedColumnSnapshots.isEmpty) return;
      for (int i = addedColumnSnapshots.length - 1; i >= 0; i--) {
        final colId = addedColumnSnapshots[i].colId;
        final colIndex = _colIds.indexOf(colId);
        if (colIndex < 0 || colIndex >= _headers.length - 1) continue;
        _headers.removeAt(colIndex);
        _colIds.removeAt(colIndex);
        _columnPrefsById.remove(colId);
        _columnOrder.removeWhere((entry) => entry == colId);
        for (final row in _rows) {
          if (colIndex >= 0 && colIndex < row.cells.length) {
            row.cells.removeAt(colIndex);
          }
        }
      }
      _frozenColId = _normalizeFrozenColId(
        colIds: _colIds,
        requested: _frozenColId,
      );
    }

    final maxColsExclusive = _headers.length - 1;
    final headerChanges = <_SmartPasteUndoHeader>[];
    final headerSource =
        firstRowIsHeader && parsed.cells.isNotEmpty ? parsed.cells.first : null;
    if (headerSource != null) {
      final availableCols = math.max(0, maxColsExclusive - startC);
      final applyCols = math.min(headerSource.length, availableCols);
      for (int dc = 0; dc < applyCols; dc++) {
        final nextHeader = headerSource[dc].trim();
        if (nextHeader.isEmpty) continue;
        final col = startC + dc;
        final previousHeader = _headers[col];
        if (previousHeader == nextHeader) continue;
        headerChanges.add(
          _SmartPasteUndoHeader(
            col: col,
            previousValue: previousHeader,
            nextValue: nextHeader,
          ),
        );
      }
    }

    final inputCells = firstRowIsHeader && parsed.rowCount > 1
        ? parsed.cells.sublist(1)
        : parsed.cells;

    if (inputCells.length == 1 &&
        inputCells.first.length == 1 &&
        selectedRows.length > 1 &&
        mode != _SmartPasteMode.insertRows) {
      final normalized =
          _normalizeCellValueForColumn(startC, inputCells.first.first);
      final refsToClear = <_CellRef>[];
      final undoCells = <_SmartPasteUndoCell>[];
      var changed = 0;
      final changedRowIds = <String>{};
      for (final r in selectedRows) {
        if (r < 0 || r >= _rows.length) continue;
        final previous = _rows[r].cells[startC];
        if (previous == normalized) continue;
        _rows[r].cells[startC] = normalized;
        undoCells.add(
          _SmartPasteUndoCell(
            rowId: _rows[r].id,
            col: startC,
            previousValue: previous,
            nextValue: normalized,
          ),
        );
        refsToClear.add(_CellRef(r, startC));
        changedRowIds.add(_rows[r].id);
        changed++;
      }
      if (changed <= 0 && headerChanges.isEmpty) {
        rollbackAddedColumns();
        return fail('Pegado sin cambios: las celdas ya tenian ese valor.');
      }
      _rememberValueForColumn(startC, normalized);
      _clearCellDrafts(refsToClear);
      for (final rowId in changedRowIds) {
        _bumpRowVersionById(rowId);
      }
      for (final header in headerChanges) {
        _headers[header.col] = header.nextValue;
      }
      _setSelection(selectedRows.first, startC, preserveRowSelection: true);
      if (headerChanges.isNotEmpty || addedColumns > 0) {
        _bumpGridVersion();
      }
      _markDirty(snapshot: true);
      _addHistoryEvent(
        type: 'batch_paste',
        message:
            '${_smartPasteModeLabel(mode)} en $changed celda(s) (${_smartTableDelimiterLabel(parsed.delimiter)})',
        origin: 'manual',
        row: selectedRows.first,
        col: startC,
        afterValue: normalized,
      );
      final result = _ActionResult(
        ok: true,
        message: _smartPasteResultMessage(
          parsed: parsed,
          usedHeaders: firstRowIsHeader,
          changedCells: changed,
          changedHeaders: headerChanges.length,
          addedRows: 0,
          addedColumns: addedColumns,
        ),
        applied: changed + headerChanges.length + addedColumns,
        undoToken: 'batch_paste',
      );
      if (emitFeedback) {
        final undoSnapshot = _SmartPasteUndoSnapshot(
          cells: undoCells,
          headers: headerChanges,
          columns: addedColumnSnapshots,
          insertedRowIds: const <String>[],
          previousSelRow: previousSelRow,
          previousSelCol: previousSelCol,
        );
        _emitActionResult(
          result,
          successIcon: Icons.table_chart_rounded,
          onUndo: () => unawaited(_undoSmartPasteSnapshot(undoSnapshot)),
        );
      }
      return result;
    }

    final existingRows = _rows
        .map((row) => List<String>.from(row.cells, growable: false))
        .toList(growable: false);
    final plan = planSmartTableBatch(
      existingRows: existingRows,
      inputCells: inputCells,
      startRow: startR,
      startCol: startC,
      maxColsExclusive: maxColsExclusive,
      insertRowsAtStart: mode == _SmartPasteMode.insertRows,
      normalize: _normalizeCellValueForColumn,
    );

    if (plan.changedCells <= 0 &&
        headerChanges.isEmpty &&
        plan.insertedRows <= 0) {
      rollbackAddedColumns();
      return fail(
          'Pegado sin cambios: el bloque coincide con los datos actuales.');
    }

    final insertAt = plan.insertedRows > 0
        ? plan.insertedAtRow.clamp(0, _rows.length).toInt()
        : -1;
    final insertedRows = List<_RowModel>.generate(
      plan.insertedRows,
      (_) => _RowModel.empty(_headers.length, id: _genStableId('r_')),
      growable: false,
    );
    final insertedRowIds =
        insertedRows.map((row) => row.id).toList(growable: false);

    String? rowIdForPlannedRow(int rowIndex) {
      if (insertedRows.isEmpty) {
        if (rowIndex < _rows.length) return _rows[rowIndex].id;
        final tail = rowIndex - _rows.length;
        if (tail < 0 || tail >= insertedRows.length) return null;
        return insertedRows[tail].id;
      }
      final insertEnd = insertAt + insertedRows.length;
      if (rowIndex >= insertAt && rowIndex < insertEnd) {
        return insertedRows[rowIndex - insertAt].id;
      }
      if (rowIndex < insertAt) {
        return rowIndex >= 0 && rowIndex < _rows.length
            ? _rows[rowIndex].id
            : null;
      }
      final sourceIndex = rowIndex - insertedRows.length;
      return sourceIndex >= 0 && sourceIndex < _rows.length
          ? _rows[sourceIndex].id
          : null;
    }

    final undoCells = <_SmartPasteUndoCell>[];
    final totalOps = headerChanges.length + plan.changedCells;
    const chunkCells = 200;
    if (totalOps > 0) {
      if (!_tryBeginLongOperation(
        message: _smartPasteProgressMessage(
          rows: parsed.rowCount,
          cols: parsed.columnCount,
          processed: 0,
          total: totalOps,
        ),
        cancellable: true,
      )) {
        rollbackAddedColumns();
        return fail(
          'Ya hay una operacion en curso. Espera a que termine y reintenta el pegado.',
        );
      }
      try {
        var processed = 0;
        for (final _ in headerChanges) {
          _throwIfLongOperationCancelled();
          processed++;
          if (processed % chunkCells == 0 || processed == totalOps) {
            _setLongOperationMessage(
              _smartPasteProgressMessage(
                rows: parsed.rowCount,
                cols: parsed.columnCount,
                processed: processed,
                total: totalOps,
              ),
            );
            await Future<void>.delayed(Duration.zero);
            _throwIfLongOperationCancelled();
          }
        }
        for (final update in plan.updates) {
          _throwIfLongOperationCancelled();
          final rowId = rowIdForPlannedRow(update.row);
          if (rowId != null) {
            undoCells.add(
              _SmartPasteUndoCell(
                rowId: rowId,
                col: update.col,
                previousValue: update.previous,
                nextValue: update.next,
              ),
            );
          }
          processed++;
          if (processed % chunkCells == 0 || processed == totalOps) {
            _setLongOperationMessage(
              _smartPasteProgressMessage(
                rows: parsed.rowCount,
                cols: parsed.columnCount,
                processed: processed,
                total: totalOps,
              ),
            );
            await Future<void>.delayed(Duration.zero);
            _throwIfLongOperationCancelled();
          }
        }
      } on _EditorLongOperationCancelled {
        rollbackAddedColumns();
        return fail('Pegado cancelado por el usuario (sin cambios).');
      } finally {
        _clearLongOperation();
      }
    }

    final refsToClear = <_CellRef>[];
    final changedRowIds = <String>{};
    if (insertedRows.isNotEmpty) {
      _rows.insertAll(insertAt, insertedRows);
      for (var i = 0; i < insertedRows.length; i++) {
        _insertMobileRowCache(insertAt + i);
      }
      _ensureMobileRowCachesLength();
    }
    for (final header in headerChanges) {
      _headers[header.col] = header.nextValue;
    }
    for (final update in plan.updates) {
      if (update.row < 0 || update.row >= _rows.length) continue;
      if (update.col < 0 || update.col >= _headers.length - 1) continue;
      _rows[update.row].cells[update.col] = update.next;
      _rememberValueForColumn(update.col, update.next);
      refsToClear.add(_CellRef(update.row, update.col));
      changedRowIds.add(_rows[update.row].id);
    }

    _clearCellDrafts(refsToClear);
    _setSelection(
      plan.lastRow.clamp(0, _rows.length - 1),
      plan.lastCol.clamp(0, maxColsExclusive - 1),
      preserveRowSelection: true,
    );
    for (final rowId in changedRowIds) {
      _bumpRowVersionById(rowId);
    }
    if (plan.insertedRows > 0 || headerChanges.isNotEmpty || addedColumns > 0) {
      _bumpGridVersion();
    }
    _markDirty(snapshot: true);
    _addHistoryEvent(
      type: 'batch_paste',
      message:
          '${_smartPasteModeLabel(mode)} ${parsed.rowCount}x${parsed.columnCount} en ${plan.changedCells} celda(s)',
      origin: 'manual',
      row: startR,
      col: startC,
    );
    final changedCellsCount = plan.changedCells + headerChanges.length;
    final result = _ActionResult(
      ok: true,
      message: _smartPasteResultMessage(
        parsed: parsed,
        usedHeaders: firstRowIsHeader,
        changedCells: plan.changedCells,
        changedHeaders: headerChanges.length,
        addedRows: plan.insertedRows,
        addedColumns: addedColumns,
      ),
      applied: changedCellsCount + plan.insertedRows + addedColumns,
      undoToken: 'batch_paste',
    );
    if (emitFeedback) {
      final undoSnapshot = _SmartPasteUndoSnapshot(
        cells: undoCells,
        headers: headerChanges,
        columns: addedColumnSnapshots,
        insertedRowIds: insertedRowIds,
        previousSelRow: previousSelRow,
        previousSelCol: previousSelCol,
      );
      _emitActionResult(
        result,
        successIcon: Icons.table_chart_rounded,
        onUndo: () => unawaited(_undoSmartPasteSnapshot(undoSnapshot)),
      );
    }
    return result;
  }

  Future<_ActionResult> _pasteTableSmartFromClipboard({
    bool emitFeedback = true,
    bool interactivePreview = true,
  }) async {
    String raw = '';
    try {
      final data = await Clipboard.getData('text/plain');
      raw = data?.text ?? '';
    } catch (_) {}
    return _pasteTableSmartFromRaw(
      raw,
      emitFeedback: emitFeedback,
      interactivePreview: interactivePreview,
    );
  }

  Future<void> _pasteFromClipboard() async {
    await _pasteTableSmartFromClipboard(emitFeedback: true);
  }

  Future<void> _openSearchDialog() async {
    _openInlineSearch();
  }

  Future<List<_GlobalSearchResult>> _searchSheetRows({
    required String sheetId,
    required String sheetTitle,
    required List<String> headers,
    required List<List<String>> rows,
    required String query,
  }) async {
    final parsed = SearchEverywhereQuery.parse(query);
    if (parsed.isEmpty) return const <_GlobalSearchResult>[];
    final needle = parsed.needle;
    final targetCol =
        parsed.hasColumnFilter ? parsed.resolveColumnIndex(headers) : null;

    final out = <_GlobalSearchResult>[];
    var processed = 0;
    for (int r = 0; r < rows.length; r++) {
      if (targetCol != null) {
        if (targetCol < 0 || targetCol >= rows[r].length) continue;
        final value = rows[r][targetCol].trim();
        if (value.toLowerCase().contains(needle)) {
          out.add(
            _GlobalSearchResult(
              sheetId: sheetId,
              sheetTitle: sheetTitle,
              row: r,
              col: targetCol,
              header: targetCol < headers.length
                  ? headers[targetCol]
                  : 'Col ${targetCol + 1}',
              value: value,
              reason: targetCol < headers.length
                  ? '${headers[targetCol]} contiene "$needle"'
                  : 'Coincidencia',
            ),
          );
        }
      } else {
        for (int c = 0; c < rows[r].length && c < headers.length; c++) {
          final value = rows[r][c].trim();
          if (value.toLowerCase().contains(needle)) {
            out.add(
              _GlobalSearchResult(
                sheetId: sheetId,
                sheetTitle: sheetTitle,
                row: r,
                col: c,
                header: headers[c],
                value: value,
                reason: '${headers[c]} contiene "$needle"',
              ),
            );
          }
        }
      }
      processed++;
      if (processed >= 140) {
        processed = 0;
        await Future<void>.delayed(Duration.zero);
      }
      if (out.length >= 220) break;
    }
    return out;
  }

  Future<List<_GlobalSearchResult>> _searchEverywhere(
    String query, {
    required bool includeAllSheets,
  }) async {
    final headers = List<String>.generate(_headers.length - 1, _headerLabel);
    final currentRows = <List<String>>[
      for (final row in _rows)
        [
          for (int c = 0; c < _headers.length - 1; c++)
            c < row.cells.length ? row.cells[c] : '',
        ],
    ];
    final current = await _searchSheetRows(
      sheetId: widget.sheetId,
      sheetTitle:
          _sheetName.trim().isEmpty ? 'Planilla actual' : _sheetName.trim(),
      headers: headers,
      rows: currentRows,
      query: query,
    );
    if (!includeAllSheets) return current;

    final out = <_GlobalSearchResult>[...current];
    final metas = SheetStore.list();
    for (final meta in metas) {
      if (meta.id == widget.sheetId) continue;
      final table = SheetStore.load(meta.id);
      if (table == null) continue;
      final otherHeaders = table.headers.isNotEmpty
          ? table.headers
              .take(math.max(0, table.headers.length - 1))
              .toList(growable: false)
          : const <String>[];
      final rows = <List<String>>[
        for (final row in table.rows)
          row
              .take(otherHeaders.length)
              .map((e) => e.toString())
              .toList(growable: false),
      ];
      final matches = await _searchSheetRows(
        sheetId: meta.id,
        sheetTitle: meta.title.trim().isEmpty ? meta.id : meta.title.trim(),
        headers: otherHeaders,
        rows: rows,
        query: query,
      );
      out.addAll(matches);
      if (out.length >= 260) break;
    }
    return out;
  }

  Future<void> _openSearchEverywhereDialog() async {
    if (!mounted) return;
    AppHaptics.selection();
    final ec = TextEditingController();
    bool includeAllSheets = false;
    bool searching = false;
    Timer? debounceT;
    List<_GlobalSearchResult> results = const <_GlobalSearchResult>[];

    Future<void> runSearch(
      BuildContext modalCtx,
      StateSetter setModalState,
    ) async {
      if (!mounted || !modalCtx.mounted) return;
      final q = ec.text.trim();
      if (q.isEmpty) {
        setModalState(() {
          searching = false;
          results = const <_GlobalSearchResult>[];
        });
        return;
      }
      setModalState(() => searching = true);
      final found = await _searchEverywhere(
        q,
        includeAllSheets: includeAllSheets,
      );
      if (!mounted || !modalCtx.mounted) return;
      setModalState(() {
        results = found;
        searching = false;
      });
    }

    await showAppModal<void>(
      context: context,
      title: 'Busqueda global',
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 470),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ec,
                  autofocus: true,
                  maxLines: 1,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Texto o col:valor (ej: Estado:Urgente)',
                  ),
                  onChanged: (_) {
                    debounceT?.cancel();
                    debounceT = Timer(const Duration(milliseconds: 180), () {
                      unawaited(runSearch(ctx, setModalState));
                    });
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Buscar en todas las planillas'),
                  value: includeAllSheets,
                  onChanged: (value) {
                    setModalState(() => includeAllSheets = value);
                    AppHaptics.selection();
                    unawaited(runSearch(ctx, setModalState));
                  },
                ),
                const SizedBox(height: 6),
                if (searching)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  Text(
                    '${results.length} resultado(s)',
                    style: TextStyle(
                      color: _palette(ctx).fgMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppMotion.quick,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: results.isEmpty
                        ? const Align(
                            key: ValueKey('search-empty'),
                            alignment: Alignment.centerLeft,
                            child: Text('Sin resultados.'),
                          )
                        : Builder(
                            key: const ValueKey('search-results'),
                            builder: (ctx) {
                              final grouped =
                                  <String, List<_GlobalSearchResult>>{};
                              for (final result in results) {
                                grouped
                                    .putIfAbsent(
                                      result.sheetTitle,
                                      () => <_GlobalSearchResult>[],
                                    )
                                    .add(result);
                              }
                              return ListView(
                                children: [
                                  for (final entry in grouped.entries) ...[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        2,
                                        4,
                                        2,
                                        6,
                                      ),
                                      child: Text(
                                        '${entry.key} (${entry.value.length})',
                                        style: TextStyle(
                                          color: _palette(ctx).fgMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    for (final result in entry.value) ...[
                                      ListTile(
                                        tileColor: _palette(ctx).hintBg,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        title: Text(
                                          '${result.header} | Fila ${result.row + 1}',
                                        ),
                                        subtitle: Text(
                                          '${result.value}\n${result.reason}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onTap: () async {
                                          AppHaptics.selection();
                                          final targetSheetId = result.sheetId;
                                          final targetRow = result.row;
                                          final targetCol = result.col;
                                          if (targetSheetId == widget.sheetId) {
                                            Navigator.of(ctx).pop();
                                            _setSelectionAndRefreshGrid(
                                              targetRow,
                                              targetCol,
                                              blink: true,
                                            );
                                            return;
                                          }
                                          final table = SheetStore.load(
                                            targetSheetId,
                                          );
                                          Navigator.of(ctx).pop();
                                          if (!mounted) return;
                                          await Navigator.of(
                                            context,
                                          ).pushReplacement(
                                            MaterialPageRoute<void>(
                                              builder: (_) => EditorScreen(
                                                sheetId: targetSheetId,
                                                initialName:
                                                    table?.headers.isNotEmpty ==
                                                            true
                                                        ? null
                                                        : result.sheetTitle,
                                                initialSelectionRow: targetRow,
                                                initialSelectionCol: targetCol,
                                                engineBaseUrl:
                                                    widget.engineBaseUrl,
                                                engineApiKey:
                                                    widget.engineApiKey,
                                                isLight: widget.isLight,
                                                onToggleTheme:
                                                    widget.onToggleTheme,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                  ],
                                ],
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        AppButton(
          label: AppStrings.close,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
    debounceT?.cancel();
    ec.dispose();
  }

  void _setInlineSearchScope(_InlineSearchScope scope) {
    if (_inlineSearchScope == scope) return;
    setState(() => _inlineSearchScope = scope);
    _refreshSearchMatches(
      _inlineSearchEC.text,
      jumpToFirst: true,
      announceEmpty: false,
    );
  }

  void _openInlineSearch() {
    if (!mounted) return;
    if (!_inlineSearchOpen) {
      setState(() => _inlineSearchOpen = true);
      AppHaptics.selection();
    }
    if (_inlineSearchEC.text.trim().isEmpty && _lastSearchQuery.isNotEmpty) {
      _inlineSearchEC.text = _lastSearchQuery;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _inlineSearchFocus.requestFocus();
      _inlineSearchEC.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _inlineSearchEC.text.length,
      );
    });

    _refreshSearchMatches(
      _inlineSearchEC.text,
      jumpToFirst: _searchMatchIndex < 0,
      announceEmpty: false,
    );
  }

  void _closeInlineSearch({bool clearQuery = false}) {
    _inlineSearchDebounceT?.cancel();
    if (!mounted) return;
    final wasOpen = _inlineSearchOpen;
    setState(() {
      _inlineSearchOpen = false;
      _searchMatches = <_CellRef>[];
      _searchHitSet = <_CellRef>{};
      _searchMatchIndex = -1;
      _lastSearchHit = null;
      if (clearQuery) {
        _inlineSearchEC.clear();
        _lastSearchQuery = '';
      }
    });
    if (wasOpen) AppHaptics.selection();
  }

  void _onInlineSearchChanged(String query) {
    _inlineSearchDebounceT?.cancel();
    _inlineSearchDebounceT = Timer(const Duration(milliseconds: 120), () {
      _refreshSearchMatches(query, jumpToFirst: true, announceEmpty: false);
    });
  }

  void _refreshSearchMatches(
    String query, {
    required bool jumpToFirst,
    required bool announceEmpty,
  }) {
    final q = query.trim();
    final rows = _rows.length;
    final cols = _headers.length - 1;
    if (!mounted || rows <= 0 || cols <= 0) return;

    if (q.isEmpty) {
      setState(() {
        _searchMatches = <_CellRef>[];
        _searchHitSet = <_CellRef>{};
        _searchMatchIndex = -1;
        _lastSearchHit = null;
        _lastSearchQuery = '';
      });
      return;
    }

    final needle = q.toLowerCase();
    final nextMatches = <_CellRef>[];
    Iterable<int> rowIndexes() sync* {
      switch (_inlineSearchScope) {
        case _InlineSearchScope.allSheet:
        case _InlineSearchScope.currentColumn:
          for (int r = 0; r < rows; r++) {
            yield r;
          }
          break;
        case _InlineSearchScope.currentRow:
          if (_selRow >= 0 && _selRow < rows) {
            yield _selRow;
          }
          break;
      }
    }

    Iterable<int> columnIndexes() sync* {
      switch (_inlineSearchScope) {
        case _InlineSearchScope.allSheet:
        case _InlineSearchScope.currentRow:
          for (int c = 0; c < cols; c++) {
            yield c;
          }
          break;
        case _InlineSearchScope.currentColumn:
          if (_selCol >= 0 && _selCol < cols) {
            yield _selCol;
          }
          break;
      }
    }

    final candidateRows = rowIndexes().toList(growable: false);
    final candidateCols = columnIndexes().toList(growable: false);
    for (final r in candidateRows) {
      for (final c in candidateCols) {
        final text = _effectiveCell(r, c).toLowerCase();
        if (text.contains(needle)) {
          nextMatches.add(_CellRef(r, c));
        }
      }
    }

    _lastSearchQuery = q;
    if (nextMatches.isEmpty) {
      setState(() {
        _searchMatches = <_CellRef>[];
        _searchHitSet = <_CellRef>{};
        _searchMatchIndex = -1;
        _lastSearchHit = null;
      });
      if (announceEmpty) {
        _showActionSnack(
          'Sin resultados para "$q".',
          isError: false,
          icon: Icons.search_off_rounded,
        );
      }
      return;
    }

    final previousHit = _lastSearchHit;
    var nextIndex = 0;
    if (previousHit != null) {
      final found = nextMatches.indexOf(previousHit);
      if (found >= 0) nextIndex = found;
    }
    if (jumpToFirst && previousHit == null) {
      nextIndex = 0;
    }

    setState(() {
      _searchMatches = nextMatches;
      _searchHitSet = nextMatches.toSet();
      _searchMatchIndex = nextIndex.clamp(0, nextMatches.length - 1);
      _lastSearchHit = _searchMatches[_searchMatchIndex];
    });

    if (jumpToFirst) {
      _goToSearchHitIndex(_searchMatchIndex, announce: false);
    }
  }

  void _goToSearchHitDelta(int delta) {
    if (_searchMatches.isEmpty) return;
    final count = _searchMatches.length;
    final current = _searchMatchIndex < 0 ? 0 : _searchMatchIndex;
    final next = (current + delta) % count;
    final normalized = next < 0 ? next + count : next;
    _goToSearchHitIndex(normalized, announce: false);
    AppHaptics.selection();
  }

  void _goToSearchHitIndex(int index, {required bool announce}) {
    if (_searchMatches.isEmpty) return;
    final safe = index.clamp(0, _searchMatches.length - 1);
    final hit = _searchMatches[safe];
    setState(() {
      _searchMatchIndex = safe;
      _lastSearchHit = hit;
    });
    _setSelectionAndRefreshGrid(hit.r, hit.c, blink: true);
    if (announce) {
      _showActionSnack(
        'Coincidencia ${safe + 1}/${_searchMatches.length} en fila ${hit.r + 1}, columna ${_headerLabel(hit.c)}.',
        isError: false,
        icon: Icons.search_rounded,
      );
    }
  }

  bool _isSearchHit(int r, int c) => _searchHitSet.contains(_CellRef(r, c));

  void _jumpToValidationIssue(_ValidationIssue issue) {
    _setSelectionAndRefreshGrid(issue.ref.r, issue.ref.c, blink: true);
    if (mounted) {
      setState(() => _errorsPanelOpen = true);
    } else {
      _errorsPanelOpen = true;
    }
    _showActionSnack(
      '${issue.label}: ${issue.message}',
      isError: false,
      icon: Icons.rule_folder_outlined,
    );
  }

  List<HistoryEventRecord> _historyFiltered({
    required _HistoryFilterWindow window,
    required String type,
  }) {
    var out = List<HistoryEventRecord>.from(_historyEvents, growable: false);
    final now = DateTime.now();
    if (window == _HistoryFilterWindow.today) {
      final minAt = DateTime(now.year, now.month, now.day);
      out = out
          .where((event) => !event.at.isBefore(minAt))
          .toList(growable: false);
    } else if (window == _HistoryFilterWindow.week) {
      final minAt = now.subtract(const Duration(days: 7));
      out =
          out.where((event) => event.at.isAfter(minAt)).toList(growable: false);
    }
    final normalizedType = type.trim().toLowerCase();
    if (normalizedType.isNotEmpty && normalizedType != 'todos') {
      out = out
          .where((event) => event.type.trim().toLowerCase() == normalizedType)
          .toList(growable: false);
    }
    return out;
  }

  String _historyWhenLabel(DateTime at) {
    final local = at.toLocal();
    return '${_two(local.day)}/${_two(local.month)} ${_two(local.hour)}:${_two(local.minute)}';
  }

  void _jumpToHistoryEvent(HistoryEventRecord event) {
    if (event.row == null || event.col == null) {
      _showActionSnack(
        'Evento sin celda asociada.',
        isError: false,
        icon: Icons.info_outline_rounded,
      );
      return;
    }
    final row = event.row!;
    final col = event.col!;
    if (row < 0 ||
        row >= _rows.length ||
        col < 0 ||
        col >= _headers.length - 1) {
      _showActionSnack(
        'La celda del evento ya no existe.',
        isError: false,
        icon: Icons.info_outline_rounded,
      );
      return;
    }
    _setSelectionAndRefreshGrid(row, col, blink: true);
  }

  Future<void> _openHistoryPanel() async {
    if (!mounted) return;
    _HistoryFilterWindow window = _HistoryFilterWindow.all;
    String selectedType = 'todos';
    await showAppModal<void>(
      context: context,
      title: 'Historial',
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          final types = <String>{
            'todos',
            ..._historyEvents.map((event) => event.type.toLowerCase()),
          }.toList(growable: false)
            ..sort();
          final filtered = _historyFiltered(window: window, type: selectedType);
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Todo'),
                      selected: window == _HistoryFilterWindow.all,
                      onSelected: (_) => setModalState(
                        () => window = _HistoryFilterWindow.all,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Hoy'),
                      selected: window == _HistoryFilterWindow.today,
                      onSelected: (_) => setModalState(
                        () => window = _HistoryFilterWindow.today,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('7 dias'),
                      selected: window == _HistoryFilterWindow.week,
                      onSelected: (_) => setModalState(
                        () => window = _HistoryFilterWindow.week,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Tipo',
                  ),
                  items: [
                    for (final type in types)
                      DropdownMenuItem<String>(
                        value: type,
                        child: Text(type == 'todos' ? 'Todos' : type),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setModalState(() => selectedType = value);
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Sin eventos para este filtro.'),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (ctx, index) {
                            final event = filtered[index];
                            final subtitle = [
                              _historyWhenLabel(event.at),
                              event.origin,
                              if (event.row != null && event.col != null)
                                _cellLabelRc(event.row!, event.col!),
                            ].join(' | ');
                            return ListTile(
                              tileColor: _palette(ctx).hintBg,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              title: Text(event.message),
                              subtitle: Text(subtitle),
                              trailing: (event.row != null && event.col != null)
                                  ? IconButton(
                                      tooltip: 'Ir a celda',
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        _jumpToHistoryEvent(event);
                                      },
                                      icon: const Icon(
                                        Icons.my_location_rounded,
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        AppButton(
          label: AppStrings.close,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
  }

  Future<bool> _confirmExportWithValidationIfNeeded() async {
    if (_invalidCells.isEmpty) return true;
    if (!mounted) return false;
    bool jumpToFirstError = false;
    final decision = await showAppModal<bool>(
      context: context,
      title: 'Hay errores de validacion',
      child: Text(
        'Se detectaron ${_invalidCells.length} celdas con error. Puedes exportar igual o revisar antes.',
      ),
      actions: [
        AppButton(
          label: 'Copiar errores',
          icon: Icons.copy_all_rounded,
          variant: AppButtonVariant.ghost,
          onPressed: () => unawaited(_copyValidationIssuesToClipboard()),
        ),
        AppButton(
          label: 'Ir a primera fila con error',
          icon: Icons.vertical_align_top_rounded,
          variant: AppButtonVariant.ghost,
          onPressed: () {
            jumpToFirstError = true;
            Navigator.of(context).pop(false);
          },
        ),
        AppButton(
          label: 'Exportar igual',
          icon: Icons.ios_share_rounded,
          variant: AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
    if (decision != true && mounted) {
      setState(() => _errorsPanelOpen = true);
      if (jumpToFirstError) {
        _jumpToFirstValidationIssue();
      }
    }
    return decision == true;
  }

  Future<void> _copyValidationIssuesToClipboard() async {
    final issues = _validationIssues();
    if (issues.isEmpty) {
      _showActionSnack(
        'No hay errores de validacion.',
        isError: false,
        icon: Icons.task_alt_rounded,
      );
      return;
    }
    final lines = StringBuffer()
      ..writeln('Errores de validacion (${issues.length})');
    for (final issue in issues) {
      lines.writeln('${issue.label}: ${issue.message}');
    }
    try {
      await Clipboard.setData(ClipboardData(text: lines.toString().trim()));
      _showActionSnack(
        'Errores copiados al portapapeles.',
        isError: false,
        icon: Icons.copy_all_rounded,
      );
    } catch (_) {
      _showActionSnack(
        'No se pudieron copiar los errores.',
        isError: true,
        icon: Icons.error_outline_rounded,
      );
    }
  }

  // ------------------------------ GPS / Maps ------------------------------

  CellMeta? _cellMetaAt(int r, int c) {
    final ref = _cellRefAt(r, c);
    if (ref == null) return null;
    return _cellMeta[ref.key];
  }

  bool _cellHasGps(int r, int c) => _cellMetaAt(r, c)?.hasGps ?? false;
  bool _cellHasAudios(int r, int c) => _cellMetaAt(r, c)?.hasAudios ?? false;

  String _cellPhotoThumb(int r, int c) {
    final meta = _cellMetaAt(r, c);
    if (meta == null || meta.photos.isEmpty) return '';
    return meta.photos.last.thumbRef;
  }

  int _cellPhotoCount(int r, int c) => _cellMetaAt(r, c)?.photos.length ?? 0;
  bool _cellIsAttachmentProcessing(int r, int c) =>
      _attachmentProcessingCells.contains(_CellRef(r, c));

  void _setAttachmentProcessing(CellRef ref, bool processing) {
    final idx = _cellIndexForRef(ref);
    if (idx == null) return;
    final localRef = _CellRef(idx.r, idx.c);
    final changed = processing
        ? _attachmentProcessingCells.add(localRef)
        : _attachmentProcessingCells.remove(localRef);
    if (changed) {
      _bumpRowVersionById(_rows[idx.r].id);
    }
  }

  Uint8List? _decodeThumbCached(String raw) => _thumbDecodeCache.decode(raw);

  _CellInlinePreviewData? _cellInlinePreviewAt(int r, int c) {
    if (!_cellInlinePreviewsEnabled) return null;
    final meta = _cellMetaAt(r, c);
    if (meta == null || meta.photos.isEmpty) return null;

    final primary = meta.photos.last;
    final safeName =
        primary.filename.trim().isEmpty ? 'Adjunto' : primary.filename.trim();
    final safeMime = primary.mime.trim().toLowerCase();
    final typeLabel = _inlineAttachmentTypeLabel(safeMime, safeName);
    final subtitle = '$typeLabel | ${_formatBytes(primary.size)}';

    return _CellInlinePreviewData(
      title: safeName,
      subtitle: subtitle,
      icon: _inlineAttachmentIcon(safeMime, safeName),
      extraCount: math.max(0, meta.photos.length - 1),
      thumbB64: _inlineThumbForAttachment(primary),
    );
  }

  String _inlineThumbForAttachment(PhotoAttachment attachment) {
    final thumb = attachment.thumbRef.trim();
    if (thumb.isNotEmpty) return thumb;
    if (_isPdfAttachment(attachment.mime, attachment.filename)) {
      // Best effort: sin rasterizador de PDF en runtime, queda fallback de icono.
      return '';
    }
    return '';
  }

  bool _isPdfAttachment(String mime, String name) {
    final m = mime.toLowerCase();
    final n = name.toLowerCase();
    return m.contains('application/pdf') || n.endsWith('.pdf');
  }

  IconData _inlineAttachmentIcon(String mime, String name) {
    final m = mime.toLowerCase();
    final n = name.toLowerCase();
    if (_isPdfAttachment(mime, name)) return Icons.picture_as_pdf_rounded;
    if (m.startsWith('image/') ||
        n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.webp') ||
        n.endsWith('.gif')) {
      return Icons.photo_rounded;
    }
    if (m.startsWith('video/') ||
        n.endsWith('.mp4') ||
        n.endsWith('.mov') ||
        n.endsWith('.webm')) {
      return Icons.videocam_rounded;
    }
    if (m.startsWith('audio/') ||
        n.endsWith('.mp3') ||
        n.endsWith('.wav') ||
        n.endsWith('.m4a')) {
      return Icons.graphic_eq_rounded;
    }
    if (m.contains('spreadsheet') ||
        n.endsWith('.xls') ||
        n.endsWith('.xlsx')) {
      return Icons.table_chart_rounded;
    }
    if (m.contains('word') || n.endsWith('.doc') || n.endsWith('.docx')) {
      return Icons.description_rounded;
    }
    if (m.contains('zip') || n.endsWith('.zip')) return Icons.archive_rounded;
    return Icons.attach_file_rounded;
  }

  String _inlineAttachmentTypeLabel(String mime, String name) {
    final m = mime.toLowerCase();
    final n = name.toLowerCase();
    if (_isPdfAttachment(mime, name)) return 'PDF';
    if (m.startsWith('image/')) return 'Imagen';
    if (m.startsWith('video/')) return 'Video';
    if (m.startsWith('audio/')) return 'Audio';
    if (m.contains('spreadsheet') ||
        n.endsWith('.xls') ||
        n.endsWith('.xlsx')) {
      return 'Planilla';
    }
    if (m.contains('word') || n.endsWith('.doc') || n.endsWith('.docx')) {
      return 'Documento';
    }
    if (m.contains('zip') || n.endsWith('.zip')) return 'ZIP';
    return 'Archivo';
  }

  String _gpsModeLabel(_GpsWriteMode mode) {
    switch (mode) {
      case _GpsWriteMode.pasteActive:
        return 'Guardar en celda activa';
      case _GpsWriteMode.pickTarget:
        return 'Capturar y elegir celda';
      case _GpsWriteMode.metadataOnly:
        return 'Solo metadata';
    }
  }

  String _gpsModeDesc(_GpsWriteMode mode) {
    switch (mode) {
      case _GpsWriteMode.pasteActive:
        return 'Guarda el GPS en la celda seleccionada y actualiza su texto.';
      case _GpsWriteMode.pickTarget:
        return 'Captura el GPS y luego te deja tocar la celda destino.';
      case _GpsWriteMode.metadataOnly:
        return 'Guarda coordenadas y hora sin cambiar el texto de la celda.';
    }
  }

  _GpsWriteMode _gpsModeFromPref(String? raw) {
    switch (raw) {
      case 'pasteActive':
        return _GpsWriteMode.pasteActive;
      case 'pickTarget':
        return _GpsWriteMode.pickTarget;
      case 'metadataOnly':
        return _GpsWriteMode.metadataOnly;
      default:
        return _GpsWriteMode.pasteActive;
    }
  }

  Future<void> _loadGpsMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefGpsMode);
      final mode = _gpsModeFromPref(raw);
      if (!mounted) return;
      if (mode != _gpsWriteMode) {
        setState(() => _gpsWriteMode = mode);
      }
    } catch (_) {}
  }

  Future<void> _loadAutoGpsBatch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefAutoGpsBatch) ?? false;
      if (!mounted) return;
      if (enabled != _autoGpsBatchEnabled) {
        setState(() => _autoGpsBatchEnabled = enabled);
      }
    } catch (_) {}
  }

  Future<void> _setGpsMode(_GpsWriteMode mode) async {
    if (mode == _gpsWriteMode) return;
    if (mounted) setState(() => _gpsWriteMode = mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefGpsMode, mode.name);
    } catch (_) {}
  }

  Future<void> _setAutoGpsBatchEnabled(bool enabled) async {
    if (enabled == _autoGpsBatchEnabled) return;
    if (mounted) setState(() => _autoGpsBatchEnabled = enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefAutoGpsBatch, enabled);
    } catch (_) {}
    if (!mounted) return;
    _showActionSnack(
      enabled
          ? 'Auto GPS activado para acciones por lote.'
          : 'Auto GPS desactivado.',
      isError: false,
      icon: enabled ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
    );
  }

  // _showGpsModePicker movido a dialogs/editor_dialogs.dart

  String _gpsCellTargetLabel(int r, int c) {
    final cellLabel = CellKey(r, c).a1;
    return 'fila ${r + 1}, celda $cellLabel';
  }

  String _gpsBatchTargetLabel(int rowCount, int targetCol) {
    final rowsLabel = rowCount == 1 ? '1 fila' : '$rowCount filas';
    return '$rowsLabel en la columna ${_a1ColumnLabel(targetCol)}';
  }

  String _gpsLoadingStatus(String targetLabel) =>
      'Buscando ubicacion para $targetLabel...';

  String _gpsSavedMessage({
    required _GpsFix fix,
    required String targetLabel,
    required bool wroteText,
  }) {
    final when = _formatDateTimeShort(fix.ts.toLocal());
    final acc = fix.accuracyM.isFinite && fix.accuracyM > 0
        ? ' Precision aprox. ${fix.accuracyM.toStringAsFixed(0)} m.'
        : '';
    final source = fix.source.toLowerCase();
    final sourceHint = source.contains('lastknown') || source == 'lastknown'
        ? ' Se uso la ultima posicion disponible (GPS aproximado).'
        : '';
    final mode =
        wroteText ? '' : ' No cambie el texto; solo actualice la metadata.';
    return 'GPS guardado en $targetLabel a las $when.$acc$sourceHint$mode';
  }

  bool _beginGpsRequest(String targetLabel) {
    if (_gpsRequestInFlight) {
      final current = (_gpsRequestLabel ?? 'la seleccion').trim();
      _showActionSnack(
        'Ya estamos buscando el GPS para $current. Espera unos segundos.',
        isError: false,
        icon: Icons.hourglass_top_rounded,
      );
      return false;
    }
    _gpsRequestInFlight = true;
    _gpsRequestLabel = targetLabel;
    _engineStatus = _gpsLoadingStatus(targetLabel);
    _engineStatusIsError = false;
    if (mounted) {
      setState(() {});
    }
    return true;
  }

  void _endGpsRequest(String targetLabel) {
    _gpsRequestInFlight = false;
    _gpsRequestLabel = null;
    final loadingStatus = _gpsLoadingStatus(targetLabel);
    if (_engineStatus == loadingStatus) {
      _engineStatus = null;
      _engineStatusIsError = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<bool> _runGpsPreflight(String targetLabel) async {
    if (kIsWeb) return true;
    if (_debugGpsOutcomeHook != null) return true;

    final preflightOk = await _runPermissionPreflight(
      storageKey: _kPrefLocationRationaleSeen,
      permissionLabel: 'ubicacion',
      rationaleTitle: 'Permiso de ubicacion',
      rationaleMessage:
          'Usamos el GPS para guardar coordenadas en la fila o celda elegida, junto con fecha y hora.',
      permission: ph.Permission.locationWhenInUse,
    );
    if (!preflightOk) {
      return false;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) return true;
    } catch (_) {
      return true;
    }

    final msg =
        'No pudimos iniciar el GPS para $targetLabel porque el servicio del dispositivo esta apagado.';
    _engineStatus = msg;
    _engineStatusIsError = true;
    DiagnosticsLog.I.record(
      type: DiagnosticActionType.gps,
      ok: false,
      message: 'gps_service_disabled_preflight target=$targetLabel',
    );
    if (mounted) {
      setState(() {});
      _showActionSnack(
        'Activa la ubicacion del dispositivo y vuelve a intentar.',
        isError: true,
        icon: Icons.gps_off_rounded,
        actionLabel: 'Abrir ajustes',
        onAction: () {
          unawaited(LocationService.I.openSystemLocationSettings());
        },
      );
    }
    return false;
  }

  _GpsOutcome _gpsOutcomeFromDebugPayload(Map<String, Object?> payload) {
    final lat = (payload['lat'] as num?)?.toDouble();
    final lng = (payload['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      final accuracy = ((payload['accuracyM'] ?? payload['accuracy_m']) as num?)
              ?.toDouble() ??
          0;
      final timestampRaw = payload['timestamp'] ?? payload['ts'];
      final timestamp = timestampRaw is DateTime
          ? timestampRaw
          : DateTime.tryParse((timestampRaw ?? '').toString()) ??
              DateTime.now();
      return _GpsOutcome(
        fix: _GpsFix(
          lat: lat,
          lng: lng,
          accuracyM: accuracy,
          ts: timestamp,
          source: (payload['source'] ?? 'debug').toString(),
          provider: (payload['provider'] ?? 'debug').toString(),
        ),
      );
    }
    return _GpsOutcome(
      error: (payload['error'] ?? 'gps_debug_error').toString(),
      code: (payload['code'] ?? 'unknown').toString(),
    );
  }

  Future<void> _requestGpsForCell(
    int r,
    int c, {
    bool forceWriteText = false,
  }) async {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    if (c == _headers.length - 1) return;

    if (_guardInAppBrowser(DiagnosticActionType.gps)) return;
    if (_guardInsecureContext(DiagnosticActionType.gps)) return;
    if (kIsWeb && !WebCapabilities.geolocationAvailable) {
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.gps,
        ok: false,
        message: 'gps_unavailable',
      );
      _showActionSnack(
        'GPS no disponible en este navegador.',
        isError: true,
        icon: Icons.gps_off_rounded,
      );
      return;
    }

    final targetLabel = _gpsCellTargetLabel(r, c);
    final preflightOk = await _runGpsPreflight(targetLabel);
    if (!preflightOk) return;
    if (!_beginGpsRequest(targetLabel)) return;

    try {
      final outcome = await _getGpsFixWithFallback(
        timeout: const Duration(seconds: 12),
      );
      if (!mounted) return;
      if (!outcome.ok || outcome.fix == null) {
        _showGpsError(outcome, targetLabel: targetLabel);
        return;
      }

      final fix = outcome.fix!;
      if (!forceWriteText && _gpsWriteMode == _GpsWriteMode.pickTarget) {
        setState(() {
          _gpsPickingTarget = true;
          _pendingGpsFix = fix;
        });
        _engineStatus = 'GPS listo. Toca la celda destino para pegarlo.';
        _engineStatusIsError = false;
        _showSnack(
          'GPS listo. Toca la celda destino para pegarlo.',
          isError: false,
        );
        return;
      }

      final shouldWrite =
          forceWriteText || _gpsWriteMode != _GpsWriteMode.metadataOnly;
      _applyGpsFixToCell(r, c, fix, writeText: shouldWrite);
    } finally {
      _endGpsRequest(targetLabel);
    }
  }

  bool _tryConsumePendingGps(int r, int c) {
    if (!_gpsPickingTarget || _pendingGpsFix == null) return false;
    if (c == _headers.length - 1) return true;
    if (_selRow != r || _selCol != c) {
      _setSelectionAndRefreshGrid(r, c);
    }
    _blink(r, c);
    final fix = _pendingGpsFix!;
    _pendingGpsFix = null;
    _gpsPickingTarget = false;
    _applyGpsFixToCell(r, c, fix, writeText: true);
    return true;
  }

  void _cancelGpsPick() {
    if (!_gpsPickingTarget) return;
    setState(() {
      _gpsPickingTarget = false;
      _pendingGpsFix = null;
    });
    _engineStatus = null;
    _engineStatusIsError = false;
  }

  Future<_GpsOutcome> _getGpsFixWithFallback({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final inflight = _gpsFetchInFlight;
    if (inflight != null) {
      return inflight;
    }

    final future = _fetchGpsFixWithFallback(timeout: timeout);
    _gpsFetchInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_gpsFetchInFlight, future)) {
        _gpsFetchInFlight = null;
      }
    }
  }

  Future<_GpsOutcome> _fetchGpsFixWithFallback({
    required Duration timeout,
  }) async {
    final debugHook = _debugGpsOutcomeHook;
    if (debugHook != null) {
      final payload = await debugHook(timeout);
      return _gpsOutcomeFromDebugPayload(payload);
    }
    try {
      if (kIsWeb) {
        final result = await LocationWebService.I.tryGetCurrent(
          timeout: timeout,
          enableHighAccuracy: true,
          maximumAge: const Duration(seconds: 5),
        );
        final fix = result.fix;
        if (!result.ok || fix == null) {
          return _GpsOutcome(error: result.message, code: result.code);
        }
        return _GpsOutcome(
          fix: _GpsFix(
            lat: fix.latitude,
            lng: fix.longitude,
            accuracyM: fix.accuracyMeters ?? 0,
            ts: fix.timestamp,
            source: fix.source,
            provider: 'browser',
          ),
        );
      }

      final quickTimeout = timeout < const Duration(seconds: 4)
          ? timeout
          : const Duration(seconds: 4);
      final result = await LocationService.I.tryGetFixPreciseFast(
        quickTimeout: quickTimeout,
        hardTimeout: timeout,
        targetAccuracyMeters: 25,
        maxAccuracyMeters: 120,
      );
      final fix = result.fix;
      if (!result.ok || fix == null) {
        return _GpsOutcome(error: result.message, code: result.code);
      }
      return _GpsOutcome(
        fix: _GpsFix(
          lat: fix.latitude,
          lng: fix.longitude,
          accuracyM: fix.accuracyMeters ?? 0,
          ts: fix.timestamp,
          source: fix.source,
          provider: 'geolocator',
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[gps] unexpected error: $e');
      return _GpsOutcome(error: e.toString(), code: 'unknown');
    }
  }

  Future<void> _captureGpsForRow(int r, {int? targetCol}) async {
    final col = targetCol ?? _selCol;
    await _requestGpsForCell(r, col);
  }

  String _gpsTextForFix(_GpsFix fix) {
    final accuracy = fix.accuracyM;
    final hasAccuracy = accuracy.isFinite && accuracy > 0;
    if (!hasAccuracy) {
      return formatLatLng(fix.lat, fix.lng);
    }
    return '${formatLatLng(fix.lat, fix.lng)} (+/-${accuracy.toStringAsFixed(0)}m)';
  }

  void _applyGpsFixToCell(
    int r,
    int c,
    _GpsFix fix, {
    required bool writeText,
    bool announce = true,
  }) {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length - 1) return;

    _setCellGpsMeta(r, c, fix, markDirty: !writeText);
    if (writeText) {
      _setCell(r, c, _gpsTextForFix(fix));
    }
    _refreshCellAfterSave(r, c);

    if (announce) {
      _announceGpsSaved(fix, cell: CellKey(r, c), wroteText: writeText);
    }
  }

  @visibleForTesting
  void debugApplyGpsFixToCell(
    int r,
    int c, {
    double lat = -38.95,
    double lng = -68.06,
    num accuracyM = 12,
    DateTime? timestamp,
    String source = 'test',
    String provider = 'test',
    bool writeText = true,
  }) {
    assert(() {
      final fix = _GpsFix(
        lat: lat,
        lng: lng,
        accuracyM: accuracyM.toDouble(),
        ts: timestamp ?? DateTime.now(),
        source: source,
        provider: provider,
      );
      _applyGpsFixToCell(r, c, fix, writeText: writeText, announce: false);
      return true;
    }());
  }

  @visibleForTesting
  Future<void> debugRequestGpsForCell(
    int r,
    int c, {
    bool forceWriteText = false,
  }) async {
    assert(() {
      return true;
    }());
    await _requestGpsForCell(r, c, forceWriteText: forceWriteText);
  }

  @visibleForTesting
  Future<void> debugSetGpsModeForTest(String mode) async {
    final raw = mode.trim().toLowerCase();
    final next = switch (raw) {
      'paste' || 'pasteactive' || 'paste_active' => _GpsWriteMode.pasteActive,
      'pick' || 'picktarget' || 'pick_target' => _GpsWriteMode.pickTarget,
      'metadata' ||
      'metadataonly' ||
      'metadata_only' =>
        _GpsWriteMode.metadataOnly,
      _ => _gpsWriteMode,
    };
    await _setGpsMode(next);
  }

  @visibleForTesting
  void debugSetGpsOutcomeHook(_DebugGpsOutcomeHook? hook) {
    assert(() {
      _debugGpsOutcomeHook = hook;
      return true;
    }());
  }

  @visibleForTesting
  String debugCellText(int r, int c) => _getCellText(r, c);

  @visibleForTesting
  String debugDisplayedCellText(int r, int c) => _displayCellValue(r, c);

  @visibleForTesting
  void debugSetCellDraft(int r, int c, String value) {
    assert(() {
      _setDraftCell(r, c, value);
      return true;
    }());
  }

  @visibleForTesting
  void debugSetCellValue(int r, int c, String value) {
    assert(() {
      _setCell(r, c, value);
      return true;
    }());
  }

  @visibleForTesting
  void debugSetColumnPresentation(
    int c, {
    int wrapLines = 1,
    String textAlign = 'left',
    String verticalAlign = 'middle',
  }) {
    assert(() {
      if (c < 0 || c >= _headers.length - 1) return true;
      final parsedTextAlign = _gridTextAlignXFromStorageName(textAlign);
      final parsedVerticalAlign = _gridTextAlignYFromStorageName(verticalAlign);
      _setColumnPresentationForIndex(
        c,
        wrapLines: wrapLines,
        textAlign: parsedTextAlign,
        verticalAlign: parsedVerticalAlign,
        snapshot: false,
      );
      return true;
    }());
  }

  @visibleForTesting
  bool debugCellHasGps(int r, int c) => _cellHasGps(r, c);

  @visibleForTesting
  bool get debugGpsRequestInFlight => _gpsRequestInFlight;

  @visibleForTesting
  String? debugEngineStatusMessage() => _engineStatus;

  @visibleForTesting
  String? debugGpsRequestLabel() => _gpsRequestLabel;

  @visibleForTesting
  int get debugRowCount => _rows.length;

  @visibleForTesting
  int get debugEditableColumnCount => math.max(0, _headers.length - 1);

  @visibleForTesting
  String debugHeaderText(int c) => _headerLabel(c);

  @visibleForTesting
  bool get debugMobileEditorOpen => _mobileEditorOpen;

  @visibleForTesting
  double get debugVerticalScrollOffset =>
      _vScroll.hasClients ? _vScroll.offset : 0;

  @visibleForTesting
  int get debugMobileEnsureVisibleCalls => _debugMobileEnsureVisibleCalls;

  @visibleForTesting
  bool get debugMobileTopBarCollapsed => _mobileTopBarCollapsed;

  @visibleForTesting
  bool get debugMobileCompactModeEnabled => _mobileCompactModeEnabled;

  @visibleForTesting
  bool get debugZenModeEnabled => _zenModeEnabled;

  @visibleForTesting
  int get debugMobileRowCacheSlots => _mobileRowScrolls.length;

  @visibleForTesting
  int get debugMobileMaterializedRowControllers =>
      _mobileRowScrolls.whereType<ScrollController>().length;

  @visibleForTesting
  void debugMaterializeMobileRowController(int row) {
    _mobileRowScrollAt(row);
  }

  @visibleForTesting
  void debugSetZenMode(bool enabled) {
    assert(() {
      _zenModeEnabled = enabled;
      _mobileTopBarCollapsed = enabled;
      return true;
    }());
  }

  @visibleForTesting
  void debugSetMobileCompactMode(bool enabled) {
    assert(() {
      _mobileCompactModeEnabled = enabled;
      if (!enabled) {
        _mobileTopBarCollapsed = false;
      }
      return true;
    }());
  }

  @visibleForTesting
  Future<FlowBotParseResult> debugParseFlowBotCommand(String transcript) {
    return _parseFlowBotCommand(transcript);
  }

  @visibleForTesting
  int get debugFlowBotMacroCount => _flowBotMacros.length;

  @visibleForTesting
  bool get debugFieldModeEnabled => _fieldModeEnabled;

  @visibleForTesting
  void debugSetLastFlowBotValidCommand(String command) {
    assert(() {
      _lastFlowBotValidCommand = command.trim();
      return true;
    }());
  }

  @visibleForTesting
  Future<void> debugSaveFlowBotMacro(String name) async {
    final command = _lastFlowBotValidCommand.trim();
    if (name.trim().isEmpty || command.isEmpty) return;
    await _upsertFlowBotMacro(
      name: name,
      command: command,
      emitFeedback: false,
    );
  }

  @visibleForTesting
  Future<void> debugRunFlowBotMacro(String name) async {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return;
    FlowBotMacroPreset? macro;
    for (final item in _flowBotMacros) {
      if (item.name.toLowerCase() == key) {
        macro = item;
        break;
      }
    }
    if (macro == null) return;
    await _runFlowBotCommandDirect(macro.command);
  }

  @visibleForTesting
  Future<void> debugSetFieldMode(bool enabled) async {
    if (_fieldModeEnabled == enabled) return;
    await _toggleFieldMode();
  }

  @visibleForTesting
  void debugOpenCommandPalette() {
    assert(() {
      unawaited(_openCommandPalette());
      return true;
    }());
  }

  @visibleForTesting
  void debugOpenExportMenuForTest() {
    assert(() {
      unawaited(_openExportMenu());
      return true;
    }());
  }

  @visibleForTesting
  void debugOpenRowFormForTest({int? rowIndex, bool createNew = false}) {
    assert(() {
      unawaited(_openRowFormMode(rowIndex: rowIndex, createNew: createNew));
      return true;
    }());
  }

  @visibleForTesting
  void debugInjectSaveErrorForTest([
    String message = 'No pudimos guardar los cambios.',
  ]) {
    _saving = false;
    _lastSaveSucceeded = false;
    _lastSaveErrorMessage = message;
    _updateSaveStatus();
  }

  @visibleForTesting
  void debugSetExportHooks({
    _DebugShareHook? shareHook,
    _DebugSaveLocationHook? saveLocationHook,
    _DebugSaveFileHook? saveFileHook,
    _DebugPersistShareTempFileHook? persistShareTempFileHook,
  }) {
    _debugShareHook = shareHook;
    _debugSaveLocationHook = saveLocationHook;
    _debugSaveFileHook = saveFileHook;
    _debugPersistShareTempFileHook = persistShareTempFileHook;
  }

  @visibleForTesting
  String? debugLastToastMessage() => _lastToastMessage;

  @visibleForTesting
  Future<void> debugTriggerExportForTest({
    String format = 'xlsx',
    bool share = false,
    bool includeAttachments = true,
  }) async {
    switch (format) {
      case 'zip':
        await _exportZipBundle(share: share);
        return;
      case 'pdf':
        await _exportPdf(
          includeAttachments: includeAttachments,
          share: share,
        );
        return;
      default:
        await _exportXlsxOnly(
          includeAttachments: includeAttachments,
          share: share,
        );
        return;
    }
  }

  @visibleForTesting
  Future<void> debugRunExportSaveFlowForTest({
    required String name,
    required String mime,
    bool share = false,
    Uint8List? bytes,
  }) async {
    try {
      await _saveExportBytes(
        name: name,
        mime: mime,
        bytes: bytes ?? Uint8List.fromList(<int>[1, 2, 3, 4]),
        share: share,
      );
    } catch (e, st) {
      _reportFlowError(
        e,
        flow: AppErrorFlow.exportData,
        operation: share
            ? 'debug_export_save_flow_share'
            : 'debug_export_save_flow_save',
        fallbackMessage: 'No pudimos completar la operación.',
        stackTrace: st,
        icon: share ? Icons.ios_share_rounded : Icons.download_rounded,
      );
    }
  }

  @visibleForTesting
  Future<Uint8List?> debugBuildZipBundleBytesForTest({
    bool includeAttachments = true,
  }) async {
    final prep = await _prepareExportPayload(
      includeZip: true,
      includeAttachments: includeAttachments,
    );
    final xlsxBytes = await _buildXlsxBytesForExport(
      embeddedPhotos: prep.embeddedPhotos,
      attachments: prep.attachments,
      exportFileName:
          buildBitFlowPackageWorkbookFileName(sheetName: _sheetName),
    );
    final pdfBytes = await _buildPdfBytesForExport(
      includeAttachments: includeAttachments,
      exportFileName: buildBitFlowPackageReportFileName(sheetName: _sheetName),
    );
    if (xlsxBytes == null || pdfBytes == null || pdfBytes.isEmpty) {
      return null;
    }
    return _buildAttachmentsZip(
      xlsxBytes: xlsxBytes,
      xlsxFileName: buildBitFlowPackageWorkbookFileName(sheetName: _sheetName),
      pdfBytes: pdfBytes,
      pdfFileName: buildBitFlowPackageReportFileName(sheetName: _sheetName),
      photoItems: prep.photoItems,
      audioItems: prep.audioItems,
      attachments: prep.attachments,
      manifest: prep.manifest,
      packageSheetJson: prep.packageSheetJson,
    );
  }

  @visibleForTesting
  void debugOpenInlineSearch() {
    _openInlineSearch();
  }

  @visibleForTesting
  void debugSearchInSheet(String query) {
    _openInlineSearch();
    _refreshSearchMatches(
      query,
      jumpToFirst: true,
      announceEmpty: false,
    );
  }

  @visibleForTesting
  void debugSearchNext() {
    _goToSearchHitDelta(1);
  }

  @visibleForTesting
  void debugSearchPrev() {
    _goToSearchHitDelta(-1);
  }

  @visibleForTesting
  int get debugSearchMatchCount => _searchMatches.length;

  @visibleForTesting
  int get debugSelectedRow => _selRow;

  @visibleForTesting
  int get debugSelectedCol => _selCol;

  @visibleForTesting
  void debugSelectCell(int r, int c) {
    assert(() {
      if (r < 0 || r >= _rows.length) return true;
      if (c < 0 || c >= _headers.length - 1) return true;
      _setSelection(r, c, preserveRowSelection: true);
      return true;
    }());
  }

  @visibleForTesting
  List<String> debugFlowBotInlineActionIds() {
    final context = _flowBotQuickContext();
    return _flowBotInlineQuickActions(
      context,
    ).map((action) => action.id).toList(growable: false);
  }

  @visibleForTesting
  void debugOpenMobileEditorForCell(int r, int c) {
    assert(() {
      if (r < 0 || r >= _rows.length) return true;
      if (c < 0 || c >= _headers.length - 1) return true;
      _openMobileInlineEditor(
        isHeader: false,
        row: r,
        col: c,
        title: _mobileCellLabel(r, c),
        initial: _effectiveCell(r, c),
        actions: _mobileActionsForCell(r, c),
      );
      return true;
    }());
  }

  @visibleForTesting
  Future<int> debugApplyFlowBotActions(List<FlowBotAction> actions) {
    return _applyFlowBotActions(actions);
  }

  @visibleForTesting
  void debugStartSmartPastePreview(String raw) {
    assert(() {
      unawaited(
        _pasteTableSmartFromRaw(
          raw,
          emitFeedback: true,
          interactivePreview: true,
        ),
      );
      return true;
    }());
  }

  @visibleForTesting
  Future<Map<String, Object?>> debugApplySmartPasteRaw(
    String raw, {
    bool interactivePreview = false,
    bool firstRowIsHeader = false,
    String mode = 'replace',
  }) async {
    final normalizedMode = mode.trim().toLowerCase();
    final forcedChoice = _SmartPasteUserChoice(
      mode: normalizedMode == 'insert'
          ? _SmartPasteMode.insertRows
          : _SmartPasteMode.replaceFromActive,
      firstRowIsHeader: firstRowIsHeader,
    );
    final result = await _pasteTableSmartFromRaw(
      raw,
      emitFeedback: true,
      interactivePreview: interactivePreview,
      forcedChoice: interactivePreview ? null : forcedChoice,
    );
    return <String, Object?>{
      'ok': result.ok,
      'message': result.message,
      'applied': result.applied,
      'undoToken': result.undoToken,
    };
  }

  @visibleForTesting
  Future<Map<String, Object?>> debugApplyFlowBotActionsResult(
    List<FlowBotAction> actions,
  ) async {
    final applied = await _applyFlowBotActions(actions);
    final result = _flowBotResultForAppliedChanges(applied);
    return <String, Object?>{
      'ok': result.ok,
      'message': result.message,
      'applied': result.applied,
      'undoToken': result.undoToken,
    };
  }

  @visibleForTesting
  void debugSimulateMobileScrollDirection(ScrollDirection direction) {
    assert(() {
      _handleMobileGridScrollDirection(direction);
      return true;
    }());
  }

  @visibleForTesting
  CellMeta? debugCellMetaAt(int r, int c) => _cellMetaAt(r, c);

  @visibleForTesting
  void debugSetCellMetaForTest(int r, int c, CellMeta? meta) {
    assert(() {
      if (meta == null || meta.isEmpty) {
        final ref = _cellRefAt(r, c);
        if (ref != null) {
          _cellMeta.remove(ref.key);
          _bumpGridVersion();
        }
        return true;
      }
      _setCellMetaEntry(r, c, meta, markDirty: false);
      return true;
    }());
  }

  @visibleForTesting
  void debugSetWebImageNormalizer(WebImageNormalizer? normalizer) {
    assert(() {
      _debugWebImageNormalizer = normalizer;
      return true;
    }());
  }

  @visibleForTesting
  void debugSetSaveImageHook(_DebugSaveImageHook? hook) {
    assert(() {
      _debugSaveImageHook = hook;
      return true;
    }());
  }

  @visibleForTesting
  void debugSetAudioHooks({
    _DebugStartAudioRecordingHook? start,
    _DebugStopAudioRecordingHook? stop,
    _DebugSaveAudioHook? save,
  }) {
    assert(() {
      _debugStartAudioRecordingHook = start;
      _debugStopAudioRecordingHook = stop;
      _debugSaveAudioHook = save;
      return true;
    }());
  }

  @visibleForTesting
  void debugSetSkipAttachmentGps(bool skip) {
    assert(() {
      _debugSkipAttachmentGps = skip;
      return true;
    }());
  }

  @visibleForTesting
  Future<Map<String, Object?>> debugGetGpsFixForTest({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final outcome = await _getGpsFixWithFallback(timeout: timeout);
    return <String, Object?>{
      'ok': outcome.ok,
      'error': outcome.error,
      'code': outcome.code,
      'lat': outcome.fix?.lat,
      'lng': outcome.fix?.lng,
      'accuracyM': outcome.fix?.accuracyM,
      'source': outcome.fix?.source,
      'provider': outcome.fix?.provider,
      'ts': outcome.fix?.ts.toIso8601String(),
    };
  }

  @visibleForTesting
  String debugGpsErrorMessageForTest({
    String? code,
    String? error,
    String? targetLabel,
  }) {
    final outcome = _GpsOutcome(code: code, error: error);
    return _gpsErrorMessage(outcome, targetLabel: targetLabel);
  }

  @visibleForTesting
  void debugSetForceWebImageNormalization(bool enabled) {
    assert(() {
      _debugForceWebImageNormalization = enabled;
      return true;
    }());
  }

  @visibleForTesting
  void debugSetAttachmentTraceHook(_DebugAttachmentTraceHook? hook) {
    assert(() {
      _debugAttachmentTraceHook = hook;
      return true;
    }());
  }

  @visibleForTesting
  Future<void> debugAttachPhotoOutcome(
    int r,
    int c,
    PhotoAcquireOutcome outcome, {
    bool fromCamera = false,
    int? replaceIndex,
  }) async {
    assert(() {
      return true;
    }());
    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    await _processPhotoOutcome(
      outcome,
      ref,
      fromCamera: fromCamera,
      replaceIndex: replaceIndex,
    );
  }

  @visibleForTesting
  Future<void> debugAttachPhotoResilient(
    int r,
    int c,
    PhotoAcquireResult result,
  ) async {
    assert(() {
      return true;
    }());
    final ref = _cellRefAt(r, c);
    if (ref == null) return;

    final prepared = await _preparePhotoForStorage(result);
    final bytes = prepared.bytes;
    if (bytes.isEmpty) return;

    final attachmentId = _genAttachmentId('ph_dbg_');
    final saveHook = _debugSaveImageHook;
    final save = await (saveHook != null
        ? saveHook(
            cellRef: ref,
            attachmentId: attachmentId,
            bytes: bytes,
            originalName: prepared.fileName,
            mime: prepared.mime,
            webFile: kIsWeb ? (prepared.webStoredSource ?? bytes) : null,
          )
        : _attachmentStore.saveImage(
            cellRef: ref,
            attachmentId: attachmentId,
            bytes: bytes,
            originalName: prepared.fileName,
            mime: prepared.mime,
            webFile: kIsWeb ? (prepared.webStoredSource ?? bytes) : null,
          ));
    if (save == null || save.storedRef.trim().isEmpty) return;

    final thumbBytes = prepared.thumbBytes ??
        _compressThumb(bytes, maxW: 320, maxH: 320, quality: 74);
    final thumbB64 = (thumbBytes == null || thumbBytes.isEmpty)
        ? ''
        : base64Encode(thumbBytes);

    final attachment = PhotoAttachment(
      id: attachmentId,
      filename: prepared.fileName,
      caption: prepared.caption,
      mime: prepared.mime,
      size: bytes.lengthInBytes,
      storedRef: save.storedRef,
      thumbRef: thumbB64,
      addedAt: DateTime.now(),
    );
    _applyPhotoToRef(ref, attachment);
  }

  @visibleForTesting
  void debugEmitLoadErrorFeedback([String rawMessage = 'invalid_json']) {
    assert(() {
      _reportFlowErrorMessage(
        rawMessage,
        flow: AppErrorFlow.load,
        operation: 'debug_emit_load_error',
        icon: Icons.folder_off_rounded,
      );
      return true;
    }());
  }

  @visibleForTesting
  Future<bool> debugConfirmExportValidationGateForTest() {
    return _confirmExportWithValidationIfNeeded();
  }

  @visibleForTesting
  void debugEmitAttachmentErrorFeedback({
    String code = 'storage_blocked',
    String detail = 'reason=storage_blocked',
    DiagnosticActionType type = DiagnosticActionType.photo,
  }) {
    assert(() {
      _reportFlowErrorMessage(
        detail,
        flow: AppErrorFlow.attachmentPermission,
        operation: 'debug_emit_attachment_error',
        fallbackMessage: 'No se pudo guardar la foto. Causa: $code.',
        code: code,
        diagnosticDetails: detail,
        icon: Icons.photo_outlined,
        diagnosticType: type,
      );
      return true;
    }());
  }

  @visibleForTesting
  String? debugLastErrorFeedbackMessage() {
    String? message;
    assert(() {
      message = _lastErrorFeedbackMessage;
      return true;
    }());
    return message;
  }

  @visibleForTesting
  void debugShowOperationProgress({
    String message = AppStrings.progressPreparingExport,
    bool cancellable = true,
  }) {
    assert(() {
      _beginLongOperation(message: message, cancellable: cancellable);
      return true;
    }());
  }

  @visibleForTesting
  void debugClearOperationProgress() {
    assert(() {
      _clearLongOperation();
      return true;
    }());
  }

  @visibleForTesting
  bool debugOperationCancelRequested() {
    var cancelled = false;
    assert(() {
      cancelled = _isLongOperationCancelled();
      return true;
    }());
    return cancelled;
  }

  @visibleForTesting
  Future<void> debugSaveNow() async {
    assert(() {
      return true;
    }());
    final prefs = await SharedPreferences.getInstance();
    final savedAt = DateTime.now();
    _syncActiveDrafts();
    final model = _buildModelForSave(savedAt);
    final encoded = json.encode(model.toJson());
    await prefs.setString(_prefsKey, encoded);
    await prefs.remove(_prefsKeyStaging);

    if (!mounted) return;
    setState(() {
      _lastSavedAt = savedAt;
      _lastSavedRev = _rev;
      _isDirty = false;
    });
    _updateSaveStatus();
  }

  @visibleForTesting
  Future<void> debugReloadFromLocal() async {
    assert(() {
      return true;
    }());
    await _loadLocal();
  }

  @visibleForTesting
  Future<void> debugOpenAttachmentPanelForTest(int r, int c) async {
    assert(() {
      return true;
    }());
    unawaited(_openAttachmentPanelForCell(r, c));
  }

  @visibleForTesting
  void debugOpenPhotosSheetForTest(int r, int c) {
    assert(() {
      _openPhotosSheetForCell(r, c);
      return true;
    }());
  }

  @visibleForTesting
  void debugOpenAudiosSheetForTest(int r, int c) {
    assert(() {
      _openAudiosSheetForCell(r, c);
      return true;
    }());
  }

  @visibleForTesting
  Future<void> debugToggleAudioRecordingForCell(int r, int c) async {
    assert(() {
      return true;
    }());
    if (_audioRecording) {
      await _stopAudioRecording();
      return;
    }
    await _startAudioRecordingForCell(r, c);
  }

  @visibleForTesting
  bool debugIsAudioRecording() => _audioRecording;

  GpsMeta _gpsMetaFromFix(_GpsFix fix) {
    final ts = fix.ts.millisecondsSinceEpoch > 0 ? fix.ts : DateTime.now();
    final accuracy =
        fix.accuracyM.isFinite && fix.accuracyM >= 0 ? fix.accuracyM : 0.0;
    return GpsMeta(
      lat: fix.lat,
      lng: fix.lng,
      accuracyM: accuracy,
      timestamp: ts,
      source: fix.source,
      provider: fix.provider,
    );
  }

  void _setCellGpsMeta(int r, int c, _GpsFix fix, {required bool markDirty}) {
    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    final current = _cellMeta[ref.key];
    final next = CellMeta(
      gps: _gpsMetaFromFix(fix),
      photos: current?.photos ?? const <PhotoAttachment>[],
      audios: current?.audios ?? const <AudioAttachment>[],
    );
    _setCellMetaEntry(r, c, next, markDirty: markDirty);
  }

  void _setCellMetaEntry(
    int r,
    int c,
    CellMeta meta, {
    required bool markDirty,
  }) {
    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    final key = ref.key;
    if (meta.isEmpty) {
      _cellMeta.remove(key);
    } else {
      _cellMeta[key] = meta;
    }

    if (markDirty) {
      _markDirty(snapshot: true);
    } else {
      _bumpGridVersion();
    }
  }

  void _announceGpsSaved(
    _GpsFix fix, {
    required CellKey cell,
    required bool wroteText,
  }) {
    final cellLabel = _cellLabelRc(cell.row, cell.col);
    final msg = _gpsSavedMessage(
      fix: fix,
      targetLabel: _gpsCellTargetLabel(cell.row, cell.col),
      wroteText: wroteText,
    );
    _engineStatus = msg;
    _engineStatusIsError = false;
    DiagnosticsLog.I.record(
      type: DiagnosticActionType.gps,
      ok: true,
      message:
          'gps cell=$cellLabel lat=${fix.lat} lng=${fix.lng} acc=${fix.accuracyM} source=${fix.source} provider=${fix.provider} wroteText=$wroteText',
    );
    if (mounted) {
      setState(() {});
      _showActionSnack(msg, isError: false, icon: Icons.gps_fixed_rounded);
    }
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_engineStatus == msg) {
        setState(() => _engineStatus = null);
      }
    });
  }

  ({String? label, VoidCallback? onPressed}) _gpsErrorAction(String code) {
    if (kIsWeb) {
      return (label: null, onPressed: null);
    }
    switch (code) {
      case 'permission_denied_forever':
        return (
          label: 'Abrir ajustes',
          onPressed: () {
            unawaited(LocationService.I.openAppSettings());
          },
        );
      case 'service_disabled':
        return (
          label: 'Activar GPS',
          onPressed: () {
            unawaited(LocationService.I.openSystemLocationSettings());
          },
        );
      default:
        return (label: null, onPressed: null);
    }
  }

  String _gpsErrorMessage(_GpsOutcome outcome, {String? targetLabel}) {
    final raw = (outcome.error ?? '').trim();
    final lower = raw.toLowerCase();
    final code = (outcome.code ?? '').trim().toLowerCase();
    final prefix = (targetLabel ?? '').trim().isEmpty
        ? 'No pudimos guardar el GPS.'
        : 'No pudimos guardar el GPS en $targetLabel.';

    late final String reason;
    if (lower.contains('https')) {
      reason = 'Este navegador solo permite GPS en HTTPS o localhost.';
    } else if (code == 'permission_denied_forever') {
      reason =
          'El permiso de ubicacion quedo bloqueado. Habilitalo en Ajustes y vuelve a intentar.';
    } else if (code == 'permission_denied' ||
        lower.contains('deneg') ||
        lower.contains('bloquead')) {
      reason =
          'BitFlow no pudo usar la ubicacion. Acepta el permiso y vuelve a intentar.';
    } else if (code == 'service_disabled' ||
        lower.contains('activa el gps') ||
        lower.contains('servicio')) {
      reason =
          'El GPS del dispositivo esta apagado. Activalo y vuelve a intentar.';
    } else if (code == 'timeout' || lower.contains('timeout')) {
      reason =
          'No llego una posicion valida a tiempo. Acercate a un lugar abierto y probalo otra vez.';
    } else if (lower.contains('no disponible') ||
        lower.contains('unavailable')) {
      reason =
          'No encontramos una ubicacion confiable. Revisa la senal y vuelve a intentar.';
    } else {
      reason = 'Revisa permiso, GPS y senal, y vuelve a intentar.';
    }

    return '$prefix $reason';
  }

  void _showGpsError(_GpsOutcome outcome, {String? targetLabel}) {
    final raw = (outcome.error ?? '').trim();
    final code = (outcome.code ?? '').trim().toLowerCase();
    final userMsg = _gpsErrorMessage(outcome, targetLabel: targetLabel);
    final action = _gpsErrorAction(code);

    _engineStatus = userMsg;
    _engineStatusIsError = true;
    DiagnosticsLog.I.record(
      type: DiagnosticActionType.gps,
      ok: false,
      message:
          'gps_error code=${outcome.code ?? 'unknown'} raw=${raw.isEmpty ? 'n/a' : raw}',
    );
    if (mounted) {
      setState(() {});
      _showActionSnack(
        userMsg,
        isError: true,
        icon: Icons.gps_off_rounded,
        actionLabel: action.label,
        onAction: action.onPressed,
      );
    }
  }

  Future<void> _openMapsForCell(int r, int c) async {
    if (r < 0 || r >= _rows.length || c < 0 || c >= _headers.length - 1) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'Selecciona una celda v\u00e1lida para abrir en mapa.',
        ),
        failureIcon: Icons.map_outlined,
      );
      return;
    }
    final meta = _cellMetaAt(r, c)?.gps;
    final txt = _getCellText(r, c);
    double? lat;
    double? lng;
    if (meta != null) {
      lat = meta.lat;
      lng = meta.lng;
    } else if (txt.trim().isNotEmpty) {
      final m = RegExp(
        r'(-?\d+(?:\.\d+)?)[,\s]+(-?\d+(?:\.\d+)?)',
      ).firstMatch(txt);
      if (m == null) {
        _emitActionResult(
          const _ActionResult(
            ok: false,
            message: 'La celda no contiene coordenadas validas.',
          ),
          failureIcon: Icons.map_outlined,
        );
        return;
      }
      lat = double.tryParse(m.group(1) ?? '');
      lng = double.tryParse(m.group(2) ?? '');
    }
    if (lat == null || lng == null) {
      _emitActionResult(
        const _ActionResult(
          ok: false,
          message: 'No hay coordenadas para abrir en mapa.',
        ),
        failureIcon: Icons.map_outlined,
      );
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // ------------------------------ Fotos -----------------------------------

  bool _isValidPhotoTarget(int r, int c) {
    if (r < 0 || c < 0) return false;
    if (r >= _rows.length) return false;
    if (c >= _headers.length) return false;
    return true;
  }

  Future<_CellTarget?> _ensurePhotoTargetCell(int r, int c) async {
    if (_isValidPhotoTarget(r, c)) return _CellTarget(r, c);
    final picked = await _pickPhotoTargetDialog();
    if (!mounted) return picked;
    if (picked != null) {
      _setSelectionAndRefreshGrid(picked.row, picked.col);
    }
    return picked;
  }

  Future<_CellTarget?> _pickPhotoTargetDialog() async {
    if (!mounted) return null;
    final rowCtrl = TextEditingController(text: (_selRow + 1).toString());
    final colCtrl = TextEditingController(text: (_selCol + 1).toString());
    String? error;

    final picked = await showDialog<_CellTarget>(
      context: context,
      builder: (ctx) {
        final pal = _palette(ctx);
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              backgroundColor: pal.menuBg,
              title: const Text('Elegir celda destino'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ingresa fila y columna (1-based).'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: rowCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Fila'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: colCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Col'),
                        ),
                      ),
                    ],
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    final r = int.tryParse(rowCtrl.text.trim());
                    final c = int.tryParse(colCtrl.text.trim());
                    if (r == null || c == null) {
                      setState(() => error = 'Fila/Col invalidas.');
                      return;
                    }
                    final rr = r - 1;
                    final cc = c - 1;
                    if (!_isValidPhotoTarget(rr, cc)) {
                      setState(() => error = 'Fuera de rango.');
                      return;
                    }
                    Navigator.of(ctx).pop(_CellTarget(rr, cc));
                  },
                  child: const Text('Continuar'),
                ),
              ],
            );
          },
        );
      },
    );

    return picked;
  }

  Future<({PhotoAcquireOutcome outcome, bool fromCamera})?>
      _showPhotoSourcePicker() async {
    if (_rows.isEmpty || _headers.isEmpty) return null;
    return showModalBottomSheet<
        ({PhotoAcquireOutcome outcome, bool fromCamera})?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (ctx) {
        final pal = _palette(ctx);
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pal.menuBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pal.border, width: pal.hairline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.photo_camera_outlined, color: pal.fg),
                    const SizedBox(width: 8),
                    Text(
                      'Agregar foto',
                      style: TextStyle(
                        color: pal.fg,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: Icon(Icons.close_rounded, color: pal.fgMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Icon(Icons.photo_camera_outlined, color: pal.fg),
                  title: const Text('Tomar foto'),
                  subtitle: const Text('Usar camara'),
                  onTap: () async {
                    if (_guardInsecureContext(
                      DiagnosticActionType.photo,
                      actionLabel: 'Camara',
                    )) {
                      return;
                    }
                    final preflightOk = await _runPermissionPreflight(
                      storageKey: _kPrefCameraRationaleSeen,
                      permissionLabel: 'camara',
                      rationaleTitle: 'Permiso de camara',
                      rationaleMessage:
                          'Usamos la camara para adjuntar evidencia a la celda seleccionada. '
                          'Las fotos quedan en tu almacenamiento local.',
                      permission: ph.Permission.camera,
                    );
                    if (!preflightOk) return;
                    if (!mounted || !ctx.mounted) return;
                    try {
                      final outcome = await PhotoAcquireService.I
                          .captureFromCamera(context: ctx);
                      if (!ctx.mounted) return;
                      Navigator.of(
                        ctx,
                      ).pop((outcome: outcome, fromCamera: true));
                    } catch (e, st) {
                      DiagnosticsLog.I.updatePhotoAttempt(
                        stage: 'picker_error',
                        error: e.toString(),
                        stack: st.toString(),
                      );
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop((
                        outcome: PhotoAcquireOutcome.error(e.toString()),
                        fromCamera: true,
                      ));
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library_outlined, color: pal.fg),
                  title: const Text('Elegir de galeria'),
                  subtitle: const Text('Seleccionar archivo'),
                  onTap: () async {
                    try {
                      final outcome =
                          await PhotoAcquireService.I.pickFromGallery();
                      if (!ctx.mounted) return;
                      Navigator.of(
                        ctx,
                      ).pop((outcome: outcome, fromCamera: false));
                    } catch (e, st) {
                      DiagnosticsLog.I.updatePhotoAttempt(
                        stage: 'picker_error',
                        error: e.toString(),
                        stack: st.toString(),
                      );
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop((
                        outcome: PhotoAcquireOutcome.error(e.toString()),
                        fromCamera: false,
                      ));
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handlePhotosCellTap(int r, int c) async {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;

    _openPhotosSheetForCell(r, c);
  }

  Future<void> _startCellPhotoPickFromSheet(int r, int c) async {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    await _startPhotoFlowForCell(r, c);
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  // ------------------------------ Export/Share -----------------------------
  // _openExportMenu movido a dialogs/export_dialogs.dart

  Future<bool> _ensureStableSheetForExport(String actionLabel) async {
    if (_saving) {
      _showActionSnack(
        'BitFlow esta guardando cambios. Espera un momento antes de $actionLabel.',
        isError: false,
        icon: Icons.sync_rounded,
      );
      return false;
    }
    if (_rows.isEmpty) {
      _showActionSnack(
        'La planilla no tiene filas. Exportaremos la estructura actual.',
        isError: false,
        icon: Icons.table_rows_outlined,
      );
    }
    if (!_hasUnsavedWork) return true;

    _showActionSnack(
      'Guardando cambios antes de $actionLabel...',
      isError: false,
      icon: Icons.save_outlined,
    );
    await _saveLocalNow();
    final canContinue = _lastSaveSucceeded && !_hasUnsavedWork;
    if (canContinue) return true;

    _showActionSnack(
      'No pudimos $actionLabel porque el guardado fallo o quedo pendiente.',
      isError: true,
      icon: Icons.warning_amber_rounded,
    );
    return false;
  }

  Future<void> _exportXlsxOnly({
    bool includeAttachments = true,
    bool share = false,
  }) async {
    final stable = await _ensureStableSheetForExport(
      share ? 'compartir el XLSX' : 'exportar el XLSX',
    );
    if (!stable) return;
    final canContinue = await _confirmExportWithValidationIfNeeded();
    if (!canContinue) return;
    if (!_tryBeginLongOperation(
      message: AppStrings.progressPreparingExport,
      cancellable: true,
    )) {
      return;
    }
    try {
      _throwIfLongOperationCancelled();
      final fileName = _buildCommercialExportFileName('xlsx');
      final prep = await _prepareExportPayload(
        includeZip: false,
        includeAttachments: includeAttachments,
        shouldCancel: _isLongOperationCancelled,
      );
      if (!mounted) return;
      _throwIfLongOperationCancelled();
      _setLongOperationMessage(AppStrings.progressGeneratingFile);

      final xlsxBytes = await _buildXlsxBytesForExport(
        embeddedPhotos: prep.embeddedPhotos,
        attachments: prep.attachments,
        exportFileName: fileName,
        shouldCancel: _isLongOperationCancelled,
      );
      if (!mounted) return;
      _throwIfLongOperationCancelled();
      if (xlsxBytes == null) {
        _reportFlowErrorMessage(
          'xlsx_generation_failed',
          flow: AppErrorFlow.exportData,
          operation: 'export_xlsx_build',
          fallbackMessage: 'No se pudo generar el archivo XLSX.',
          icon: Icons.table_view_rounded,
        );
        return;
      }

      _setLongOperationMessage(AppStrings.progressWritingFile);
      await _saveExportBytes(
        name: fileName,
        mime:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        bytes: xlsxBytes,
        share: share,
        shouldCancel: _isLongOperationCancelled,
        successMessage: _exportReadyMessage(
          format: 'xlsx',
          share: share,
          fileName: fileName,
        ),
        shareSubject: 'BitFlow | Excel | $_sheetName',
        shareText: 'Planilla Excel exportada desde BitFlow: $_sheetName',
      );
      _throwIfLongOperationCancelled();
      AppHaptics.success();
    } on _EditorLongOperationCancelled {
      _showActionSnack(
        _exportCancelledMessage(share: share),
        isError: false,
        icon: Icons.info_outline_rounded,
      );
    } catch (e, st) {
      final outcome = classifyExportFlowOutcome(e);
      if (outcome == ExportFlowOutcome.cancelled) {
        _showActionSnack(
          _exportCancelledMessage(share: share),
          isError: false,
          icon: Icons.info_outline_rounded,
        );
        return;
      }
      if (outcome == ExportFlowOutcome.unsupported) {
        _reportFlowError(
          e,
          flow: AppErrorFlow.exportData,
          operation: share ? 'share_xlsx' : 'export_xlsx',
          fallbackMessage: _exportUnsupportedMessage(share: share),
          stackTrace: st,
          icon: Icons.table_view_rounded,
        );
        return;
      }
      _reportFlowError(
        e,
        flow: AppErrorFlow.exportData,
        operation: share ? 'share_xlsx' : 'export_xlsx',
        fallbackMessage: _exportFailureMessage(share: share),
        stackTrace: st,
        icon: Icons.table_view_rounded,
      );
    } finally {
      _clearLongOperation();
    }
  }

  Future<void> _exportPdf({
    bool includeAttachments = true,
    bool share = false,
  }) async {
    final stable = await _ensureStableSheetForExport(
      share ? 'compartir el PDF' : 'exportar el PDF',
    );
    if (!stable) return;
    final canContinue = await _confirmExportWithValidationIfNeeded();
    if (!canContinue) return;
    if (!_tryBeginLongOperation(
      message: AppStrings.progressPreparingExport,
      cancellable: true,
    )) {
      return;
    }
    try {
      _throwIfLongOperationCancelled();
      final fileName = _buildCommercialExportFileName('pdf');
      _setLongOperationMessage(AppStrings.progressGeneratingFile);

      final pdfBytes = await _buildPdfBytesForExport(
        includeAttachments: includeAttachments,
        exportFileName: fileName,
        shouldCancel: _isLongOperationCancelled,
      );
      if (!mounted) return;
      _throwIfLongOperationCancelled();
      if (pdfBytes == null || pdfBytes.isEmpty) {
        _reportFlowErrorMessage(
          'pdf_generation_failed',
          flow: AppErrorFlow.exportData,
          operation: 'export_pdf_build',
          fallbackMessage: 'No se pudo generar el archivo PDF.',
          icon: Icons.picture_as_pdf_outlined,
        );
        return;
      }

      _setLongOperationMessage(AppStrings.progressWritingFile);
      await _saveExportBytes(
        name: fileName,
        mime: 'application/pdf',
        bytes: pdfBytes,
        share: share,
        shouldCancel: _isLongOperationCancelled,
        successMessage: _exportReadyMessage(
          format: 'pdf',
          share: share,
          fileName: fileName,
        ),
        shareSubject: 'BitFlow | PDF | $_sheetName',
        shareText: 'Reporte PDF exportado desde BitFlow: $_sheetName',
      );
      _throwIfLongOperationCancelled();
      AppHaptics.success();
    } on _EditorLongOperationCancelled {
      _showActionSnack(
        _exportCancelledMessage(share: share),
        isError: false,
        icon: Icons.info_outline_rounded,
      );
    } catch (e, st) {
      final outcome = classifyExportFlowOutcome(e);
      if (outcome == ExportFlowOutcome.cancelled) {
        _showActionSnack(
          _exportCancelledMessage(share: share),
          isError: false,
          icon: Icons.info_outline_rounded,
        );
        return;
      }
      if (outcome == ExportFlowOutcome.unsupported) {
        _reportFlowError(
          e,
          flow: AppErrorFlow.exportData,
          operation: share ? 'share_pdf' : 'export_pdf',
          fallbackMessage: _exportUnsupportedMessage(share: share),
          stackTrace: st,
          icon: Icons.picture_as_pdf_outlined,
        );
        return;
      }
      _reportFlowError(
        e,
        flow: AppErrorFlow.exportData,
        operation: share ? 'share_pdf' : 'export_pdf',
        fallbackMessage: _exportFailureMessage(share: share),
        stackTrace: st,
        icon: Icons.picture_as_pdf_outlined,
      );
    } finally {
      _clearLongOperation();
    }
  }

  Future<void> _exportZipBundle({required bool share}) async {
    final stable = await _ensureStableSheetForExport(
      share ? 'compartir el ZIP' : 'exportar el ZIP',
    );
    if (!stable) return;
    final canContinue = await _confirmExportWithValidationIfNeeded();
    if (!canContinue) return;
    if (!_tryBeginLongOperation(
      message: AppStrings.progressPreparingExport,
      cancellable: true,
    )) {
      return;
    }
    try {
      _throwIfLongOperationCancelled();
      final xlsxFileName = buildBitFlowPackageWorkbookFileName(
        sheetName: _sheetName,
      );
      final pdfFileName = buildBitFlowPackageReportFileName(
        sheetName: _sheetName,
      );
      final fileName = buildBitFlowBundleExportFileName(sheetName: _sheetName);
      final prep = await _prepareExportPayload(
        includeZip: true,
        shouldCancel: _isLongOperationCancelled,
      );
      if (!mounted) return;
      _throwIfLongOperationCancelled();
      _setLongOperationMessage(AppStrings.progressGeneratingFile);

      final xlsxBytes = await _buildXlsxBytesForExport(
        embeddedPhotos: prep.embeddedPhotos,
        attachments: prep.attachments,
        exportFileName: xlsxFileName,
        shouldCancel: _isLongOperationCancelled,
      );
      if (!mounted) return;
      _throwIfLongOperationCancelled();
      if (xlsxBytes == null) {
        _reportFlowErrorMessage(
          'xlsx_generation_failed',
          flow: AppErrorFlow.exportData,
          operation: 'export_zip_build_xlsx',
          fallbackMessage: 'No se pudo preparar el XLSX para exportar ZIP.',
          icon: Icons.folder_zip_rounded,
        );
        return;
      }

      _setLongOperationMessage('Generando reporte PDF...');
      final pdfBytes = await _buildPdfBytesForExport(
        includeAttachments: true,
        exportFileName: pdfFileName,
        shouldCancel: _isLongOperationCancelled,
      );
      if (!mounted) return;
      _throwIfLongOperationCancelled();
      if (pdfBytes == null) {
        _reportFlowErrorMessage(
          'pdf_generation_failed',
          flow: AppErrorFlow.exportData,
          operation: 'export_zip_build_pdf',
          fallbackMessage: 'No se pudo preparar el PDF para exportar ZIP.',
          icon: Icons.picture_as_pdf_rounded,
        );
        return;
      }

      _setLongOperationMessage(AppStrings.progressPackagingAssets);
      final zipBytes = await _buildAttachmentsZip(
        xlsxBytes: xlsxBytes,
        xlsxFileName: xlsxFileName,
        pdfBytes: pdfBytes,
        pdfFileName: pdfFileName,
        photoItems: prep.photoItems,
        audioItems: prep.audioItems,
        attachments: prep.attachments,
        manifest: prep.manifest,
        packageSheetJson: prep.packageSheetJson,
        shouldCancel: _isLongOperationCancelled,
      );
      if (!mounted) return;
      _throwIfLongOperationCancelled();
      if (zipBytes == null) {
        _reportFlowErrorMessage(
          'zip_generation_failed',
          flow: AppErrorFlow.exportData,
          operation: 'export_zip_build_archive',
          fallbackMessage: 'No se pudo generar el archivo ZIP.',
          icon: Icons.folder_zip_rounded,
        );
        return;
      }

      final evidenceCount = prep.attachments
          .where((item) => item.type.trim().toLowerCase() != 'gps')
          .length;

      _setLongOperationMessage(AppStrings.progressWritingFile);
      await _saveExportBytes(
        name: fileName,
        mime: 'application/zip',
        bytes: zipBytes,
        share: share,
        shouldCancel: _isLongOperationCancelled,
        successMessage: _exportReadyMessage(
          format: 'zip',
          share: share,
          fileName: fileName,
          includeEvidenceHint: evidenceCount > 0,
        ),
        shareSubject: 'BitFlow | Paquete completo | $_sheetName',
        shareText:
            'Paquete ZIP exportado desde BitFlow (XLSX + PDF + evidencias): $_sheetName',
      );
      _throwIfLongOperationCancelled();
      AppHaptics.success();
    } on _EditorLongOperationCancelled {
      _showActionSnack(
        _exportCancelledMessage(share: share),
        isError: false,
        icon: Icons.info_outline_rounded,
      );
    } catch (e, st) {
      final outcome = classifyExportFlowOutcome(e);
      if (outcome == ExportFlowOutcome.cancelled) {
        _showActionSnack(
          _exportCancelledMessage(share: share),
          isError: false,
          icon: Icons.info_outline_rounded,
        );
        return;
      }
      if (outcome == ExportFlowOutcome.unsupported) {
        _reportFlowError(
          e,
          flow: AppErrorFlow.exportData,
          operation: share ? 'share_zip' : 'export_zip',
          fallbackMessage: _exportUnsupportedMessage(share: share),
          stackTrace: st,
          icon: Icons.folder_zip_rounded,
        );
        return;
      }
      _reportFlowError(
        e,
        flow: AppErrorFlow.exportData,
        operation: share ? 'share_zip' : 'export_zip',
        fallbackMessage: _exportFailureMessage(share: share),
        stackTrace: st,
        icon: Icons.folder_zip_rounded,
      );
    } finally {
      _clearLongOperation();
    }
  }

  Future<void> _exportBackupZip() async {
    if (!_tryBeginLongOperation(
      message: AppStrings.progressPreparingExport,
      cancellable: true,
    )) {
      return;
    }
    try {
      _throwIfLongOperationCancelled();
      final bundle = await _prepareBackupBundle(
        shouldCancel: _isLongOperationCancelled,
      );
      if (!mounted) return;
      _throwIfLongOperationCancelled();
      if (bundle == null) {
        _reportFlowErrorMessage(
          'backup_bundle_generation_failed',
          flow: AppErrorFlow.exportData,
          operation: 'export_backup_bundle',
          fallbackMessage: 'No se pudo preparar el backup del proyecto.',
          icon: Icons.backup_rounded,
        );
        return;
      }
      _setLongOperationMessage(AppStrings.progressPackagingAssets);
      final zipBytes = await _buildBackupZip(
        bundle,
        shouldCancel: _isLongOperationCancelled,
      );
      if (!mounted) return;
      _throwIfLongOperationCancelled();
      if (zipBytes == null) {
        _reportFlowErrorMessage(
          'backup_zip_generation_failed',
          flow: AppErrorFlow.exportData,
          operation: 'export_backup_zip_build',
          fallbackMessage: 'No se pudo generar el backup ZIP.',
          icon: Icons.backup_rounded,
        );
        return;
      }

      final now = DateTime.now();
      final baseName =
          '${_safeFile(_sheetName)}_backup_${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}';

      _setLongOperationMessage(AppStrings.progressWritingFile);
      await _saveExportBytes(
        name: '$baseName.zip',
        mime: 'application/zip',
        bytes: zipBytes,
        share: false,
        shouldCancel: _isLongOperationCancelled,
      );
      _throwIfLongOperationCancelled();
      AppHaptics.success();
      _showActionSnack(
        'Backup ZIP listo.',
        isError: false,
        icon: Icons.backup_rounded,
      );
    } on _EditorLongOperationCancelled {
      _showActionSnack(
        AppStrings.infoExportCancelled,
        isError: false,
        icon: Icons.info_outline_rounded,
      );
    } catch (e, st) {
      final outcome = classifyExportFlowOutcome(e);
      if (outcome == ExportFlowOutcome.cancelled) {
        _showActionSnack(
          AppStrings.infoExportCancelled,
          isError: false,
          icon: Icons.info_outline_rounded,
        );
        return;
      }
      if (outcome == ExportFlowOutcome.unsupported) {
        _reportFlowError(
          e,
          flow: AppErrorFlow.exportData,
          operation: 'export_backup_zip',
          fallbackMessage:
              'Exportar backup ZIP no esta disponible en este dispositivo.',
          stackTrace: st,
          icon: Icons.backup_rounded,
        );
        return;
      }
      _reportFlowError(
        e,
        flow: AppErrorFlow.exportData,
        operation: 'export_backup_zip',
        stackTrace: st,
        icon: Icons.backup_rounded,
      );
    } finally {
      _clearLongOperation();
    }
  }

  Future<void> _exportHtmlReport() async {
    if (!_tryBeginLongOperation(
      message: AppStrings.progressPreparingExport,
      cancellable: true,
    )) {
      return;
    }
    try {
      _throwIfLongOperationCancelled();
      _setLongOperationMessage(AppStrings.progressGeneratingFile);
      final bytes = await _buildHtmlReport(
        shouldCancel: _isLongOperationCancelled,
      );
      if (!mounted) return;
      _throwIfLongOperationCancelled();
      if (bytes == null) {
        _reportFlowErrorMessage(
          'html_report_generation_failed',
          flow: AppErrorFlow.exportData,
          operation: 'export_html_build',
          fallbackMessage: 'No se pudo generar el reporte HTML.',
          icon: Icons.description_rounded,
        );
        return;
      }
      final now = DateTime.now();
      final baseName =
          '${_safeFile(_sheetName)}_reporte_${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}';

      _setLongOperationMessage(AppStrings.progressWritingFile);
      await _saveExportBytes(
        name: '$baseName.html',
        mime: 'text/html',
        bytes: bytes,
        share: false,
        shouldCancel: _isLongOperationCancelled,
      );
      _throwIfLongOperationCancelled();
      AppHaptics.success();
      _showActionSnack(
        'Reporte HTML listo.',
        isError: false,
        icon: Icons.description_rounded,
      );
    } on _EditorLongOperationCancelled {
      _showActionSnack(
        AppStrings.infoExportCancelled,
        isError: false,
        icon: Icons.info_outline_rounded,
      );
    } catch (e, st) {
      final outcome = classifyExportFlowOutcome(e);
      if (outcome == ExportFlowOutcome.cancelled) {
        _showActionSnack(
          AppStrings.infoExportCancelled,
          isError: false,
          icon: Icons.info_outline_rounded,
        );
        return;
      }
      if (outcome == ExportFlowOutcome.unsupported) {
        _reportFlowError(
          e,
          flow: AppErrorFlow.exportData,
          operation: 'export_html',
          fallbackMessage:
              'Exportar reporte HTML no esta disponible en este dispositivo.',
          stackTrace: st,
          icon: Icons.description_rounded,
        );
        return;
      }
      _reportFlowError(
        e,
        flow: AppErrorFlow.exportData,
        operation: 'export_html',
        stackTrace: st,
        icon: Icons.description_rounded,
      );
    } finally {
      _clearLongOperation();
    }
  }

  Future<_BackupBundle?> _prepareBackupBundle({
    bool Function()? shouldCancel,
  }) async {
    try {
      _throwIfOperationCancelledBy(shouldCancel);
      final now = DateTime.now();
      final model = _buildModelForSave(now);

      final rowIndexById = <String, int>{};
      for (int i = 0; i < _rows.length; i++) {
        rowIndexById[_rows[i].id] = i;
      }
      final colIndexById = <String, int>{};
      for (int i = 0; i < _colIds.length; i++) {
        colIndexById[_colIds[i]] = i;
      }

      CellKey? resolveCellKey(String raw) {
        final ref = CellRef.fromKey(raw, defaultSheetId: widget.sheetId);
        if (ref != null) {
          final r = rowIndexById[ref.rowId];
          final c = colIndexById[ref.colId];
          if (r == null || c == null) return null;
          return CellKey(r, c);
        }
        return CellKey.fromKey(raw);
      }

      String? resolveCellKeyString(String raw) {
        final ref = CellRef.fromKey(raw, defaultSheetId: widget.sheetId);
        if (ref != null) {
          return ref.withSheet(widget.sheetId).key;
        }
        final cell = CellKey.fromKey(raw);
        if (cell == null) return null;
        if (cell.row < 0 || cell.row >= _rows.length) return null;
        if (cell.col < 0 || cell.col >= _colIds.length) return null;
        final rId = _rows[cell.row].id;
        final cId = _colIds[cell.col];
        return CellRef(sheetId: widget.sheetId, rowId: rId, colId: cId).key;
      }

      final assets = <_BackupAsset>[];
      final manifestAssets = <Map<String, dynamic>>[];

      final entries = _cellMeta.entries.toList();
      entries.sort((a, b) {
        final ca = resolveCellKey(a.key);
        final cb = resolveCellKey(b.key);
        if (ca == null && cb == null) return 0;
        if (ca == null) return 1;
        if (cb == null) return -1;
        final r = ca.row.compareTo(cb.row);
        if (r != 0) return r;
        return ca.col.compareTo(cb.col);
      });

      for (final entry in entries) {
        _throwIfOperationCancelledBy(shouldCancel);
        final cellKey = resolveCellKey(entry.key);
        if (cellKey == null) continue;
        final cellRef = cellKey.a1;
        final normalizedCellKey = resolveCellKeyString(entry.key) ?? entry.key;
        final meta = entry.value;

        for (int i = 0; i < meta.photos.length; i++) {
          _throwIfOperationCancelledBy(shouldCancel);
          final photo = meta.photos[i];
          final fileName = _backupPhotoFileName(cellRef, photo, index: i + 1);
          final path = 'attachments/photos/$fileName';
          final bytes = await _loadPhotoBytesFromAttachment(photo);
          assets.add(
            _BackupAsset(
              kind: 'photo',
              id: photo.id,
              cellKey: normalizedCellKey,
              fileName: fileName,
              path: path,
              mime: photo.mime,
              size: bytes?.lengthInBytes ?? photo.size,
              addedAt: photo.addedAt,
              caption: photo.caption,
              bytes: bytes,
            ),
          );
          manifestAssets.add({
            'kind': 'photo',
            'id': photo.id,
            'cellKey': normalizedCellKey,
            'fileName': fileName,
            'path': path,
            'mime': photo.mime,
            'size': bytes?.lengthInBytes ?? photo.size,
            if (photo.caption.trim().isNotEmpty)
              'caption': photo.caption.trim(),
            'addedAt': photo.addedAt.toIso8601String(),
            if (bytes == null || bytes.isEmpty) 'missing': true,
          });
        }

        for (int i = 0; i < meta.audios.length; i++) {
          _throwIfOperationCancelledBy(shouldCancel);
          final audio = meta.audios[i];
          final fileName = _backupAudioFileName(cellRef, audio, index: i + 1);
          final path = 'attachments/audio/$fileName';
          final bytes = await _loadAudioBytesFromAttachment(audio);
          assets.add(
            _BackupAsset(
              kind: 'audio',
              id: audio.id,
              cellKey: normalizedCellKey,
              fileName: fileName,
              path: path,
              mime: audio.mime,
              size: bytes?.lengthInBytes ?? audio.size,
              addedAt: audio.addedAt,
              durationMs: audio.durationMs,
              bytes: bytes,
            ),
          );
          manifestAssets.add({
            'kind': 'audio',
            'id': audio.id,
            'cellKey': normalizedCellKey,
            'fileName': fileName,
            'path': path,
            'mime': audio.mime,
            'size': bytes?.lengthInBytes ?? audio.size,
            'durationMs': audio.durationMs,
            'addedAt': audio.addedAt.toIso8601String(),
            if (bytes == null || bytes.isEmpty) 'missing': true,
          });
        }
      }

      final backupJson = <String, dynamic>{
        'format': 'bitacora_backup_v1',
        'exportedAt': now.toIso8601String(),
        'sheet': model.toJson(),
        if (manifestAssets.isNotEmpty) 'assets': manifestAssets,
      };

      return _BackupBundle(json: backupJson, assets: assets);
    } on _EditorLongOperationCancelled {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _buildBackupZip(
    _BackupBundle bundle, {
    bool Function()? shouldCancel,
  }) async {
    try {
      _throwIfOperationCancelledBy(shouldCancel);
      final archive = Archive();
      final backupBytes = Uint8List.fromList(
        utf8.encode(jsonEncode(bundle.json)),
      );
      archive.addFile(
        ArchiveFile('backup.json', backupBytes.length, backupBytes),
      );

      for (final asset in bundle.assets) {
        _throwIfOperationCancelledBy(shouldCancel);
        final bytes = asset.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        archive.addFile(ArchiveFile(asset.path, bytes.length, bytes));
      }

      final encoder = ZipEncoder();
      final zipData = encoder.encode(archive);
      return Uint8List.fromList(zipData);
    } on _EditorLongOperationCancelled {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _buildHtmlReport({bool Function()? shouldCancel}) async {
    try {
      _throwIfOperationCancelledBy(shouldCancel);
      final html = StringBuffer();
      final esc = const HtmlEscape(HtmlEscapeMode.element);
      final now = DateTime.now();
      final title = _sheetName.trim().isEmpty ? 'Bitacora' : _sheetName.trim();

      html.write('<!doctype html><html><head><meta charset="utf-8">');
      html.write(
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
      );
      html.write('<title>${esc.convert(title)} - Reporte</title>');
      html.write('<style>');
      html.write(
        'body{font-family:Arial,Helvetica,sans-serif;margin:32px;color:#111;}',
      );
      html.write(
        '.header{display:flex;justify-content:space-between;align-items:flex-end;margin-bottom:20px;}',
      );
      html.write('.brand{font-weight:700;font-size:20px;}');
      html.write('.muted{color:#666;font-size:12px;}');
      html.write('.actions{margin:12px 0 20px 0;}');
      html.write(
        'button{padding:8px 12px;border:1px solid #111;background:#fff;cursor:pointer;}',
      );
      html.write('table{width:100%;border-collapse:collapse;font-size:12px;}');
      html.write(
        'th,td{border:1px solid #ddd;padding:8px;vertical-align:top;}',
      );
      html.write('th{background:#f5f5f5;text-align:left;}');
      html.write(
        '.evidences{margin-top:6px;display:flex;gap:8px;flex-wrap:wrap;}',
      );
      html.write('.evidence{width:110px;}');
      html.write(
        '.evidence img{width:100%;height:auto;border-radius:6px;border:1px solid #ddd;}',
      );
      html.write(
        '.evidence .cap{font-size:10px;color:#555;margin-top:4px;line-height:1.2;}',
      );
      html.write('@media print{button{display:none;} body{margin:8px;}}');
      html.write('</style></head><body>');
      html.write('<div class="header">');
      html.write('<div class="brand">${esc.convert(title)}</div>');
      html.write(
        '<div class="muted">Generado: ${_formatDateTimeShort(now)}</div>',
      );
      html.write('</div>');
      html.write(
        '<div class="actions"><button onclick="window.print()">Imprimir / Guardar PDF</button></div>',
      );
      html.write('<table><thead><tr>');

      final dataCols = math.max(0, _headers.length);
      for (int c = 0; c < dataCols; c++) {
        html.write('<th>${esc.convert(_headerLabel(c))}</th>');
      }
      html.write('</tr></thead><tbody>');

      for (int r = 0; r < _rows.length; r++) {
        _throwIfOperationCancelledBy(shouldCancel);
        html.write('<tr>');
        for (int c = 0; c < dataCols; c++) {
          _throwIfOperationCancelledBy(shouldCancel);
          final text = (c < _rows[r].cells.length) ? _rows[r].cells[c] : '';
          html.write('<td>');
          html.write('<div>${esc.convert(text)}</div>');
          final meta = _cellMetaAt(r, c);
          final photos = meta?.photos ?? const <PhotoAttachment>[];
          if (photos.isNotEmpty) {
            html.write('<div class="evidences">');
            for (final photo in photos) {
              _throwIfOperationCancelledBy(shouldCancel);
              final dataUri = await _photoThumbDataUri(photo);
              if (dataUri.isEmpty) continue;
              html.write('<div class="evidence">');
              html.write('<img src="$dataUri" alt="evidencia">');
              final caption = photo.caption.trim().isNotEmpty
                  ? photo.caption.trim()
                  : photo.filename.trim();
              final dateLabel = _formatDateTimeShort(photo.addedAt);
              html.write(
                '<div class="cap">${esc.convert(caption)}<br>${esc.convert(dateLabel)}</div>',
              );
              html.write('</div>');
            }
            html.write('</div>');
          }
          html.write('</td>');
        }
        html.write('</tr>');
      }

      html.write('</tbody></table></body></html>');
      return Uint8List.fromList(utf8.encode(html.toString()));
    } on _EditorLongOperationCancelled {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<String> _photoThumbDataUri(PhotoAttachment photo) async {
    final thumb = photo.thumbRef.trim();
    if (thumb.isNotEmpty) {
      return 'data:image/jpeg;base64,$thumb';
    }
    final bytes = await _loadPhotoBytesFromAttachment(photo, preferThumb: true);
    if (bytes == null || bytes.isEmpty) return '';
    final thumbBytes =
        _compressThumb(bytes, maxW: 320, maxH: 320, quality: 70) ?? bytes;
    final b64 = base64Encode(thumbBytes);
    return 'data:image/jpeg;base64,$b64';
  }

  Future<Uint8List?> _buildXlsxBytesForExport({
    required List<EmbeddedPhoto> embeddedPhotos,
    required List<AttachmentRow> attachments,
    String? exportFileName,
    bool Function()? shouldCancel,
  }) async {
    _throwIfOperationCancelledBy(shouldCancel);
    _recomputeValidation();
    final quality = _sheetQuality;
    final dataCols = math.max(0, _headers.length - 1); // sin Photos
    final columns = List<String>.generate(dataCols, (i) => _headerLabel(i));
    final columnTypes = _buildExportColumnTypes(dataCols);
    final cover = _buildExportCoverContext();
    final gpsByRow = _buildGpsByRowForExport();
    final rows = <List<String>>[];
    for (final row in _rows) {
      _throwIfOperationCancelledBy(shouldCancel);
      final values = List<String>.filled(dataCols, '');
      for (int c = 0; c < dataCols && c < row.cells.length; c++) {
        values[c] = row.cells[c];
      }
      rows.add(values);
    }

    return buildXlsxWithPhotos(
      columns: columns,
      rows: rows,
      embeddedPhotos: embeddedPhotos,
      attachments: attachments,
      gpsByRow: gpsByRow,
      columnTypes: columnTypes,
      sheetName: _sheetName,
      includeIndexColumn: false,
      includeCoverSheet: true,
      includeSummarySheet: true,
      exportedAt: DateTime.now(),
      exportFileName: exportFileName,
      clientName: cover.clientName,
      projectName: cover.projectName,
      responsibleName: cover.responsibleName,
      observations: cover.observations,
      qualityStatus: quality.statusLabel,
      qualityCompletionPercent: quality.requiredCompletionPercent,
      qualityRowsReady: quality.rowsReady,
      qualityRowsWithData: quality.rowsWithData,
      qualityInvalidCells: quality.invalidCells,
      qualityPendingRequired: quality.pendingRequired,
    );
  }

  Future<Uint8List?> _buildPdfBytesForExport({
    required bool includeAttachments,
    String? exportFileName,
    bool Function()? shouldCancel,
  }) async {
    _throwIfOperationCancelledBy(shouldCancel);
    _recomputeValidation();
    final quality = _sheetQuality;
    final dataCols = math.max(0, _headers.length - 1);
    final includeReviewColumns = _rows.any(
      (row) =>
          row.reviewed ||
          (row.reviewedBy?.trim().isNotEmpty ?? false) ||
          row.reviewedAt != null,
    );
    final headers = List<String>.generate(dataCols, (i) => _headerLabel(i));
    if (includeReviewColumns) {
      headers
        ..add('Revisado')
        ..add('Revisado por')
        ..add('Revisado en');
    }
    final rows = <List<String>>[];
    var reviewedCount = 0;
    for (final row in _rows) {
      _throwIfOperationCancelledBy(shouldCancel);
      final values = <String>[];
      for (int c = 0; c < dataCols && c < row.cells.length; c++) {
        values.add(row.cells[c]);
      }
      if (includeReviewColumns) {
        final reviewed = row.reviewed;
        if (reviewed) reviewedCount++;
        values.add(reviewed ? 'Si' : 'No');
        values.add(row.reviewedBy ?? '');
        values.add(
          row.reviewedAt == null
              ? ''
              : _formatDateTimeShort(row.reviewedAt!.toLocal()),
        );
      }
      rows.add(values);
    }

    pw.Font? pdfBaseFont;
    pw.Font? pdfBoldFont;
    try {
      final regular = await rootBundle.load('assets/fonts/roboto-regular.ttf');
      final bold = await rootBundle.load('assets/fonts/roboto-bold.ttf');
      pdfBaseFont = pw.Font.ttf(regular);
      pdfBoldFont = pw.Font.ttf(bold);
    } catch (_) {}

    final doc = pw.Document(
      theme: (pdfBaseFont != null && pdfBoldFont != null)
          ? pw.ThemeData.withFont(
              base: pdfBaseFont,
              bold: pdfBoldFont,
            )
          : null,
    );
    final appVersion = await _readAppVersionForExport();
    final buildId = BuildInfo.buildIdLabel;
    final now = DateTime.now().toLocal();
    final exportedAt =
        '${now.year}-${_two(now.month)}-${_two(now.day)} ${_two(now.hour)}:${_two(now.minute)}';
    final cover = _buildExportCoverContext();
    final reportFileName = (exportFileName ?? '').trim();

    final attachmentRows = <List<String>>[];
    final evidenceItems = <({
      String cell,
      String kind,
      String caption,
      String date,
      String detail,
      String? mapUrl,
      Uint8List? thumb,
    })>[];
    var photoCount = 0;
    var videoCount = 0;
    var audioCount = 0;
    var gpsCount = 0;
    var fileCount = 0;

    if (includeAttachments) {
      final entries = _cellMeta.entries.toList(growable: false);
      entries.sort((a, b) => a.key.compareTo(b.key));
      for (final entry in entries) {
        _throwIfOperationCancelledBy(shouldCancel);
        final meta = entry.value;
        if (meta.isEmpty) continue;
        final ref = CellRef.fromKey(entry.key, defaultSheetId: widget.sheetId);
        final cellLabel = _cellLabelForRef(ref);

        if (meta.gps != null) {
          final gps = meta.gps!;
          gpsCount++;
          final mapUrl =
              'https://www.google.com/maps/search/?api=1&query=${gps.lat},${gps.lng}';
          attachmentRows.add(<String>[
            cellLabel,
            'GPS',
            'Precisión ${gps.accuracyM.toStringAsFixed(1)} m',
            _formatDateTimeShort(gps.timestamp.toLocal()),
          ]);
          evidenceItems.add((
            cell: cellLabel,
            kind: 'GPS',
            caption:
                '${gps.lat.toStringAsFixed(6)}, ${gps.lng.toStringAsFixed(6)}',
            date: _formatDateTimeShort(gps.timestamp.toLocal()),
            detail:
                'Precisión ${gps.accuracyM.toStringAsFixed(1)} m${gps.source.trim().isNotEmpty ? ' | ${gps.source}' : ''}',
            mapUrl: mapUrl,
            thumb: null,
          ));
        }

        for (final photo in meta.photos) {
          _throwIfOperationCancelledBy(shouldCancel);
          final mime = photo.mime.toLowerCase();
          final isVideo = mime.startsWith('video/');
          final isImage = mime.startsWith('image/');
          final kindLabel = isVideo ? 'Video' : (isImage ? 'Foto' : 'Archivo');
          if (isVideo) {
            videoCount++;
          } else if (isImage) {
            photoCount++;
          } else {
            fileCount++;
          }
          final caption = photo.caption.trim().isNotEmpty
              ? photo.caption.trim()
              : photo.filename.trim();
          final mapUrl = (photo.lat != null && photo.lon != null)
              ? 'https://www.google.com/maps/search/?api=1&query=${photo.lat},${photo.lon}'
              : null;
          final dateText = _formatDateTimeShort(photo.addedAt.toLocal());
          attachmentRows.add(<String>[
            cellLabel,
            kindLabel,
            caption.isEmpty ? photo.filename : caption,
            dateText,
          ]);

          Uint8List? thumb;
          final bytes = await _loadPhotoBytesFromAttachment(
            photo,
            preferThumb: true,
          );
          if (bytes != null && bytes.isNotEmpty) {
            thumb = _compressThumb(bytes, maxW: 360, maxH: 240, quality: 70) ??
                bytes;
          }
          evidenceItems.add((
            cell: cellLabel,
            kind: kindLabel,
            caption: caption.isEmpty ? photo.filename : caption,
            date: dateText,
            detail: [
              _formatBytes(photo.size),
              if (photo.lat != null && photo.lon != null)
                '${photo.lat!.toStringAsFixed(6)}, ${photo.lon!.toStringAsFixed(6)}',
            ].join(' | '),
            mapUrl: mapUrl,
            thumb: thumb,
          ));
        }

        for (final audio in meta.audios) {
          audioCount++;
          final dateText = _formatDateTimeShort(audio.addedAt.toLocal());
          attachmentRows.add(<String>[
            cellLabel,
            'Audio',
            audio.filename.trim().isEmpty ? 'audio' : audio.filename.trim(),
            dateText,
          ]);
          evidenceItems.add((
            cell: cellLabel,
            kind: 'Audio',
            caption:
                'Duracion ${(audio.durationMs / 1000).toStringAsFixed(1)}s',
            date: dateText,
            detail: _formatBytes(audio.size),
            mapUrl: null,
            thumb: null,
          ));
        }
      }
    }

    final totalAttachments = photoCount + videoCount + audioCount + fileCount;
    final evidencePreview = evidenceItems.take(18).toList(growable: false);

    doc.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
        ),
        build: (context) {
          pw.Widget infoRow(String label, String value) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 110,
                    child: pw.Text(
                      label,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      value.isEmpty ? 'No informado' : value,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            );
          }

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                color: PdfColors.blueGrey900,
                child: pw.Text(
                  'BitFlow',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 28),
              pw.Text(
                'Reporte profesional',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                _sheetName.trim().isEmpty ? 'Planilla' : _sheetName.trim(),
                style: const pw.TextStyle(fontSize: 15),
              ),
              pw.SizedBox(height: 24),
              infoRow('Fecha', exportedAt),
              infoRow(
                'Archivo',
                reportFileName.isEmpty ? 'No informado' : reportFileName,
              ),
              infoRow('Cliente', cover.clientName ?? ''),
              infoRow('Obra / proyecto', cover.projectName ?? ''),
              infoRow('Responsable', cover.responsibleName ?? ''),
              infoRow('Observaciones', cover.observations ?? ''),
              pw.Spacer(),
              pw.Text(
                'BitFlow | Version $appVersion | Build $buildId',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          );
        },
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
        ),
        build: (context) {
          pw.Widget metricChip(String label, String value) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    '$label: ',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            );
          }

          final content = <pw.Widget>[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'BitFlow | Reporte profesional',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Planilla: ${_sheetName.trim().isEmpty ? 'Planilla' : _sheetName.trim()}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    'Exportado: $exportedAt',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  if (reportFileName.isNotEmpty)
                    pw.Text(
                      'Archivo: $reportFileName',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                metricChip('Registros', '${_rows.length}'),
                metricChip('Celdas con dato', '${_countNonEmptyCells()}'),
                metricChip(
                  'Integridad',
                  '${quality.requiredCompletionPercent}%',
                ),
                metricChip(
                  'Filas listas',
                  '${quality.rowsReady}/${math.max(quality.rowsWithData, quality.rowsTotal)}',
                ),
                metricChip('Errores', '${quality.invalidCells}'),
                metricChip('Evidencias', '$totalAttachments'),
                metricChip('Fotos', '$photoCount'),
                metricChip('Videos', '$videoCount'),
                metricChip('Audios', '$audioCount'),
                metricChip('GPS', '$gpsCount'),
                if (includeReviewColumns)
                  metricChip('Revisadas', '$reviewedCount/${_rows.length}'),
              ],
            ),
            pw.SizedBox(height: 12),
          ];

          content.add(
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: pw.BoxDecoration(
                color:
                    quality.hasIssues ? PdfColors.orange50 : PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(
                  color: quality.hasIssues
                      ? PdfColors.orange300
                      : PdfColors.green300,
                  width: 0.8,
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Estado de carga: ${quality.statusLabel}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _sheetQualityDetail(
                      quality,
                      evidenceCount: totalAttachments,
                    ),
                    style: const pw.TextStyle(fontSize: 8.5),
                  ),
                ],
              ),
            ),
          );
          content.add(pw.SizedBox(height: 12));

          if (headers.isNotEmpty) {
            content
              ..add(
                pw.Text(
                  'Tabla principal',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              )
              ..add(pw.SizedBox(height: 6));
            content.add(
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: rows,
                headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignments: {
                  for (int i = 0; i < headers.length; i++)
                    i: pw.Alignment.centerLeft,
                },
              ),
            );
          } else {
            content.add(pw.Text('Sin columnas exportables.'));
          }

          if (includeAttachments) {
            content
              ..add(pw.SizedBox(height: 14))
              ..add(
                pw.Text(
                  'Adjuntos por celda',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              )
              ..add(pw.SizedBox(height: 6));
            if (attachmentRows.isEmpty) {
              content.add(
                pw.Text(
                  'No hay adjuntos registrados.',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              );
            } else {
              content.add(
                pw.TableHelper.fromTextArray(
                  headers: const <String>['Celda', 'Tipo', 'Detalle', 'Fecha'],
                  data: attachmentRows,
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                ),
              );
            }

            if (evidencePreview.isNotEmpty) {
              content
                ..add(pw.SizedBox(height: 12))
                ..add(
                  pw.Text(
                    'Evidencias',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                )
                ..add(pw.SizedBox(height: 6))
                ..add(
                  pw.Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in evidencePreview)
                        pw.Container(
                          width: 220,
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            borderRadius: pw.BorderRadius.circular(8),
                            border: pw.Border.all(
                              color: PdfColors.grey400,
                              width: 0.6,
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                '${item.kind} | ${item.cell}',
                                style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              if (item.thumb != null &&
                                  item.thumb!.isNotEmpty) ...[
                                pw.SizedBox(height: 6),
                                pw.ClipRRect(
                                  horizontalRadius: 6,
                                  verticalRadius: 6,
                                  child: pw.Image(
                                    pw.MemoryImage(item.thumb!),
                                    height: 70,
                                    width: double.infinity,
                                    fit: pw.BoxFit.cover,
                                  ),
                                ),
                              ],
                              pw.SizedBox(height: 5),
                              pw.Text(
                                item.caption,
                                maxLines: 2,
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                              if (item.detail.trim().isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  item.detail,
                                  maxLines: 2,
                                  style: const pw.TextStyle(fontSize: 7.5),
                                ),
                              ],
                              pw.SizedBox(height: 2),
                              pw.Text(
                                item.date,
                                style: const pw.TextStyle(fontSize: 7.5),
                              ),
                              if (item.mapUrl != null) ...[
                                pw.SizedBox(height: 2),
                                pw.UrlLink(
                                  destination: item.mapUrl!,
                                  child: pw.Text(
                                    'Abrir en mapas',
                                    style: pw.TextStyle(
                                      fontSize: 7.5,
                                      color: PdfColors.blue700,
                                      decoration: pw.TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                );
            }
          }
          return content;
        },
      ),
    );
    return Uint8List.fromList(await doc.save());
  }

  Future<_ExportPrep> _prepareExportPayload({
    required bool includeZip,
    bool includeAttachments = true,
    bool Function()? shouldCancel,
  }) async {
    _throwIfOperationCancelledBy(shouldCancel);
    _recomputeValidation();
    final quality = _sheetQuality;
    final attachments = <AttachmentRow>[];
    final embeddedPhotos = <EmbeddedPhoto>[];
    final photoItems = <_ZipPhotoItem>[];
    final audioItems = <_ZipAudioItem>[];
    final manifestCells = <String, Map<String, dynamic>>{};
    final manifestAssets = <Map<String, dynamic>>[];
    final dataCols = math.max(0, _headers.length - 1);
    final exportedAtUtc = DateTime.now().toUtc();
    final packageSheetJson = _buildPackageSheetJson(
      exportedAtUtc: exportedAtUtc,
    );

    if (!includeAttachments) {
      final manifest = includeZip
          ? await _buildPackageManifest(
              exportedAtUtc: exportedAtUtc,
              manifestCells: manifestCells,
              manifestAssets: manifestAssets,
              photoCount: 0,
              videoCount: 0,
              audioCount: 0,
              gpsCount: 0,
              fileCount: 0,
              quality: quality,
            )
          : const <String, dynamic>{};
      return _ExportPrep(
        attachments: attachments,
        embeddedPhotos: embeddedPhotos,
        photoItems: photoItems,
        audioItems: audioItems,
        manifest: manifest,
        packageSheetJson: packageSheetJson,
      );
    }

    final rowIndexById = <String, int>{};
    for (int i = 0; i < _rows.length; i++) {
      rowIndexById[_rows[i].id] = i;
    }
    final colIndexById = <String, int>{};
    for (int i = 0; i < _colIds.length; i++) {
      colIndexById[_colIds[i]] = i;
    }

    final entries = _cellMeta.entries.toList();
    entries.sort((a, b) {
      final ca = _resolveExportCellKey(
        a.key,
        rowIndexById: rowIndexById,
        colIndexById: colIndexById,
      );
      final cb = _resolveExportCellKey(
        b.key,
        rowIndexById: rowIndexById,
        colIndexById: colIndexById,
      );
      if (ca == null && cb == null) return 0;
      if (ca == null) return 1;
      if (cb == null) return -1;
      final r = ca.row.compareTo(cb.row);
      if (r != 0) return r;
      return ca.col.compareTo(cb.col);
    });

    for (final entry in entries) {
      _throwIfOperationCancelledBy(shouldCancel);
      final cell = _resolveExportCellKey(
        entry.key,
        rowIndexById: rowIndexById,
        colIndexById: colIndexById,
      );
      if (cell == null) continue;
      final meta = entry.value;
      if (meta.isEmpty) continue;
      final cellRef = cell.a1;
      final rowLabel = 'Fila-${cell.row + 1}';
      final rowNumber = cell.row + 1;
      final cellManifest = <String, dynamic>{};

      if (meta.gps != null) {
        final gps = meta.gps!;
        attachments.add(
          AttachmentRow(
            sheetName: _sheetName,
            cellRef: cellRef,
            rowLabel: rowLabel,
            type: 'gps',
            fileName: '',
            description: _gpsNotes(gps),
            addedAt: gps.timestamp,
            relativePath: '',
            rowNumber: rowNumber,
            latitude: gps.lat,
            longitude: gps.lng,
          ),
        );
        if (includeZip) {
          cellManifest['gps'] = gps.toJson();
        }
      }

      if (meta.photos.isNotEmpty) {
        final manifestPhotos = <Map<String, dynamic>>[];
        for (int i = 0; i < meta.photos.length; i++) {
          _throwIfOperationCancelledBy(shouldCancel);
          final photo = meta.photos[i];
          final lowerMime = photo.mime.toLowerCase();
          final isVideo = lowerMime.startsWith('video/');
          final isImage = lowerMime.startsWith('image/');
          final itemType = isVideo ? 'video' : (isImage ? 'foto' : 'archivo');
          final manifestKind = isVideo ? 'video' : (isImage ? 'photo' : 'file');
          final fileName = _exportPhotoFileName(
            cellRef,
            photo,
            kind: itemType,
            index: i + 1,
          );
          final folder = itemType == 'foto'
              ? 'fotos'
              : (itemType == 'video' ? 'videos' : 'archivos');
          final relPath = 'evidencias/$folder/$fileName';

          attachments.add(
            AttachmentRow(
              sheetName: _sheetName,
              cellRef: cellRef,
              rowLabel: rowLabel,
              type: itemType,
              fileName: fileName,
              description: _photoNotes(photo),
              addedAt: photo.addedAt,
              relativePath: relPath,
              rowNumber: rowNumber,
              latitude: photo.lat,
              longitude: photo.lon,
            ),
          );

          if (i == 0 && isImage && cell.col >= 0 && cell.col < dataCols) {
            final bytes = await _loadPhotoBytesFromAttachment(photo);
            if (bytes != null && bytes.isNotEmpty) {
              embeddedPhotos.add(
                EmbeddedPhoto(
                  rowIndex: cell.row,
                  colIndex: cell.col,
                  bytes: _resizeForExport(bytes),
                ),
              );
            }
          }

          if (includeZip) {
            photoItems.add(
              _ZipPhotoItem(
                cell: cell,
                photo: photo,
                fileName: fileName,
                pathInZip: relPath,
              ),
            );
            final photoManifest = <String, dynamic>{
              'id': photo.id,
              'kind': manifestKind,
              'cellKey': cellRef,
              'row': rowNumber,
              'type': itemType,
              'fileName': fileName,
              if (photo.caption.trim().isNotEmpty)
                'caption': photo.caption.trim(),
              'mime': photo.mime,
              'size': photo.size,
              'path': relPath,
              if (photo.lat != null) 'lat': photo.lat,
              if (photo.lon != null) 'lon': photo.lon,
              if (photo.accuracyM != null) 'accuracyM': photo.accuracyM,
              'addedAt': photo.addedAt.toIso8601String(),
            };
            manifestPhotos.add(photoManifest);
            manifestAssets.add(photoManifest);
          }
        }
        if (includeZip && manifestPhotos.isNotEmpty) {
          cellManifest['photos'] = manifestPhotos;
        }
      }

      if (meta.audios.isNotEmpty) {
        final manifestAudios = <Map<String, dynamic>>[];
        for (int i = 0; i < meta.audios.length; i++) {
          _throwIfOperationCancelledBy(shouldCancel);
          final audio = meta.audios[i];
          final fileName = _exportAudioFileName(cellRef, audio, index: i + 1);
          final relPath = 'evidencias/audio/$fileName';

          attachments.add(
            AttachmentRow(
              sheetName: _sheetName,
              cellRef: cellRef,
              rowLabel: rowLabel,
              type: 'audio',
              fileName: fileName,
              description: _audioNotes(audio),
              addedAt: audio.addedAt,
              relativePath: relPath,
              rowNumber: rowNumber,
            ),
          );

          if (includeZip) {
            audioItems.add(
              _ZipAudioItem(
                cell: cell,
                audio: audio,
                fileName: fileName,
                pathInZip: relPath,
              ),
            );
            final audioManifest = <String, dynamic>{
              'id': audio.id,
              'kind': 'audio',
              'cellKey': cellRef,
              'row': rowNumber,
              'fileName': fileName,
              'mime': audio.mime,
              'size': audio.size,
              'durationMs': audio.durationMs,
              'path': relPath,
              'addedAt': audio.addedAt.toIso8601String(),
            };
            manifestAudios.add(audioManifest);
            manifestAssets.add(audioManifest);
          }
        }
        if (includeZip && manifestAudios.isNotEmpty) {
          cellManifest['audios'] = manifestAudios;
        }
      }

      if (includeZip && cellManifest.isNotEmpty) {
        manifestCells[cellRef] = cellManifest;
      }
    }

    final photoCount = attachments
        .where((item) => item.type.trim().toLowerCase() == 'foto')
        .length;
    final videoCount = attachments
        .where((item) => item.type.trim().toLowerCase() == 'video')
        .length;
    final audioCount = attachments
        .where((item) => item.type.trim().toLowerCase() == 'audio')
        .length;
    final fileCount = attachments
        .where((item) => item.type.trim().toLowerCase() == 'archivo')
        .length;
    final gpsCount = attachments
        .where((item) => item.type.trim().toLowerCase() == 'gps')
        .length;
    final manifest = includeZip
        ? await _buildPackageManifest(
            exportedAtUtc: exportedAtUtc,
            manifestCells: manifestCells,
            manifestAssets: manifestAssets,
            photoCount: photoCount,
            videoCount: videoCount,
            audioCount: audioCount,
            gpsCount: gpsCount,
            fileCount: fileCount,
            quality: quality,
          )
        : const <String, dynamic>{};

    return _ExportPrep(
      attachments: attachments,
      embeddedPhotos: embeddedPhotos,
      photoItems: photoItems,
      audioItems: audioItems,
      manifest: manifest,
      packageSheetJson: packageSheetJson,
    );
  }

  Future<Uint8List?> _buildAttachmentsZip({
    required Uint8List xlsxBytes,
    required String xlsxFileName,
    required Uint8List pdfBytes,
    required String pdfFileName,
    required List<_ZipPhotoItem> photoItems,
    required List<_ZipAudioItem> audioItems,
    required List<AttachmentRow> attachments,
    required Map<String, dynamic> manifest,
    required Map<String, dynamic> packageSheetJson,
    bool Function()? shouldCancel,
  }) async {
    _throwIfOperationCancelledBy(shouldCancel);
    final archive = Archive();
    archive.addFile(
      ArchiveFile(xlsxFileName, xlsxBytes.length, xlsxBytes),
    );
    archive.addFile(
      ArchiveFile(pdfFileName, pdfBytes.length, pdfBytes),
    );

    for (final item in photoItems) {
      _throwIfOperationCancelledBy(shouldCancel);
      final bytes = await _loadPhotoBytesFromAttachment(item.photo);
      if (bytes == null || bytes.isEmpty) continue;
      archive.addFile(ArchiveFile(item.pathInZip, bytes.length, bytes));
    }

    for (final item in audioItems) {
      _throwIfOperationCancelledBy(shouldCancel);
      final bytes = await _loadAudioBytesFromAttachment(item.audio);
      if (bytes == null || bytes.isEmpty) continue;
      archive.addFile(ArchiveFile(item.pathInZip, bytes.length, bytes));
    }

    final manifestBytes = Uint8List.fromList(utf8.encode(jsonEncode(manifest)));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    final sheetJsonBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(packageSheetJson)),
    );
    archive.addFile(
      ArchiveFile('sheet.json', sheetJsonBytes.length, sheetJsonBytes),
    );

    final readme = _buildPackageReadme(
      xlsxFileName: xlsxFileName,
      pdfFileName: pdfFileName,
      attachments: attachments,
    );
    final readmeBytes = Uint8List.fromList(utf8.encode(readme));
    archive.addFile(ArchiveFile('README.txt', readmeBytes.length, readmeBytes));

    final encoder = ZipEncoder();
    final zipData = encoder.encode(archive);
    return Uint8List.fromList(zipData);
  }

  Future<Map<String, dynamic>> _buildPackageManifest({
    required DateTime exportedAtUtc,
    required Map<String, Map<String, dynamic>> manifestCells,
    required List<Map<String, dynamic>> manifestAssets,
    required int photoCount,
    required int videoCount,
    required int audioCount,
    required int gpsCount,
    required int fileCount,
    required _SheetQualitySnapshot quality,
  }) async {
    final appVersion = await _readAppVersionForExport();
    final nonEmptyCells = _countNonEmptyCells();
    final totalAttachments = photoCount + videoCount + audioCount + fileCount;
    final evidencePaths = <String>[
      'evidencias/fotos',
      'evidencias/videos',
      'evidencias/audio',
      if (fileCount > 0) 'evidencias/archivos',
    ];

    return <String, dynamic>{
      'format': 'bitflow_package_v1',
      'collaboration': {'snapshotMode': 'full', 'supportsMerge': true},
      'appVersion': appVersion,
      'buildId': BuildInfo.buildIdLabel,
      'exportedAt': exportedAtUtc.toIso8601String(),
      'platform': _platformLabelForExport(),
      'sheet': {
        'id': widget.sheetId,
        'name': _sheetName,
        'rowCount': _rows.length,
        'columnCount': _headers.length,
      },
      'package': {
        'workbook': buildBitFlowPackageWorkbookFileName(sheetName: _sheetName),
        'report': buildBitFlowPackageReportFileName(sheetName: _sheetName),
        'evidencePaths': evidencePaths,
      },
      'counts': {
        'rows': _rows.length,
        'cells': nonEmptyCells,
        'attachments': totalAttachments,
        'photos': photoCount,
        'videos': videoCount,
        'audios': audioCount,
        'gps': gpsCount,
        'files': fileCount,
      },
      'quality': {
        'status': quality.statusLabel,
        'requiredCompletionPercent': quality.requiredCompletionPercent,
        'rowsWithData': quality.rowsWithData,
        'rowsReady': quality.rowsReady,
        'invalidCells': quality.invalidCells,
        'pendingRequired': quality.pendingRequired,
      },
      if (manifestCells.isNotEmpty) 'cells': manifestCells,
      if (manifestAssets.isNotEmpty) 'assets': manifestAssets,
    };
  }

  Map<String, dynamic> _buildPackageSheetJson({
    required DateTime exportedAtUtc,
  }) {
    final model = _buildModelForSave(DateTime.now());
    final json = model.toJson();
    json['sheetId'] = widget.sheetId;
    json['packageMeta'] = <String, dynamic>{
      'format': 'bitflow_package_v1',
      'exportedAt': exportedAtUtc.toIso8601String(),
      'snapshotMode': 'full',
      'sourceRevision': _rev,
    };
    return json;
  }

  String _buildPackageReadme({
    required String xlsxFileName,
    required String pdfFileName,
    required List<AttachmentRow> attachments,
  }) {
    final quality = _sheetQuality;
    final photoCount = attachments
        .where((item) => item.type.trim().toLowerCase() == 'foto')
        .length;
    final videoCount = attachments
        .where((item) => item.type.trim().toLowerCase() == 'video')
        .length;
    final audioCount = attachments
        .where((item) => item.type.trim().toLowerCase() == 'audio')
        .length;
    final gpsCount = attachments
        .where((item) => item.type.trim().toLowerCase() == 'gps')
        .length;
    final fileCount = attachments
        .where((item) => item.type.trim().toLowerCase() == 'archivo')
        .length;
    final evidenceTotal = photoCount + videoCount + audioCount + fileCount;
    return [
      'BitFlow - Paquete completo',
      '',
      'Planilla: ${_sheetName.trim().isEmpty ? 'Planilla' : _sheetName.trim()}',
      'Exportado: ${_formatDateTimeShort(DateTime.now().toLocal())}',
      '',
      'Contenido principal:',
      '- $xlsxFileName',
      '- $pdfFileName',
      '- evidencias/fotos/',
      '- evidencias/videos/',
      '- evidencias/audio/',
      if (fileCount > 0) '- evidencias/archivos/',
      '- manifest.json',
      '- sheet.json',
      '',
      'Resumen:',
      '- Evidencias totales: $evidenceTotal',
      '- Fotos: $photoCount',
      '- Videos: $videoCount',
      '- Audios: $audioCount',
      '- Ubicaciones GPS: $gpsCount',
      if (fileCount > 0) '- Archivos relacionados: $fileCount',
      '- Estado de carga: ${quality.statusLabel}',
      '- Completitud de obligatorios: ${quality.requiredCompletionPercent}%',
      '- Filas listas: ${quality.rowsReady}/${math.max(quality.rowsWithData, quality.rowsTotal)}',
      if (quality.invalidCells > 0)
        '- Errores de validacion: ${quality.invalidCells}',
      if (quality.pendingRequired > 0)
        '- Campos obligatorios pendientes: ${quality.pendingRequired}',
      '',
      'Uso recomendado:',
      '- Abrir primero el PDF para presentar o compartir.',
      '- Abrir el XLSX para seguimiento y edición posterior.',
      '- Revisar la hoja "Evidencias" para relacionar cada archivo con su celda.',
      '- Usar sheet.json solo para reimportar en BitFlow.',
    ].join('\n');
  }

  Future<String> _readAppVersionForExport() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      if (version.isNotEmpty) return version;
    } catch (_) {}
    return '0.0.0';
  }

  String _platformLabelForExport() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  int _countNonEmptyCells() {
    var total = 0;
    for (final row in _rows) {
      final maxCol = math.min(row.cells.length, _headers.length);
      for (int col = 0; col < maxCol; col++) {
        if (row.cells[col].trim().isNotEmpty) {
          total++;
        }
      }
    }
    return total;
  }

  Uint8List _archiveFileBytes(ArchiveFile file) {
    return file.content;
  }

  ArchiveFile? _findArchiveFileByPath(
    Map<String, ArchiveFile> filesByPath,
    String path,
  ) {
    final normalized = path.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) return null;
    final direct = filesByPath[normalized];
    if (direct != null) return direct;
    for (final entry in filesByPath.entries) {
      final key = entry.key;
      if (key == normalized || key.endsWith('/$normalized')) {
        return entry.value;
      }
    }
    return null;
  }

  CellRef? _resolveImportCellRef(
    String rawKey, {
    required String targetSheetId,
    required List<String> rowIds,
    required List<String> colIds,
  }) {
    final ref = CellRef.fromKey(rawKey, defaultSheetId: targetSheetId);
    if (ref != null) return ref.withSheet(targetSheetId);
    final cell = CellKey.fromKey(rawKey);
    if (cell == null) return null;
    if (cell.row < 0 || cell.row >= rowIds.length) return null;
    if (cell.col < 0 || cell.col >= colIds.length) return null;
    return CellRef(
      sheetId: targetSheetId,
      rowId: rowIds[cell.row],
      colId: colIds[cell.col],
    );
  }

  Future<_PackageImportBundle> _readPackageImportBundle(
    Uint8List bytes, {
    bool Function()? shouldCancel,
  }) async {
    _throwIfOperationCancelledBy(shouldCancel);
    final archive = ZipDecoder().decodeBytes(bytes);
    final filesByPath = <String, ArchiveFile>{};
    for (final f in archive) {
      filesByPath[f.name.replaceAll('\\', '/')] = f;
    }

    ArchiveFile? findByName(String name) {
      for (final entry in filesByPath.entries) {
        final key = entry.key;
        if (key == name || key.endsWith('/$name')) return entry.value;
      }
      return null;
    }

    final backupFile = findByName('backup.json');
    final sheetFile = findByName('sheet.json');
    final manifestFile = findByName('manifest.json');

    if (backupFile == null && sheetFile == null) {
      throw const FormatException(
        'ZIP invalido: falta backup.json o sheet.json.',
      );
    }

    if (backupFile != null) {
      final rootRaw = jsonDecode(utf8.decode(_archiveFileBytes(backupFile)));
      if (rootRaw is! Map) {
        throw const FormatException('backup.json invalido.');
      }
      final root = Map<String, dynamic>.from(rootRaw);
      final sheetRaw = root['sheet'];
      if (sheetRaw is! Map) {
        throw const FormatException('backup.json invalido: falta sheet.');
      }

      final assets = <Map<String, dynamic>>[];
      final assetsRaw = root['assets'];
      if (assetsRaw is List) {
        for (final item in assetsRaw) {
          if (item is Map) {
            assets.add(Map<String, dynamic>.from(item));
          }
        }
      }
      final photos = assets.where((a) => a['kind'] == 'photo').length;
      final audios = assets.where((a) => a['kind'] == 'audio').length;
      final rows = ((sheetRaw)['rows'] as List?)?.length ?? 0;
      final sourceSheetId = (sheetRaw['sheetId'] ?? '').toString().trim();
      final sourceSheetName = (sheetRaw['name'] ?? '').toString().trim();
      return _PackageImportBundle(
        format: 'backup_legacy',
        sheetRaw: Map<String, dynamic>.from(sheetRaw),
        assets: assets,
        filesByPath: filesByPath,
        preview: _PackageImportPreview(
          formatLabel: 'Backup legacy',
          rows: rows,
          attachments: assets.length,
          photos: photos,
          audios: audios,
          exportedAt: DateTime.tryParse((root['exportedAt'] ?? '').toString()),
          sourceSheetId: sourceSheetId.isEmpty ? null : sourceSheetId,
          sourceSheetName: sourceSheetName.isEmpty ? null : sourceSheetName,
        ),
      );
    }

    final sheetRawDecoded = jsonDecode(
      utf8.decode(_archiveFileBytes(sheetFile!)),
    );
    if (sheetRawDecoded is! Map) {
      throw const FormatException('sheet.json invalido.');
    }
    final sheetRaw = Map<String, dynamic>.from(sheetRawDecoded);

    Map<String, dynamic> manifest = const <String, dynamic>{};
    if (manifestFile != null) {
      final manifestRaw = jsonDecode(
        utf8.decode(_archiveFileBytes(manifestFile)),
      );
      if (manifestRaw is Map) {
        manifest = Map<String, dynamic>.from(manifestRaw);
      }
    }

    final assets = <Map<String, dynamic>>[];
    final assetsRaw = manifest['assets'];
    if (assetsRaw is List) {
      for (final item in assetsRaw) {
        if (item is Map) {
          assets.add(Map<String, dynamic>.from(item));
        }
      }
    }
    if (assets.isEmpty) {
      final cellsRaw = manifest['cells'];
      if (cellsRaw is Map) {
        for (final cellEntry in cellsRaw.entries) {
          if (cellEntry.value is! Map) continue;
          final cellMap = Map<String, dynamic>.from(cellEntry.value as Map);
          final photos = cellMap['photos'];
          if (photos is List) {
            for (final item in photos) {
              if (item is! Map) continue;
              final next = Map<String, dynamic>.from(item);
              next.putIfAbsent('kind', () => 'photo');
              next.putIfAbsent('cellKey', () => cellEntry.key.toString());
              assets.add(next);
            }
          }
          final audios = cellMap['audios'];
          if (audios is List) {
            for (final item in audios) {
              if (item is! Map) continue;
              final next = Map<String, dynamic>.from(item);
              next.putIfAbsent('kind', () => 'audio');
              next.putIfAbsent('cellKey', () => cellEntry.key.toString());
              assets.add(next);
            }
          }
        }
      }
    }

    final counts = manifest['counts'];
    final rowsCount =
        ((counts is Map ? counts['rows'] : null) as num?)?.toInt() ??
            ((sheetRaw['rows'] as List?)?.length ?? 0);
    final photosCount =
        ((counts is Map ? counts['photos'] : null) as num?)?.toInt() ??
            assets.where((a) => a['kind'] == 'photo').length;
    final audiosCount =
        ((counts is Map ? counts['audios'] : null) as num?)?.toInt() ??
            assets.where((a) => a['kind'] == 'audio').length;
    final attachmentsCount =
        ((counts is Map ? counts['attachments'] : null) as num?)?.toInt() ??
            assets.length;
    final manifestSheet = manifest['sheet'];
    final sourceSheetId = ((manifestSheet is Map
                ? (manifestSheet['id'] ?? sheetRaw['sheetId'])
                : sheetRaw['sheetId']) ??
            '')
        .toString()
        .trim();
    final sourceSheetName = ((manifestSheet is Map
                ? (manifestSheet['name'] ?? sheetRaw['name'])
                : sheetRaw['name']) ??
            '')
        .toString()
        .trim();

    return _PackageImportBundle(
      format: (manifest['format'] ?? 'bitflow_package').toString(),
      sheetRaw: sheetRaw,
      assets: assets,
      filesByPath: filesByPath,
      preview: _PackageImportPreview(
        formatLabel: (manifest['format'] ?? 'BitFlow package').toString(),
        rows: rowsCount,
        attachments: attachmentsCount,
        photos: photosCount,
        audios: audiosCount,
        exportedAt: DateTime.tryParse(
          (manifest['exportedAt'] ?? '').toString(),
        ),
        appVersion: (manifest['appVersion'] ?? '').toString(),
        buildId: (manifest['buildId'] ?? '').toString(),
        sourceSheetId: sourceSheetId.isEmpty ? null : sourceSheetId,
        sourceSheetName: sourceSheetName.isEmpty ? null : sourceSheetName,
      ),
    );
  }

  Future<void> _importPackageBundle(
    _PackageImportBundle bundle, {
    required _PackageImportMode mode,
  }) async {
    if (!_tryBeginLongOperation(
      message: AppStrings.progressImportingBackup,
      cancellable: true,
    )) {
      return;
    }
    try {
      _throwIfLongOperationCancelled();
      final normalized = SheetStore.normalizeModel(bundle.sheetRaw);
      final replaceCurrent = mode == _PackageImportMode.replaceCurrent;
      final mergeCurrent = mode == _PackageImportMode.mergeCurrent;
      final targetSheetId = (replaceCurrent || mergeCurrent)
          ? widget.sheetId
          : DateTime.now().millisecondsSinceEpoch.toString();
      normalized['savedAt'] = DateTime.now().toIso8601String();

      final imported = await _restorePackageAssetsIntoModel(
        normalizedModel: normalized,
        assets: bundle.assets,
        filesByPath: bundle.filesByPath,
        targetSheetId: targetSheetId,
        shouldCancel: _isLongOperationCancelled,
      );
      _throwIfLongOperationCancelled();

      _setLongOperationMessage(AppStrings.progressWritingFile);
      if (mergeCurrent) {
        final loaded = _SheetModel.fromJson(imported.model);
        final previewPlan = _computePackageMergePlan(
          imported: loaded,
          conflictPolicy: PackageMergeConflictPolicy.keepLocal,
        );
        var policy = PackageMergeConflictPolicy.keepLocal;
        if (previewPlan.conflicts > 0) {
          _clearLongOperation();
          final picked = await _showPackageMergeConflictDialog(
            conflicts: previewPlan.conflicts,
            applied: previewPlan.importedApplied,
          );
          if (picked == null || !mounted) return;
          policy = picked;
          if (!_tryBeginLongOperation(
            message: AppStrings.progressImportingBackup,
            cancellable: true,
          )) {
            return;
          }
        }
        final applied = _computePackageMergePlan(
          imported: loaded,
          conflictPolicy: policy,
        );
        _applyPackageMergePlan(applied);
        await _saveLocalNow();
        if (!_lastSaveSucceeded) {
          return;
        }
        _addHistoryEvent(
          type: 'package_merge',
          message:
              'Merge paquete: +${applied.appendedRows} filas, ${applied.importedApplied} celdas importadas, ${applied.conflicts} conflictos.',
          origin: 'import',
        );
        _showActionSnack(
          applied.conflicts > 0
              ? 'Merge aplicado (${applied.conflicts} conflictos).'
              : 'Merge aplicado sin conflictos.',
          isError: false,
          icon: Icons.merge_type_rounded,
        );
        return;
      }
      if (replaceCurrent) {
        await _clearOfflineQueueForCurrentSheet();
        final loaded = _SheetModel.fromJson(imported.model);
        if (mounted) {
          _applyLoadedModel(loaded);
          await _saveLocalNow();
          if (!_lastSaveSucceeded) {
            return;
          }
          _addHistoryEvent(
            type: 'package_import_replace',
            message:
                'Paquete reemplazado (${imported.importedPhotos + imported.importedAudios} adjuntos importados).',
            origin: 'import',
          );
          _showActionSnack(
            imported.missingAssets > 0
                ? 'Paquete restaurado. Faltantes: ${imported.missingAssets}.'
                : 'Paquete restaurado en planilla actual.',
            isError: false,
            icon: Icons.system_update_alt_rounded,
          );
        }
        return;
      }

      SheetStore.saveModel(targetSheetId, imported.model);
      if (!mounted) return;
      _showActionSnack(
        imported.missingAssets > 0
            ? 'Paquete importado. Faltantes: ${imported.missingAssets}.'
            : 'Paquete importado como nueva planilla.',
        isError: false,
        icon: Icons.check_circle_outline_rounded,
      );
      _addHistoryEvent(
        type: 'package_import_new',
        message: 'Paquete importado como nueva planilla.',
        origin: 'import',
      );
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => EditorScreen(
            sheetId: targetSheetId,
            initialName: (imported.model['name'] ?? '').toString(),
            engineBaseUrl: widget.engineBaseUrl,
            engineApiKey: widget.engineApiKey,
            isLight: widget.isLight,
            onToggleTheme: widget.onToggleTheme,
          ),
        ),
      );
    } on _EditorLongOperationCancelled {
      _showActionSnack(
        AppStrings.infoImportCancelled,
        isError: false,
        icon: Icons.info_outline_rounded,
      );
    } catch (e, st) {
      _reportFlowError(
        e,
        flow: AppErrorFlow.importData,
        operation: mode == _PackageImportMode.mergeCurrent
            ? 'import_package_merge_current'
            : (mode == _PackageImportMode.replaceCurrent
                ? 'import_package_replace_current'
                : 'import_package_create_new'),
        stackTrace: st,
        fallbackMessage: 'No se pudo importar el paquete.',
        icon: Icons.file_open_rounded,
      );
    } finally {
      _clearLongOperation();
    }
  }

  Future<PackageMergeConflictPolicy?> _showPackageMergeConflictDialog({
    required int conflicts,
    required int applied,
  }) async {
    return showAppModal<PackageMergeConflictPolicy>(
      context: context,
      title: 'Conflictos detectados',
      child: Text(
        'Se detectaron $conflicts conflictos (misma celda con valor distinto). '
        'Importables sin conflicto: $applied.',
        style: TextStyle(color: _palette(context).fg),
      ),
      actions: [
        AppButton(
          label: AppStrings.cancel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: 'Mantener local',
          variant: AppButtonVariant.secondary,
          onPressed: () =>
              Navigator.of(context).pop(PackageMergeConflictPolicy.keepLocal),
        ),
        AppButton(
          label: 'Usar importado',
          variant: AppButtonVariant.primary,
          onPressed: () =>
              Navigator.of(context).pop(PackageMergeConflictPolicy.useImported),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
  }

  ({
    List<String> headers,
    List<String> colIds,
    Map<String, _ColumnPrefs> columnPrefsById,
    List<String> columnOrder,
    String? frozenColId,
    List<_RowModel> rows,
    Map<String, CellMeta> cellMeta,
    int conflicts,
    int importedApplied,
    int autoMerged,
    int appendedRows,
    int addedColumns,
  }) _computePackageMergePlan({
    required _SheetModel imported,
    required PackageMergeConflictPolicy conflictPolicy,
  }) {
    final incomingHeaders = _normalizeHeaders(imported.headers);
    final incomingColIds = _normalizeColIds(incomingHeaders, imported.colIds);
    final mergedHeaders = List<String>.from(_headers);
    final mergedColIds = List<String>.from(_colIds);
    final mergedPrefs = Map<String, _ColumnPrefs>.from(_columnPrefsById);
    final mergedOrder = List<String>.from(_columnOrder);
    final existingColSet = mergedColIds.toSet();
    var addedColumns = 0;

    for (int i = 0;
        i < incomingColIds.length && i < incomingHeaders.length;
        i++) {
      final colId = incomingColIds[i].trim();
      if (colId.isEmpty || existingColSet.contains(colId)) continue;
      existingColSet.add(colId);
      mergedColIds.add(colId);
      mergedHeaders.add(incomingHeaders[i]);
      if (imported.columnPrefsById[colId] != null) {
        mergedPrefs[colId] = imported.columnPrefsById[colId]!;
      } else {
        mergedPrefs[colId] = const _ColumnPrefs(type: _ColType.text);
      }
      if (!mergedOrder.contains(colId)) mergedOrder.add(colId);
      addedColumns++;
    }

    final localById = <String, _RowModel>{for (final r in _rows) r.id: r};
    final importedById = <String, _RowModel>{
      for (final r in imported.rows) r.id: r,
    };
    final mergedRowIds = <String>[...localById.keys];
    for (final row in imported.rows) {
      if (!localById.containsKey(row.id)) mergedRowIds.add(row.id);
    }

    final mergedColSet = mergedColIds.toSet();
    String keyOf(String rowId, String colId) => '$rowId::$colId';

    final localCells = <String, String>{};
    for (final row in _rows) {
      for (int c = 0; c < _colIds.length && c < row.cells.length; c++) {
        final colId = _colIds[c];
        if (!mergedColSet.contains(colId)) continue;
        localCells[keyOf(row.id, colId)] = row.cells[c];
      }
    }

    final importedCells = <String, String>{};
    for (final row in imported.rows) {
      for (int c = 0; c < incomingColIds.length && c < row.cells.length; c++) {
        final colId = incomingColIds[c];
        if (!mergedColSet.contains(colId)) continue;
        importedCells[keyOf(row.id, colId)] = row.cells[c];
      }
    }

    final cellMerge = PackageMergeEngine.mergeMaps(
      local: localCells,
      imported: importedCells,
      conflictPolicy: conflictPolicy,
    );

    final mergedRows = <_RowModel>[];
    var appendedRows = 0;
    for (final rowId in mergedRowIds) {
      final localRow = localById[rowId];
      final importedRow = importedById[rowId];
      final source =
          (localRow ?? importedRow ?? _RowModel.empty(mergedColIds.length))
              .copy();
      if (localRow == null && importedRow != null) appendedRows++;
      final cells = List<String>.filled(mergedColIds.length, '');
      for (int c = 0; c < mergedColIds.length; c++) {
        cells[c] = cellMerge.merged[keyOf(rowId, mergedColIds[c])] ?? '';
      }
      mergedRows.add(source.copyWithCells(cells));
    }

    final normalizedImportedMeta = _normalizeCellMeta(
      imported.cellMeta,
      imported.rows,
      incomingColIds,
    );
    final mergedMeta = Map<String, CellMeta>.from(_cellMeta);
    for (final entry in normalizedImportedMeta.entries) {
      final hasLocal = mergedMeta.containsKey(entry.key);
      if (!hasLocal ||
          conflictPolicy == PackageMergeConflictPolicy.useImported) {
        mergedMeta[entry.key] = entry.value;
      }
    }

    return (
      headers: mergedHeaders,
      colIds: mergedColIds,
      columnPrefsById: mergedPrefs,
      columnOrder: mergedOrder,
      frozenColId: _frozenColId,
      rows: mergedRows,
      cellMeta: mergedMeta,
      conflicts: cellMerge.conflicts.length,
      importedApplied: cellMerge.importedApplied,
      autoMerged: cellMerge.autoMerged,
      appendedRows: appendedRows,
      addedColumns: addedColumns,
    );
  }

  void _applyPackageMergePlan(
    ({
      List<String> headers,
      List<String> colIds,
      Map<String, _ColumnPrefs> columnPrefsById,
      List<String> columnOrder,
      String? frozenColId,
      List<_RowModel> rows,
      Map<String, CellMeta> cellMeta,
      int conflicts,
      int importedApplied,
      int autoMerged,
      int appendedRows,
      int addedColumns,
    }) plan,
  ) {
    setState(() {
      _headers = plan.headers;
      _colIds = plan.colIds;
      _columnPrefsById = plan.columnPrefsById;
      _columnOrder = plan.columnOrder;
      _frozenColId = plan.frozenColId;
      _rows = plan.rows;
      _cellMeta
        ..clear()
        ..addAll(plan.cellMeta);
      _selRow = _selRow.clamp(0, _rows.length - 1);
      _selCol = _selCol.clamp(0, _headers.length - 1);
      _isDirty = true;
      _rev++;
    });
    _syncRowVersionNotifiers();
    _syncSelectionController();
    _resetMobileRowCaches();
    _scheduleValidationRecompute(immediate: true);
    _seedRecentValuesFromRows();
    _updateSaveStatus();
    _pushUndoSnapshot();
    _queueSave();
  }

  Future<
      ({
        Map<String, dynamic> model,
        int importedPhotos,
        int importedAudios,
        int missingAssets,
      })> _restorePackageAssetsIntoModel({
    required Map<String, dynamic> normalizedModel,
    required List<Map<String, dynamic>> assets,
    required Map<String, ArchiveFile> filesByPath,
    required String targetSheetId,
    bool Function()? shouldCancel,
  }) async {
    _throwIfOperationCancelledBy(shouldCancel);
    final rowsRaw = (normalizedModel['rows'] as List?) ?? const [];
    final rowIds = <String>[];
    for (final row in rowsRaw) {
      if (row is Map) {
        rowIds.add((row['id'] ?? '').toString());
      }
    }
    final colIds = (normalizedModel['colIds'] as List?)
            ?.map((e) => (e ?? '').toString())
            .toList() ??
        const <String>[];

    final assetsById = <String, Map<String, dynamic>>{};
    for (final asset in assets) {
      final kind = (asset['kind'] ?? '').toString();
      final id = (asset['id'] ?? '').toString();
      if (kind.isEmpty || id.isEmpty) continue;
      assetsById['$kind:$id'] = asset;
    }

    var importedPhotos = 0;
    var importedAudios = 0;
    var missingAssets = 0;
    final usedPhotoIds = <String>{};
    final usedAudioIds = <String>{};
    final nextCellMeta = <String, dynamic>{};
    final cellMetaRaw = normalizedModel['cellMeta'];

    if (cellMetaRaw is Map) {
      for (final entry in cellMetaRaw.entries) {
        _throwIfOperationCancelledBy(shouldCancel);
        final rawKey = entry.key.toString();
        final metaRaw = entry.value;
        if (metaRaw is! Map) continue;

        final ref = _resolveImportCellRef(
          rawKey,
          targetSheetId: targetSheetId,
          rowIds: rowIds,
          colIds: colIds,
        );
        if (ref == null) continue;

        final nextMeta = <String, dynamic>{};
        final gps = metaRaw['gps'];
        if (gps is Map && gps.isNotEmpty) {
          nextMeta['gps'] = gps;
        }

        final photosRaw = metaRaw['photos'];
        if (photosRaw is List) {
          final updatedPhotos = <Map<String, dynamic>>[];
          for (final p in photosRaw) {
            _throwIfOperationCancelledBy(shouldCancel);
            if (p is! Map) continue;
            final source = Map<String, dynamic>.from(p);
            final sourceId = (source['id'] ?? '').toString();
            var id = sourceId.isNotEmpty ? sourceId : _genAttachmentId('ph_');
            if (!usedPhotoIds.add(id)) {
              id = _genAttachmentId('ph_');
              usedPhotoIds.add(id);
            }

            final asset = assetsById['photo:$sourceId'] ??
                assetsById['video:$sourceId'] ??
                assetsById['file:$sourceId'];
            final assetPath = (asset?['path'] ?? source['path'] ?? '')
                .toString()
                .replaceAll('\\', '/');
            final archiveFile = _findArchiveFileByPath(filesByPath, assetPath);
            final contentBytes =
                archiveFile == null ? null : _archiveFileBytes(archiveFile);

            final fileName = (source['name'] ??
                    asset?['fileName'] ??
                    source['filename'] ??
                    'foto.jpg')
                .toString();
            final mime =
                (source['mime'] ?? asset?['mime'] ?? 'image/jpeg').toString();
            final thumbRef = (source['thumbRef'] ?? '').toString();
            var storedRef = '';
            var size = (source['size'] as num?)?.toInt() ?? 0;

            if (contentBytes != null && contentBytes.isNotEmpty) {
              final save = await AttachmentStore.I.saveImage(
                cellRef: ref,
                attachmentId: id,
                bytes: contentBytes,
                originalName: fileName,
                mime: mime,
                webFile: null,
              );
              if (save != null && save.storedRef.trim().isNotEmpty) {
                storedRef = save.storedRef;
                size = contentBytes.lengthInBytes;
                importedPhotos++;
              }
            } else if (assetPath.isNotEmpty) {
              missingAssets++;
            }

            final updated = <String, dynamic>{
              'id': id,
              'name': fileName,
              'mime': mime,
              'size': size,
              'storedRef': storedRef,
              'thumbRef': thumbRef,
              'addedAt': (source['addedAt'] ?? DateTime.now().toIso8601String())
                  .toString(),
              'lastKnown': (source['lastKnown'] as bool?) ?? false,
            };
            final caption = (source['caption'] ?? '').toString().trim();
            if (caption.isNotEmpty) updated['caption'] = caption;
            if (source['lat'] != null) updated['lat'] = source['lat'];
            if (source['lon'] != null) updated['lon'] = source['lon'];
            if (source['acc'] != null) updated['acc'] = source['acc'];
            updatedPhotos.add(updated);
          }
          if (updatedPhotos.isNotEmpty) {
            nextMeta['photos'] = updatedPhotos;
          }
        }

        final audiosRaw = metaRaw['audios'];
        if (audiosRaw is List) {
          final updatedAudios = <Map<String, dynamic>>[];
          for (final a in audiosRaw) {
            _throwIfOperationCancelledBy(shouldCancel);
            if (a is! Map) continue;
            final source = Map<String, dynamic>.from(a);
            final sourceId = (source['id'] ?? '').toString();
            var id = sourceId.isNotEmpty ? sourceId : _genAttachmentId('au_');
            if (!usedAudioIds.add(id)) {
              id = _genAttachmentId('au_');
              usedAudioIds.add(id);
            }

            final asset = assetsById['audio:$sourceId'];
            final assetPath = (asset?['path'] ?? source['path'] ?? '')
                .toString()
                .replaceAll('\\', '/');
            final archiveFile = _findArchiveFileByPath(filesByPath, assetPath);
            final contentBytes =
                archiveFile == null ? null : _archiveFileBytes(archiveFile);

            final fileName = (source['name'] ??
                    asset?['fileName'] ??
                    source['filename'] ??
                    'audio.m4a')
                .toString();
            final mime =
                (source['mime'] ?? asset?['mime'] ?? 'audio/m4a').toString();
            final durationMs = (source['durationMs'] as num?)?.toInt() ??
                (asset?['durationMs'] as num?)?.toInt() ??
                0;
            var storedRef = '';
            var size = (source['size'] as num?)?.toInt() ?? 0;

            if (contentBytes != null && contentBytes.isNotEmpty) {
              final recording = RecordedAudio(
                fileName: fileName,
                mime: mime,
                duration: Duration(milliseconds: durationMs),
                bytes: contentBytes,
              );
              final stored = await AudioStorageService.I.saveRecording(
                sheetId: targetSheetId,
                cellKey: ref.compactKey,
                attachmentId: id,
                recording: recording,
              );
              if (stored != null) {
                storedRef = _audioStoredRefFrom(stored);
                size = stored.bytesLength;
                importedAudios++;
              }
            } else if (assetPath.isNotEmpty) {
              missingAssets++;
            }

            updatedAudios.add(<String, dynamic>{
              'id': id,
              'name': fileName,
              'mime': mime,
              'size': size,
              'durationMs': durationMs,
              'storedRef': storedRef,
              'addedAt': (source['addedAt'] ?? DateTime.now().toIso8601String())
                  .toString(),
            });
          }
          if (updatedAudios.isNotEmpty) {
            nextMeta['audios'] = updatedAudios;
          }
        }

        if (nextMeta.isNotEmpty) {
          nextCellMeta[ref.key] = nextMeta;
        }
      }
    }

    if (nextCellMeta.isNotEmpty) {
      normalizedModel['cellMeta'] = nextCellMeta;
    } else {
      normalizedModel.remove('cellMeta');
    }

    return (
      model: normalizedModel,
      importedPhotos: importedPhotos,
      importedAudios: importedAudios,
      missingAssets: missingAssets,
    );
  }

  String _exportPhotoFileName(
    String cellRef,
    PhotoAttachment photo, {
    required String kind,
    required int index,
  }) {
    final base = _safeFile(photo.filename.isNotEmpty ? photo.filename : kind);
    final ext = _extForName(base, photo.mime, fallback: '.jpg');
    final safeRef = '${cellRef}_${index > 1 ? 'v$index' : 'v1'}';
    return buildBitFlowEvidenceFileName(
      kind: kind,
      sheetName: _sheetName,
      reference: safeRef,
      timestamp: photo.addedAt.toLocal(),
      extension: ext,
    );
  }

  String _exportAudioFileName(
    String cellRef,
    AudioAttachment audio, {
    required int index,
  }) {
    final base = _safeFile(
      audio.filename.isNotEmpty ? audio.filename : 'audio',
    );
    final ext = _extForName(base, audio.mime, fallback: '.m4a');
    final safeRef = '${cellRef}_${index > 1 ? 'a$index' : 'a1'}';
    return buildBitFlowEvidenceFileName(
      kind: 'audio',
      sheetName: _sheetName,
      reference: safeRef,
      timestamp: audio.addedAt.toLocal(),
      extension: ext,
    );
  }

  String _backupPhotoFileName(
    String cellRef,
    PhotoAttachment photo, {
    required int index,
  }) {
    final base = _safeFile(photo.filename.isNotEmpty ? photo.filename : 'foto');
    final ext = _extForName(base, photo.mime, fallback: '.jpg');
    final stem = _stripExt(base);
    final safeId = _safeFile(photo.id);
    return '${cellRef}_p${index}_${safeId}_$stem$ext';
  }

  String _backupAudioFileName(
    String cellRef,
    AudioAttachment audio, {
    required int index,
  }) {
    final base = _safeFile(
      audio.filename.isNotEmpty ? audio.filename : 'audio',
    );
    final ext = _extForName(base, audio.mime, fallback: '.m4a');
    final stem = _stripExt(base);
    final safeId = _safeFile(audio.id);
    return '${cellRef}_a${index}_${safeId}_$stem$ext';
  }

  String _stripExt(String name) {
    final idx = name.lastIndexOf('.');
    if (idx <= 0) return name;
    return name.substring(0, idx);
  }

  String _extForName(String name, String mime, {required String fallback}) {
    final lower = name.toLowerCase();
    final idx = lower.lastIndexOf('.');
    if (idx >= 0 && idx < lower.length - 1) {
      return lower.substring(idx);
    }
    final m = mime.toLowerCase();
    if (m.contains('png')) return '.png';
    if (m.contains('webp')) return '.webp';
    if (m.contains('jpeg') || m.contains('jpg')) return '.jpg';
    if (m.contains('wav')) return '.wav';
    if (m.contains('mp3') || m.contains('mpeg')) return '.mp3';
    if (m.contains('ogg')) return '.ogg';
    if (m.contains('m4a')) return '.m4a';
    return fallback;
  }

  String _gpsNotes(GpsMeta gps) {
    final details = <String>[
      'Captura GPS',
      'Precisión ${gps.accuracyM.toStringAsFixed(1)} m',
      if (gps.source.trim().isNotEmpty) gps.source.trim(),
      if (gps.provider.trim().isNotEmpty) gps.provider.trim(),
    ];
    return details.join(' | ');
  }

  String _photoNotes(PhotoAttachment photo) {
    final mime = photo.mime.toLowerCase();
    final kind = mime.startsWith('video/')
        ? 'Video'
        : (mime.startsWith('image/') ? 'Foto' : 'Archivo');
    final parts = <String>[
      kind,
      _formatBytes(photo.size),
    ];
    if (photo.caption.trim().isNotEmpty) {
      parts.insert(1, photo.caption.trim());
    }
    if (photo.lat != null && photo.lon != null) {
      parts.add(
        '${photo.lat!.toStringAsFixed(6)}, ${photo.lon!.toStringAsFixed(6)}',
      );
    }
    if (photo.accuracyM != null) {
      parts.add('Precisión ${photo.accuracyM!.toStringAsFixed(1)} m');
    }
    return parts.join('; ');
  }

  String _audioNotes(AudioAttachment audio) {
    return 'Audio; '
        '${_formatDuration(Duration(milliseconds: audio.durationMs))}; '
        '${_formatBytes(audio.size)}';
  }

  Future<Uint8List?> _loadAudioBytesFromAttachment(
    AudioAttachment audio,
  ) async {
    final key = _audioKeyFromRef(audio.storedRef);
    if (key.trim().isEmpty) return null;
    return _audioStore.readAudioBytes(key);
  }

  Uint8List _resizeForExport(Uint8List bytes) {
    const maxSide = 1280;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      final oriented = img.bakeOrientation(decoded);
      if (oriented.width <= maxSide && oriented.height <= maxSide) {
        return bytes;
      }
      final resized = img.copyResize(
        oriented,
        width: oriented.width > oriented.height ? maxSide : null,
        height: oriented.height >= oriented.width ? maxSide : null,
        interpolation: img.Interpolation.average,
      );
      final jpg = img.encodeJpg(resized, quality: 86);
      return Uint8List.fromList(jpg);
    } catch (_) {
      return bytes;
    }
  }

  String _formatBytes(int bytes) {
    const kb = 1024;
    const mb = 1024 * 1024;
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatDateTimeShort(DateTime dt) {
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
        '${_two(dt.hour)}:${_two(dt.minute)}';
  }

  String _safeFile(String s) {
    final t = s.trim().isEmpty ? 'Hoja' : s.trim();
    return t.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  String _exportCancelledMessage({required bool share}) {
    return share ? 'Compartir cancelado.' : 'Operación cancelada.';
  }

  String _exportReadyMessage({
    required String format,
    required bool share,
    required String fileName,
    bool includeEvidenceHint = false,
  }) {
    switch (format) {
      case 'pdf':
        return share
            ? 'PDF listo para compartir: $fileName'
            : 'PDF listo para presentar: $fileName';
      case 'zip':
        final suffix =
            includeEvidenceHint ? ' Incluye planilla y evidencias.' : '';
        return share
            ? 'Paquete completo listo para compartir: $fileName'
            : 'Paquete completo preparado: $fileName.$suffix';
      default:
        return share
            ? 'Archivo listo para compartir: $fileName'
            : 'Archivo listo: $fileName';
    }
  }

  String _exportFailureMessage({required bool share}) {
    if (share) return 'No pudimos completar la operación.';
    return 'No pudimos completar la operación.';
  }

  String _exportUnsupportedMessage({required bool share}) {
    if (share) return 'Compartir no está disponible en este dispositivo.';
    return 'Esta exportación no está disponible en este dispositivo.';
  }

  List<String> _buildExportColumnTypes(int dataCols) {
    return List<String>.generate(
      dataCols,
      (index) => _colType(index).name,
      growable: false,
    );
  }

  CellKey? _resolveExportCellKey(
    String raw, {
    required Map<String, int> rowIndexById,
    required Map<String, int> colIndexById,
  }) {
    final ref = CellRef.fromKey(raw, defaultSheetId: widget.sheetId);
    if (ref != null) {
      final row = rowIndexById[ref.rowId];
      final col = colIndexById[ref.colId];
      if (row == null || col == null) return null;
      return CellKey(row, col);
    }
    return CellKey.fromKey(raw);
  }

  List<GpsExport?> _buildGpsByRowForExport() {
    if (_rows.isEmpty) return const <GpsExport?>[];
    final gpsByRow = List<GpsExport?>.filled(_rows.length, null);

    for (int rowIndex = 0; rowIndex < _rows.length; rowIndex++) {
      final row = _rows[rowIndex];
      if (row.gpsLat == null || row.gpsLng == null) continue;
      gpsByRow[rowIndex] = GpsExport(
        lat: row.gpsLat,
        lng: row.gpsLng,
        accuracy: row.gpsAccuracyM,
        ts: row.gpsTs,
        isLastKnown: row.gpsIsLastKnown,
      );
    }

    final rowIndexById = <String, int>{};
    for (int i = 0; i < _rows.length; i++) {
      rowIndexById[_rows[i].id] = i;
    }
    final colIndexById = <String, int>{};
    for (int i = 0; i < _colIds.length; i++) {
      colIndexById[_colIds[i]] = i;
    }

    final entries = _cellMeta.entries.toList(growable: false);
    entries.sort((a, b) {
      final left = _resolveExportCellKey(
        a.key,
        rowIndexById: rowIndexById,
        colIndexById: colIndexById,
      );
      final right = _resolveExportCellKey(
        b.key,
        rowIndexById: rowIndexById,
        colIndexById: colIndexById,
      );
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      final rowCmp = left.row.compareTo(right.row);
      if (rowCmp != 0) return rowCmp;
      return left.col.compareTo(right.col);
    });

    for (final entry in entries) {
      final cell = _resolveExportCellKey(
        entry.key,
        rowIndexById: rowIndexById,
        colIndexById: colIndexById,
      );
      if (cell == null ||
          cell.row < 0 ||
          cell.row >= gpsByRow.length ||
          gpsByRow[cell.row] != null) {
        continue;
      }
      final gps = entry.value.gps;
      if (gps == null) continue;
      gpsByRow[cell.row] = GpsExport(
        lat: gps.lat,
        lng: gps.lng,
        accuracy: gps.accuracyM,
        ts: gps.timestamp,
        isLastKnown: gps.source.toLowerCase().contains('last'),
      );
    }

    if (!gpsByRow.any((item) => item != null && item.hasFix)) {
      return const <GpsExport?>[];
    }
    return gpsByRow;
  }

  ({
    String? clientName,
    String? projectName,
    String? responsibleName,
    String? observations,
  }) _buildExportCoverContext() {
    final client = _extractExportColumnSummary(
      const <String>['cliente', 'client', 'empresa'],
    );
    final project = _extractExportColumnSummary(
      const <String>['obra', 'proyecto', 'project', 'frente'],
    );
    final responsible = _extractExportColumnSummary(
          const <String>['responsable', 'encargado', 'supervisor', 'tecnico'],
        ) ??
        _extractReviewedBySummary();
    final observations = _extractObservationsSummary();
    return (
      clientName: client,
      projectName: project,
      responsibleName: responsible,
      observations: observations,
    );
  }

  String? _extractExportColumnSummary(
    List<String> aliases, {
    int maxInlineValues = 2,
  }) {
    final column = _findExportColumn(aliases);
    if (column == null) return null;
    final values = _collectNonEmptyColumnValues(column);
    if (values.isEmpty) return null;
    return _summarizeExportValues(values, maxInlineValues: maxInlineValues);
  }

  String? _extractReviewedBySummary() {
    final values = <String>[];
    for (final row in _rows) {
      final reviewedBy = (row.reviewedBy ?? '').trim();
      if (reviewedBy.isEmpty || values.contains(reviewedBy)) continue;
      values.add(reviewedBy);
    }
    if (values.isEmpty) return null;
    return _summarizeExportValues(values, maxInlineValues: 2);
  }

  String? _extractObservationsSummary() {
    final column = _findExportColumn(
      const <String>['observaciones', 'observacion', 'nota', 'comentario'],
    );
    if (column == null) return null;
    final values = _collectNonEmptyColumnValues(column);
    if (values.isEmpty) return null;
    if (values.length == 1) return _truncateExportText(values.first, 180);
    return '${values.length} observaciones registradas. '
        'Ejemplo: ${_truncateExportText(values.first, 120)}';
  }

  int? _findExportColumn(List<String> aliases) {
    final normalizedAliases = aliases
        .map(_normalizeExportFieldToken)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (normalizedAliases.isEmpty) return null;
    final dataCols = math.max(0, _headers.length - 1);
    for (int c = 0; c < dataCols; c++) {
      final header = _normalizeExportFieldToken(_headerLabel(c));
      if (header.isEmpty) continue;
      for (final alias in normalizedAliases) {
        if (header == alias || header.contains(alias)) {
          return c;
        }
      }
    }
    return null;
  }

  List<String> _collectNonEmptyColumnValues(int column) {
    final values = <String>[];
    for (final row in _rows) {
      if (column < 0 || column >= row.cells.length) continue;
      final value = row.cells[column].trim();
      if (value.isEmpty || values.contains(value)) continue;
      values.add(value);
    }
    return values;
  }

  String _summarizeExportValues(
    List<String> values, {
    required int maxInlineValues,
  }) {
    if (values.isEmpty) return '';
    if (values.length == 1) return _truncateExportText(values.first, 120);
    final head = values.take(maxInlineValues).map((item) {
      return _truncateExportText(item, 54);
    }).join(' | ');
    final remaining = values.length - maxInlineValues;
    if (remaining <= 0) return head;
    return '$head +$remaining más';
  }

  String _truncateExportText(String raw, int maxChars) {
    final value = raw.trim();
    if (value.length <= maxChars) return value;
    return '${value.substring(0, maxChars - 3).trim()}...';
  }

  String _normalizeExportFieldToken(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  String _buildCommercialExportFileName(String extension) {
    return buildBitFlowExportFileName(
      sheetName: _sheetName,
      extension: extension,
    );
  }
  // ------------------------------ Engine compute (opcional) ----------------

  Future<void> _initEngineConnection({bool manualRetry = false}) async {
    if (_engineHealthCheckInFlight) return;
    _engineHealthCheckInFlight = true;

    try {
      final ready = await _ensureEngineReady(showErrors: false);
      if (!mounted) return;

      if (ready) {
        setState(() {
          _engineFallbackMode = false;
          if (!manualRetry) {
            _engineStatus = null;
            _engineStatusIsError = false;
          } else {
            _engineStatus = 'Engine OK';
            _engineStatusIsError = false;
          }
        });
        if (manualRetry) {
          _showSnack('Engine listo', isError: false);
        }
        return;
      }

      setState(() {
        _engineFallbackMode = true;
        _engineStatus =
            _suppressEngineUnavailableUx ? null : _engineFallbackMessage;
        _engineStatusIsError = false;
      });
      if (manualRetry && !_suppressEngineUnavailableUx) {
        _showSnack(_engineFallbackMessage, isError: false);
      }
    } finally {
      _engineHealthCheckInFlight = false;
    }
  }

  bool get _suppressEngineUnavailableUx => RuntimeFlags.demoMode;

  String get _engineFallbackMessage => 'Modo local activo.';

  Future<void> _retryEngineConnection() async {
    await _initEngineConnection(manualRetry: true);
  }

  Future<bool> _ensureEngineReady({required bool showErrors}) async {
    if (_isWidgetTestRuntime) {
      if (mounted) {
        setState(() {
          _engineStatus = null;
          _engineStatusIsError = false;
          _engineFallbackMode = true;
        });
      }
      return false;
    }

    final resolved = await _resolveEngineConfig();
    if (!mounted) return false;

    _engineBaseResolved = resolved.baseUrl;
    _engineKeyResolved = resolved.apiKey;

    final base = _engineBaseResolved?.trim() ?? '';
    if (base.isEmpty || !EngineConfig.isValidBaseUrl(base)) {
      if (mounted) {
        setState(() {
          if (showErrors) {
            _engineStatus =
                'Engine URL invalida o vacia. Configura engine_url.';
            _engineStatusIsError = true;
          } else {
            _engineStatus = null;
            _engineStatusIsError = false;
          }
          _engineFallbackMode = true;
        });
      }
      return false;
    }

    if (kDebugMode) {
      debugPrint('[engine] base url: $base');
    }

    try {
      await _engineApi.ensureHealthyBase(
        base,
        paths: const ['/health', '/healthz', '/readyz', '/openapi.json', '/'],
        timeout: const Duration(seconds: 8),
      );
      if (!mounted) return true;
      setState(() {
        _engineStatus =
            (showErrors && !_suppressEngineUnavailableUx) ? 'Engine OK' : null;
        _engineStatusIsError = false;
        _engineFallbackMode = false;
      });
      if (showErrors && !_suppressEngineUnavailableUx) {
        _showSnack('Engine listo', isError: false);
      }
      return true;
    } catch (e) {
      final details = _engineErrorDetails(e);
      if (kDebugMode) {
        debugPrint('[engine] health fail: $details');
      }
      if (mounted) {
        final shouldShowEngineFeedback =
            showErrors && !_suppressEngineUnavailableUx;
        setState(() {
          _engineStatus =
              shouldShowEngineFeedback ? _engineErrorMessage(e) : null;
          _engineStatusIsError = shouldShowEngineFeedback;
          _engineFallbackMode = true;
        });
        if (shouldShowEngineFeedback) {
          _showSnack(_engineStatus ?? _engineFallbackMessage, isError: true);
        }
      }
      return false;
    }
  }

  Future<_EngineConfig> _resolveEngineConfig() async {
    if (_isWidgetTestRuntime) {
      return const _EngineConfig(baseUrl: null, apiKey: null);
    }

    final widgetBaseRaw = (widget.engineBaseUrl ?? '').trim();
    final widgetKeyRaw = (widget.engineApiKey ?? '').trim();

    String? baseUrl;

    // 1) Override expl??cito del widget (MANUAL por hoja)
    if (widgetBaseRaw.isNotEmpty) {
      final normalized = EngineConfig.normalize(widgetBaseRaw);
      baseUrl = EngineConfig.isValidBaseUrl(normalized) ? normalized : null;
    } else {
      // 2) EngineConfig global (manual)
      final cfg = EngineConfig.instance;
      final mode = await cfg.mode;
      final manual = await cfg.manualBaseUrl;

      if (mode == EngineConfig.modeManual && (manual ?? '').trim().isNotEmpty) {
        final normalized = EngineConfig.normalize(manual!.trim());
        baseUrl = EngineConfig.isValidBaseUrl(normalized) ? normalized : null;
      } else {
        // 3) Auto: resolver (LAN -> t??nel / web=t??nel) v??a EngineApi
        final uri = await _engineApi.resolveBaseUri();
        baseUrl = uri.toString();
      }
    }

    // API key: manten?? compatibilidad (si realmente se usa)
    final prefKey = await _readEngineApiKeyFromPrefs();
    final apiKey = widgetKeyRaw.isNotEmpty ? widgetKeyRaw : prefKey;

    return _EngineConfig(
      baseUrl: baseUrl,
      apiKey: (apiKey == null || apiKey.trim().isEmpty) ? null : apiKey.trim(),
    );
  }

  Future<String?> _readEngineApiKeyFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = (prefs.getString(_kPrefEngineApiKey) ??
              prefs.getString(_kPrefEngineApiKeyAlt) ??
              '')
          .trim();
      return key.isEmpty ? null : key;
    } catch (_) {
      return null;
    }
  }

  String _engineErrorMessage(Object error) {
    final details = _engineErrorDetails(error);
    if (details.isCors) {
      return 'CORS bloqueado (OPTIONS). Revisar allow_origins y OPTIONS.';
    }
    if (details.statusCode != null) {
      return 'Engine error ${details.message}';
    }
    if (details.isTimeout) {
      return 'Engine timeout. Reintenta o revisa el tunel.';
    }
    if (details.message.isNotEmpty && error is EngineApiDataException) {
      return details.message;
    }
    return 'Engine no responde. En movil fisico, 127.0.0.1 es el telefono: usa IP LAN o tunel.';
  }

  void _commitActiveEditors() {
    _syncActiveDrafts();

    if (_mobileEditorOpen) {
      if (_mobileEditingHeader) {
        _commitDraftHeader(_mobileCol);
      } else {
        _commitDraftCell(_mobileRow, _mobileCol);
      }
      _closeMobileEditor();
    }

    final headerCol = _editingHeaderCol;
    final cell = _editingCellRef;

    if (headerCol != null) {
      _commitDraftHeader(headerCol);
    } else if (cell != null) {
      _commitDraftCell(cell.r, cell.c);
    }

    if (_cellEditorEntry != null) {
      if (_cellFocus.hasFocus) _cellFocus.unfocus();
      _removeCellEditor();
    }
  }

  _EngineErrorDetails _engineErrorDetails(Object error) {
    if (error is EngineApiException) {
      return _EngineErrorDetails(
        message: 'HTTP ${error.statusCode}: ${error.bodySnippet}',
        statusCode: error.statusCode,
      );
    }
    if (error is EngineApiDataException) {
      return _EngineErrorDetails(message: error.message);
    }

    final text = error.toString();
    final lower = text.toLowerCase();
    final isTimeout = error is TimeoutException ||
        lower.contains('timeout') ||
        lower.contains('timed out');
    final isCors = kIsWeb &&
        (text.contains('XMLHttpRequest') || text.contains('Failed to fetch'));

    return _EngineErrorDetails(
      message: text,
      isCors: isCors,
      isTimeout: isTimeout,
    );
  }

  Future<void> _runSmokeTest() async {
    if (!mounted) return;
    setState(() {
      _smokeStatus = 'Chequeo del motor...';
      _smokeOk = null;
    });

    final base = _engineBaseResolved?.trim() ?? '';
    if (base.isEmpty) {
      setState(() {
        _smokeOk = false;
        _smokeStatus = 'Engine BLOQUEADO (base url vacia)';
      });
      return;
    }

    try {
      await _engineApi.getJsonFromBase(
        base,
        '/openapi.json',
        timeout: const Duration(seconds: 8),
      );
      if (!mounted) return;
      if (kDebugMode) debugPrint('[smoke] engine ping ok: $base');
      setState(() {
        _smokeOk = true;
        _smokeStatus = 'Engine OK';
      });
    } catch (e) {
      if (!mounted) return;
      final details = _engineErrorDetails(e);
      if (kDebugMode) debugPrint('[smoke] engine ping failed: $details');
      setState(() {
        _smokeOk = false;
        _smokeStatus = _formatSmokeFailure(details);
      });
    }
  }

  Uint8List _smokePngBytes() {
    try {
      final image = img.Image(width: 8, height: 8);
      img.fill(image, color: img.ColorRgb8(255, 196, 0));
      return Uint8List.fromList(img.encodePng(image));
    } catch (_) {
      return Uint8List.fromList(<int>[137, 80, 78, 71]);
    }
  }

  Uint8List _smokeWavBytes() {
    const sampleRate = 44100;
    const seconds = 0.2;
    final totalSamples = (sampleRate * seconds).round();
    final byteLength = 44 + totalSamples * 2;
    final data = ByteData(byteLength);
    int offset = 0;

    void writeString(String value) {
      for (int i = 0; i < value.length; i++) {
        data.setUint8(offset++, value.codeUnitAt(i));
      }
    }

    void writeUint32(int value) {
      data.setUint32(offset, value, Endian.little);
      offset += 4;
    }

    void writeUint16(int value) {
      data.setUint16(offset, value, Endian.little);
      offset += 2;
    }

    writeString('RIFF');
    writeUint32(36 + totalSamples * 2);
    writeString('WAVE');
    writeString('fmt ');
    writeUint32(16);
    writeUint16(1);
    writeUint16(1);
    writeUint32(sampleRate);
    writeUint32(sampleRate * 2);
    writeUint16(2);
    writeUint16(16);
    writeString('data');
    writeUint32(totalSamples * 2);

    for (int i = 0; i < totalSamples; i++) {
      data.setInt16(offset, 0, Endian.little);
      offset += 2;
    }

    return data.buffer.asUint8List();
  }

  Future<void> _runAttachmentSmokeTest() async {
    if (!mounted) return;

    var r = _selRow >= 0 ? _selRow : 0;
    var c = _selCol >= 0 ? _selCol : 0;
    if (c >= _headers.length - 1) c = 0;
    if (r >= _rows.length) r = 0;

    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    final cellLabel = _cellLabelForRef(ref);
    final fix = _GpsFix(
      lat: -38.95,
      lng: -68.06,
      accuracyM: 12,
      ts: DateTime.now(),
      source: 'smoke',
      provider: 'smoke',
    );
    _applyGpsFixToCell(r, c, fix, writeText: true, announce: false);

    var photoOk = false;
    var audioOk = false;

    final pngBytes = _smokePngBytes();
    final phId = _genAttachmentId('ph_smoke_');
    final storedPhoto = await _attachmentStore.saveImage(
      cellRef: ref,
      attachmentId: phId,
      bytes: pngBytes,
      originalName: 'smoke.png',
      mime: 'image/png',
      webFile: kIsWeb ? pngBytes : null,
    );
    if (!mounted) return;

    String photoRef;
    if (storedPhoto != null && storedPhoto.storedRef.trim().isNotEmpty) {
      photoRef = storedPhoto.storedRef;
      if (photoRef.startsWith('mem:') || storedPhoto.storageLabel == 'ram') {
        _warnStorageFallbackOnce(
          'foto',
          reasonCode: kIsWeb ? WebBlobStore.I.lastSaveReason : null,
        );
      }
      photoOk = true;
    } else {
      photoRef = '';
    }

    final thumbBytes =
        _compressThumb(pngBytes, maxW: 320, maxH: 320, quality: 70) ?? pngBytes;
    final photoAttachment = PhotoAttachment(
      id: phId,
      filename: 'smoke.png',
      caption: 'smoke',
      mime: 'image/png',
      size: pngBytes.lengthInBytes,
      storedRef: photoRef,
      thumbRef: base64Encode(thumbBytes),
      addedAt: DateTime.now(),
    );
    if (photoRef.trim().isNotEmpty) {
      _applyPhotoToRef(ref, photoAttachment);
    }

    final wavBytes = _smokeWavBytes();
    final rec = RecordedAudio(
      fileName: 'smoke.wav',
      mime: 'audio/wav',
      duration: const Duration(milliseconds: 200),
      bytes: wavBytes,
    );
    final auId = _genAttachmentId('au_smoke_');
    final storedAudio = await _audioStore.saveRecording(
      sheetId: widget.sheetId,
      cellKey: ref.compactKey,
      attachmentId: auId,
      recording: rec,
    );
    if (!mounted) return;

    if (storedAudio != null) {
      final audioRef = _audioStoredRefFrom(storedAudio);
      if (audioRef.startsWith('mem:')) {
        _warnStorageFallbackOnce('audio');
      }
      final audioAttachment = AudioAttachment(
        id: auId,
        filename: rec.fileName,
        mime: rec.mime,
        size: storedAudio.bytesLength,
        durationMs: rec.duration.inMilliseconds,
        storedRef: audioRef,
        addedAt: DateTime.now(),
      );
      final idx = _cellIndexForRef(ref);
      if (idx != null) {
        _addAudioToCell(idx.r, idx.c, audioAttachment);
      }
      audioOk = true;
    }

    final gpsOk = _cellHasGps(r, c);
    final photoBadgeOk = _cellPhotoCount(r, c) > 0 && photoOk;
    final audioBadgeOk = _cellHasAudios(r, c) && audioOk;

    final ok = gpsOk && photoBadgeOk && audioBadgeOk;
    final msg = ok
        ? 'Smoke test OK en celda $cellLabel.'
        : 'Smoke test incompleto en celda $cellLabel.';
    _showActionSnack(
      msg,
      isError: !ok,
      icon: ok ? Icons.science_rounded : Icons.report_problem_rounded,
    );
  }

  bool _looksLikeExpression(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return false;
    if (t.startsWith('=')) return true;
    return RegExp(r'[-+*/()%]').hasMatch(t);
  }

  Future<_EngineComputeOutcome> _computeLocal() async {
    _syncActiveDrafts();

    final updatedRefs = <_CellRef>[];
    for (int r = 0; r < _rows.length; r++) {
      for (int c = 0; c < _headers.length - 1; c++) {
        final raw = _effectiveCell(r, c);
        if (!_looksLikeExpression(raw)) continue;
        final expr =
            raw.trim().startsWith('=') ? raw.trim().substring(1) : raw.trim();
        final res = evalExpression(expr);
        if (res == null) continue;
        final out = _formatNumber(res);
        if (out != raw) {
          _rows[r].cells[c] = out;
          updatedRefs.add(_CellRef(r, c));
        }
      }
    }

    if (!mounted) {
      return const _EngineComputeOutcome(
        ok: false,
        hadUpdates: false,
        errorDetails: _EngineErrorDetails(message: 'Widget unmounted'),
      );
    }

    if (updatedRefs.isNotEmpty) {
      setState(() {
        _engineStatus = 'Calculado localmente';
        _engineStatusIsError = false;
        _isDirty = true;
        _rev++;
      });
      _updateSaveStatus();

      _clearCellDrafts(updatedRefs);
      _bumpGridVersion();
      _pushUndoSnapshot();
      _queueSave();

      Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _engineStatus = null);
      });
      return const _EngineComputeOutcome(ok: true, hadUpdates: true);
    }

    setState(() {
      _engineStatus = 'Sin cambios';
      _engineStatusIsError = false;
    });
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _engineStatus = null);
    });
    return const _EngineComputeOutcome(ok: true, hadUpdates: false);
  }

  Future<_EngineComputeOutcome> _computeEngine() async {
    _syncActiveDrafts();

    if (_engineBusy) {
      if (mounted) {
        setState(() {
          _engineStatus = 'Engine ocupado.';
          _engineStatusIsError = true;
        });
      } else {
        _engineStatus = 'Engine ocupado.';
        _engineStatusIsError = true;
      }
      return const _EngineComputeOutcome(
        ok: false,
        hadUpdates: false,
        errorDetails: _EngineErrorDetails(message: 'Engine ocupado'),
      );
    }

    final resolved = await _resolveEngineConfig();
    if (!mounted) {
      return const _EngineComputeOutcome(
        ok: false,
        hadUpdates: false,
        errorDetails: _EngineErrorDetails(message: 'Widget unmounted'),
      );
    }
    _engineBaseResolved = resolved.baseUrl;
    _engineKeyResolved = resolved.apiKey;
    final baseResolved = _engineBaseResolved?.trim() ?? '';
    if (baseResolved.isEmpty) {
      return _computeLocal();
    }

    final ready = await _ensureEngineReady(showErrors: true);
    if (!ready) {
      return const _EngineComputeOutcome(
        ok: false,
        hadUpdates: false,
        errorDetails: _EngineErrorDetails(message: 'Engine no disponible.'),
      );
    }

    final base = _engineBaseResolved;
    if (base == null || base.trim().isEmpty) {
      return const _EngineComputeOutcome(
        ok: false,
        hadUpdates: false,
        errorDetails: _EngineErrorDetails(message: 'Engine base URL vacia'),
      );
    }

    setState(() {
      _engineBusy = true;
      _engineStatus = 'Computando...';
      _engineStatusIsError = false;
    });

    try {
      final effectiveHeaders = List<String>.generate(
        _headers.length,
        _effectiveHeader,
      );
      final effectiveRows = <List<String>>[];
      for (int r = 0; r < _rows.length; r++) {
        final row = <String>[];
        for (int c = 0; c < _headers.length; c++) {
          row.add(_effectiveCell(r, c));
        }
        effectiveRows.add(row);
      }

      final payload = <String, dynamic>{
        // Requerido por tu backend
        'sheet_id': widget.sheetId,
        // Recomendado (te evita heur??sticas raras)
        'operation': 'calc',
        'headers': effectiveHeaders,
        'rows': effectiveRows,
        // Metadata opcional (se ignora si el backend no la usa)
        'name': _sheetName,
        'savedAt': DateTime.now().toIso8601String(),
      };

      final headers = () {
        final h = <String, String>{
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        };
        final key = _engineKeyResolved?.trim();
        if (key != null && key.isNotEmpty) {
          h['authorization'] = 'Bearer $key';
          h['x-api-key'] = key;
        }
        return h;
      }();

      final map = await _engineApi.postJsonFromBase(
        base,
        '/engine/compute',
        body: payload,
        headers: headers,
        timeout: const Duration(seconds: 18),
      );

      if (!mounted) {
        return const _EngineComputeOutcome(
          ok: false,
          hadUpdates: false,
          errorDetails: _EngineErrorDetails(message: 'Widget unmounted'),
        );
      }

      // Formatos soportados por el engine:
      // - rows: reemplazo completo
      // - updated_cells: delta por celda (m?s r?pido)
      final outRows = (map['rows'] as List?) ?? const [];
      final updatedCells = (map['updated_cells'] as List?) ?? const [];

      if (outRows.isNotEmpty) {
        // ? Preserva fotos por ?ndice (no borra Photos).
        final old = _rows;

        final normalized = <_RowModel>[];
        for (int i = 0; i < outRows.length; i++) {
          final rr = outRows[i];
          if (rr is List) {
            final cells = _normalizeRow(rr, _headers.length);
            final photos = (i < old.length) ? old[i].photos : <_RowPhoto>[];
            final rowId = (i < old.length) ? old[i].id : _genStableId('r_');
            normalized.add(_RowModel(id: rowId, cells: cells, photos: photos));
          }
        }

        setState(() {
          _rows = normalized.isNotEmpty ? normalized : _rows;
          _engineStatus = (map['message'] ?? 'Listo').toString();
          _engineStatusIsError = false;
          _isDirty = true;
          _rev++;
        });
        _updateSaveStatus();

        _resetMobileRowCaches();
        if (_draftCells.isNotEmpty) {
          _draftCells.clear();
        }
        _bumpGridVersion();

        _pushUndoSnapshot();
        _queueSave();
        return const _EngineComputeOutcome(ok: true, hadUpdates: true);
      }

      if (updatedCells.isNotEmpty) {
        final updatedRefs = <_CellRef>[];
        setState(() {
          for (final u in updatedCells) {
            if (u is! Map) continue;
            final r = (u['row'] as num?)?.toInt();
            final c = (u['col'] as num?)?.toInt();
            final v = u['value'];
            if (r == null || c == null) continue;
            if (r < 0 || r >= _rows.length) continue;
            if (c < 0 || c >= _rows[r].cells.length) continue;
            _rows[r].cells[c] = v == null ? '' : '$v';
            updatedRefs.add(_CellRef(r, c));
          }
          _engineStatus = (map['message'] ?? 'Listo').toString();
          _engineStatusIsError = false;
          _isDirty = true;
          _rev++;
        });
        _updateSaveStatus();

        _clearCellDrafts(updatedRefs);
        _bumpGridVersion();

        _pushUndoSnapshot();
        _queueSave();
        return const _EngineComputeOutcome(ok: true, hadUpdates: true);
      }

      setState(() {
        _engineStatus = (map['message'] ?? 'Sin cambios').toString();
        _engineStatusIsError = false;
      });
      return const _EngineComputeOutcome(ok: true, hadUpdates: false);
    } catch (e) {
      if (!mounted) {
        return const _EngineComputeOutcome(
          ok: false,
          hadUpdates: false,
          errorDetails: _EngineErrorDetails(message: 'Widget unmounted'),
        );
      }
      final details = _engineErrorDetails(e);
      if (kDebugMode) debugPrint('[engine] compute error: $details');
      setState(() {
        _engineStatus = _engineErrorMessage(e);
        _engineStatusIsError = true;
      });
      return _EngineComputeOutcome(
        ok: false,
        hadUpdates: false,
        errorDetails: details,
      );
    } finally {
      if (mounted) {
        setState(() => _engineBusy = false);
      } else {
        _engineBusy = false; // opcional; no es critico si ya se desmonto
      }

      if (mounted) {
        Timer(const Duration(seconds: 3), () {
          if (!mounted) return;
          setState(() => _engineStatus = null);
        });
      }
    }
  }
}

// ============================== Header Apple ===============================
