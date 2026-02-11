part of 'editor_screen.dart';

// ============================== Constantes globales ========================

const int kDefaultCols = 15; // 14 + Photos
const String kPhotosHeader = 'Photos';
const String kPhotosColId = 'col_photos';
const double _kMobileQuickBarH = 62.0;
const int _kMaxPhotosPerCell = 6;
const int _kMaxPhotosBytesPerCell = 25 * 1024 * 1024;
const int _kStableIdRandomMaxExclusive = 0x100000000; // 2^32
const bool _kDebugGridBuildCounter =
    bool.fromEnvironment('BITFLOW_DEBUG_GRID_REBUILDS', defaultValue: false);

// ??? Persistencia segura: NO guardar thumbs base64 en prefs/localStorage.
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
const String _kPrefAndroidInstallHelperDismissed =
    'bitflow.editor.android_install_helper_dismissed.v1';
const String _kPrefExportPreset = 'bitflow.editor.export_preset.v1';

enum _OverlayMove { none, next, prev, down, up }

enum _GridDensity { compact, normal, roomy }

enum _MobileEditPhase { closed, opening, open, switching, closing }

enum _GpsWriteMode { pasteActive, pickTarget, metadataOnly }

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

// ============================== Pantalla principal =========================

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.sheetId,
    this.initialName,
    this.initialHeaders,
    this.initialRows,
    this.engineBaseUrl,
    this.engineApiKey,
    this.isLight, // compat StartPage
    this.onToggleTheme, // compat StartPage
  });

  final String sheetId;
  final String? initialName;
  final List<String>? initialHeaders;
  final List<List<String>>? initialRows;
  final String? engineBaseUrl;
  final String? engineApiKey;

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
  static const Duration _validationDebounce = Duration(milliseconds: 260);
  static const Duration _toastCoalesceWindow = Duration(milliseconds: 900);
  static const Duration _slowValidationThreshold = Duration(milliseconds: 12);
  static const String _kPhotoReadErrorMsg =
      'No se pudo leer la imagen (bytes vacios).';
// ------------------------------ Estado ----------------------------------

  late String _sheetName;
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

  bool _isLight = true;
  bool _isDirty = false;
  late final ValueNotifier<EditorSaveSnapshot> _saveStatus =
      ValueNotifier(const EditorSaveSnapshot(state: EditorSaveState.idle));
  late final ValueNotifier<OfflineSyncSnapshot> _offlineStatus = ValueNotifier(
    const OfflineSyncSnapshot(
      state: OfflineSyncState.synced,
      pendingCount: 0,
    ),
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
  final GridSelectionController _selection =
      GridSelectionController(initial: null);
  final Set<int> _selectedRows = <int>{};
  int? _rowSelectionAnchor;

  final Map<String, CellMeta> _cellMeta = <String, CellMeta>{};
  _GpsWriteMode _gpsWriteMode = _GpsWriteMode.pasteActive;
  _GpsFix? _pendingGpsFix;
  bool _gpsPickingTarget = false;
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
  late final FocusNode _nameFocus =
      FocusNode(debugLabel: 'SheetNameAppleFocus');
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
  _CellRef? _editingCellRef;
  int? _editingHeaderCol;
  final ValueNotifier<int> _gridVersion = ValueNotifier<int>(0);
  final Map<String, ValueNotifier<int>> _rowVersionById =
      <String, ValueNotifier<int>>{};
  int _debugGridBuilds = 0;
  DateTime _debugGridBuildsWindowStart = DateTime.now();
  bool _isInAppBrowser = false;
  bool _isSecureContext = true;
  bool? _storageOk;
  String? _storageMessage;
  bool _storageWarned = false;
  VoidCallback? _cellDraftListener;
  VoidCallback? _mobileDraftListener;

// Blink visual
  final ValueNotifier<_CellRef?> _blinkCell = ValueNotifier<_CellRef?>(null);

// ??? FIX: blink timer cancelable (evita callback tras dispose)
  Timer? _blinkT;

// Scroll
  final ScrollController _vScroll = ScrollController();
  final ScrollController _hScroll = ScrollController();
  final ScrollController _mobileHeaderScroll = ScrollController();
  final List<ScrollController> _mobileRowScrolls = <ScrollController>[];
  final List<GlobalKey> _mobileRowKeys = <GlobalKey>[];
  final GlobalKey _mobileHeaderKey = GlobalKey();
  bool _mobileHSyncing = false;

// Guardado
  Timer? _saveT;
  Timer? _validationDebounceT;
  bool _saving = false;
  _EditorLongOperationState? _longOperation;
  bool _saveHapticPending = false;
  final EditorAtomicSnapshotStore _atomicSnapshotStore =
      EditorAtomicSnapshotStore();

// ??? Teclado m??vil: controlador robusto de insets
  late final KeyboardInsetsController _kbController =
      KeyboardInsetsController(onLog: kDebugMode ? debugPrint : null);
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
  DateTime? _engineLastCheckAt;
  bool _engineLastOk = false;
  String? _engineLastError;
  late final EngineApi _engineApi = EngineApi();

  bool get _engineHasBase =>
      _engineBaseResolved != null && _engineBaseResolved!.trim().isNotEmpty;

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
  bool _mobileEditingHeader = false;
  int _mobileRow = -1;
  int _mobileCol = 0;
  String _mobileTitle = '';

  final TextEditingController _mobileEC = TextEditingController();
  final FocusNode _mobileFocus =
      FocusNode(debugLabel: 'MobileInlineEditorFocus');

  List<_MobileAction> _mobileActions = const [];
  final GlobalKey _mobileBarKey = GlobalKey();
  final Key _mobileFieldKey = const ValueKey('mobileInlineEditorField');
  double _mobileBarH = 0.0;
  bool _mobileBarMeasureScheduled = false;
  String? _lastMobileSnack;
  String? _lastToastMessage;
  DateTime _lastToastAt = DateTime.fromMillisecondsSinceEpoch(0);
  VoidCallback? _vvDetach;
  VoidCallback? _detachWebFlushSignal;
  int _fillDownCount = 5;
  int _incrementCount = 5;
  int _incrementStep = 1;
  Set<_CellRef> _invalidCells = <_CellRef>{};
  int _pendingRequired = 0;
  bool _inlineSearchOpen = false;
  final TextEditingController _inlineSearchEC = TextEditingController();
  final FocusNode _inlineSearchFocus =
      FocusNode(debugLabel: 'InlineSearchFocus');
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
  String _lastExportPreset = 'pdf';
  final List<_QuickCapturePending> _quickCaptureQueue =
      <_QuickCapturePending>[];
  final List<_EditPending> _editQueue = <_EditPending>[];
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
  String? _recoveryStagingRaw;
  bool _recoveryBannerVisible = false;
  bool _androidInstallHelperHiddenSession = false;
  bool _androidInstallHelperDismissed = false;

// ??? para evitar setState dentro de dispose
  bool _isDisposing = false;

// ------------------------------ Init/Dispose ----------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mobileFocus.addListener(_handleMobileFocusChange);
    _kbController.attach();
    _kbController.kbInsetDp.addListener(_handleKbInsetChanged);
    if (kIsWeb) {
      _vvDetach = vv.attachViewportListener(() {
        if (mounted) setState(() {});
      });
      _detachWebFlushSignal = WebFlushSignal.attach(
        _flushLocalStateForBackground,
      );
    }

    _sheetName = (widget.initialName?.trim().isNotEmpty ?? false)
        ? widget.initialName!.trim()
        : 'Sheet';
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
    _selectedRows
      ..clear()
      ..add(0);
    _rowSelectionAnchor = 0;
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
    unawaited(_refreshOnlineState());
    _quickCaptureSyncTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(_tickQuickCaptureSync(fromTimer: true)),
    );
    unawaited(_loadQuickCaptureQueue());

    _pushUndoSnapshot(); // estado inicial
    _smokeRequested = _isSmokeRequested();
    unawaited(_loadGpsMode());
    unawaited(_loadAutoGpsBatch());
    unawaited(_loadGridDensity());
    unawaited(_loadEditorDefaultsPrefs());
    unawaited(_loadExportPresetPref());
    unawaited(_loadRecentValuesFromPrefs());
    unawaited(_loadEditorTourPrefs());
    unawaited(_loadAndroidInstallHelperPref());
    unawaited(_loadLocal().whenComplete(() => unawaited(_maybeRunSmoke())));
    unawaited(_initEngineConnection()
        .whenComplete(() => unawaited(_maybeRunSmoke())));
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
        _storageMessage =
            'Session-only (${webCaps?.privateModeReason ?? 'private_mode'})';
      } else {
        _storageOk = result.ok;
        _storageMessage = result.message;
      }
    });
    if (webCaps?.privateModeLikely == true) {
      _showActionSnack(
        'Modo temporal detectado: al recargar podrias perder adjuntos.',
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
    _saveT?.cancel();
    _validationDebounceT?.cancel();
    _nameDebounceT?.cancel();
    _inlineSearchDebounceT?.cancel();
    _recentValuesSaveT?.cancel();
    _blinkT?.cancel();
    _kbEnsureDebounceT?.cancel();
    _mobileEnsureLateT?.cancel();
    _mobileFocusRetryT?.cancel();
    _photoFlowClearT?.cancel();
    _quickCaptureSyncTimer?.cancel();
    _mobileFocus.removeListener(_handleMobileFocusChange);
    _kbController.kbInsetDp.removeListener(_handleKbInsetChanged);
    _kbController.dispose();
    _vvDetach?.call();
    _detachWebFlushSignal?.call();
    _detachWebFlushSignal = null;

    _vScroll.dispose();
    _hScroll.dispose();
    _mobileHeaderScroll.dispose();
    for (final controller in _mobileRowScrolls) {
      controller.dispose();
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
    final targetRow = _mobileEditingHeader ? -1 : _mobileRow;
    if (_mobileEditingHeader || _mobileRow >= 0) {
      _debouncedEnsureRowVisible(targetRow);
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
      out[colId] = pref;
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
      final photos = <PhotoAttachment>[
        ...?current?.photos,
      ];
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
      SharedPreferences prefs, _SheetModel model) async {
    final encoded = json.encode(model.toJson());
    if (_decodeSheetModelRaw(encoded) == null) {
      throw StateError('save_payload_invalid');
    }

    await prefs.setString(_prefsKeyStaging, encoded);
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
      await prefs.setString(_prefsKeyBackup, current);
    }
    await prefs.setString(_prefsKey, stagedRaw);
    await prefs.remove(_prefsKeyStaging);
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
    final normalizedRows =
        _normalizeRowModels(loaded.rows, loadedHeaders.length);
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
      _headers = loadedHeaders;
      _colIds = colIds;
      _columnPrefsById = columnPrefs;
      _columnOrder = columnOrder;
      _frozenColId = frozenColId;
      _rows = normalizedRows.isNotEmpty
          ? normalizedRows
          : <_RowModel>[
              _RowModel.empty(_headers.length, id: _genStableId('r_'))
            ];
      _cellMeta
        ..clear()
        ..addAll(normalizedMeta);
      _selRow = _selRow.clamp(0, _rows.length - 1);
      _selCol = _selCol.clamp(0, _headers.length - 1);
      _isDirty = false;
      _lastSavedAt = loaded.savedAt;

      _rev = 0;
      _lastSavedRev = 0;
      _savePending = false;
    });
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
      headers: List<String>.from(_headers),
      colIds: List<String>.from(_colIds),
      rows: _rows
          .map(
            (r) => _RowModel(
              id: r.id,
              cells: List<String>.from(r.cells),
              photos: r.photos
                  .map((p) => p.copyWithoutThumb())
                  .toList(growable: false),
              gpsLat: r.gpsLat,
              gpsLng: r.gpsLng,
              gpsAccuracyM: r.gpsAccuracyM,
              gpsTs: r.gpsTs,
              gpsIsLastKnown: r.gpsIsLastKnown,
            ),
          )
          .toList(growable: false),
      cellMeta: _cloneCellMeta(_cellMeta),
      savedAt: savedAt,
      columnPrefsById: _cloneColumnPrefs(_columnPrefsById),
      columnOrder: List<String>.from(_columnOrder),
      frozenColId: _frozenColId,
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
    _beginLongOperation(
      message: AppStrings.progressSaving,
      cancellable: false,
    );
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
    _savePending = false;
    _lastSaveStartedAt = DateTime.now();
    _updateSaveStatus();

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

      if (!mounted) return;
      setState(() {
        _lastSavedAt = savedAt;
// ??? Solo limpio Dirty si no cambi?? mientras guardaba
        _isDirty = _rev != _lastSavedRev;
      });
      _updateSaveStatus();
      await _clearSavedEditPending();
      if (_saveHapticPending) {
        AppHaptics.success();
      }
      await _createBackupIfNeeded();
    } catch (e, st) {
      if (_pendingOfflineCount > 0 && mounted) {
        unawaited(_markOfflineSyncFailure('save_failed'));
      }
      _reportFlowError(
        e,
        flow: AppErrorFlow.save,
        operation: 'save_local',
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
      _setSelection(
        prev.selRow.clamp(0, maxRow),
        prev.selCol.clamp(0, maxCol),
      );

      _isDirty = true;
      _rev++;
    });
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
      _setSelection(
        snap.selRow.clamp(0, maxRow),
        snap.selCol.clamp(0, maxCol),
      );

      _isDirty = true;
      _rev++;
    });
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
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final nextDate = (decoded['defaultDateTodayEnabled'] as bool?) ?? true;
      final nextStatus = (decoded['defaultStatusOkEnabled'] as bool?) ?? true;
      final nextAutoIncrement =
          (decoded['autoIncrementIdEnabled'] as bool?) ?? false;
      if (!mounted) {
        _defaultDateTodayEnabled = nextDate;
        _defaultStatusOkEnabled = nextStatus;
        _autoIncrementIdEnabled = nextAutoIncrement;
        return;
      }
      setState(() {
        _defaultDateTodayEnabled = nextDate;
        _defaultStatusOkEnabled = nextStatus;
        _autoIncrementIdEnabled = nextAutoIncrement;
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
        }),
      );
    } catch (_) {}
  }

  Future<void> _setEditorDefaultRules({
    bool? defaultDateTodayEnabled,
    bool? defaultStatusOkEnabled,
    bool? autoIncrementIdEnabled,
  }) async {
    final nextDate = defaultDateTodayEnabled ?? _defaultDateTodayEnabled;
    final nextStatus = defaultStatusOkEnabled ?? _defaultStatusOkEnabled;
    final nextAutoIncrement = autoIncrementIdEnabled ?? _autoIncrementIdEnabled;
    if (nextDate == _defaultDateTodayEnabled &&
        nextStatus == _defaultStatusOkEnabled &&
        nextAutoIncrement == _autoIncrementIdEnabled) {
      return;
    }
    if (mounted) {
      setState(() {
        _defaultDateTodayEnabled = nextDate;
        _defaultStatusOkEnabled = nextStatus;
        _autoIncrementIdEnabled = nextAutoIncrement;
      });
    } else {
      _defaultDateTodayEnabled = nextDate;
      _defaultStatusOkEnabled = nextStatus;
      _autoIncrementIdEnabled = nextAutoIncrement;
    }
    await _saveEditorDefaultsPrefs();
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
              (existing) => existing.toLowerCase() == text.toLowerCase())) {
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
              (existing) => existing.toLowerCase() == entry.toLowerCase())) {
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
              (existing) => existing.toLowerCase() == text.toLowerCase())) {
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

  Future<void> _loadEditorTourPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(_kPrefEditorTourSeen) ?? false;
      final dismissed = prefs.getBool(_kPrefEditorTourDismissed) ?? false;
      final shouldShow = !seen && !dismissed;
      if (!mounted) {
        _editorTourDismissed = dismissed;
        _editorTourVisible = shouldShow;
        return;
      }
      setState(() {
        _editorTourDismissed = dismissed;
        _editorTourVisible = shouldShow;
      });
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

  bool get _isAndroidDevice =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
    }

    _blinkT = Timer(_blinkDuration, () {
      if (!mounted) return;
      if (_blinkCell.value == ref) _blinkCell.value = null;
    });
  }

  void _markDirty({bool snapshot = true}) {
    if (snapshot) _pushUndoSnapshot();
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

  List<String>? _statusOptionsForCol(int c) {
    if (_colType(c) != _ColType.status) return null;
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
        return DateTime(y, m, d, hh, mm);
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
        return DateTime(y, m, d, hh, mm);
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
        value == 'sÃ­' ||
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
    final h = _headerLabel(c).toLowerCase();
    return h.startsWith('fecha') || h.startsWith('actividad');
  }

  void _recomputeValidation() {
    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    if (kDebugMode) {
      developer.Timeline.startSync('editor.validation.recompute');
    }
    try {
      final invalid = <_CellRef>{};
      int pending = 0;

      for (int r = 0; r < _rows.length; r++) {
        for (int c = 0; c < _headers.length - 1; c++) {
          final v = _rows[r].cells[c].trim();
          final type = _colType(c);
          final required = _isRequired(c);
          final ref = _CellRef(r, c);

          if (required && v.isEmpty) {
            invalid.add(ref);
            pending++;
            continue;
          }
          if (v.isEmpty) continue;

          switch (type) {
            case _ColType.date:
              if (_parseDateCellValue(v) == null) invalid.add(ref);
              break;
            case _ColType.number:
              if (_parseNumberCellValue(v) == null) invalid.add(ref);
              break;
            case _ColType.status:
              final options = _statusOptionsForCol(c);
              if (options == null || options.isEmpty) break;
              var matched = false;
              for (final item in options) {
                if (item.toLowerCase() == v.toLowerCase()) {
                  matched = true;
                  break;
                }
              }
              if (!matched) invalid.add(ref);
              break;
            case _ColType.checkbox:
              if (_parseCheckboxCellValue(v) == null) invalid.add(ref);
              break;
            default:
              break;
          }
        }
      }

      final hasChanges = _pendingRequired != pending ||
          _invalidCells.length != invalid.length ||
          !_invalidCells.containsAll(invalid);
      if (!hasChanges) return;

      if (!mounted) {
        _invalidCells = invalid;
        _pendingRequired = pending;
        return;
      }
      setState(() {
        _invalidCells = invalid;
        _pendingRequired = pending;
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
    return _rowVersionById.putIfAbsent(
      rowId,
      () => ValueNotifier<int>(0),
    );
  }

  void _bumpRowVersionById(String rowId) {
    final notifier = _rowVersionById.putIfAbsent(
      rowId,
      () => ValueNotifier<int>(0),
    );
    notifier.value = notifier.value + 1;
  }

  void _syncRowVersionNotifiers() {
    if (_rows.isEmpty && _rowVersionById.isNotEmpty) {
      for (final notifier in _rowVersionById.values) {
        notifier.dispose();
      }
      _rowVersionById.clear();
      return;
    }

    final activeIds = _rows.map((row) => row.id).toSet();
    final stale = <String>[];
    for (final id in _rowVersionById.keys) {
      if (!activeIds.contains(id)) stale.add(id);
    }
    for (final id in stale) {
      _rowVersionById.remove(id)?.dispose();
    }
    for (final id in activeIds) {
      _rowVersionById.putIfAbsent(id, () => ValueNotifier<int>(0));
    }
  }

  void _trackGridHostBuild(String surface) {
    if (!kDebugMode || !_kDebugGridBuildCounter) return;
    _debugGridBuilds++;
    final now = DateTime.now();
    final elapsed = now.difference(_debugGridBuildsWindowStart);
    if (elapsed < const Duration(seconds: 2)) return;
    debugPrint(
      '[editor_perf] grid_host_builds[$surface]: $_debugGridBuilds/${elapsed.inMilliseconds}ms',
    );
    _debugGridBuilds = 0;
    _debugGridBuildsWindowStart = now;
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

  void _setDraftHeader(int c, String value) {
    if (c < 0 || c >= _headers.length) return;
    if (c == _headers.length - 1) return;

    final existing = _draftHeaders[c];
    if (existing == value) return;

    if (value == _headers[c]) {
      if (_draftHeaders.remove(c) != null) {
        _bumpGridVersion();
      }
      return;
    }

    _draftHeaders[c] = value;
    _bumpGridVersion();
  }

  void _setDraftCell(int r, int c, String value) {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    if (c == _headers.length - 1) return;

    final rowId = _rows[r].id;
    final ref = _CellRef(r, c);
    final existing = _draftCells[ref];
    if (existing == value) return;

    if (value == _rows[r].cells[c]) {
      if (_draftCells.remove(ref) != null) {
        _bumpRowVersionById(rowId);
      }
      return;
    }

    _draftCells[ref] = value;
    _bumpRowVersionById(rowId);
  }

  void _commitDraftHeader(int c) {
    if (c < 0 || c >= _headers.length) return;
    if (c == _headers.length - 1) return;

    final draft = _draftHeaders[c];
    final next = (draft ?? _headers[c]).trim();
    if (next == _headers[c]) {
      if (_draftHeaders.remove(c) != null) {
        _bumpGridVersion();
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
      }
      return;
    }

    _rows[r].cells[c] = next;
    _draftCells.remove(ref);
    _markDirty(snapshot: true);
    _bumpRowVersionById(rowId);
  }

  void _clearDrafts() {
    if (_draftCells.isEmpty && _draftHeaders.isEmpty) return;
    _draftCells.clear();
    _draftHeaders.clear();
    _bumpGridVersion();
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
      controller.dispose();
    }
    _mobileRowScrolls.clear();
    _mobileRowKeys.clear();
    for (int i = 0; i < _rows.length; i++) {
      _mobileRowScrolls.add(ScrollController());
      _mobileRowKeys.add(GlobalKey());
    }
  }

  void _ensureMobileRowCachesLength() {
    while (_mobileRowScrolls.length < _rows.length) {
      _mobileRowScrolls.add(ScrollController());
      _mobileRowKeys.add(GlobalKey());
    }
    while (_mobileRowScrolls.length > _rows.length) {
      final controller = _mobileRowScrolls.removeLast();
      controller.dispose();
      _mobileRowKeys.removeLast();
    }
  }

  void _insertMobileRowCache(int index) {
    final idx = index.clamp(0, _mobileRowScrolls.length);
    _mobileRowScrolls.insert(idx, ScrollController());
    _mobileRowKeys.insert(idx, GlobalKey());
  }

  void _removeMobileRowCache(int index) {
    if (_mobileRowScrolls.isEmpty) return;
    final idx = index.clamp(0, _mobileRowScrolls.length - 1);
    final controller = _mobileRowScrolls.removeAt(idx);
    controller.dispose();
    _mobileRowKeys.removeAt(idx);
  }

  void _syncMobileHorizontal(double offset, bool isHeader, int row) {
    if (_mobileHSyncing) return;
    _mobileHSyncing = true;
    try {
      void jumpTo(ScrollController controller) {
        if (!controller.hasClients) return;
        final min = controller.position.minScrollExtent;
        final max = controller.position.maxScrollExtent;
        final clamped = offset.clamp(min, max).toDouble();
        if ((controller.offset - clamped).abs() < 0.5) return;
        controller.jumpTo(clamped);
      }

      jumpTo(_mobileHeaderScroll);
      for (final c in _mobileRowScrolls) {
        jumpTo(c);
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

  void _attachCellDraftListener() {
    if (_cellDraftListener != null) return;
    _cellDraftListener = () {
      final headerCol = _editingHeaderCol;
      final cellRef = _editingCellRef;
      final v = _cellEC.text;
      if (headerCol != null) {
        _setDraftHeader(headerCol, v);
      } else if (cellRef != null) {
        _setDraftCell(cellRef.r, cellRef.c, v);
      }
    };
    _cellEC.addListener(_cellDraftListener!);
  }

  void _detachCellDraftListener() {
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

  Future<void> _maybeRunSmoke() async {
    if (!_smokeRequested || _smokeRan) return;
    final base = _engineBaseResolved?.trim() ?? '';
    if (base.isEmpty || _engineBusy) return;
    _smokeRan = true;
    await _runSmokeTest();
  }

  void _updateSaveStatus() {
    final state = _saving
        ? EditorSaveState.saving
        : (_isDirty
            ? EditorSaveState.dirty
            : (_lastSavedAt != null
                ? EditorSaveState.saved
                : EditorSaveState.idle));
    _saveStatus.value = EditorSaveSnapshot(state: state, savedAt: _lastSavedAt);
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
      return pal.isLight ? const Color(0xFFD1FAE5) : const Color(0xFF064E3B);
    }
    if (_smokeOk == false) {
      return pal.isLight ? const Color(0xFFFEE2E2) : const Color(0xFF7F1D1D);
    }
    return pal.statusBg;
  }

  Color _smokeFg(_SheetPalette pal) {
    if (_smokeOk == true) {
      return pal.isLight ? const Color(0xFF065F46) : const Color(0xFF6EE7B7);
    }
    if (_smokeOk == false) {
      return pal.isLight ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5);
    }
    return pal.statusFg;
  }

  Color _errorBg(_SheetPalette pal) {
    return pal.isLight ? const Color(0xFFFEE2E2) : const Color(0xFF7F1D1D);
  }

  Color _errorFg(_SheetPalette pal) {
    return pal.isLight ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5);
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
    _selection.update(
      rowIndex: _selRow,
      colIndex: _selCol,
      cellRef: ref,
    );
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
              title: const Text('Jump to...'),
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
                          () => error = 'No hay columna para buscar ID.');
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
    if (rows.isEmpty || _headers.length < 2) return;
    final targetCol = _resolveBatchTargetColumn();
    final initial = _effectiveCell(rows.first, targetCol);
    final controller = TextEditingController(text: initial);
    final suggestions = _recentValuesForColumn(
      targetCol,
      excluding: initial,
    );

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
                Text(
                  'Recientes',
                  style: Theme.of(ctx).textTheme.labelMedium,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final item in suggestions.take(10))
                      ActionChip(
                        label: Text(
                          item,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () {
                          controller.value = controller.value.copyWith(
                            text: item,
                            selection:
                                TextSelection.collapsed(offset: item.length),
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
    final outcome =
        await _getGpsFixWithFallback(timeout: const Duration(seconds: 12));
    if (!mounted) return;
    if (!outcome.ok || outcome.fix == null) {
      _showGpsError(outcome);
      return;
    }
    final fix = outcome.fix!;
    final gpsMeta = GpsMeta(
      lat: fix.lat,
      lng: fix.lng,
      accuracyM: fix.accuracyM,
      timestamp: fix.ts,
      source: fix.source,
      provider: fix.provider,
    );
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
    _showActionSnack(
      'GPS aplicado a $applied fila(s).',
      isError: false,
      icon: Icons.my_location_rounded,
    );
  }

  void _duplicateSelectedRows() {
    final targets = _batchTargetRows();
    if (targets.isEmpty) return;
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
        _setSelection(
          insertAtList.first,
          _selCol,
          preserveRowSelection: true,
        );
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

  void _setCellMetaEntryRef(CellRef ref, CellMeta meta,
      {required bool markDirty}) {
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
        if (retry == null)
          return _offlineLastError ?? 'Fallo de sincronizacion';
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
      final idx =
          _editQueue.indexWhere((item) => item.sheetId == widget.sheetId);
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
    final found = _findDataColumnByKeywords(
      const <String>['fecha', 'date', 'hora', 'time', 'timestamp'],
    );
    if (found != null) return found;
    if (_selCol >= 0 && _selCol < _headers.length - 1) return _selCol;
    return 0;
  }

  int? _resolveQuickCaptureNoteColumn(int dateCol) {
    final found = _findDataColumnByKeywords(
      const <String>['nota', 'observ', 'coment', 'detalle', 'note'],
    );
    if (found != null && found != dateCol) return found;
    final dataCols = _headers.length - 1;
    for (int c = 0; c < dataCols; c++) {
      if (c != dateCol) return c;
    }
    return null;
  }

  int _resolveQuickCaptureGpsColumn(int fallbackCol) {
    final found = _findDataColumnByKeywords(
      const <String>['gps', 'ubic', 'coord', 'lat', 'lon'],
    );
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
    final gpsCol =
        _resolveQuickCaptureGpsColumn(dateCol).clamp(0, dataCols - 1);

    cells[dateCol] = _quickCaptureTimestampText(capturedAt);
    if (note.trim().isNotEmpty && noteCol != null) {
      cells[noteCol] = note.trim();
    }
    if (gpsFix != null && gpsCol != dateCol) {
      cells[gpsCol] = _gpsTextForFix(gpsFix);
    }

    final row = _RowModel(
      id: rowId,
      cells: cells,
      photos: const <_RowPhoto>[],
    );
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
          gps: GpsMeta(
            lat: gpsFix.lat,
            lng: gpsFix.lng,
            accuracyM: gpsFix.accuracyM,
            timestamp: gpsFix.ts,
            source: gpsFix.source,
            provider: gpsFix.provider,
          ),
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
        'Registro guardado sin GPS (permiso o senal no disponible).',
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
    if (mounted) {
      setState(() => _longOperation = next);
      return;
    }
    _longOperation = next;
  }

  void _setLongOperationMessage(String message) {
    final current = _longOperation;
    if (current == null || current.message == message) return;
    final next = current.copyWith(message: message);
    if (mounted) {
      setState(() => _longOperation = next);
      return;
    }
    _longOperation = next;
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
    if (mounted) {
      setState(() => _longOperation = next);
    } else {
      _longOperation = next;
    }
    _showActionSnack(
      AppStrings.infoOperationCancelling,
      isError: false,
      icon: Icons.hourglass_bottom_rounded,
    );
  }

  void _clearLongOperation() {
    if (_longOperation == null) return;
    if (mounted) {
      setState(() => _longOperation = null);
      return;
    }
    _longOperation = null;
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
    AppErrorReporter.I.record(
      appError,
      operation: operation,
    );
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
                  _showActionSnack('Link copiado.',
                      isError: false, icon: Icons.link_rounded);
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

  void _warnStorageFallbackOnce(String kindLabel) {
    if (_storageWarned) return;
    _storageWarned = true;
    if (mounted) {
      setState(() {
        _storageOk = false;
        _storageMessage = 'Session-only';
      });
    } else {
      _storageOk = false;
      _storageMessage = 'Session-only';
    }
    _showActionSnack(
      'Storage limitado: $kindLabel en modo temporal (session-only). Exporta ZIP para conservar.',
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
    final borderColor =
        t.colors.warningFg.withValues(alpha: pal.isLight ? 0.35 : 0.5);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.colors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: pal.hairline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: t.colors.warningFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: t.colors.warningFg,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
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
        final effectiveInset = mqInset > 0 ? mqInset : kbInset;
        final isDesktop = _isDesktopUi(ctx, effectiveInset);
        final sensorsEnabled = !_isInAppBrowser;
        _ensureDefaultDensity(isDesktop);
        final metrics = _gridMetricsFor(_gridDensity);

        if (!isDesktop) {
          _scheduleMobileBarMeasure();
        }

// Evitar escalados raros de texto (iOS / Web).
        final mq = MediaQuery.of(ctx);
        final bottomSafe = mq.padding.bottom;
        final requestedScale = mq.textScaler.scale(14) / 14;
        final boundedScale = requestedScale.clamp(1.0, 1.2).toDouble();
        final fixedMq =
            mq.copyWith(textScaler: TextScaler.linear(boundedScale));

        _kbController.reportMediaQueryInset(mqInset);
        final vvInset = vv.visualViewportKeyboardInset();
        final keyboardInset = math.max(effectiveInset, vvInset);
        final isMobile = !isDesktop;
        final editorActive = isMobile && _mobileEditorOpen;
        final desiredPanelH = _kMobilePanelCompactH;
        final panelH = isDesktop
            ? 0.0
            : (editorActive
                ? (_mobileBarH > 0 && (_mobileBarH - desiredPanelH).abs() < 8)
                    ? _mobileBarH
                    : desiredPanelH
                : 0.0);
        final quickBarH = isMobile && !_mobileEditorOpen
            ? _kMobileQuickBarH + bottomSafe + 12
            : 0.0;
        final bodyBottomPad = isDesktop
            ? 0.0
            : (editorActive ? panelH + keyboardInset : quickBarH);
        final showSelectionQuickActions =
            !_mobileEditorOpen && (_selRow >= 0 && _selCol >= 0);
        final canMarkSelectionStatus = _statusColumnForBatchActions() != null;
        final displayColumns = _displayColumnIndexes();
        final displayHeaders = List<String>.generate(
          displayColumns.length,
          (i) => _effectiveHeader(displayColumns[i]),
          growable: false,
        );
        final selectedDisplayCol =
            _displayColumnIndexForActual(_selCol, displayColumns);

        if (isMobile) {
          if (_engineStatusIsError && _engineStatus != null) {
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
            child: AppScaffold(
              resizeToAvoidBottomInset: false, // clave iOS Web
              backgroundColor: pal.bg,
              appBar: null,
              body: SafeArea(
                bottom: true,
                child: Stack(
                  children: [
                    if (pal.isLight)
                      Positioned.fill(child: _WarmBackdrop(palette: pal)),
                    AnimatedPadding(
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.only(bottom: bodyBottomPad),
                      child: Column(
                        children: [
                          if (isDesktop)
                            _PremiumAppleHeader(
                              palette: pal,
                              titleController: _nameEC,
                              titleFocus: _nameFocus,
                              controller: _controller,
                              onTitleChanged: _onTitleChangedDebounced,
                              onToggleTheme: _toggleTheme,
                              onUndo: _undoOnce,
                              onRedo: _redoOnce,
                              onAddRow: () => _insertRow(_rows.length),
                              onQuickCapture: () =>
                                  unawaited(_startQuickCaptureFlow()),
                              onForm: () => unawaited(
                                _openRowFormMode(
                                  rowIndex: _selRow,
                                  createNew: false,
                                ),
                              ),
                              onSearch: () => unawaited(_openSearchDialog()),
                              onJumpTo: () => unawaited(_openJumpToDialog()),
                              onColumns: () => unawaited(_openColumnPanel()),
                              onSave: () => unawaited(_saveNowFromUserAction()),
                              onExport: () => unawaited(_openExportMenu()),
                              onSmokeTest: () =>
                                  unawaited(_runAttachmentSmokeTest()),
                              onCompute: _engineBusy
                                  ? null
                                  : () => unawaited(_computeEngine()),
                              onBatch: () =>
                                  unawaited(_openBatchActionsSheet()),
                              onGps: () => unawaited(_requestGpsForCell(
                                  _selRow, _selCol,
                                  forceWriteText: true)),
                              onPhoto: () => unawaited(
                                _startPhotoFlowForCell(_selRow, _selCol),
                              ),
                              onVideo: () => unawaited(
                                  _attachVideoForCell(_selRow, _selCol)),
                              onAudio: () {
                                if (_audioRecording) {
                                  unawaited(_stopAudioRecording());
                                } else {
                                  unawaited(_startAudioRecordingForCell(
                                      _selRow, _selCol));
                                }
                              },
                              onFile: () => unawaited(
                                _attachDocumentForCell(_selRow, _selCol),
                              ),
                              onAttachments: () => unawaited(
                                _openAttachmentPanelForCell(_selRow, _selCol),
                              ),
                              onShare: () =>
                                  unawaited(_exportZipBundle(share: true)),
                              onPalette: () => unawaited(_openCommandPalette()),
                              onGpsMode: () => unawaited(_showGpsModePicker()),
                              onDensity: () => unawaited(_showDensityPicker()),
                              onOpenOfflineQueue: _openOfflineQueueDialog,
                              lastLocalSavedAt: _lastSavedAt,
                              sensorsEnabled: sensorsEnabled,
                              selectedRow: _selRow,
                              selectedCol: _selCol,
                              selectedRowsCount: _selectedRows.length,
                              pendingOfflineCount: _pendingOfflineCount,
                            )
                          else
                            _MobileCompactHeader(
                              palette: pal,
                              title: _sheetName,
                              controller: _controller,
                              pendingRequired: _pendingRequired,
                              pendingOfflineCount: _pendingOfflineCount,
                              selectedRow: _selRow,
                              selectedCol: _selCol,
                              onSave: () => unawaited(_saveNowFromUserAction()),
                              onExport: () => unawaited(_openExportMenu()),
                              onMenu: () => _openMobileHeaderMenu(
                                context,
                                pal,
                              ),
                              onOpenOfflineQueue: _openOfflineQueueDialog,
                              lastLocalSavedAt: _lastSavedAt,
                            ),
                          if (_isInAppBrowser)
                            _warningBanner(pal,
                                text:
                                    'Estas usando un navegador embebido. Abri en Safari/Chrome para GPS, camara y microfono.',
                                icon: Icons.open_in_new_rounded),
                          if (!_isSecureContext)
                            _warningBanner(pal,
                                text:
                                    'Para GPS, camara y audio necesitas HTTPS o localhost. Abri esta pagina en Safari/Chrome.',
                                icon: Icons.lock_outline_rounded),
                          if (_storageOk == false)
                            _warningBanner(pal,
                                text:
                                    "Storage limitado: ${_storageMessage ?? 'no disponible'}. Guardado temporal. Exporta ZIP.",
                                icon: Icons.warning_amber_rounded,
                                actionLabel: 'Exportar ZIP',
                                onAction: () =>
                                    unawaited(_exportZipBundle(share: false))),
                          if (_recoveryBannerVisible &&
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
                          if (_shouldShowAndroidInstallHelper)
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
                          if (_pendingOfflineCount > 0)
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
                                      _syncQuickCaptureQueue(notify: true))
                                  : _openOfflineQueueDialog,
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
                            child: _editorTourVisible
                                ? KeyedSubtree(
                                    key: const ValueKey('editor-tour-open'),
                                    child: _EditorFirstRunTourBanner(
                                      palette: pal,
                                      onAcknowledge: () => unawaited(
                                        _closeEditorTour(
                                          dontShowAgain: false,
                                        ),
                                      ),
                                      onDismissForever: () => unawaited(
                                        _closeEditorTour(
                                          dontShowAgain: true,
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey('editor-tour-closed'),
                                  ),
                          ),
                          if (_photoFlowStatus != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: pal.statusBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: pal.border, width: pal.hairline),
                                boxShadow: [
                                  BoxShadow(
                                    color: pal.border.withOpacity(0.22),
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
                                                  picked.row, picked.col);
                                              if (ref == null) return;
                                              _setSelectionAndRefreshGrid(
                                                  picked.row, picked.col);
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
                                        'selection-quick-actions-open'),
                                    child: _SelectionQuickActionsBar(
                                      palette: pal,
                                      selectionLabel:
                                          _selectionLabelForQuickActions(),
                                      selectedRowsCount:
                                          _batchTargetRows().length,
                                      canMarkStatus: canMarkSelectionStatus,
                                      onApplyValue: () =>
                                          unawaited(_promptBatchApplyValue()),
                                      onFillDown: () => unawaited(
                                          _promptFillDown(
                                              context, _selRow, _selCol)),
                                      onDuplicateRows: _duplicateSelectedRows,
                                      onAttachPhoto: () => unawaited(
                                        _startPhotoFlowForCell(
                                            _selRow, _selCol),
                                      ),
                                      onAttachGps: () => unawaited(
                                        _requestGpsForCell(_selRow, _selCol,
                                            forceWriteText: true),
                                      ),
                                      onJumpTo: () =>
                                          unawaited(_openJumpToDialog()),
                                      onMarkStatus: (value) => unawaited(
                                        _applyStatusToSelectedRows(value),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey(
                                        'selection-quick-actions-closed'),
                                  ),
                          ),
                          if (isDesktop && _smokeStatus != null)
                            _StatusBar(
                              text: _smokeStatus!,
                              bg: _smokeBg(pal),
                              fg: _smokeFg(pal),
                            ),
                          if (isDesktop && _engineStatus != null)
                            _StatusBar(
                              text: _engineStatus!,
                              bg: _engineStatusIsError
                                  ? _errorBg(pal)
                                  : pal.statusBg,
                              fg: _engineStatusIsError
                                  ? _errorFg(pal)
                                  : pal.statusFg,
                            ),
                          Expanded(
                            child: isDesktop
                                ? Focus(
                                    autofocus: true,
                                    onKeyEvent: _onKeyEvent,
                                    child: FocusTraversalOrder(
                                      order: const NumericFocusOrder(2.0),
                                      child: Semantics(
                                        container: true,
                                        label: 'Grilla de planilla',
                                        child: RepaintBoundary(
                                          child: ValueListenableBuilder<int>(
                                            valueListenable: _gridVersion,
                                            builder: (ctx, _, __) {
                                              _trackGridHostBuild('desktop');
                                              return _GridView(
                                                palette: pal,
                                                metrics: metrics,
                                                headers: displayHeaders,
                                                rowModels: _rows,
                                                cellTextAt: (r, c) {
                                                  final actualCol =
                                                      _actualColumnFromDisplay(
                                                          c, displayColumns);
                                                  return _effectiveCell(
                                                      r, actualCol);
                                                },
                                                cellHasGps: (r, c) {
                                                  final actualCol =
                                                      _actualColumnFromDisplay(
                                                          c, displayColumns);
                                                  return _cellHasGps(
                                                      r, actualCol);
                                                },
                                                cellHasAudios: (r, c) {
                                                  final actualCol =
                                                      _actualColumnFromDisplay(
                                                          c, displayColumns);
                                                  return _cellHasAudios(
                                                      r, actualCol);
                                                },
                                                cellPhotoThumb: (r, c) {
                                                  final actualCol =
                                                      _actualColumnFromDisplay(
                                                          c, displayColumns);
                                                  return _cellPhotoThumb(
                                                      r, actualCol);
                                                },
                                                cellPhotoCount: (r, c) {
                                                  final actualCol =
                                                      _actualColumnFromDisplay(
                                                          c, displayColumns);
                                                  return _cellPhotoCount(
                                                      r, actualCol);
                                                },
                                                isInvalid: (r, c) {
                                                  final actualCol =
                                                      _actualColumnFromDisplay(
                                                          c, displayColumns);
                                                  return _invalidCells.contains(
                                                      _CellRef(r, actualCol));
                                                },
                                                isSearchHit: (r, c) {
                                                  final actualCol =
                                                      _actualColumnFromDisplay(
                                                          c, displayColumns);
                                                  return _isSearchHit(
                                                      r, actualCol);
                                                },
                                                vScroll: _vScroll,
                                                hScroll: _hScroll,
                                                selRow: _selRow,
                                                selCol: selectedDisplayCol,
                                                selectedRows: _selectedRows,
                                                blink: _blinkCell,
                                                editorLink: _editorLink,
                                                overlayTargetCell:
                                                    _overlayTargetCell == null
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
                                                  final actualCol =
                                                      _actualColumnFromDisplay(
                                                          c, displayColumns);
                                                  _setSelectionAndRefreshGrid(
                                                      r, actualCol,
                                                      blink: true);
                                                },
                                                onRowIndexTap:
                                                    _handleRowIndexTap,
                                                onEditRequested: (r, c, w) {
                                                  final actualCol =
                                                      _actualColumnFromDisplay(
                                                          c, displayColumns);
                                                  return _beginEditCell(context,
                                                      pal, r, actualCol, w);
                                                },
                                                onHeaderEditRequested: (c, w) {
                                                  final actualCol =
                                                      _actualColumnFromDisplay(
                                                          c, displayColumns);
                                                  return _beginEditHeader(
                                                      context,
                                                      pal,
                                                      actualCol,
                                                      w);
                                                },
                                                onContextMenu:
                                                    (pos, r, c, isHeader) {
                                                  final actualCol =
                                                      _actualColumnFromDisplay(
                                                          c, displayColumns);
                                                  unawaited(_openContextMenu(
                                                      context,
                                                      pal,
                                                      pos,
                                                      r,
                                                      actualCol,
                                                      isHeader));
                                                },
                                                onDeleteRow: (r) =>
                                                    _deleteRow(r),
                                                onPickPhoto: (r) =>
                                                    _startPhotoFlowForCell(
                                                  r,
                                                  _headers.length - 1,
                                                ),
                                                onOpenAttachments: (r, c) =>
                                                    _openAttachmentPanelForCell(
                                                        r,
                                                        _actualColumnFromDisplay(
                                                            c, displayColumns)),
                                                rowVersionListenable:
                                                    _rowVersionListenable,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : RepaintBoundary(
                                    child: ValueListenableBuilder<int>(
                                      valueListenable: _gridVersion,
                                      builder: (ctx, _, __) {
                                        _ensureMobileRowCachesLength();
                                        final cardW = _mobileCardWidthForScreen(
                                            MediaQuery.of(ctx).size.width);
                                        _trackGridHostBuild('mobile');
                                        return _MobileNotesGrid(
                                          palette: pal,
                                          density: _gridDensity,
                                          headers: displayHeaders,
                                          rowModels: _rows,
                                          cellTextAt: (r, c) {
                                            final actualCol =
                                                _actualColumnFromDisplay(
                                                    c, displayColumns);
                                            return _effectiveCell(r, actualCol);
                                          },
                                          cellHasGps: (r, c) {
                                            final actualCol =
                                                _actualColumnFromDisplay(
                                                    c, displayColumns);
                                            return _cellHasGps(r, actualCol);
                                          },
                                          cellHasAudios: (r, c) {
                                            final actualCol =
                                                _actualColumnFromDisplay(
                                                    c, displayColumns);
                                            return _cellHasAudios(r, actualCol);
                                          },
                                          cellPhotoThumb: (r, c) {
                                            final actualCol =
                                                _actualColumnFromDisplay(
                                                    c, displayColumns);
                                            return _cellPhotoThumb(
                                                r, actualCol);
                                          },
                                          cellPhotoCount: (r, c) {
                                            final actualCol =
                                                _actualColumnFromDisplay(
                                                    c, displayColumns);
                                            return _cellPhotoCount(
                                                r, actualCol);
                                          },
                                          verticalController: _vScroll,
                                          headerScrollController:
                                              _mobileHeaderScroll,
                                          rowScrollControllers:
                                              _mobileRowScrolls,
                                          headerKey: _mobileHeaderKey,
                                          rowKeys: _mobileRowKeys,
                                          selectedRow: _selRow,
                                          selectedCol: selectedDisplayCol,
                                          activeRow: _mobileEditorOpen &&
                                                  !_mobileEditingHeader
                                              ? _mobileRow
                                              : -1,
                                          activeCol: _mobileEditorOpen
                                              ? _displayColumnIndexForActual(
                                                  _mobileCol, displayColumns)
                                              : -1,
                                          activeIsHeader: _mobileEditorOpen &&
                                              _mobileEditingHeader,
                                          activeController: _mobileEC,
                                          onHorizontalScroll:
                                              _syncMobileHorizontal,
                                          onCellTap: (cellCtx, r, c) =>
                                              _beginEditCell(
                                                  cellCtx,
                                                  pal,
                                                  r,
                                                  _actualColumnFromDisplay(
                                                      c, displayColumns),
                                                  cardW),
                                          onHeaderTap: (cellCtx, c) =>
                                              _beginEditHeader(
                                                  cellCtx,
                                                  pal,
                                                  _actualColumnFromDisplay(
                                                      c, displayColumns),
                                                  cardW),
                                          onContextMenu:
                                              (pos, r, c, isHeader) =>
                                                  _openContextMenu(
                                                      ctx,
                                                      pal,
                                                      pos,
                                                      r,
                                                      _actualColumnFromDisplay(
                                                          c, displayColumns),
                                                      isHeader),
                                          onDeleteRow: (r) => _deleteRow(r),
                                          onPickPhoto: (r) =>
                                              _startPhotoFlowForCell(
                                            r,
                                            _headers.length - 1,
                                          ),
                                          onOpenAttachments: (r, c) =>
                                              _openAttachmentPanelForCell(
                                                  r,
                                                  _actualColumnFromDisplay(
                                                      c, displayColumns)),
                                        );
                                      },
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),

                    if (!isDesktop && !_mobileEditorOpen)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12 + bottomSafe,
                        child: _MobileQuickActionsBar(
                          palette: pal,
                          sensorsEnabled: sensorsEnabled,
                          onQuickCapture: () =>
                              unawaited(_startQuickCaptureFlow()),
                          onForm: () => unawaited(
                            _openRowFormMode(
                              rowIndex: _selRow,
                              createNew: false,
                            ),
                          ),
                          onBatch: () => unawaited(_openBatchActionsSheet()),
                          onGps: () => unawaited(_requestGpsForCell(
                              _selRow, _selCol,
                              forceWriteText: true)),
                          onPhoto: () => unawaited(
                            _startPhotoFlowForCell(_selRow, _selCol),
                          ),
                          onVideo: () =>
                              unawaited(_attachVideoForCell(_selRow, _selCol)),
                          onAudio: () {
                            if (_audioRecording) {
                              unawaited(_stopAudioRecording());
                            } else {
                              unawaited(_startAudioRecordingForCell(
                                  _selRow, _selCol));
                            }
                          },
                          onFile: () => unawaited(
                            _attachDocumentForCell(_selRow, _selCol),
                          ),
                          onExport: () => unawaited(_openExportMenu()),
                          onShare: () =>
                              unawaited(_exportZipBundle(share: true)),
                          onDensity: () => unawaited(_showDensityPicker()),
                        ),
                      ),
// ??? SIEMPRE montado (iPhone estable). Solo se anima/inhabilita.
                    if (!isDesktop)
                      _MobileInlineEditorBar(
                        palette: pal,
                        density: _gridDensity,
                        barKey: _mobileBarKey,
                        fieldKey: _mobileFieldKey,
                        isOpen: _mobileEditorOpen,
                        title: _mobileTitle,
                        controller: _mobileEC,
                        focusNode: _mobileFocus,
                        actions: _mobileActions,
                        keyboardInset: keyboardInset,
                        panelHeight: panelH,
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
                        onCancel: _cancelMobileEdit,
                        onDone: _commitMobileEdit,
                      ),
                    if (_longOperation != null)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black
                                .withOpacity(pal.isLight ? 0.18 : 0.34),
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360),
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
        final nextDisplay = (displayIndex + dCol)
            .clamp(
              0,
              displayColumns.length - 1,
            )
            .toInt();
        nc = displayColumns[nextDisplay];
      } else {
        nc = (nc + dCol).clamp(0, _headers.length - 1).toInt();
      }
    }
    _setSelectionAndRefreshGrid(nr, nc, blink: true);
  }

// ------------------------------ Edici??n Header --------------------------

  void _beginEditHeader(
      BuildContext context, _SheetPalette pal, int c, double headerWidth) {
    if (c < 0 || c >= _headers.length) return;
    if (c == _headers.length - 1) return; // Photos no editable

    _removeCellEditor();
    _blink(-1, c);

    final isDesktop = _isDesktopUi(context, _kbController.kbInsetDp.value);
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
      BuildContext context, _SheetPalette pal, int r, int c, double cellWidth,
      {String? initialOverride}) {
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

    final isDesktop = _isDesktopUi(context, _kbController.kbInsetDp.value);
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
    next[colId] = _ColumnPrefs(type: type, hidden: hidden);
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
    next[colId] = _ColumnPrefs(type: type, hidden: hidden);
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

  void _sortRowsByColumn(int col, {required bool ascending}) {
    if (col < 0 || col >= _headers.length - 1) return;
    if (_rows.isEmpty) return;
    final currentSelId =
        (_selRow >= 0 && _selRow < _rows.length) ? _rows[_selRow].id : null;
    final type = _colType(col);

    int cmpValue(String a, String b) {
      final left = a.trim();
      final right = b.trim();
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

    _rows.sort((a, b) {
      final av = (col < a.cells.length) ? a.cells[col] : '';
      final bv = (col < b.cells.length) ? b.cells[col] : '';
      final base = cmpValue(av, bv);
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

    final next = _normalizeCellValueForColumn(c, value);
    if (_rows[r].cells[c] == next) return;

    _rows[r].cells[c] = next;
    _rememberValueForColumn(c, next);
    _markDirty(snapshot: true);
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

    _mobileEditingHeader = isHeader;
    _mobileRow = row;
    _mobileCol = col;
    _mobileTitle = title;
    _mobileActions = actions;

    _detachMobileDraftListener();
    _mobileEC.text = initial;
    _mobileEC.selection =
        TextSelection(baseOffset: 0, extentOffset: _mobileEC.text.length);
    _attachMobileDraftListener();

    if (!_mobileEditorOpen) {
      setState(() {
        _mobileEditorOpen = true;
        _mobilePhase = _MobileEditPhase.opening;
      });
    } else {
      setState(() => _mobilePhase = _MobileEditPhase.switching);
    }

    _requestMobileFocusWithRetry();

    if (row >= 0 || isHeader) {
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
        label: _audioRecording ? 'Detener audio' : 'Audio',
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
        label: 'Maps',
        onTap: () => unawaited(_openMapsForCell(r, c)),
      ),
    ];
  }

  void _handleMobileFocusChange() {
    if (!_mobileFocus.hasFocus) return;
    if (!_mobileEditorOpen) return;
    if (!_mobileEditingHeader && _mobileRow < 0) return;
    final targetRow = _mobileEditingHeader ? -1 : _mobileRow;
    _scheduleEnsureRowVisiblePostFrame(targetRow);
    _scheduleEnsureRowVisibleLate(targetRow);
  }

  void _requestMobileFocusWithRetry() {
    if (!_mobileEditorOpen) return;
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
    _kbEnsureDebounceT?.cancel();
    _kbEnsureDebounceT = Timer(const Duration(milliseconds: 80), () {
      if (!mounted || !_mobileEditorOpen) return;
      _ensureRowVisibleForKeyboard(row);
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
                title: const Text('Done'),
                onTap: () {
                  Navigator.pop(ctx);
                  _commitMobileEdit();
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
                  title: Text(_audioRecording
                      ? 'Detener grabacion'
                      : 'Grabar audio en esta celda'),
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
                    unawaited(_requestGpsForCell(row, _mobileCol,
                        forceWriteText: true));
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

  static const double _kMobilePanelCompactH = 96.0;
  void _ensureRowVisibleForKeyboard(int row) {
    if (!mounted) return;
    if (!_vScroll.hasClients) return;
    final panelMargin = _mobileBarH > 0 ? _mobileBarH + 16 : 120.0;
    if (_mobileEditingHeader || row < 0) {
      final ctx = _mobileHeaderKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: 0.06,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
      } else {
        _vScroll.animateTo(
          _vScroll.position.minScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
      _ensureColumnVisibleForMobile();
      return;
    }

    if (row >= _mobileRowKeys.length) return;
    final rowCtx = _mobileRowKeys[row].currentContext;
    if (rowCtx != null) {
      Scrollable.ensureVisible(
        rowCtx,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: 0.06,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    } else {
      final target = _mobileRowOffsetFor(row);
      final clamped = target.clamp(
          _vScroll.position.minScrollExtent, _vScroll.position.maxScrollExtent);
      _vScroll.animateTo(
        math.max(
          _vScroll.position.minScrollExtent,
          clamped.toDouble() - panelMargin,
        ),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
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
            ? _mobileRowScrolls[_mobileRow]
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

    final clamped = target.clamp(controller.position.minScrollExtent,
        controller.position.maxScrollExtent);
    if ((clamped - controller.offset).abs() < 6.0) return;
    controller.animateTo(
      clamped.toDouble(),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
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
      _mobileActions = _mobileActionsForCell(r, c);
      _mobileEditorOpen = true;
      _mobilePhase = _MobileEditPhase.switching;
    });

    _blink(r, c);

    _mobileEC.text = _effectiveCell(r, c);
    _mobileEC.selection =
        TextSelection(baseOffset: 0, extentOffset: _mobileEC.text.length);

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
      _mobileActions = _mobileActionsForCell(r, c);
      _mobileEditorOpen = true;
      _mobilePhase = _MobileEditPhase.switching;
    });

    _blink(r, c);

    _mobileEC.text = _effectiveCell(r, c);
    _mobileEC.selection =
        TextSelection(baseOffset: 0, extentOffset: _mobileEC.text.length);

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
    _cellEC.selection =
        TextSelection(baseOffset: 0, extentOffset: _cellEC.text.length);
    _attachCellDraftListener();
    _cellDraftListener?.call();

    final metrics = _gridMetricsFor(_gridDensity);
    final editorFont = (metrics.cellFontSize + 2).clamp(13.0, 17.0);
    final activeCol = _overlayTargetCell?.c ?? _overlayTargetHeaderCol;
    final hintText =
        activeCol == null ? 'Escribir' : 'Editar ${_headerLabel(activeCol)}';
    final suggestions = activeCol == null
        ? const <String>[]
        : _recentValuesForColumn(activeCol, excluding: initial)
            .take(10)
            .toList(growable: false);
    final overlay = Overlay.of(context, rootOverlay: true);

    _cellEditorEntry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  onCommit(_cellEC.text);
                  _removeCellEditor();
                },
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
                      onCommit(_cellEC.text);
                      _removeCellEditor();
                      return KeyEventResult.handled;
                    }

// Tab / Shift+Tab => commit + mover.
                    if (event.logicalKey == LogicalKeyboardKey.tab) {
                      _overlayCommitAndNavigate(
                        context: context,
                        pal: pal,
                        onCommit: onCommit,
                        move: isShift ? _OverlayMove.prev : _OverlayMove.next,
                      );
                      return KeyEventResult.handled;
                    }

// Enter / Shift+Enter => commit + bajar/subir.
                    if (event.logicalKey == LogicalKeyboardKey.enter) {
                      _overlayCommitAndNavigate(
                        context: context,
                        pal: pal,
                        onCommit: onCommit,
                        move: isShift ? _OverlayMove.up : _OverlayMove.down,
                      );
                      return KeyEventResult.handled;
                    }

                    return KeyEventResult.ignored;
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: pal.isLight ? 16.0 : 14.0,
                        sigmaY: pal.isLight ? 16.0 : 14.0,
                        tileMode: TileMode.decal,
                      ),
                      child: Container(
                        width: width,
                        padding: metrics.cellPadding,
                        decoration: BoxDecoration(
// Dark: glass visible sin quedar bloque opaco.
                          color: pal.isLight
                              ? Colors.white.withValues(alpha: 0.90)
                              : const Color(0xFF0B0B0C).withValues(alpha: 0.56),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: pal.isLight
                                ? Colors.black.withValues(alpha: 0.10)
                                : Colors.white.withValues(alpha: 0.24),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: pal.isLight ? 0.10 : 0.55),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
// Micro-glow monocromo.
                            if (!pal.isLight)
                              BoxShadow(
                                color: pal.accent.withValues(alpha: 0.18),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
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
                                    maxLines: 1,
                                    autocorrect: false,
                                    enableSuggestions: false,
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
                                    onSubmitted: (v) {
                                      onCommit(v);
                                      _removeCellEditor();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    onCommit(_cellEC.text);
                                    _removeCellEditor();
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 4),
                                    child: Icon(Icons.check_rounded,
                                        color: pal.fg, size: 20),
                                  ),
                                ),
                              ],
                            ),
                            if (suggestions.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final suggestion in suggestions) ...[
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
                                            selection: TextSelection.collapsed(
                                                offset: suggestion.length),
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
                            ],
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
    final dataOrder = List<String>.from(_normalizeColumnOrder(
      colIds: _colIds,
      incoming: _columnOrder,
    ));
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
                        label: 'Reset template',
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
                            draftFrozen = null;
                          });
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
                final orderIndex = draftOrder.indexOf(colId);

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                              value: type,
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
        actions.add(_CtxAction('Editar encabezado', Icons.edit_outlined,
            () => _beginEditHeader(context, pal, c, 220)));
        actions.add(_CtxAction(
            'Renombrar columna',
            Icons.drive_file_rename_outline,
            () => _beginEditHeader(context, pal, c, 240)));
        actions.add(_CtxAction('Limpiar encabezado', Icons.clear_rounded, () {
          if (_headers[c].isEmpty) return;
          _headers[c] = '';
          _markDirty(snapshot: true);
        }));
        actions.add(_CtxAction(
          'Tipo: ${_columnTypeLabel(colType)}',
          Icons.category_outlined,
          () => unawaited(_openColumnTypePicker(c)),
          runOnTap: true,
        ));
        actions.add(_CtxAction(
          'Ordenar ascendente',
          Icons.arrow_upward_rounded,
          () => _sortRowsByColumn(c, ascending: true),
        ));
        actions.add(_CtxAction(
          'Ordenar descendente',
          Icons.arrow_downward_rounded,
          () => _sortRowsByColumn(c, ascending: false),
        ));
        actions.add(_CtxAction(
          frozen ? 'Desfijar columna' : 'Fijar columna',
          frozen ? Icons.push_pin : Icons.push_pin_outlined,
          () => _setFrozenColumnByIndex(frozen ? null : c),
        ));
        actions.add(_CtxAction(
          hidden ? 'Mostrar columna' : 'Ocultar columna',
          hidden ? Icons.visibility_rounded : Icons.visibility_off_outlined,
          () => _setColumnHidden(c, !hidden),
        ));
        actions.add(_CtxAction(
          'Panel Columnas',
          Icons.view_column_rounded,
          () => unawaited(_openColumnPanel()),
          runOnTap: true,
        ));
      }
    } else {
      actions.add(_CtxAction('Copiar', Icons.copy_rounded,
          () => unawaited(_copySelectionToClipboard())));
      actions.add(_CtxAction('Pegar', Icons.paste_rounded,
          () => unawaited(_pasteFromClipboard())));
      actions.add(_CtxAction(
          'Duplicar fila', Icons.copy_all_outlined, () => _duplicateRow(r)));
      actions.add(_CtxAction('Duplicar N veces', Icons.copy_all_rounded,
          () => unawaited(_promptDuplicateRowCount(r))));

      if (_batchTargetRows().length > 1) {
        actions.add(_CtxAction(
            'Aplicar valor a seleccion',
            Icons.format_color_text_rounded,
            () => unawaited(_promptBatchApplyValue())));
      }

      actions.add(_CtxAction(
        'Adjuntar foto',
        Icons.add_photo_alternate_outlined,
        () => unawaited(_startPhotoFlowForCell(r, c)),
        runOnTap: true,
      ));
      if (c != _headers.length - 1) {
        actions.add(_CtxAction(
          'Adjuntar GPS',
          Icons.my_location_rounded,
          () => unawaited(_requestGpsForCell(r, c, forceWriteText: true)),
          runOnTap: true,
        ));
      }

      final hasAttachments = _cellMetaAt(r, c)?.isEmpty == false;
      if (hasAttachments) {
        actions.add(_CtxAction('Ver adjuntos', Icons.attach_file_rounded,
            () => unawaited(_openAttachmentPanelForCell(r, c))));
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

  void _duplicateRow(int r) {
    _duplicateRowMultiple(r, times: 1);
  }

  void _duplicateRowMultiple(int r, {required int times}) {
    if (r < 0 || r >= _rows.length) return;
    if (times <= 0) return;
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
  }

  Future<void> _promptDuplicateRowCount(int row) async {
    if (row < 0 || row >= _rows.length) return;
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
    if (c < 0 || c >= _headers.length - 1) return;
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
    if (c < 0 || c >= _headers.length - 1) return;
    if (r < 0 || r >= _rows.length) return;
    final value = (_mobileEditorOpen &&
            _mobileRow == r &&
            _mobileCol == c &&
            !_mobileEditingHeader)
        ? _mobileEC.text
        : _effectiveCell(r, c);
    if (count <= 0) return;

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
  }

  Future<void> _promptIncrement(BuildContext context, int r, int c) async {
    if (c < 0 || c >= _headers.length - 1) return;
    final countCtrl = TextEditingController(text: _incrementCount.toString());
    final stepCtrl = TextEditingController(text: _incrementStep.toString());
    final res = await showDialog<List<int>>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Incrementar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: countCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad'),
              ),
              TextField(
                controller: stepCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Paso'),
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
                final count = int.tryParse(countCtrl.text.trim());
                final step = int.tryParse(stepCtrl.text.trim());
                if (count == null || step == null) {
                  Navigator.of(ctx).pop();
                  return;
                }
                Navigator.of(ctx).pop([count, step]);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    countCtrl.dispose();
    stepCtrl.dispose();
    if (!mounted) return;
    if (res == null || res.length != 2) return;
    final count = res[0];
    final step = res[1];
    if (count <= 0) return;
    _incrementCount = count;
    _incrementStep = step == 0 ? 1 : step;
    _incrementDownColumn(r, c, count: _incrementCount, step: _incrementStep);
  }

  void _incrementDownColumn(int r, int c,
      {required int count, required int step}) {
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
    _pushUndoSnapshot();
    _queueSave();
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

  Future<void> _openRowFormMode({
    int? rowIndex,
    bool createNew = false,
  }) async {
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
    final gpsCol = (_resolveQuickCaptureGpsColumn(dateCol ?? 0))
        .clamp(0, _headers.length - 2);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final pal = _palette(ctx);
        var saving = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> runPhoto() async {
              setModalState(() => saving = true);
              await _startPhotoFlowForCell(targetRow, _headers.length - 1);
              if (!ctx.mounted) return;
              setModalState(() => saving = false);
            }

            Future<void> runGps() async {
              setModalState(() => saving = true);
              await _requestGpsForCell(targetRow, gpsCol, forceWriteText: true);
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
                            label: AppStrings.save,
                            icon: Icons.check_rounded,
                            variant: AppButtonVariant.primary,
                            onPressed: saving
                                ? null
                                : () {
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
    final border = Border.all(color: palette.border, width: palette.hairline);

    Widget field;
    switch (type) {
      case _ColType.status:
        final current = controller.text.trim();
        field = Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final status in const <String>['OK', 'Obs', 'Urgente'])
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
          controller: controller,
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
          controller: controller,
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
          controller: controller,
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
            Text(
              label,
              style: TextStyle(
                color: palette.fgMuted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
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
    _pushUndoSnapshot();
    _queueSave();
  }

// ------------------------------ Clipboard -------------------------------

  Future<void> _copySelectionToClipboard() async {
    final txt = _getCellText(_selRow, _selCol);
    try {
      await Clipboard.setData(ClipboardData(text: txt));
    } catch (_) {}
  }

  Future<void> _copyActiveMobileCell() async {
    if (!_mobileEditorOpen) return;
    if (_mobileEditingHeader) return;
    final txt = _mobileEC.text;
    try {
      await Clipboard.setData(ClipboardData(text: txt));
    } catch (_) {}
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

  Future<void> _pasteFromClipboard() async {
    String raw = '';
    try {
      final data = await Clipboard.getData('text/plain');
      raw = data?.text ?? '';
    } catch (_) {}
    if (raw.trim().isEmpty) return;

    final grid = _parseGrid(raw);
    if (grid.isEmpty) return;

// ??? FIX: si est??s parado en Photos, peg?? en el ??ltimo editable.
    final startR = _selRow;
    final startC = math.min(_selCol, _headers.length - 2);
    final maxColsExclusive = _headers.length - 1; // no pegamos sobre Photos
    final selectedRows = _batchTargetRows();

    if (grid.length == 1 && grid.first.length == 1 && selectedRows.length > 1) {
      final normalized = _normalizeCellValueForColumn(startC, grid.first.first);
      final refsToClear = <_CellRef>[];
      var changed = 0;
      for (final r in selectedRows) {
        if (r < 0 || r >= _rows.length) continue;
        if (_rows[r].cells[startC] == normalized) continue;
        _rows[r].cells[startC] = normalized;
        refsToClear.add(_CellRef(r, startC));
        changed++;
      }
      if (changed <= 0) return;
      _rememberValueForColumn(startC, normalized);
      _clearCellDrafts(refsToClear);
      _setSelection(
        selectedRows.first,
        startC,
        preserveRowSelection: true,
      );
      _markDirty(snapshot: true);
      return;
    }

// Extender filas si hace falta
    final neededRows = startR + grid.length;
    if (neededRows > _rows.length) {
      final add = neededRows - _rows.length;
      for (int i = 0; i < add; i++) {
        _rows.add(_RowModel.empty(_headers.length, id: _genStableId('r_')));
      }
    }
    _ensureMobileRowCachesLength();

    final refsToClear = <_CellRef>[];
    var changed = 0;
    for (int dr = 0; dr < grid.length; dr++) {
      final row = grid[dr];
      for (int dc = 0; dc < row.length; dc++) {
        final rr = startR + dr;
        final cc = startC + dc;
        if (cc >= maxColsExclusive) break;
        final normalized = _normalizeCellValueForColumn(cc, row[dc]);
        if (_rows[rr].cells[cc] == normalized) continue;
        _rows[rr].cells[cc] = normalized;
        _rememberValueForColumn(cc, normalized);
        refsToClear.add(_CellRef(rr, cc));
        changed++;
      }
    }

    if (changed <= 0) return;
    _clearCellDrafts(refsToClear);
    _markDirty(snapshot: true);
  }

  List<List<String>> _parseGrid(String raw) {
    final txt = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = txt.split('\n').where((e) => e.isNotEmpty).toList();
    if (lines.isEmpty) return const [];

    final out = <List<String>>[];
    for (final line in lines) {
      final hasTab = line.contains('\t');
      final parts = hasTab
          ? line.split('\t')
          : (line.contains(',') ? _parseCsvLine(line) : <String>[line]);
      out.add(parts.map((e) => e.trimRight()).toList());
    }
    return out;
  }

  List<String> _parseCsvLine(String line) {
    final out = <String>[];
    var buffer = StringBuffer();
    var inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
          continue;
        }
        inQuotes = !inQuotes;
        continue;
      }
      if (!inQuotes && ch == ',') {
        out.add(buffer.toString());
        buffer = StringBuffer();
        continue;
      }
      buffer.write(ch);
    }
    out.add(buffer.toString());
    return out;
  }

  Future<void> _openSearchDialog() async {
    _openInlineSearch();
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
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final text = _effectiveCell(r, c).toLowerCase();
        if (!text.contains(needle)) continue;
        nextMatches.add(_CellRef(r, c));
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

// ------------------------------ GPS / Maps ------------------------------

  CellMeta? _cellMetaAt(int r, int c) {
    final ref = _cellRefAt(r, c);
    if (ref == null) return null;
    return _cellMeta[ref.key];
  }

  bool _cellHasGps(int r, int c) => _cellMetaAt(r, c)?.hasGps ?? false;
  bool _cellHasPhotos(int r, int c) => _cellMetaAt(r, c)?.hasPhotos ?? false;
  bool _cellHasAudios(int r, int c) => _cellMetaAt(r, c)?.hasAudios ?? false;

  List<PhotoAttachment> _cellPhotosAt(int r, int c) =>
      _cellMetaAt(r, c)?.photos ?? const <PhotoAttachment>[];

  List<AudioAttachment> _cellAudiosAt(int r, int c) =>
      _cellMetaAt(r, c)?.audios ?? const <AudioAttachment>[];

  String _cellPhotoThumb(int r, int c) {
    final meta = _cellMetaAt(r, c);
    if (meta == null || meta.photos.isEmpty) return '';
    return meta.photos.last.thumbRef;
  }

  int _cellPhotoCount(int r, int c) => _cellMetaAt(r, c)?.photos.length ?? 0;

  String _gpsModeLabel(_GpsWriteMode mode) {
    switch (mode) {
      case _GpsWriteMode.pasteActive:
        return 'Pegar en celda activa';
      case _GpsWriteMode.pickTarget:
        return 'Elegir celda destino';
      case _GpsWriteMode.metadataOnly:
        return 'Solo metadata (no texto)';
    }
  }

  String _gpsModeDesc(_GpsWriteMode mode) {
    switch (mode) {
      case _GpsWriteMode.pasteActive:
        return 'Inserta coordenadas en la celda seleccionada.';
      case _GpsWriteMode.pickTarget:
        return 'Luego de capturar GPS, elegis la celda destino.';
      case _GpsWriteMode.metadataOnly:
        return 'Guarda GPS en metadata sin tocar el texto.';
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

  Future<void> _requestGpsForCell(int r, int c,
      {bool forceWriteText = false}) async {
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
      _showActionSnack('GPS no disponible en este navegador.',
          isError: true, icon: Icons.gps_off_rounded);
      return;
    }

    final outcome = await _getGpsFixWithFallback(
      timeout: const Duration(seconds: 12),
    );
    if (!mounted) return;
    if (!outcome.ok || outcome.fix == null) {
      _showGpsError(outcome);
      return;
    }

    final fix = outcome.fix!;
    if (!forceWriteText && _gpsWriteMode == _GpsWriteMode.pickTarget) {
      setState(() {
        _gpsPickingTarget = true;
        _pendingGpsFix = fix;
      });
      _engineStatus = 'Toca la celda destino para pegar GPS.';
      _engineStatusIsError = false;
      _showSnack('Toca la celda destino para pegar GPS.', isError: false);
      return;
    }

    final shouldWrite =
        forceWriteText || _gpsWriteMode != _GpsWriteMode.metadataOnly;
    _applyGpsFixToCell(r, c, fix, writeText: shouldWrite);
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

  Future<void> _pasteGpsIntoCell(int r, int c) async {
    await _requestGpsForCell(r, c, forceWriteText: true);
  }

  Future<_GpsOutcome> _getGpsFixWithFallback(
      {Duration timeout = const Duration(seconds: 10)}) async {
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
    return '${formatLatLng(fix.lat, fix.lng)} (+/-${fix.accuracyM.toStringAsFixed(0)}m)';
  }

  void _applyGpsFixToCell(int r, int c, _GpsFix fix,
      {required bool writeText, bool announce = true}) {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length - 1) return;

    _setCellGpsMeta(r, c, fix, markDirty: !writeText);
    if (writeText) {
      _setCell(r, c, _gpsTextForFix(fix));
    }
    _refreshCellAfterSave(r, c);

    if (announce) {
      _announceGpsSaved(
        fix,
        cell: CellKey(r, c),
        wroteText: writeText,
      );
    }
  }

  @visibleForTesting
  void debugApplyGpsFixToCell(
    int r,
    int c, {
    double lat = -38.95,
    double lng = -68.06,
    double accuracyM = 12,
    DateTime? timestamp,
    String source = 'test',
    String provider = 'test',
    bool writeText = true,
  }) {
    assert(() {
      final fix = _GpsFix(
        lat: lat,
        lng: lng,
        accuracyM: accuracyM,
        ts: timestamp ?? DateTime.now(),
        source: source,
        provider: provider,
      );
      _applyGpsFixToCell(r, c, fix, writeText: writeText, announce: false);
      return true;
    }());
  }

  @visibleForTesting
  String debugCellText(int r, int c) => _getCellText(r, c);

  @visibleForTesting
  bool debugCellHasGps(int r, int c) => _cellHasGps(r, c);

  @visibleForTesting
  CellMeta? debugCellMetaAt(int r, int c) => _cellMetaAt(r, c);

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
  void debugSetSkipAttachmentGps(bool skip) {
    assert(() {
      _debugSkipAttachmentGps = skip;
      return true;
    }());
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
        _compressThumb(bytes, maxW: 560, maxH: 560, quality: 78);
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

  void _setCellGpsMeta(int r, int c, _GpsFix fix, {required bool markDirty}) {
    final ref = _cellRefAt(r, c);
    if (ref == null) return;
    final current = _cellMeta[ref.key];
    final gps = GpsMeta(
      lat: fix.lat,
      lng: fix.lng,
      accuracyM: fix.accuracyM,
      timestamp: fix.ts,
      source: fix.source,
      provider: fix.provider,
    );
    final next = CellMeta(
      gps: gps,
      photos: current?.photos ?? const <PhotoAttachment>[],
      audios: current?.audios ?? const <AudioAttachment>[],
    );
    _setCellMetaEntry(r, c, next, markDirty: markDirty);
  }

  void _setCellMetaEntry(int r, int c, CellMeta meta,
      {required bool markDirty}) {
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

  void _announceGpsSaved(_GpsFix fix,
      {required CellKey cell, required bool wroteText}) {
    final cellLabel = _cellLabelRc(cell.row, cell.col);
    final detail =
        '${formatLatLng(fix.lat, fix.lng)} +/-${fix.accuracyM.toStringAsFixed(0)}m';
    final msg =
        'Guardado en celda $cellLabel (GPS $detail${wroteText ? '' : ', solo metadata'})';
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

  void _showGpsError(_GpsOutcome outcome) {
    final raw = (outcome.error ?? '').trim();
    final lower = raw.toLowerCase();
    String userMsg;
    if (lower.contains('https')) {
      userMsg = 'GPS requiere HTTPS o localhost.';
    } else if (lower.contains('deneg')) {
      userMsg = 'Permiso de ubicacion denegado. Habilitalo en Ajustes.';
    } else if (lower.contains('timeout')) {
      userMsg = 'Timeout obteniendo GPS.';
    } else if (lower.contains('no disponible') ||
        lower.contains('unavailable')) {
      userMsg = 'Ubicacion no disponible.';
    } else {
      userMsg = 'No se pudo obtener GPS. Revisa permisos y conexion.';
    }

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
      _showActionSnack(userMsg, isError: true, icon: Icons.gps_off_rounded);
    }
  }

  Future<void> _openMapsForCell(int r, int c) async {
    final meta = _cellMetaAt(r, c)?.gps;
    final txt = _getCellText(r, c);
    double? lat;
    double? lng;
    if (meta != null) {
      lat = meta.lat;
      lng = meta.lng;
    } else if (txt.trim().isNotEmpty) {
      final m =
          RegExp(r'(-?\d+(?:\.\d+)?)[,\s]+(-?\d+(?:\.\d+)?)').firstMatch(txt);
      if (m == null) return;
      lat = double.tryParse(m.group(1) ?? '');
      lng = double.tryParse(m.group(2) ?? '');
    }
    if (lat == null || lng == null) return;

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
                        style: const TextStyle(color: Colors.redAccent),
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
                    try {
                      final outcome =
                          await PhotoAcquireService.I.captureFromCamera(
                        context: context,
                      );
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop(
                        (outcome: outcome, fromCamera: true),
                      );
                    } catch (e, st) {
                      DiagnosticsLog.I.updatePhotoAttempt(
                        stage: 'picker_error',
                        error: e.toString(),
                        stack: st.toString(),
                      );
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop(
                        (
                          outcome: PhotoAcquireOutcome.error(e.toString()),
                          fromCamera: true
                        ),
                      );
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
                      Navigator.of(ctx).pop(
                        (outcome: outcome, fromCamera: false),
                      );
                    } catch (e, st) {
                      DiagnosticsLog.I.updatePhotoAttempt(
                        stage: 'picker_error',
                        error: e.toString(),
                        stack: st.toString(),
                      );
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop(
                        (
                          outcome: PhotoAcquireOutcome.error(e.toString()),
                          fromCamera: false
                        ),
                      );
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

  Future<void> _exportXlsxOnly({
    bool includeAttachments = true,
    bool share = false,
  }) async {
    _beginLongOperation(
      message: AppStrings.progressPreparingExport,
      cancellable: true,
    );
    try {
      _throwIfLongOperationCancelled();
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

      final fileName = _buildCommercialExportFileName('xlsx');

      _setLongOperationMessage(AppStrings.progressWritingFile);
      await _saveExportBytes(
        name: fileName,
        mime:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        bytes: xlsxBytes,
        share: share,
        shouldCancel: _isLongOperationCancelled,
      );
      _throwIfLongOperationCancelled();
      AppHaptics.success();
    } on _EditorLongOperationCancelled {
      _showActionSnack(
        AppStrings.infoExportCancelled,
        isError: false,
        icon: Icons.info_outline_rounded,
      );
    } catch (e, st) {
      _reportFlowError(
        e,
        flow: AppErrorFlow.exportData,
        operation: share ? 'share_xlsx' : 'export_xlsx',
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
    _beginLongOperation(
      message: AppStrings.progressPreparingExport,
      cancellable: true,
    );
    try {
      _throwIfLongOperationCancelled();
      _setLongOperationMessage(AppStrings.progressGeneratingFile);

      final pdfBytes = await _buildPdfBytesForExport(
        includeAttachments: includeAttachments,
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

      final fileName = _buildCommercialExportFileName('pdf');

      _setLongOperationMessage(AppStrings.progressWritingFile);
      await _saveExportBytes(
        name: fileName,
        mime: 'application/pdf',
        bytes: pdfBytes,
        share: share,
        shouldCancel: _isLongOperationCancelled,
      );
      _throwIfLongOperationCancelled();
      AppHaptics.success();
    } on _EditorLongOperationCancelled {
      _showActionSnack(
        AppStrings.infoExportCancelled,
        isError: false,
        icon: Icons.info_outline_rounded,
      );
    } catch (e, st) {
      _reportFlowError(
        e,
        flow: AppErrorFlow.exportData,
        operation: share ? 'share_pdf' : 'export_pdf',
        stackTrace: st,
        icon: Icons.picture_as_pdf_outlined,
      );
    } finally {
      _clearLongOperation();
    }
  }

  Future<void> _exportZipBundle({required bool share}) async {
    _beginLongOperation(
      message: AppStrings.progressPreparingExport,
      cancellable: true,
    );
    try {
      _throwIfLongOperationCancelled();
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

      _setLongOperationMessage(AppStrings.progressPackagingAssets);
      final zipBytes = await _buildAttachmentsZip(
        xlsxBytes: xlsxBytes,
        photoItems: prep.photoItems,
        audioItems: prep.audioItems,
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

      final now = DateTime.now();
      final baseName =
          'BitFlow-package_${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}';

      _setLongOperationMessage(AppStrings.progressWritingFile);
      await _saveExportBytes(
        name: '$baseName.bitflow.zip',
        mime: 'application/zip',
        bytes: zipBytes,
        share: share,
        shouldCancel: _isLongOperationCancelled,
      );
      _throwIfLongOperationCancelled();
      AppHaptics.success();
    } on _EditorLongOperationCancelled {
      _showActionSnack(
        AppStrings.infoExportCancelled,
        isError: false,
        icon: Icons.info_outline_rounded,
      );
    } catch (e, st) {
      _reportFlowError(
        e,
        flow: AppErrorFlow.exportData,
        operation: share ? 'share_zip' : 'export_zip',
        stackTrace: st,
        icon: Icons.folder_zip_rounded,
      );
    } finally {
      _clearLongOperation();
    }
  }

  Future<void> _exportBackupZip() async {
    _beginLongOperation(
      message: AppStrings.progressPreparingExport,
      cancellable: true,
    );
    try {
      _throwIfLongOperationCancelled();
      final bundle =
          await _prepareBackupBundle(shouldCancel: _isLongOperationCancelled);
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
      _showActionSnack('Backup ZIP listo.',
          isError: false, icon: Icons.backup_rounded);
    } on _EditorLongOperationCancelled {
      _showActionSnack(
        AppStrings.infoExportCancelled,
        isError: false,
        icon: Icons.info_outline_rounded,
      );
    } catch (e, st) {
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
    _beginLongOperation(
      message: AppStrings.progressPreparingExport,
      cancellable: true,
    );
    try {
      _throwIfLongOperationCancelled();
      _setLongOperationMessage(AppStrings.progressGeneratingFile);
      final bytes =
          await _buildHtmlReport(shouldCancel: _isLongOperationCancelled);
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
      _showActionSnack('Reporte HTML listo.',
          isError: false, icon: Icons.description_rounded);
    } on _EditorLongOperationCancelled {
      _showActionSnack(
        AppStrings.infoExportCancelled,
        isError: false,
        icon: Icons.info_outline_rounded,
      );
    } catch (e, st) {
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

      return _BackupBundle(
        json: backupJson,
        assets: assets,
      );
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
      final backupBytes =
          Uint8List.fromList(utf8.encode(jsonEncode(bundle.json)));
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

  Future<Uint8List?> _buildHtmlReport({
    bool Function()? shouldCancel,
  }) async {
    try {
      _throwIfOperationCancelledBy(shouldCancel);
      final html = StringBuffer();
      final esc = const HtmlEscape(HtmlEscapeMode.element);
      final now = DateTime.now();
      final title = _sheetName.trim().isEmpty ? 'Bitacora' : _sheetName.trim();

      html.write('<!doctype html><html><head><meta charset=\"utf-8\">');
      html.write(
          '<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">');
      html.write('<title>${esc.convert(title)} - Reporte</title>');
      html.write('<style>');
      html.write(
          'body{font-family:Arial,Helvetica,sans-serif;margin:32px;color:#111;}');
      html.write(
          '.header{display:flex;justify-content:space-between;align-items:flex-end;margin-bottom:20px;}');
      html.write('.brand{font-weight:700;font-size:20px;}');
      html.write('.muted{color:#666;font-size:12px;}');
      html.write('.actions{margin:12px 0 20px 0;}');
      html.write(
          'button{padding:8px 12px;border:1px solid #111;background:#fff;cursor:pointer;}');
      html.write('table{width:100%;border-collapse:collapse;font-size:12px;}');
      html.write(
          'th,td{border:1px solid #ddd;padding:8px;vertical-align:top;}');
      html.write('th{background:#f5f5f5;text-align:left;}');
      html.write(
          '.evidences{margin-top:6px;display:flex;gap:8px;flex-wrap:wrap;}');
      html.write('.evidence{width:110px;}');
      html.write(
          '.evidence img{width:100%;height:auto;border-radius:6px;border:1px solid #ddd;}');
      html.write(
          '.evidence .cap{font-size:10px;color:#555;margin-top:4px;line-height:1.2;}');
      html.write('@media print{button{display:none;} body{margin:8px;}}');
      html.write('</style></head><body>');
      html.write('<div class=\"header\">');
      html.write('<div class=\"brand\">${esc.convert(title)}</div>');
      html.write(
          '<div class=\"muted\">Generado: ${_formatDateTimeShort(now)}</div>');
      html.write('</div>');
      html.write(
          '<div class=\"actions\"><button onclick=\"window.print()\">Imprimir / Guardar PDF</button></div>');
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
            html.write('<div class=\"evidences\">');
            for (final photo in photos) {
              _throwIfOperationCancelledBy(shouldCancel);
              final dataUri = await _photoThumbDataUri(photo);
              if (dataUri.isEmpty) continue;
              html.write('<div class=\"evidence\">');
              html.write('<img src=\"$dataUri\" alt=\"evidencia\">');
              final caption = photo.caption.trim().isNotEmpty
                  ? photo.caption.trim()
                  : photo.filename.trim();
              final dateLabel = _formatDateTimeShort(photo.addedAt);
              html.write(
                  '<div class=\"cap\">${esc.convert(caption)}<br>${esc.convert(dateLabel)}</div>');
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
    bool Function()? shouldCancel,
  }) async {
    _throwIfOperationCancelledBy(shouldCancel);
    final dataCols = math.max(0, _headers.length - 1); // sin Photos
    final columns = List<String>.generate(dataCols, (i) => _headerLabel(i));
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
      sheetName: _sheetName,
      includeIndexColumn: false,
      includeCoverSheet: true,
      includeSummarySheet: true,
    );
  }

  Future<Uint8List?> _buildPdfBytesForExport({
    required bool includeAttachments,
    bool Function()? shouldCancel,
  }) async {
    _throwIfOperationCancelledBy(shouldCancel);
    final dataCols = math.max(0, _headers.length - 1);
    final headers = List<String>.generate(dataCols, (i) => _headerLabel(i));
    final rows = <List<String>>[];
    for (final row in _rows) {
      _throwIfOperationCancelledBy(shouldCancel);
      final values = <String>[];
      for (int c = 0; c < dataCols && c < row.cells.length; c++) {
        values.add(row.cells[c]);
      }
      rows.add(values);
    }

    final doc = pw.Document();
    final appVersion = await _readAppVersionForExport();
    final buildId = BuildInfo.buildIdLabel;
    final now = DateTime.now().toLocal();
    final exportedAt =
        '${now.year}-${_two(now.month)}-${_two(now.day)} ${_two(now.hour)}:${_two(now.minute)}';

    final attachmentRows = <List<String>>[];
    final evidenceItems = <({
      String cell,
      String kind,
      String caption,
      String date,
      String? mapUrl,
      Uint8List? thumb,
    })>[];
    var photoCount = 0;
    var audioCount = 0;
    var gpsCount = 0;

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
            '${gps.lat.toStringAsFixed(6)}, ${gps.lng.toStringAsFixed(6)}',
            _formatDateTimeShort(gps.timestamp.toLocal()),
          ]);
          evidenceItems.add((
            cell: cellLabel,
            kind: 'GPS',
            caption:
                'Prec: ${gps.accuracyM.toStringAsFixed(1)}m${gps.source.trim().isNotEmpty ? ' · ${gps.source}' : ''}',
            date: _formatDateTimeShort(gps.timestamp.toLocal()),
            mapUrl: mapUrl,
            thumb: null,
          ));
        }

        for (final photo in meta.photos) {
          _throwIfOperationCancelledBy(shouldCancel);
          photoCount++;
          final caption = photo.caption.trim().isNotEmpty
              ? photo.caption.trim()
              : photo.filename.trim();
          final mapUrl = (photo.lat != null && photo.lon != null)
              ? 'https://www.google.com/maps/search/?api=1&query=${photo.lat},${photo.lon}'
              : null;
          final dateText = _formatDateTimeShort(photo.addedAt.toLocal());
          attachmentRows.add(<String>[
            cellLabel,
            'Foto',
            caption.isEmpty ? photo.filename : caption,
            dateText,
          ]);

          Uint8List? thumb;
          final bytes =
              await _loadPhotoBytesFromAttachment(photo, preferThumb: true);
          if (bytes != null && bytes.isNotEmpty) {
            thumb = _compressThumb(bytes, maxW: 360, maxH: 240, quality: 70) ??
                bytes;
          }
          evidenceItems.add((
            cell: cellLabel,
            kind: 'Foto',
            caption: caption.isEmpty ? photo.filename : caption,
            date: dateText,
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
            mapUrl: null,
            thumb: null,
          ));
        }
      }
    }

    final totalAttachments = photoCount + audioCount;
    final evidencePreview = evidenceItems.take(24).toList(growable: false);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
        ),
        build: (context) {
          pw.Widget metricChip(String label, String value) {
            return pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                  pw.Text(
                    value,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            );
          }

          final content = <pw.Widget>[
            pw.Text(
              'BitFlow Reporte - ${_sheetName.trim().isEmpty ? 'Planilla' : _sheetName.trim()}',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Exportado: $exportedAt',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Version: $appVersion · Build: $buildId',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                metricChip('Filas', '${_rows.length}'),
                metricChip('Celdas con dato', '${_countNonEmptyCells()}'),
                metricChip('Adjuntos', '$totalAttachments'),
                metricChip('Fotos', '$photoCount'),
                metricChip('Audios', '$audioCount'),
                metricChip('GPS', '$gpsCount'),
              ],
            ),
            pw.SizedBox(height: 12),
          ];

          if (headers.isNotEmpty) {
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
                  headers: const <String>[
                    'Celda',
                    'Tipo',
                    'Detalle',
                    'Fecha',
                  ],
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
                                '${item.kind} · ${item.cell}',
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
              audioCount: 0,
              gpsCount: 0,
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
      final cell = resolveCellKey(entry.key);
      if (cell == null) continue;
      final meta = entry.value;
      if (meta.isEmpty) continue;
      final cellRef = cell.a1;
      final cellManifest = <String, dynamic>{};

      if (meta.gps != null) {
        final gps = meta.gps!;
        attachments.add(
          AttachmentRow(
            cellRef: cellRef,
            type: 'gps',
            fileName: '',
            notes: _gpsNotes(gps),
            relativePath: '',
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
          final fileName = _exportPhotoFileName(cellRef, photo, index: i + 1);
          final lowerMime = photo.mime.toLowerCase();
          final itemType = lowerMime.startsWith('video/')
              ? 'video'
              : (lowerMime.startsWith('image/') ? 'photo' : 'file');
          final folder = itemType == 'photo'
              ? 'photos'
              : (itemType == 'video' ? 'video' : 'files');
          final relPath = 'attachments/$folder/$fileName';

          attachments.add(
            AttachmentRow(
              cellRef: cellRef,
              type: itemType,
              fileName: fileName,
              notes: _photoNotes(photo),
              relativePath: relPath,
            ),
          );

          if (i == 0 && cell.col >= 0 && cell.col < dataCols) {
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
            photoItems.add(_ZipPhotoItem(
              cell: cell,
              photo: photo,
              fileName: fileName,
              pathInZip: relPath,
            ));
            final photoManifest = <String, dynamic>{
              'id': photo.id,
              'kind': itemType,
              'cellKey': cellRef,
              'type': itemType,
              'fileName': fileName,
              if (photo.caption.trim().isNotEmpty)
                'caption': photo.caption.trim(),
              'mime': photo.mime,
              'size': photo.size,
              'path': relPath,
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
          final relPath = 'attachments/audio/$fileName';

          attachments.add(
            AttachmentRow(
              cellRef: cellRef,
              type: 'audio',
              fileName: fileName,
              notes: _audioNotes(audio),
              relativePath: relPath,
            ),
          );

          if (includeZip) {
            audioItems.add(_ZipAudioItem(
              cell: cell,
              audio: audio,
              fileName: fileName,
              pathInZip: relPath,
            ));
            final audioManifest = <String, dynamic>{
              'id': audio.id,
              'kind': 'audio',
              'cellKey': cellRef,
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

    final gpsCount = attachments.where((item) => item.type == 'gps').length;
    final manifest = includeZip
        ? await _buildPackageManifest(
            exportedAtUtc: exportedAtUtc,
            manifestCells: manifestCells,
            manifestAssets: manifestAssets,
            photoCount: photoItems.length,
            audioCount: audioItems.length,
            gpsCount: gpsCount,
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
    required List<_ZipPhotoItem> photoItems,
    required List<_ZipAudioItem> audioItems,
    required Map<String, dynamic> manifest,
    required Map<String, dynamic> packageSheetJson,
    bool Function()? shouldCancel,
  }) async {
    _throwIfOperationCancelledBy(shouldCancel);
    final archive = Archive();
    archive.addFile(ArchiveFile('export.xlsx', xlsxBytes.length, xlsxBytes));

    for (final item in photoItems) {
      _throwIfOperationCancelledBy(shouldCancel);
      final bytes = await _loadPhotoBytesFromAttachment(item.photo);
      if (bytes == null || bytes.isEmpty) continue;
      archive.addFile(
        ArchiveFile(item.pathInZip, bytes.length, bytes),
      );
    }

    for (final item in audioItems) {
      _throwIfOperationCancelledBy(shouldCancel);
      final bytes = await _loadAudioBytesFromAttachment(item.audio);
      if (bytes == null || bytes.isEmpty) continue;
      archive.addFile(
        ArchiveFile(item.pathInZip, bytes.length, bytes),
      );
    }

    final manifestBytes = Uint8List.fromList(utf8.encode(jsonEncode(manifest)));
    archive.addFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    final sheetJsonBytes =
        Uint8List.fromList(utf8.encode(jsonEncode(packageSheetJson)));
    archive.addFile(
      ArchiveFile('sheet.json', sheetJsonBytes.length, sheetJsonBytes),
    );

    final encoder = ZipEncoder();
    final zipData = encoder.encode(archive);
    return Uint8List.fromList(zipData);
  }

  Future<Map<String, dynamic>> _buildPackageManifest({
    required DateTime exportedAtUtc,
    required Map<String, Map<String, dynamic>> manifestCells,
    required List<Map<String, dynamic>> manifestAssets,
    required int photoCount,
    required int audioCount,
    required int gpsCount,
  }) async {
    final appVersion = await _readAppVersionForExport();
    final nonEmptyCells = _countNonEmptyCells();
    final totalAttachments = photoCount + audioCount;

    return <String, dynamic>{
      'format': 'bitflow_package_v1',
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
      'counts': {
        'rows': _rows.length,
        'cells': nonEmptyCells,
        'attachments': totalAttachments,
        'photos': photoCount,
        'audios': audioCount,
        'gps': gpsCount,
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
    };
    return json;
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
    final content = file.content;
    if (content is Uint8List) return content;
    if (content is List<int>) return Uint8List.fromList(content);
    return Uint8List(0);
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
      final rows = ((sheetRaw as Map)['rows'] as List?)?.length ?? 0;
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
        ),
      );
    }

    final sheetRawDecoded =
        jsonDecode(utf8.decode(_archiveFileBytes(sheetFile!)));
    if (sheetRawDecoded is! Map) {
      throw const FormatException('sheet.json invalido.');
    }
    final sheetRaw = Map<String, dynamic>.from(sheetRawDecoded);

    Map<String, dynamic> manifest = const <String, dynamic>{};
    if (manifestFile != null) {
      final manifestRaw =
          jsonDecode(utf8.decode(_archiveFileBytes(manifestFile)));
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
        exportedAt:
            DateTime.tryParse((manifest['exportedAt'] ?? '').toString()),
        appVersion: (manifest['appVersion'] ?? '').toString(),
        buildId: (manifest['buildId'] ?? '').toString(),
      ),
    );
  }

  Future<void> _importPackageBundle(
    _PackageImportBundle bundle, {
    required bool replaceCurrent,
  }) async {
    _beginLongOperation(
      message: AppStrings.progressImportingBackup,
      cancellable: true,
    );
    try {
      _throwIfLongOperationCancelled();
      final normalized = SheetStore.normalizeModel(bundle.sheetRaw);
      final targetSheetId = replaceCurrent
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
      if (replaceCurrent) {
        await _clearOfflineQueueForCurrentSheet();
        final loaded = _SheetModel.fromJson(imported.model);
        if (mounted) {
          _applyLoadedModel(loaded);
          await _saveLocalNow();
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
        operation: replaceCurrent
            ? 'import_package_replace_current'
            : 'import_package_create_new',
        stackTrace: st,
        fallbackMessage: 'No se pudo importar el paquete.',
        icon: Icons.file_open_rounded,
      );
    } finally {
      _clearLongOperation();
    }
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

  Map<String, dynamic> _buildPortableSheetJson({
    required Map<String, Map<String, dynamic>> manifestCells,
  }) {
    final rows = <Map<String, dynamic>>[];
    for (int r = 0; r < _rows.length; r++) {
      final row = _rows[r];
      final cells = <String, String>{};
      for (int c = 0; c < _headers.length; c++) {
        final value = c < row.cells.length ? row.cells[c] : '';
        if (value.trim().isEmpty) continue;
        cells[CellKey(r, c).a1] = value;
      }
      rows.add(<String, dynamic>{
        'row': r + 1,
        'id': row.id,
        'cells': cells,
      });
    }

    return <String, dynamic>{
      'schema_version': 1,
      'sheet_id': widget.sheetId,
      'sheet_name': _sheetName,
      'exported_at_utc': DateTime.now().toUtc().toIso8601String(),
      'headers': List<String>.from(_headers, growable: false),
      'rows': rows,
      'attachments_manifest': manifestCells,
    };
  }

  String _portableViewerHtml() {
    return '''
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>BitFlow Viewer</title>
  <style>
    :root {
      --bg: #f5f6f8;
      --panel: #ffffffcc;
      --ink: #0b0d12;
      --muted: #5f6673;
      --line: #d8dde6;
    }
    body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: var(--ink); background: linear-gradient(180deg,#f7f8fa 0%,#edf0f5 100%); }
    .wrap { max-width: 1200px; margin: 0 auto; padding: 16px; }
    .card { backdrop-filter: blur(8px); background: var(--panel); border: 1px solid #ffffff88; border-radius: 16px; box-shadow: 0 8px 30px #0f172a14; padding: 14px; }
    h1 { margin: 0 0 6px; font-size: 20px; }
    .meta { color: var(--muted); font-size: 12px; margin-bottom: 12px; }
    table { border-collapse: collapse; width: 100%; background: #fff; border-radius: 12px; overflow: hidden; }
    th, td { border: 1px solid var(--line); padding: 8px; font-size: 12px; vertical-align: top; }
    th { background: #f4f6fa; position: sticky; top: 0; z-index: 1; text-align: left; }
    .hint { color: var(--muted); font-size: 12px; margin-top: 10px; }
    #attachments { margin-top: 14px; display: grid; grid-template-columns: repeat(auto-fill,minmax(210px,1fr)); gap: 10px; }
    .att { border: 1px solid var(--line); border-radius: 10px; background: #fff; padding: 10px; }
    .att a { color: #0b57d0; text-decoration: none; word-break: break-word; }
    .cell-title { font-weight: 700; margin-bottom: 8px; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <h1 id="title">BitFlow Viewer</h1>
      <div class="meta" id="meta"></div>
      <div style="overflow:auto; max-height: 65vh;">
        <table id="grid"></table>
      </div>
      <div class="hint">Toca una celda para ver adjuntos.</div>
      <div id="attachments"></div>
    </div>
  </div>
  <script src="./app.js"></script>
</body>
</html>
''';
  }

  String _portableViewerJs() {
    return '''
(async function () {
  const byId = (id) => document.getElementById(id);
  const title = byId('title');
  const meta = byId('meta');
  const grid = byId('grid');
  const attachments = byId('attachments');

  let payload;
  try {
    const res = await fetch('../sheet.json');
    payload = await res.json();
  } catch (err) {
    title.textContent = 'BitFlow Viewer (error)';
    meta.textContent = 'No se pudo leer sheet.json';
    return;
  }

  const headers = Array.isArray(payload.headers) ? payload.headers : [];
  const rows = Array.isArray(payload.rows) ? payload.rows : [];
  const manifest = payload.attachments_manifest || {};

  title.textContent = payload.sheet_name || 'BitFlow Viewer';
  meta.textContent = 'Exportado: ' + (payload.exported_at_utc || 'n/a');

  const thead = document.createElement('thead');
  const trh = document.createElement('tr');
  headers.forEach((h) => {
    const th = document.createElement('th');
    th.textContent = h;
    trh.appendChild(th);
  });
  thead.appendChild(trh);
  grid.appendChild(thead);

  const tbody = document.createElement('tbody');
  rows.forEach((rowObj, rIdx) => {
    const tr = document.createElement('tr');
    const cells = rowObj.cells || {};
    headers.forEach((_, cIdx) => {
      const a1 = colLetters(cIdx) + String(rIdx + 1);
      const td = document.createElement('td');
      td.textContent = cells[a1] || '';
      td.style.cursor = 'pointer';
      td.addEventListener('click', () => showAttachments(a1));
      tr.appendChild(td);
    });
    tbody.appendChild(tr);
  });
  grid.appendChild(tbody);

  function showAttachments(cellRef) {
    attachments.innerHTML = '';
    const block = manifest[cellRef];
    const title = document.createElement('div');
    title.className = 'cell-title';
    title.textContent = 'Adjuntos de ' + cellRef;
    attachments.appendChild(title);
    if (!block) {
      const empty = document.createElement('div');
      empty.textContent = 'Sin adjuntos en esta celda.';
      attachments.appendChild(empty);
      return;
    }
    const list = [];
    if (Array.isArray(block.photos)) list.push(...block.photos.map((x) => ({...x, type: (x.type || 'photo')})));
    if (Array.isArray(block.audios)) list.push(...block.audios.map((x) => ({...x, type: 'audio'})));
    if (!list.length) {
      const empty = document.createElement('div');
      empty.textContent = 'Sin adjuntos en esta celda.';
      attachments.appendChild(empty);
      return;
    }
    list.forEach((item) => {
      const card = document.createElement('div');
      card.className = 'att';
      const kind = document.createElement('div');
      kind.textContent = item.type || 'file';
      kind.style.fontWeight = '700';
      kind.style.marginBottom = '4px';
      const name = document.createElement('div');
      name.textContent = item.fileName || 'archivo';
      const link = document.createElement('a');
      link.href = '../' + (item.path || '');
      link.textContent = 'Abrir';
      link.target = '_blank';
      link.rel = 'noopener';
      card.appendChild(kind);
      card.appendChild(name);
      card.appendChild(link);
      attachments.appendChild(card);
    });
  }

  function colLetters(idx) {
    let n = idx + 1;
    let out = '';
    while (n > 0) {
      const rem = (n - 1) % 26;
      out = String.fromCharCode(65 + rem) + out;
      n = Math.floor((n - 1) / 26);
    }
    return out || 'A';
  }
})();
''';
  }

  String _portableViewerReadme() {
    return '''
BitFlow portable viewer
=======================
1) Descomprime el ZIP completo.
2) Abre "viewer/index.html" en un navegador moderno.
3) Si el navegador bloquea lectura local, levanta un servidor estatico simple.

Este paquete incluye:
- sheet.json
- attachments/
- viewer/index.html + viewer/app.js
''';
  }

  String _exportPhotoFileName(
    String cellRef,
    PhotoAttachment photo, {
    required int index,
  }) {
    final base = _safeFile(photo.filename.isNotEmpty ? photo.filename : 'foto');
    final ext = _extForName(base, photo.mime, fallback: '.jpg');
    final stem = _stripExt(base);
    return '${cellRef}_p${index}_$stem$ext';
  }

  String _exportAudioFileName(
    String cellRef,
    AudioAttachment audio, {
    required int index,
  }) {
    final base =
        _safeFile(audio.filename.isNotEmpty ? audio.filename : 'audio');
    final ext = _extForName(base, audio.mime, fallback: '.m4a');
    final stem = _stripExt(base);
    return '${cellRef}_a${index}_$stem$ext';
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
    final base =
        _safeFile(audio.filename.isNotEmpty ? audio.filename : 'audio');
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
    return 'lat=${gps.lat.toStringAsFixed(6)}; '
        'lon=${gps.lng.toStringAsFixed(6)}; '
        'acc=${gps.accuracyM.toStringAsFixed(0)}m; '
        'ts=${gps.timestamp.toIso8601String()}; '
        'source=${gps.source}; '
        'provider=${gps.provider}';
  }

  String _photoNotes(PhotoAttachment photo) {
    final parts = <String>[
      'addedAt=${photo.addedAt.toIso8601String()}',
      'size=${_formatBytes(photo.size)}',
    ];
    if (photo.lat != null && photo.lon != null) {
      parts.add(
          'lat=${photo.lat!.toStringAsFixed(6)} lon=${photo.lon!.toStringAsFixed(6)}');
    }
    if (photo.accuracyM != null) {
      parts.add('acc=${photo.accuracyM!.toStringAsFixed(0)}m');
    }
    return parts.join('; ');
  }

  String _audioNotes(AudioAttachment audio) {
    return 'addedAt=${audio.addedAt.toIso8601String()}; '
        'duration=${_formatDuration(Duration(milliseconds: audio.durationMs))}; '
        'size=${_formatBytes(audio.size)}';
  }

  Future<Uint8List?> _loadAudioBytesFromAttachment(
      AudioAttachment audio) async {
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

  Future<void> _saveExportBytes({
    required String name,
    required String mime,
    required Uint8List bytes,
    required bool share,
    bool Function()? shouldCancel,
  }) async {
    _throwIfOperationCancelledBy(shouldCancel);
    final xf = XFile.fromData(bytes, name: name, mimeType: mime);

    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (share) {
      if (kIsWeb) {
        final shared = await _tryShareWebFile(xf);
        if (shared) return;
        _throwIfOperationCancelledBy(shouldCancel);
        await xf.saveTo(name);
        if (!mounted) return;
        _showActionSnack(
          _isIosWeb
              ? 'Safari iOS limita compartir archivos. Se descargo el archivo.'
              : 'Web Share no soportado. Archivo descargado.',
          isError: false,
          icon: Icons.download_rounded,
        );
        return;
      }

      if (isMobile) {
        final shared = await _shareOnMobileWithFallbacks(
          name: name,
          mime: mime,
          bytes: bytes,
          shouldCancel: shouldCancel,
        );
        if (shared) return;
      }
    }

    if (kIsWeb) {
      try {
        _throwIfOperationCancelledBy(shouldCancel);
        await xf.saveTo(name);
        return;
      } catch (_) {}
    }

    if (isMobile) {
      try {
        _throwIfOperationCancelledBy(shouldCancel);
        await Share.shareXFiles([xf], subject: 'BitFlow Export');
        return;
      } catch (_) {}
    }

    final lower = name.toLowerCase();
    final extensions = lower.endsWith('.zip')
        ? const ['zip']
        : lower.endsWith('.pdf')
            ? const ['pdf']
            : (lower.endsWith('.html') || lower.endsWith('.htm'))
                ? const ['html', 'htm']
                : const ['xlsx'];
    final typeGroup = XTypeGroup(
      label: 'Export',
      extensions: extensions,
    );
    _throwIfOperationCancelledBy(shouldCancel);
    final loc = await getSaveLocation(
        suggestedName: name, acceptedTypeGroups: [typeGroup]);
    if (loc == null) return;
    _throwIfOperationCancelledBy(shouldCancel);
    await xf.saveTo(loc.path);
  }

  Future<bool> _tryShareWebFile(XFile file) async {
    try {
      await Share.shareXFiles([file], subject: 'BitFlow Export');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _shareOnMobileWithFallbacks({
    required String name,
    required String mime,
    required Uint8List bytes,
    bool Function()? shouldCancel,
  }) async {
    final path = await persistShareTempFile(fileName: name, bytes: bytes);

    if (path != null && path.trim().isNotEmpty) {
      try {
        _throwIfOperationCancelledBy(shouldCancel);
        await Share.shareXFiles(
          <XFile>[XFile(path, mimeType: mime, name: name)],
          subject: 'BitFlow Export',
        );
        return true;
      } catch (_) {}

      try {
        _throwIfOperationCancelledBy(shouldCancel);
        final email = Email(
          subject: 'BitFlow Export',
          body: 'Adjunto generado por BitFlow: $name',
          attachmentPaths: <String>[path],
          isHTML: false,
        );
        await FlutterEmailSender.send(email);
        return true;
      } catch (_) {}

      try {
        _throwIfOperationCancelledBy(shouldCancel);
        final mailto = Uri(
          scheme: 'mailto',
          queryParameters: <String, String>{
            'subject': 'BitFlow Export',
            'body':
                'Adjunto generado por BitFlow: $name\n\nSi tu cliente no adjunta automaticamente, usa:\n$path',
          },
        );
        if (await canLaunchUrl(mailto)) {
          await launchUrl(mailto, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (_) {}
    }

    try {
      _throwIfOperationCancelledBy(shouldCancel);
      await Share.shareXFiles(
        <XFile>[XFile.fromData(bytes, name: name, mimeType: mime)],
        subject: 'BitFlow Export',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatDateTimeShort(DateTime dt) {
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
        '${_two(dt.hour)}:${_two(dt.minute)}';
  }

  String _safeFile(String s) {
    final t = s.trim().isEmpty ? 'Sheet' : s.trim();
    return t.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  String _buildCommercialExportFileName(String extension) {
    final now = DateTime.now().toLocal();
    final safeSheet =
        _safeFile(_sheetName).replaceAll(RegExp(r'\s+'), '_').trim();
    final normalizedExt = extension.trim().toLowerCase().replaceAll('.', '');
    return 'BitFlow_${now.year}-${_two(now.month)}-${_two(now.day)}_$safeSheet.$normalizedExt';
  }
// ------------------------------ Engine compute (opcional) ----------------

  Future<void> _initEngineConnection() async {
    await _ensureEngineReady(showErrors: true);
  }

  Future<bool> _ensureEngineReady({required bool showErrors}) async {
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
          _engineLastOk = false;
          _engineLastError = 'URL invalida o vacia';
          _engineLastCheckAt = DateTime.now();
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
        _engineStatus = showErrors ? 'Engine OK' : null;
        _engineStatusIsError = false;
        _engineLastOk = true;
        _engineLastError = null;
        _engineLastCheckAt = DateTime.now();
      });
      if (showErrors) {
        _showSnack('Engine listo', isError: false);
      }
      return true;
    } catch (e) {
      final details = _engineErrorDetails(e);
      if (kDebugMode) {
        debugPrint('[engine] health fail: $details');
      }
      if (mounted) {
        setState(() {
          _engineStatus = showErrors ? _engineErrorMessage(e) : null;
          _engineStatusIsError = showErrors;
          _engineLastOk = false;
          _engineLastError = _engineErrorMessage(e);
          _engineLastCheckAt = DateTime.now();
        });
        if (showErrors) {
          _showSnack(_engineStatus ?? 'Engine no disponible', isError: true);
        }
      }
      return false;
    }
  }

  Future<_EngineConfig> _resolveEngineConfig() async {
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

  Future<bool> _checkEngineHealth(String baseUrl) async {
    final normalized = EngineConfig.normalize(baseUrl);
    if (!EngineConfig.isValidBaseUrl(normalized)) return false;

    final candidates = <String>[
      '/openapi.json',
      '/healthz',
      '/readyz',
      '/health',
      '/',
    ];

    for (final path in candidates) {
      try {
        await _engineApi.getJsonFromBase(
          normalized,
          path,
          timeout: const Duration(seconds: 10),
        );
        if (kDebugMode) {
          debugPrint('[engine] health ok: $normalized$path');
        }
        return true;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[engine] health fail: $normalized$path -> '
              '${_engineErrorDetails(e)}');
        }
      }
    }

    return false;
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
      _smokeStatus = 'Engine CHECK...';
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
        _warnStorageFallbackOnce('foto');
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
    _showActionSnack(msg,
        isError: !ok,
        icon: ok ? Icons.science_rounded : Icons.report_problem_rounded);
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
        errorDetails: _EngineErrorDetails(
          message: 'Engine no disponible.',
        ),
      );
    }

    final base = _engineBaseResolved;
    if (base == null || base.trim().isEmpty) {
      return const _EngineComputeOutcome(
        ok: false,
        hadUpdates: false,
        errorDetails: _EngineErrorDetails(
          message: 'Engine base URL vacia',
        ),
      );
    }

    setState(() {
      _engineBusy = true;
      _engineStatus = 'Computando...';
      _engineStatusIsError = false;
    });

    try {
      final effectiveHeaders =
          List<String>.generate(_headers.length, _effectiveHeader);
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
