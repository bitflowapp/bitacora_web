// lib/screens/editor_screen.dart
//
// BitFlow / Gridnote ??? EditorScreen
// Grilla editable ???tipo Notes???: 1 toque => parpadeo => editar.
// Mobile (incluye Web iOS/Android): editor inferior FIJO arriba del teclado (SIEMPRE montado -> iPhone estable).
// Desktop: edici??n in-cell con overlay anclado a la celda (no modal centrado).
//
// Requiere (pubspec):
//   shared_preferences
//   file_selector
//   image
//   geolocator
//   url_launcher
//   http
//   syncfusion_flutter_xlsio
//
// Nota: este archivo NO usa dart:io (compila en Web).
// ?? 2025
//
// FIXES aplicados (estabilidad + ???planilla en blanco??? + UX):
// - ??? Guardado robusto con REV + pending-save: evita ???se guard?? pero no guard????? y Dirty falso.
// - ??? Compute preserva fotos por ??ndice (no borra la metadata de Photos).
// - ??? Undo/Redo ahora incluye metadata de fotos sin duplicar thumbs (revierte count/filas sin lag).
// - ??? Noche (modo oscuro): glass m??s visible + mayor nitidez + selecci??n m??s Apple (menos ???azul gen??rico???).
//
import 'dart:async'
    hide unawaited; // ??? FIX: evita colisi??n con unawaited de dart:async
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, TileMode;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bitacora_web/models/cell_meta.dart';
import 'package:bitacora_web/services/export_xlsx_with_photos.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bitacora_web/services/photo_acquire_service.dart';
import 'package:bitacora_web/services/photo_mime_sniffer.dart';
import 'package:bitacora_web/services/keyboard_insets_controller.dart';
import 'package:bitacora_web/services/photo_storage_service.dart';
import 'package:bitacora_web/services/audio_service.dart';
import 'package:bitacora_web/services/audio_storage_service.dart';
import 'package:bitacora_web/services/photo_bytes_resolver.dart';
import 'package:bitacora_web/services/photo_json_codec.dart';
import 'package:bitacora_web/services/location_service.dart';
import 'package:bitacora_web/services/location_web_service.dart';
import 'package:bitacora_web/services/engine_api.dart';
import 'package:bitacora_web/services/engine_config.dart';
import 'package:bitacora_web/services/expression_eval.dart';
import 'package:bitacora_web/services/diagnostics_log.dart';
import 'package:bitacora_web/services/storage_diagnostics.dart';
import 'package:bitacora_web/services/web_capabilities.dart';
import 'package:bitacora_web/theme/app_theme.dart';
import 'package:bitacora_web/widgets/apple_ui.dart';
import 'package:bitacora_web/widgets/command_palette.dart';
import 'package:bitacora_web/widgets/web_blob_image.dart';
import 'package:bitacora_web/utils/location_format.dart';
import 'package:bitacora_web/utils/viewport_insets.dart' as vv;

part '../widgets/mobile_notes_grid.dart';

// ============================== Constantes globales ========================

const int kDefaultCols = 15; // 14 + Photos
const String kPhotosHeader = 'Photos';
const double _kMobileQuickBarH = 62.0;

// ??? Persistencia segura: NO guardar thumbs base64 en prefs/localStorage.
const bool _kPersistPhotoThumbs = true;
const String _kPrefEngineApiKey = 'bitflow.engine_api_key';
const String _kPrefEngineApiKeyAlt = 'bitflow_engine_api_key';

enum _OverlayMove { none, next, prev, down, up }

enum _GridDensity { compact, normal, roomy }

enum _PhotoSource { camera, gallery }

enum _MobileEditPhase { closed, opening, open, switching, closing }

enum _GpsWriteMode { pasteActive, pickTarget, metadataOnly }

class _CellTarget {
  const _CellTarget(this.row, this.col);
  final int row;
  final int col;
}

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
  static const Duration _saveDebounce = Duration(milliseconds: 500);
  static const String _kPhotoReadErrorMsg =
      'No se pudo leer la imagen (bytes vacíos).';
// ------------------------------ Estado ----------------------------------

  late String _sheetName;
  DateTime? _lastSavedAt;

  late List<String> _headers;
  late List<_RowModel> _rows;

  bool _isLight = true;
  bool _isDirty = false;

  int _selRow = 0;
  int _selCol = 0;

  final Map<String, CellMeta> _cellMeta = <String, CellMeta>{};
  _GpsWriteMode _gpsWriteMode = _GpsWriteMode.pasteActive;
  _GpsFix? _pendingGpsFix;
  bool _gpsPickingTarget = false;
  static const String _prefGpsMode = 'bitflow:gps_mode';
  static const String _prefGridDensity = 'bitflow:grid_density';

  _GridDensity _gridDensity = _GridDensity.normal;
  bool _gridDensityExplicit = false;
  bool _inAppModalShown = false;

// ??? Guardado robusto
  int _rev = 0;
  int _lastSavedRev = 0;
  bool _savePending = false;
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
  bool _saving = false;

// ??? Teclado m??vil: controlador robusto de insets
  late final KeyboardInsetsController _kbController =
      KeyboardInsetsController(onLog: kDebugMode ? debugPrint : null);
  late final PhotoStorageService _photoStore = PhotoStorageService.I;
  late final AudioService _audioService = AudioService.I;
  late final AudioStorageService _audioStore = AudioStorageService.I;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<void>? _audioCompleteSub;
  CellKey? _recordingAudioCell;
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
  String? _photoFlowStatus;
  _CellTarget? _photoFlowTarget;
  Timer? _photoFlowClearT;
  String? _engineBaseResolved;
  String? _engineKeyResolved;
  DateTime? _engineLastCheckAt;
  bool _engineLastOk = false;
  String? _engineLastError;
  late final EngineApi _engineApi = EngineApi();

  bool get _engineHasBase =>
      _engineBaseResolved != null && _engineBaseResolved!.trim().isNotEmpty;

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
  VoidCallback? _vvDetach;
  int _fillDownCount = 5;
  int _incrementCount = 5;
  int _incrementStep = 1;
  Set<_CellRef> _invalidCells = <_CellRef>{};
  int _pendingRequired = 0;

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
    _rows = initial.rows;
    _resetMobileRowCaches();
    _recomputeValidation();

    _audioCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _playingAudioId = null);
    });

    _rev = 0;
    _lastSavedRev = 0;
    _savePending = false;

    _pushUndoSnapshot(); // estado inicial
    _smokeRequested = _isSmokeRequested();
    unawaited(_loadGpsMode());
    unawaited(_loadGridDensity());
    unawaited(_loadLocal().whenComplete(() => unawaited(_maybeRunSmoke())));
    unawaited(_initEngineConnection()
        .whenComplete(() => unawaited(_maybeRunSmoke())));
  }

  Future<void> _loadStorageStatus() async {
    final result = await StorageDiagnostics.check();
    if (!mounted) return;
    setState(() {
      _storageOk = result.ok;
      _storageMessage = result.message;
    });
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
    _nameDebounceT?.cancel();
    _blinkT?.cancel();
    _kbEnsureDebounceT?.cancel();
    _mobileEnsureLateT?.cancel();
    _mobileFocusRetryT?.cancel();
    _photoFlowClearT?.cancel();
    _mobileFocus.removeListener(_handleMobileFocusChange);
    _kbController.kbInsetDp.removeListener(_handleKbInsetChanged);
    _kbController.dispose();
    _vvDetach?.call();

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

    _nameEC.dispose();
    _nameFocus.dispose();
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
      if (_isDirty) {
        unawaited(_saveLocalNow());
      }
      _removeCellEditor();
    }
  }

// ------------------------------ Construcci??n inicial --------------------

  _SheetModel _buildInitialState() {
    final headers =
        (widget.initialHeaders != null && widget.initialHeaders!.isNotEmpty)
            ? _normalizeHeaders(widget.initialHeaders!)
            : _defaultHeaders();

    final rowModels = <_RowModel>[];

    if (widget.initialRows != null && widget.initialRows!.isNotEmpty) {
      for (final r in widget.initialRows!) {
        rowModels.add(_RowModel.fromCells(_normalizeRow(r, headers.length)));
      }
    } else {
// 3 filas vac??as por defecto (mobile-friendly)
      for (int i = 0; i < 3; i++) {
        rowModels.add(_RowModel.empty(headers.length));
      }
    }

    return _SheetModel(
      headers: headers,
      rows: rowModels,
      name: _sheetName,
      savedAt: _lastSavedAt,
    );
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

// ??? Acepta List<String>, List<dynamic>, etc.
  List<String> _normalizeRow(Iterable<dynamic> incoming, int cols) {
    final r = incoming.map((e) => (e ?? '').toString()).toList();
    if (r.length < cols) r.addAll(List<String>.filled(cols - r.length, ''));
    if (r.length > cols) r.removeRange(cols, r.length);
    return r;
  }

  Map<String, CellMeta> _normalizeCellMeta(
    Map<String, CellMeta> incoming,
    int rowCount,
    int colCount,
  ) {
    if (incoming.isEmpty) return <String, CellMeta>{};
    final out = <String, CellMeta>{};
    incoming.forEach((key, meta) {
      final cell = CellKey.fromKey(key);
      if (cell == null) return;
      if (cell.row < 0 || cell.row >= rowCount) return;
      if (cell.col < 0 || cell.col >= colCount) return;
      out[CellKey(cell.row, cell.col).toKey()] = meta.copy();
    });
    return out;
  }

  Map<String, CellMeta> _migrateLegacyRowGps(
    Map<String, CellMeta> incoming,
    List<_RowModel> rows,
    int colCount,
  ) {
    if (incoming.isNotEmpty) return incoming;
    final out = <String, CellMeta>{};
    if (colCount <= 0) return out;
    final lastDataCol = math.max(0, colCount - 1);
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
      out[CellKey(r, targetCol).toKey()] = CellMeta(gps: gps);
    }

    return out;
  }

  Map<String, CellMeta> _migrateLegacyRowPhotos(
    Map<String, CellMeta> incoming,
    List<_RowModel> rows,
    int colCount,
  ) {
    if (rows.isEmpty) return incoming;
    if (colCount <= 0) return incoming;

    final out = <String, CellMeta>{};
    out.addAll(incoming);
    final photosCol = colCount - 1;

    for (int r = 0; r < rows.length; r++) {
      final row = rows[r];
      if (row.photos.isEmpty) continue;

      final key = CellKey(r, photosCol).toKey();
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
  String get _backupListKey => '$_prefsKey:bk:list';
  String _backupKey(DateTime ts) =>
      '$_prefsKey:bk:${ts.millisecondsSinceEpoch}';

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.trim().isEmpty) return;

      final map = json.decode(raw) as Map<String, dynamic>;
      final loaded = _SheetModel.fromJson(map);

      if (!mounted) return;

      _lastBackup = _latestBackupFromPrefs(prefs);
      _applyLoadedModel(loaded);
    } catch (e) {
      if (kDebugMode) debugPrint('[EditorScreen] load failed: $e');
    }
  }

  void _applyLoadedModel(_SheetModel loaded) {
    if (!mounted) return;

    final loadedHeaders = _normalizeHeaders(loaded.headers);
    final normalizedRows = <_RowModel>[];
    for (final rm in loaded.rows) {
      final cells = _normalizeRow(rm.cells, loadedHeaders.length);
      normalizedRows.add(rm.copyWithCells(cells));
    }
    final migratedMeta = _migrateLegacyRowGps(
      loaded.cellMeta,
      normalizedRows,
      loadedHeaders.length,
    );
    final migratedPhotos = _migrateLegacyRowPhotos(
      migratedMeta,
      normalizedRows,
      loadedHeaders.length,
    );
    final normalizedMeta = _normalizeCellMeta(
      migratedPhotos,
      normalizedRows.length,
      loadedHeaders.length,
    );

    setState(() {
      _sheetName = (loaded.name?.trim().isNotEmpty ?? false)
          ? loaded.name!.trim()
          : _sheetName;
      _headers = loadedHeaders;
      _rows = normalizedRows.isNotEmpty
          ? normalizedRows
          : <_RowModel>[_RowModel.empty(_headers.length)];
      _cellMeta
        ..clear()
        ..addAll(normalizedMeta);
      _isDirty = false;
      _lastSavedAt = loaded.savedAt;

      _rev = 0;
      _lastSavedRev = 0;
      _savePending = false;
    });

    _resetMobileRowCaches();
    _resetDraftsAndEditors();
    _recomputeValidation();

    if (!_nameFocus.hasFocus) {
      _nameEC.text = _sheetName;
    }

    _undo
      ..clear()
      ..add(_snapshot());
    _redo.clear();
  }

  _SheetModel _buildModelForSave(DateTime savedAt) {
    return _SheetModel(
      name: _sheetName,
      headers: List<String>.from(_headers),
      rows: _rows
          .map(
            (r) => _RowModel(
              cells: List<String>.from(r.cells),
              photos: r.photos
                  .map((p) => p.copyWithoutThumb())
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
      cellMeta: _cloneCellMeta(_cellMeta),
      savedAt: savedAt,
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

  Future<void> _saveLocalNow() async {
// ??? Si ya est??s guardando, marc?? pendiente y sal??.
    if (_saving) {
      _savePending = true;
      return;
    }

    _saving = true;
    _savePending = false;

    final startRev = _rev;
    final savedAt = DateTime.now();

    if (mounted) setState(() {}); // refresca ???Saving??????

    try {
      final prefs = await SharedPreferences.getInstance();

// ??? Captura consistente: copia headers + cells (evita mutaciones durante await).
      final model = _buildModelForSave(savedAt);

      await prefs.setString(_prefsKey, json.encode(model.toJson()));

      _lastSavedRev = startRev;
      _lastBackup = _latestBackupFromPrefs(prefs);

      if (!mounted) return;
      setState(() {
        _lastSavedAt = savedAt;
// ??? Solo limpio Dirty si no cambi?? mientras guardaba
        _isDirty = _rev != _lastSavedRev;
      });
      await _createBackupIfNeeded();
    } catch (e) {
      if (kDebugMode) debugPrint('[EditorScreen] save failed: $e');
    } finally {
      _saving = false;
      if (mounted) {
        setState(() {}); // refresca ???Saved??????

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
    }
  }

  void _queueSave() {
    _saveT?.cancel();
    _saveT = Timer(_saveDebounce, () {
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

  _SheetSnapshot _snapshot() => _SheetSnapshot(
        name: _sheetName,
        headers: List<String>.from(_headers),
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
    if (_undo.length <= 1) return;
    final current = _undo.removeLast();
    _redo.add(current);

    final prev = _undo.last;

    setState(() {
      _sheetName = prev.name;
      _headers = List<String>.from(prev.headers);
      _rows = prev.rowModels.map((r) => r.copyForSnapshot()).toList();
      _cellMeta
        ..clear()
        ..addAll(_cloneCellMeta(prev.cellMeta));
      _selRow = prev.selRow.clamp(0, _rows.length - 1);
      _selCol = prev.selCol.clamp(0, _headers.length - 1);

      _isDirty = true;
      _rev++;
    });

    _resetMobileRowCaches();
    _resetDraftsAndEditors();

    if (!_nameFocus.hasFocus) {
      _nameEC.text = _sheetName;
    }

    _queueSave();
  }

  void _redoOnce() {
    if (_redo.isEmpty) return;
    final snap = _redo.removeLast();
    _undo.add(snap);

    setState(() {
      _sheetName = snap.name;
      _headers = List<String>.from(snap.headers);
      _rows = snap.rowModels.map((r) => r.copyForSnapshot()).toList();
      _cellMeta
        ..clear()
        ..addAll(_cloneCellMeta(snap.cellMeta));
      _selRow = snap.selRow.clamp(0, _rows.length - 1);
      _selCol = snap.selCol.clamp(0, _headers.length - 1);

      _isDirty = true;
      _rev++;
    });

    _resetMobileRowCaches();
    _resetDraftsAndEditors();

    if (!_nameFocus.hasFocus) {
      _nameEC.text = _sheetName;
    }

    _queueSave();
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

  Future<void> _showDensityPicker() async {
    if (!mounted) return;
    final picked = await showModalBottomSheet<_GridDensity>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final pal = _palette(ctx);
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    const Icon(Icons.format_line_spacing_rounded),
                    const SizedBox(width: 8),
                    Text(
                      'Densidad',
                      style: TextStyle(
                        color: pal.fg,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final d in _GridDensity.values)
                  RadioListTile<_GridDensity>(
                    value: d,
                    groupValue: _gridDensity,
                    onChanged: (v) => Navigator.of(ctx).pop(v),
                    activeColor: pal.accent,
                    title: Text(
                      _densityLabel(d),
                      style:
                          TextStyle(color: pal.fg, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) {
      await _setGridDensity(picked);
    }
  }

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

    _queueSave();
    _scheduleBackupCheck();
    _recomputeValidation();
  }

  _ColType _colType(int c) {
    if (c == _headers.length - 1) return _ColType.photos;
    final h = _headerLabel(c).toLowerCase();
    if (h.contains('fecha') || h.contains('date')) return _ColType.date;
    if (h.contains('lat') || h.contains('lon') || h.contains('acc')) {
      return _ColType.number;
    }
    if (h.contains('progres')) return _ColType.number;
    return _ColType.text;
  }

  bool _isRequired(int c) {
    final h = _headerLabel(c).toLowerCase();
    return h.startsWith('fecha') || h.startsWith('actividad');
  }

  void _recomputeValidation() {
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
            if (DateTime.tryParse(v) == null) invalid.add(ref);
            break;
          case _ColType.number:
            if (double.tryParse(v) == null) invalid.add(ref);
            break;
          default:
            break;
        }
      }
    }

    if (!mounted) {
      _invalidCells = invalid;
      _pendingRequired = pending;
      return;
    }
    setState(() {
      _invalidCells = invalid;
      _pendingRequired = pending;
    });
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
    _gridVersion.value = _gridVersion.value + 1;
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

    final ref = _CellRef(r, c);
    final existing = _draftCells[ref];
    if (existing == value) return;

    if (value == _rows[r].cells[c]) {
      if (_draftCells.remove(ref) != null) {
        _bumpGridVersion();
      }
      return;
    }

    _draftCells[ref] = value;
    _bumpGridVersion();
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

    final ref = _CellRef(r, c);
    final draft = _draftCells[ref];
    final next = draft ?? _rows[r].cells[c];
    if (next == _rows[r].cells[c]) {
      if (_draftCells.remove(ref) != null) {
        _bumpGridVersion();
      }
      return;
    }

    _rows[r].cells[c] = next;
    _draftCells.remove(ref);
    _markDirty(snapshot: true);
    _bumpGridVersion();
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

  String _savedLabel(_SheetPalette pal) {
    if (_saving) return 'Saving???';
    final d = _lastSavedAt;
    if (d == null) return _isDirty ? 'Not saved' : ' ';
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return 'Saved $hh:$mm';
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
    if (message == _lastMobileSnack) return;
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
    AppleToast.show(context, message: message, isError: isError);
  }

  String _cellLabelRc(int r, int c) => 'R${r + 1}C${c + 1}';

  void _showActionSnack(
    String message, {
    required bool isError,
    IconData? icon,
  }) {
    if (!mounted || message.trim().isEmpty) return;
    AppleToast.show(context, message: message, isError: isError, icon: icon);
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
        _storageMessage = 'Fallback RAM';
      });
    } else {
      _storageOk = false;
      _storageMessage = 'Fallback RAM';
    }
    _showActionSnack(
      'Storage no disponible: $kindLabel guardado temporal (RAM). Exporta ZIP para conservar.',
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
  }) {
    final t = AppTheme.of(context);
    final borderColor =
        t.colors.warningFg.withOpacity(pal.isLight ? 0.35 : 0.5);
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
        final fixedMq = mq.copyWith(textScaler: const TextScaler.linear(1.0));

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
                              savedText: _savedLabel(pal),
                              isDirty: _isDirty,
                              onTitleChanged: _onTitleChangedDebounced,
                              onToggleTheme: _toggleTheme,
                              onUndo: _undoOnce,
                              onRedo: _redoOnce,
                              onAddRow: () => _insertRow(_rows.length),
                              onSave: () => unawaited(_saveLocalNow()),
                              onExport: () => unawaited(_openExportMenu()),
                              onSmokeTest: () =>
                                  unawaited(_runAttachmentSmokeTest()),
                              onCompute: _engineBusy
                                  ? null
                                  : () => unawaited(_computeEngine()),
                              onGps: () => unawaited(_requestGpsForCell(
                                  _selRow, _selCol,
                                  forceWriteText: true)),
                              onPhoto: () => unawaited(
                                _showPhotoSourcePickerForCell(_selRow, _selCol),
                              ),
                              onAudio: () {
                                if (_audioRecording) {
                                  unawaited(_stopAudioRecording());
                                } else {
                                  unawaited(_startAudioRecordingForCell(
                                      _selRow, _selCol));
                                }
                              },
                              onShare: () =>
                                  unawaited(_exportZipBundle(share: true)),
                              onPalette: () => unawaited(_openCommandPalette()),
                              onGpsMode: () => unawaited(_showGpsModePicker()),
                              onDensity: () => unawaited(_showDensityPicker()),
                              sensorsEnabled: sensorsEnabled,
                            )
                          else
                            _MobileCompactHeader(
                              palette: pal,
                              title: _sheetName,
                              savedText: _savedLabel(pal),
                              isDirty: _isDirty,
                              pendingRequired: _pendingRequired,
                              onSave: () => unawaited(_saveLocalNow()),
                              onExport: () => unawaited(_openExportMenu()),
                              onMenu: () => _openMobileHeaderMenu(
                                context,
                                pal,
                              ),
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
                                      onPressed: () async {
                                        final picked =
                                            await _pickPhotoTargetDialog();
                                        if (picked != null && mounted) {
                                          setState(() {
                                            _selRow = picked.row;
                                            _selCol = picked.col;
                                          });
                                          _updatePhotoFlowStatus(
                                            'Destino R${picked.row + 1}C${picked.col + 1} · listo',
                                            target: picked,
                                          );
                                        }
                                      },
                                      child: const Text('Cambiar'),
                                    ),
                                ],
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
                                    child: RepaintBoundary(
                                      child: ValueListenableBuilder<int>(
                                        valueListenable: _gridVersion,
                                        builder: (ctx, _, __) {
                                          return _GridView(
                                            palette: pal,
                                            metrics: metrics,
                                            headers: List<String>.generate(
                                                _headers.length,
                                                _effectiveHeader),
                                            rowModels: _rows,
                                            cellTextAt: (r, c) =>
                                                _effectiveCell(r, c),
                                            cellHasGps: _cellHasGps,
                                            cellHasAudios: _cellHasAudios,
                                            cellPhotoThumb: _cellPhotoThumb,
                                            cellPhotoCount: _cellPhotoCount,
                                            isInvalid: (r, c) => _invalidCells
                                                .contains(_CellRef(r, c)),
                                            vScroll: _vScroll,
                                            hScroll: _hScroll,
                                            selRow: _selRow,
                                            selCol: _selCol,
                                            blink: _blinkCell,
                                            editorLink: _editorLink,
                                            overlayTargetCell:
                                                _overlayTargetCell,
                                            overlayTargetHeaderCol:
                                                _overlayTargetHeaderCol,
                                            onSelect: (r, c) {
                                              setState(() {
                                                _selRow = r;
                                                _selCol = c;
                                              });
                                              _blink(r, c);
                                            },
                                            onEditRequested: (r, c, w) =>
                                                _beginEditCell(
                                                    context, pal, r, c, w),
                                            onHeaderEditRequested: (c, w) =>
                                                _beginEditHeader(
                                                    context, pal, c, w),
                                            onContextMenu:
                                                (pos, r, c, isHeader) =>
                                                    _openContextMenu(
                                                        context,
                                                        pal,
                                                        pos,
                                                        r,
                                                        c,
                                                        isHeader),
                                            onDeleteRow: (r) => _deleteRow(r),
                                            onPickPhoto: (r) =>
                                                _showPhotoSourcePickerForCell(
                                              r,
                                              _headers.length - 1,
                                            ),
                                          );
                                        },
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
                                        return _MobileNotesGrid(
                                          palette: pal,
                                          density: _gridDensity,
                                          headers: List<String>.generate(
                                              _headers.length,
                                              _effectiveHeader),
                                          rowModels: _rows,
                                          cellTextAt: (r, c) =>
                                              _effectiveCell(r, c),
                                          cellHasGps: _cellHasGps,
                                          cellHasAudios: _cellHasAudios,
                                          cellPhotoThumb: _cellPhotoThumb,
                                          cellPhotoCount: _cellPhotoCount,
                                          verticalController: _vScroll,
                                          headerScrollController:
                                              _mobileHeaderScroll,
                                          rowScrollControllers:
                                              _mobileRowScrolls,
                                          headerKey: _mobileHeaderKey,
                                          rowKeys: _mobileRowKeys,
                                          selectedRow: _selRow,
                                          selectedCol: _selCol,
                                          activeRow: _mobileEditorOpen &&
                                                  !_mobileEditingHeader
                                              ? _mobileRow
                                              : -1,
                                          activeCol: _mobileEditorOpen
                                              ? _mobileCol
                                              : -1,
                                          activeIsHeader: _mobileEditorOpen &&
                                              _mobileEditingHeader,
                                          activeController: _mobileEC,
                                          onHorizontalScroll:
                                              _syncMobileHorizontal,
                                          onCellTap: (cellCtx, r, c) =>
                                              _beginEditCell(
                                                  cellCtx, pal, r, c, cardW),
                                          onHeaderTap: (cellCtx, c) =>
                                              _beginEditHeader(
                                                  cellCtx, pal, c, cardW),
                                          onContextMenu:
                                              (pos, r, c, isHeader) =>
                                                  _openContextMenu(ctx, pal,
                                                      pos, r, c, isHeader),
                                          onDeleteRow: (r) => _deleteRow(r),
                                          onPickPhoto: (r) =>
                                              _showPhotoSourcePickerForCell(
                                            r,
                                            _headers.length - 1,
                                          ),
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
                          onGps: () => unawaited(_requestGpsForCell(
                              _selRow, _selCol,
                              forceWriteText: true)),
                          onPhoto: () => unawaited(
                            _showPhotoSourcePickerForCell(_selRow, _selCol),
                          ),
                          onAudio: () {
                            if (_audioRecording) {
                              unawaited(_stopAudioRecording());
                            } else {
                              unawaited(_startAudioRecordingForCell(
                                  _selRow, _selCol));
                            }
                          },
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

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape && _gpsPickingTarget) {
      _cancelGpsPick();
      return KeyEventResult.handled;
    }

    if (_cellEditorEntry != null || _mobileEditorOpen) {
      return KeyEventResult.ignored;
    }

    final isCmd = HardwareKeyboard.instance.isMetaPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isMod = isCmd || isCtrl;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSel(dRow: 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSel(dRow: -1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _moveSel(dCol: 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _moveSel(dCol: -1);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _beginEditCell(context, _palette(context), _selRow, _selCol, 340);
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (isShift) {
        _redoOnce();
      } else {
        _undoOnce();
      }
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyY) {
      _redoOnce();
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyC) {
      unawaited(_copySelectionToClipboard());
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyV) {
      unawaited(_pasteFromClipboard());
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyS) {
      unawaited(_saveLocalNow());
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyE) {
      if (isShift) {
        unawaited(_exportZipBundle(share: false));
      } else {
        unawaited(_exportXlsxOnly());
      }
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyK) {
      unawaited(_openCommandPalette());
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyG) {
      unawaited(_requestGpsForCell(_selRow, _selCol, forceWriteText: true));
      return KeyEventResult.handled;
    }

    if (isMod && isShift && event.logicalKey == LogicalKeyboardKey.keyA) {
      if (_audioRecording) {
        unawaited(_stopAudioRecording());
      } else {
        unawaited(_startAudioRecordingForCell(_selRow, _selCol));
      }
      return KeyEventResult.handled;
    }

    if (isMod && event.logicalKey == LogicalKeyboardKey.keyP) {
      unawaited(_showPhotoSourcePickerForCell(_selRow, _selCol));
      return KeyEventResult.handled;
    }

    if (!isMod && !isAlt) {
      if (event.logicalKey == LogicalKeyboardKey.keyG) {
        unawaited(_requestGpsForCell(_selRow, _selCol, forceWriteText: true));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyP) {
        unawaited(_showPhotoSourcePickerForCell(_selRow, _selCol));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyA) {
        if (_audioRecording) {
          unawaited(_stopAudioRecording());
        } else {
          unawaited(_startAudioRecordingForCell(_selRow, _selCol));
        }
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      _setCell(_selRow, _selCol, '');
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _removeCellEditor();
      return KeyEventResult.handled;
    }

    final printableChar = _extractPrintableChar(event);
    if (printableChar != null &&
        _selRow >= 0 &&
        _selCol >= 0 &&
        _selRow < _rows.length &&
        _selCol < _headers.length) {
      _beginEditCell(
        context,
        _palette(context),
        _selRow,
        _selCol,
        340,
        initialOverride: printableChar,
      );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _openCommandPalette() async {
    if (!mounted) return;
    await showCommandPalette(
      context,
      title: 'Comandos',
      actions: [
        CommandAction(
          id: 'save',
          label: 'Guardar',
          shortcut: 'Ctrl/Cmd+S',
          icon: Icons.check_circle_outline_rounded,
          onSelected: () => unawaited(_saveLocalNow()),
        ),
        CommandAction(
          id: 'gps',
          label: 'GPS en celda',
          shortcut: 'G',
          icon: Icons.my_location_rounded,
          onSelected: () => unawaited(
              _requestGpsForCell(_selRow, _selCol, forceWriteText: true)),
        ),
        CommandAction(
          id: 'gps_mode',
          label: 'Modo GPS',
          icon: Icons.tune_rounded,
          onSelected: () => unawaited(_showGpsModePicker()),
        ),
        CommandAction(
          id: 'photo',
          label: 'Foto en celda',
          shortcut: 'P',
          icon: Icons.photo_camera_outlined,
          onSelected: () => unawaited(
            _showPhotoSourcePickerForCell(_selRow, _selCol),
          ),
        ),
        CommandAction(
          id: 'audio',
          label: 'Audio en celda',
          shortcut: 'A',
          icon: Icons.mic_none_rounded,
          onSelected: () {
            if (_audioRecording) {
              unawaited(_stopAudioRecording());
            } else {
              unawaited(_startAudioRecordingForCell(_selRow, _selCol));
            }
          },
        ),
        CommandAction(
          id: 'export_xlsx',
          label: 'Exportar XLSX',
          shortcut: 'Ctrl/Cmd+E',
          icon: Icons.download_rounded,
          onSelected: () => unawaited(_exportXlsxOnly()),
        ),
        CommandAction(
          id: 'export_zip',
          label: 'Exportar ZIP',
          shortcut: 'Ctrl/Cmd+Shift+E',
          icon: Icons.archive_outlined,
          onSelected: () => unawaited(_exportZipBundle(share: false)),
        ),
        CommandAction(
          id: 'share_zip',
          label: 'Compartir ZIP',
          icon: Icons.ios_share_rounded,
          onSelected: () => unawaited(_exportZipBundle(share: true)),
        ),
        if (!_engineBusy)
          CommandAction(
            id: 'compute',
            label: 'Calcular',
            icon: Icons.functions_rounded,
            onSelected: () => unawaited(_computeEngine()),
          ),
        CommandAction(
          id: 'shortcuts',
          label: 'Ver atajos',
          shortcut: 'Ctrl/Cmd+K',
          icon: Icons.keyboard,
          onSelected: () => unawaited(_openShortcutsHelp()),
        ),
      ],
    );
  }

  Future<void> _openShortcutsHelp() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final pal = _palette(ctx);
        return AlertDialog(
          backgroundColor: pal.menuBg,
          title: const Text('Atajos'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Ctrl/Cmd+S — Guardar'),
                Text('Ctrl/Cmd+Z — Deshacer'),
                Text('Ctrl/Cmd+Y — Rehacer'),
                Text('Ctrl/Cmd+E — Exportar XLSX'),
                Text('Ctrl/Cmd+Shift+E — Exportar ZIP'),
                Text('Ctrl/Cmd+G — GPS en celda'),
                Text('Ctrl/Cmd+Shift+A — Audio en celda'),
                Text('Ctrl/Cmd+P — Foto en celda'),
                Text('Ctrl/Cmd+K — Ayuda'),
                Text('Enter — Editar/confirmar'),
                Text('Esc — Cancelar'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String? _extractPrintableChar(KeyDownEvent event) {
    final char = event.character;
    if (char == null || char.isEmpty) return null;
    if (char.codeUnits.any((unit) => unit < 32)) return null;

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return null;
    }

    return char;
  }

  void _moveSel({int dRow = 0, int dCol = 0}) {
    final nr = (_selRow + dRow).clamp(0, _rows.length - 1);
    final nc = (_selCol + dCol).clamp(0, _headers.length - 1);
    setState(() {
      _selRow = nr;
      _selCol = nc;
    });
    _blink(nr, nc);
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
        setState(() {
          _selRow = r;
          _selCol = c;
        });
      }
      _blink(r, c);
      return;
    }

    if (_selRow != r || _selCol != c) {
      setState(() {
        _selRow = r;
        _selCol = c;
      });
    }

    _removeCellEditor();
    _blink(r, c);

// Photos => pick
    if (c == _headers.length - 1) {
      _handlePhotosCellTap(r, c);
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
      _selRow = row;
      _selCol = col;
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

  String _headerLabel(int c) {
    final t = _effectiveHeader(c).trim();
    if (t.isNotEmpty) return t;
    if (c == _headers.length - 1) return kPhotosHeader;
    return 'Col ${c + 1}';
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

    if (_rows[r].cells[c] == value) return;

    _rows[r].cells[c] = value;
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
        onTap: () => _showPhotoSourcePickerForCell(r, c),
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
                  leading: Icon(
                    _audioRecording
                        ? Icons.stop_circle_outlined
                        : Icons.mic_none_rounded,
                  ),
                  title: Text(_audioRecording
                      ? 'Detener grabación'
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
    final col = _mobileCol;
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
    return _mobileEditorOpen && !_mobileEditingHeader && _headers.length >= 2;
  }

  bool get _canMobileGps {
    return _mobileEditorOpen && !_mobileEditingHeader && _mobileRow >= 0;
  }

  int get _lastEditableCol => math.max(0, _headers.length - 2);

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

    int r = _mobileRow;
    int c = _mobileCol;
    final last = _lastEditableCol;

    if (c < last) {
      c += 1;
    } else {
      r += 1;
      c = 0;
      if (r >= _rows.length) {
        _insertRow(_rows.length);
      }
      if (r >= _rows.length) return;
    }

    setState(() {
      _selRow = r;
      _selCol = c;
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

    int r = _mobileRow;
    int c = _mobileCol;
    final last = _lastEditableCol;

    if (r <= 0 && c <= 0) return;

    if (c > 0) {
      c -= 1;
    } else {
      r -= 1;
      if (r < 0) return;
      c = last;
    }

    setState(() {
      _selRow = r;
      _selCol = c;
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
      final lastHeaderCol = math.max(0, _headers.length - 2); // sin Photos
      int nextC = currentHeader;

      if (move == _OverlayMove.next) {
        nextC = (currentHeader + 1).clamp(0, lastHeaderCol);
      }
      if (move == _OverlayMove.prev) {
        nextC = (currentHeader - 1).clamp(0, lastHeaderCol);
      }

      if (move == _OverlayMove.down) {
        if (_rows.isEmpty) {
          _rows.add(_RowModel.empty(_headers.length));
          _ensureMobileRowCachesLength();
        }
        _beginEditCell(
            context, pal, 0, currentHeader.clamp(0, lastHeaderCol), width);
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

    final lastCol = math.max(0, _headers.length - 2); // sin Photos
    int r = currentCell.r;
    int c = currentCell.c.clamp(0, lastCol);

    if (move == _OverlayMove.next) {
      if (c < lastCol) {
        c += 1;
      } else {
        r += 1;
        c = 0;
      }
    } else if (move == _OverlayMove.prev) {
      if (c > 0) {
        c -= 1;
      } else {
        r -= 1;
        c = lastCol;
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
    c = c.clamp(0, lastCol);

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
// ??? Dark: glass m??s visible (sin quedar ???bloque??? opaco).
                          color: pal.isLight
                              ? Colors.white.withOpacity(0.90)
                              : const Color(0xFF0B0B0C).withOpacity(0.56),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: pal.isLight
                                ? Colors.black.withOpacity(0.10)
                                : Colors.white.withOpacity(0.24),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(pal.isLight ? 0.10 : 0.55),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
// ??? micro-glow Apple (no azul fuerte)
                            if (!pal.isLight)
                              BoxShadow(
                                color: pal.accent.withOpacity(0.18),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _cellEC,
                                focusNode: _cellFocus,
                                autofocus: true,
                                maxLines: 1,
                                style: TextStyle(
                                  color: pal.fg,
                                  fontSize: metrics.cellFontSize,
                                  height: 1.08,
                                  fontWeight: FontWeight.w800, // ??? nitidez
                                  letterSpacing: -0.2,
                                ),
                                cursorColor: pal.accent,
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'Escribir???',
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
        actions.add(_CtxAction('Editar encabezado', Icons.edit_outlined,
            () => _beginEditHeader(context, pal, c, 220)));
        actions.add(_CtxAction('Limpiar encabezado', Icons.clear_rounded, () {
          if (_headers[c].isEmpty) return;
          _headers[c] = '';
          _markDirty(snapshot: true);
        }));
      }
    } else {
      actions.add(_CtxAction('Editar', Icons.edit_outlined,
          () => _beginEditCell(context, pal, r, c, 320)));
      actions.add(_CtxAction('Copiar', Icons.copy_rounded,
          () => unawaited(_copySelectionToClipboard())));
      actions.add(_CtxAction('Pegar', Icons.paste_rounded,
          () => unawaited(_pasteFromClipboard())));
      actions.add(_CtxAction('Pegar resultado', Icons.calculate_outlined,
          () => _applyCalcToCell(r, c)));
      actions.add(_CtxAction('Fecha/Hora ahora', Icons.schedule_rounded,
          () => _insertNowInCell(r, c)));
      actions.add(_CtxAction(
          'Rellenar abajo...',
          Icons.vertical_align_bottom_rounded,
          () => unawaited(_promptFillDown(context, r, c))));
      actions.add(_CtxAction('Incrementar...', Icons.exposure_plus_1_rounded,
          () => unawaited(_promptIncrement(context, r, c))));
      actions.add(_CtxAction(
          'Limpiar celda', Icons.backspace_outlined, () => _setCell(r, c, '')));

      if (c != _headers.length - 1) {
        actions.add(_CtxAction(
            'GPS -> Pegar en esta celda',
            Icons.my_location_outlined,
            () => unawaited(_requestGpsForCell(r, c, forceWriteText: true)),
            runOnTap: true));
        actions.add(_CtxAction('Modo GPS...', Icons.tune_rounded,
            () => unawaited(_showGpsModePicker()),
            runOnTap: true));
        actions.add(_CtxAction('Maps', Icons.map_outlined,
            () => unawaited(_openMapsForCell(r, c))));

        if (_audioRecording) {
          actions.add(_CtxAction(
              'Detener grabación',
              Icons.stop_circle_outlined,
              () => unawaited(_stopAudioRecording()),
              runOnTap: true));
        } else {
          actions.add(_CtxAction(
              'Grabar audio en esta celda',
              Icons.mic_none_rounded,
              () => unawaited(_startAudioRecordingForCell(r, c)),
              runOnTap: true));
        }
        if (_cellHasAudios(r, c)) {
          actions.add(_CtxAction('Audios de esta celda',
              Icons.graphic_eq_rounded, () => _openAudiosSheetForCell(r, c)));
        }

        actions.add(_CtxAction(
            'Agregar foto a esta celda',
            Icons.add_photo_alternate_outlined,
            () => unawaited(_showPhotoSourcePickerForCell(r, c)),
            runOnTap: true));
        if (_cellHasPhotos(r, c)) {
          actions.add(_CtxAction(
              'Ver fotos de esta celda',
              Icons.photo_library_outlined,
              () => _openPhotosSheetForCell(r, c)));
        }
      } else {
        if (_audioRecording) {
          actions.add(_CtxAction(
            'Detener grabación',
            Icons.stop_circle_outlined,
            () => unawaited(_stopAudioRecording()),
            runOnTap: true,
          ));
        } else {
          actions.add(_CtxAction(
            'Grabar audio en esta celda',
            Icons.mic_none_rounded,
            () => unawaited(_startAudioRecordingForCell(r, c)),
            runOnTap: true,
          ));
        }
        if (_cellHasAudios(r, c)) {
          actions.add(_CtxAction('Audios de esta celda',
              Icons.graphic_eq_rounded, () => _openAudiosSheetForCell(r, c)));
        }
        actions.add(_CtxAction(
          'Agregar foto',
          Icons.add_photo_alternate_outlined,
          () => unawaited(_showPhotoSourcePickerForCell(r, c)),
          runOnTap: true,
        ));
        if (_cellHasPhotos(r, c)) {
          actions.add(_CtxAction(
              'Ver fotos de esta celda',
              Icons.photo_library_outlined,
              () => _openPhotosSheetForCell(r, c)));
        }
      }

      actions.add(_CtxAction('Insertar fila arriba', Icons.arrow_upward_rounded,
          () => _insertRow(r)));
      actions.add(_CtxAction('Insertar fila abajo',
          Icons.arrow_downward_rounded, () => _insertRow(r + 1)));
      actions.add(_CtxAction(
          'Duplicar fila', Icons.copy_all_outlined, () => _duplicateRow(r)));
      actions.add(_CtxAction(
          'Borrar fila', Icons.delete_outline_rounded, () => _deleteRow(r)));
    }

    if (actions.isEmpty) return;

    final overlay = Overlay.of(context);

    final size = overlay.context.size;
    if (size == null) return;

    final res = await showMenu<int>(
      context: context,
      color: pal.menuBg,
      elevation: 10,
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
            child: Row(
              children: [
                Icon(actions[i].icon, size: 18, color: pal.fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    actions[i].label,
                    style:
                        TextStyle(color: pal.fg, fontWeight: FontWeight.w800),
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
    if (r < 0 || r >= _rows.length) return;
    final src = _rows[r];
    final copy = _RowModel(
      cells: List<String>.from(src.cells),
      photos: src.photos.map((p) => p.copy()).toList(),
      gpsLat: src.gpsLat,
      gpsLng: src.gpsLng,
      gpsAccuracyM: src.gpsAccuracyM,
      gpsTs: src.gpsTs,
      gpsIsLastKnown: src.gpsIsLastKnown,
    );
    final insertAt = (r + 1).clamp(0, _rows.length);
    _duplicateCellMetaRow(r, insertAt);
    setState(() {
      _rows.insert(insertAt, copy);
      _selRow = insertAt;
      _selCol = _selCol.clamp(0, _headers.length - 1);
      _isDirty = true;
      _rev++;
    });
    _insertMobileRowCache(insertAt);
    _pushUndoSnapshot();
    _queueSave();
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
        _rows.add(_RowModel.empty(_headers.length));
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
    final base = double.tryParse(baseRaw.trim());
    if (base == null) return;
    if (count <= 0) return;

    final targetRows = r + count;
    if (targetRows >= _rows.length) {
      final add = targetRows - _rows.length + 1;
      for (int i = 0; i < add; i++) {
        _rows.add(_RowModel.empty(_headers.length));
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

  void _shiftCellMetaForInsert(int atRow) {
    if (_cellMeta.isEmpty) return;
    final updated = <String, CellMeta>{};
    _cellMeta.forEach((key, meta) {
      final cell = CellKey.fromKey(key);
      if (cell == null) return;
      final r = cell.row >= atRow ? cell.row + 1 : cell.row;
      updated[CellKey(r, cell.col).toKey()] = meta;
    });
    _cellMeta
      ..clear()
      ..addAll(updated);
  }

  void _shiftCellMetaForDelete(int atRow) {
    if (_cellMeta.isEmpty) return;
    final updated = <String, CellMeta>{};
    _cellMeta.forEach((key, meta) {
      final cell = CellKey.fromKey(key);
      if (cell == null) return;
      if (cell.row == atRow) return;
      final r = cell.row > atRow ? cell.row - 1 : cell.row;
      if (r < 0) return;
      updated[CellKey(r, cell.col).toKey()] = meta;
    });
    _cellMeta
      ..clear()
      ..addAll(updated);
  }

  void _duplicateCellMetaRow(int fromRow, int insertAt) {
    if (_cellMeta.isEmpty) {
      _shiftCellMetaForInsert(insertAt);
      return;
    }
    final rowEntries = <MapEntry<int, CellMeta>>[];
    _cellMeta.forEach((key, meta) {
      final cell = CellKey.fromKey(key);
      if (cell == null) return;
      if (cell.row == fromRow) {
        rowEntries.add(MapEntry(cell.col, meta.copy()));
      }
    });
    _shiftCellMetaForInsert(insertAt);
    for (final entry in rowEntries) {
      _cellMeta[CellKey(insertAt, entry.key).toKey()] = entry.value;
    }
  }

  void _insertRow(int index) {
    final idx = index.clamp(0, _rows.length);
    _shiftCellMetaForInsert(idx);
    setState(() {
      _rows.insert(idx, _RowModel.empty(_headers.length));
      _selRow = idx.clamp(0, _rows.length - 1);
      _selCol = _selCol.clamp(0, _headers.length - 1);
      _isDirty = true;
      _rev++;
    });
    _insertMobileRowCache(idx);
    _pushUndoSnapshot();
    _queueSave();
  }

  void _deleteRow(int r) {
    if (_rows.isEmpty) return;
    final idx = r.clamp(0, _rows.length - 1);

    final toDelete = List<_RowPhoto>.from(_rows[idx].photos);
    final metaPhotos = <PhotoAttachment>[];
    final metaAudios = <AudioAttachment>[];
    _cellMeta.forEach((key, meta) {
      final cell = CellKey.fromKey(key);
      if (cell == null) return;
      if (cell.row != idx) return;
      metaPhotos.addAll(meta.photos);
      metaAudios.addAll(meta.audios);
    });
    _shiftCellMetaForDelete(idx);
    setState(() {
      _rows.removeAt(idx);
      if (_rows.isEmpty) _rows.add(_RowModel.empty(_headers.length));
      _selRow = _selRow.clamp(0, _rows.length - 1);

      _isDirty = true;
      _rev++;
    });

    for (final p in toDelete) {
      unawaited(_photoStore.deletePhoto(p.path));
    }
    for (final p in metaPhotos) {
      final path = _photoPathFromRef(p.storedRef);
      if (path.trim().isNotEmpty) {
        unawaited(_photoStore.deletePhoto(path));
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

// Extender filas si hace falta
    final neededRows = startR + grid.length;
    if (neededRows > _rows.length) {
      final add = neededRows - _rows.length;
      for (int i = 0; i < add; i++) {
        _rows.add(_RowModel.empty(_headers.length));
      }
    }
    _ensureMobileRowCachesLength();

    for (int dr = 0; dr < grid.length; dr++) {
      final row = grid[dr];
      for (int dc = 0; dc < row.length; dc++) {
        final rr = startR + dr;
        final cc = startC + dc;
        if (cc >= maxColsExclusive) break;
        _rows[rr].cells[cc] = row[dc];
      }
    }

    _markDirty(snapshot: true);
  }

  List<List<String>> _parseGrid(String raw) {
    final txt = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = txt.split('\n').where((e) => e.isNotEmpty).toList();
    if (lines.isEmpty) return const [];

    final out = <List<String>>[];
    for (final line in lines) {
      final hasTab = line.contains('\t');
      final parts = hasTab ? line.split('\t') : line.split(',');
      out.add(parts.map((e) => e.trimRight()).toList());
    }
    return out;
  }

// ------------------------------ GPS / Maps ------------------------------

  CellMeta? _cellMetaAt(int r, int c) => _cellMeta[CellKey(r, c).toKey()];

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
        return 'Luego de capturar GPS, elegís la celda destino.';
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

  Future<void> _setGpsMode(_GpsWriteMode mode) async {
    if (mode == _gpsWriteMode) return;
    if (mounted) setState(() => _gpsWriteMode = mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefGpsMode, mode.name);
    } catch (_) {}
  }

  Future<void> _showGpsModePicker() async {
    if (!mounted) return;
    final picked = await showModalBottomSheet<_GpsWriteMode>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Modo GPS',
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
                const SizedBox(height: 6),
                for (final mode in _GpsWriteMode.values)
                  RadioListTile<_GpsWriteMode>(
                    dense: true,
                    value: mode,
                    groupValue: _gpsWriteMode,
                    onChanged: (v) => Navigator.of(ctx).pop(v),
                    title: Text(
                      _gpsModeLabel(mode),
                      style: TextStyle(
                        color: pal.fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      _gpsModeDesc(mode),
                      style: TextStyle(color: pal.fgMuted, fontSize: 12),
                    ),
                    activeColor: pal.accent,
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (picked != null) {
      await _setGpsMode(picked);
    }
  }

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
      setState(() {
        _selRow = r;
        _selCol = c;
      });
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
    final fix = _GpsFix(
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
      ts: timestamp ?? DateTime.now(),
      source: source,
      provider: provider,
    );
    _applyGpsFixToCell(r, c, fix, writeText: writeText, announce: false);
  }

  @visibleForTesting
  String debugCellText(int r, int c) => _getCellText(r, c);

  @visibleForTesting
  bool debugCellHasGps(int r, int c) => _cellHasGps(r, c);

  void _setCellGpsMeta(int r, int c, _GpsFix fix, {required bool markDirty}) {
    final key = CellKey(r, c).toKey();
    final current = _cellMeta[key];
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
    final key = CellKey(r, c).toKey();
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
      setState(() {
        _selRow = picked.row;
        _selCol = picked.col;
      });
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

  Future<void> _showPhotoSourcePickerForCell(int r, int c) async {
    if (_rows.isEmpty || _headers.isEmpty) return;

    final target = await _ensurePhotoTargetCell(r, c);
    if (target == null) return;
    r = target.row;
    c = target.col;

    if (_guardInAppBrowser(DiagnosticActionType.photo)) return;

    await showModalBottomSheet<void>(
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
                  onTap: () {
                    if (_guardInsecureContext(
                      DiagnosticActionType.photo,
                      actionLabel: 'Camara',
                    )) {
                      return;
                    }
                    _startPhotoPickFromGesture(
                      r: r,
                      c: c,
                      fromCamera: true,
                      sheetContext: ctx,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library_outlined, color: pal.fg),
                  title: const Text('Elegir de galeria'),
                  subtitle: const Text('Seleccionar archivo'),
                  onTap: () {
                    _startPhotoPickFromGesture(
                      r: r,
                      c: c,
                      fromCamera: false,
                      sheetContext: ctx,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handlePhotosCellTap(int r, int c) {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;

    final photos = _cellMetaAt(r, c)?.photos ?? const <PhotoAttachment>[];
    if (photos.isNotEmpty) {
      _openPhotosSheetForCell(r, c);
      return;
    }
    unawaited(_showPhotoSourcePickerForCell(r, c));
  }

  void _startCellPhotoPickFromSheet(int r, int c) {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    unawaited(_showPhotoSourcePickerForCell(r, c).whenComplete(() {
      if (!mounted) return;
      Navigator.of(context).maybePop();
    }));
  }

  String _genAttachmentId(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = math.Random().nextInt(1 << 32);
    return '$prefix$now$rand';
  }

  String _photoStoredRefFrom(StoredPhoto stored) {
    final path = stored.path.trim();
    if (path.isNotEmpty) {
      if (path.startsWith('key:') || path.startsWith('mem:')) {
        return path;
      }
      return 'file:$path';
    }
    if (stored.dataB64.trim().isNotEmpty) {
      return 'b64:${stored.dataB64}';
    }
    return '';
  }

  String _photoPathFromRef(String storedRef) {
    final raw = storedRef.trim();
    if (raw.startsWith('key:')) return raw;
    if (raw.startsWith('mem:')) return raw;
    if (raw.startsWith('file:')) return kIsWeb ? '' : raw.substring(5);
    if (raw.startsWith('b64:')) return '';
    if (raw.startsWith('data:')) return '';
    final looksLikePath =
        raw.contains('\\') || raw.contains('/') || raw.contains(':');
    if (looksLikePath) {
      return kIsWeb ? '' : raw;
    }
    return '';
  }

  String _photoDataFromRef(String storedRef) {
    final raw = storedRef.trim();
    if (raw.startsWith('b64:')) return raw.substring(4);
    if (raw.startsWith('data:')) return raw;
    if (raw.startsWith('key:')) return '';
    if (raw.startsWith('mem:')) return '';
    final looksLikePath =
        raw.contains('\\') || raw.contains('/') || raw.contains(':');
    return looksLikePath ? '' : raw;
  }

  String _photoStoredRefFromRowPhoto(_RowPhoto photo) {
    if (photo.path.trim().isNotEmpty) {
      return 'file:${photo.path}';
    }
    if (photo.dataB64.trim().isNotEmpty) {
      return 'b64:${photo.dataB64}';
    }
    return '';
  }

  int _estimateB64Size(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return 0;
    if (s.startsWith('data:')) {
      final comma = s.indexOf(',');
      if (comma >= 0 && comma < s.length - 1) {
        s = s.substring(comma + 1);
      }
    }
    s = s.replaceAll(RegExp(r'\s+'), '');
    if (s.isEmpty) return 0;
    return ((s.length * 3) / 4).floor();
  }

  PhotoAttachment _photoAttachmentFromRowPhoto(_RowPhoto photo) {
    final storedRef = _photoStoredRefFromRowPhoto(photo);
    final size =
        photo.dataB64.trim().isNotEmpty ? _estimateB64Size(photo.dataB64) : 0;
    return PhotoAttachment(
      id: _genAttachmentId('ph_legacy_'),
      filename: photo.name,
      mime: photo.mime,
      size: size,
      storedRef: storedRef,
      thumbRef: photo.thumbB64,
      addedAt: photo.addedAt,
      lat: photo.lat,
      lon: photo.lng,
      accuracyM: photo.accuracyM,
      isLastKnown: photo.isLastKnown,
    );
  }

  void _updatePhotoFlowStatus(String? text, {_CellTarget? target}) {
    _photoFlowClearT?.cancel();
    if (!mounted) return;
    setState(() {
      _photoFlowStatus = text;
      _photoFlowTarget = text == null ? null : (target ?? _photoFlowTarget);
    });
  }

  void _clearPhotoFlowStatusSoon(
      {Duration delay = const Duration(seconds: 3)}) {
    _photoFlowClearT?.cancel();
    _photoFlowClearT = Timer(delay, () {
      _updatePhotoFlowStatus(null);
    });
  }

  void _startPhotoPickFromGesture({
    required int r,
    required int c,
    required bool fromCamera,
    required BuildContext sheetContext,
  }) {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    if (_guardInAppBrowser(DiagnosticActionType.photo)) return;
    if (fromCamera &&
        _guardInsecureContext(
          DiagnosticActionType.photo,
          actionLabel: 'Camara',
        )) {
      return;
    }

    final target = _CellTarget(r, c);
    _updatePhotoFlowStatus(
      'Destino R${r + 1}C${c + 1} \u00b7 esperando seleccion',
      target: target,
    );

    final future = fromCamera
        ? PhotoAcquireService.I.captureFromCamera(context: context)
        : PhotoAcquireService.I.pickFromGallery();

    unawaited(_handlePhotoOutcome(future, r, c,
        fromCamera: fromCamera, sheetContext: sheetContext));
  }

  Future<void> _handlePhotoOutcome(
    Future<PhotoAcquireOutcome> future,
    int r,
    int c, {
    required bool fromCamera,
    BuildContext? sheetContext,
  }) async {
    final outcome = await future;
    if (!mounted) return;

    if (fromCamera &&
        _isIosWeb &&
        (outcome.cancelled || outcome.blocked || outcome.isError)) {
      final fallbackOutcome = await _offerGalleryFallback();
      if (!mounted) return;
      if (fallbackOutcome != null) {
        await _handlePhotoOutcomeResult(fallbackOutcome, r, c);
        if (sheetContext != null && mounted && sheetContext.mounted) {
          if (Navigator.of(sheetContext).canPop()) {
            Navigator.of(sheetContext).pop();
          }
        }
        return;
      }
    }

    await _handlePhotoOutcomeResult(outcome, r, c);
    if (sheetContext != null && mounted && sheetContext.mounted) {
      if (Navigator.of(sheetContext).canPop()) {
        Navigator.of(sheetContext).pop();
      }
    }
  }

  Future<PhotoAcquireOutcome?> _offerGalleryFallback() async {
    if (!mounted) return null;
    final future = await showDialog<Future<PhotoAcquireOutcome>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final pal = _palette(ctx);
        return AlertDialog(
          backgroundColor: pal.menuBg,
          title: const Text('No se pudo abrir la camara'),
          content: const Text(
            'No se pudo capturar desde camara. ¿Queres elegir desde galeria?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final future = PhotoAcquireService.I.pickFromGallery();
                Navigator.of(ctx).pop(future);
              },
              child: const Text('Elegir galeria'),
            ),
          ],
        );
      },
    );
    if (future == null) return null;
    return await future;
  }

  Future<void> _pickPhotoForCell(int r, int c,
      {bool fromCamera = false}) async {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;

    if (_guardInAppBrowser(DiagnosticActionType.photo)) return;
    if (fromCamera &&
        _guardInsecureContext(
          DiagnosticActionType.photo,
          actionLabel: 'Camara',
        )) {
      return;
    }

    try {
      final future = fromCamera
          ? PhotoAcquireService.I.captureFromCamera(context: context)
          : PhotoAcquireService.I.pickFromGallery();
      await _handlePhotoOutcome(future, r, c, fromCamera: fromCamera);
      return;
    } catch (e, st) {
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.photo,
        ok: false,
        message: 'photo_error $e',
      );
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: 'error',
        error: e.toString(),
        stack: st.toString(),
      );
      _showActionSnack('No se pudo guardar la foto. Revisa permisos.',
          isError: true, icon: Icons.photo_outlined);
      return;
    }
  }

  Future<void> _handlePhotoOutcomeResult(
    PhotoAcquireOutcome outcome,
    int r,
    int c,
  ) async {
    if (outcome.cancelled) {
      _updatePhotoFlowStatus(
        'Destino ${_cellLabelRc(r, c)} · cancelado',
        target: _CellTarget(r, c),
      );
      _clearPhotoFlowStatusSoon();
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.photo,
        ok: false,
        message: 'photo_cancelled',
      );
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: 'cancelled',
        error: 'cancelled',
      );
      _showActionSnack(
        'Cancelado por el usuario.',
        isError: true,
        icon: Icons.photo_outlined,
      );
      return;
    }
    if (outcome.blocked) {
      final msg = outcome.error ?? 'Bloqueado por el navegador.';
      _updatePhotoFlowStatus(
        'Destino ${_cellLabelRc(r, c)} · bloqueado',
        target: _CellTarget(r, c),
      );
      _clearPhotoFlowStatusSoon();
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.photo,
        ok: false,
        message: 'photo_blocked $msg',
      );
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: 'blocked',
        error: msg,
      );
      _showActionSnack(
        msg,
        isError: true,
        icon: Icons.photo_outlined,
      );
      return;
    }
    if (!outcome.ok) {
      final rawMsg = outcome.error ?? 'No se pudo obtener la foto.';
      final lower = rawMsg.toLowerCase();
      final readFail = lower.contains('empty_bytes') ||
          lower.contains('leer la imagen') ||
          lower.contains('leer los bytes');
      final userMsg = readFail ? _kPhotoReadErrorMsg : rawMsg;

      _updatePhotoFlowStatus(
        'Destino ${_cellLabelRc(r, c)} · ${readFail ? 'error lectura' : 'error foto'}',
        target: _CellTarget(r, c),
      );
      _clearPhotoFlowStatusSoon();
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.photo,
        ok: false,
        message: 'photo_error $rawMsg',
      );
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: readFail ? 'error_bytes' : 'error',
        error: rawMsg,
      );
      _showActionSnack(
        userMsg,
        isError: true,
        icon: Icons.photo_outlined,
      );
      return;
    }

    final result = outcome.result!;
    if (result.bytes.isEmpty) {
      _updatePhotoFlowStatus(
        'Destino ${_cellLabelRc(r, c)} · bytes vacíos',
        target: _CellTarget(r, c),
      );
      _clearPhotoFlowStatusSoon();
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.photo,
        ok: false,
        message: 'photo_error empty_bytes',
      );
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: 'error_bytes',
        error: 'empty_bytes',
      );
      _showActionSnack(
        _kPhotoReadErrorMsg,
        isError: true,
        icon: Icons.photo_outlined,
      );
      return;
    }

    final safeMime = result.mime.trim().isEmpty
        ? 'application/octet-stream'
        : result.mime.trim();

    final sniffedMime = sniffMime(result.bytes, name: result.name);
    final reportedMime = result.mime.trim();
    DiagnosticsLog.I.updatePhotoAttempt(
      stage: 'bytes_ready',
      fileName: result.name,
      sniffedMime: sniffedMime.isNotEmpty ? sniffedMime : null,
      reportedMime: reportedMime.isNotEmpty ? reportedMime : null,
      bytes: result.bytes.lengthInBytes,
    );
    _updatePhotoFlowStatus(
      'Destino ${_cellLabelRc(r, c)} · bytes listos (${_formatBytes(result.bytes.lengthInBytes)})',
      target: _CellTarget(r, c),
    );

    final attachmentId = _genAttachmentId('ph_');
    final cellKey = CellKey(r, c).toKey();
    StoredPhoto? stored;
    try {
      stored = await _photoStore.savePhoto(
        sheetId: widget.sheetId,
        cellKey: cellKey,
        attachmentId: attachmentId,
        bytes: result.bytes,
        originalName: result.name,
        mime: safeMime,
      );
    } catch (e, st) {
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: 'store_error',
        error: e.toString(),
        stack: st.toString(),
      );
      stored = null;
    }
    if (!mounted) return;

    var storedRef = '';
    if (stored != null) {
      storedRef = _photoStoredRefFrom(stored);
    }
    if (storedRef.trim().isEmpty) {
      storedRef = 'b64:${base64Encode(result.bytes)}';
    }
    if (storedRef.startsWith('mem:') ||
        stored == null ||
        storedRef.startsWith('b64:')) {
      _warnStorageFallbackOnce('foto');
    }

    final previewable = _isPreviewableMime(safeMime, result.name);
    final thumbBytes = previewable
        ? _compressThumb(result.bytes, maxW: 560, maxH: 560, quality: 78)
        : null;
    final storageLabel = storedRef.startsWith('key:')
        ? 'indexeddb'
        : (storedRef.startsWith('mem:')
            ? 'ram'
            : (storedRef.startsWith('b64:') ? 'b64' : 'unknown'));

    DiagnosticsLog.I.updatePhotoAttempt(
      stage: 'stored',
      storageMode: storageLabel,
      bytes: result.bytes.lengthInBytes,
    );
    _updatePhotoFlowStatus(
      'Destino ${_cellLabelRc(r, c)} · guardado (${storageLabel.toUpperCase()})',
      target: _CellTarget(r, c),
    );

    final thumbB64 = (thumbBytes == null || thumbBytes.isEmpty)
        ? ''
        : base64Encode(thumbBytes);

    final fixOutcome =
        await _getGpsFixWithFallback(timeout: const Duration(seconds: 8));
    if (!mounted) return;

    final attachment = PhotoAttachment(
      id: attachmentId,
      filename: result.name,
      mime: safeMime,
      size: result.bytes.lengthInBytes,
      storedRef: storedRef,
      thumbRef: thumbB64,
      addedAt: DateTime.now(),
      lat: fixOutcome.fix?.lat,
      lon: fixOutcome.fix?.lng,
      accuracyM: fixOutcome.fix?.accuracyM,
      isLastKnown: fixOutcome.fix?.source == 'lastKnown',
    );

    _addPhotoToCell(r, c, attachment);
    DiagnosticsLog.I.updatePhotoAttempt(
      stage: 'meta_attached',
      storageMode: storageLabel,
      previewable: previewable,
    );
    DiagnosticsLog.I.updatePhotoAttempt(
      stage: 'ui_refresh',
      storageMode: storageLabel,
      previewable: previewable,
    );
    final cellLabel = _cellLabelRc(r, c);
    DiagnosticsLog.I.record(
      type: DiagnosticActionType.photo,
      ok: true,
      message:
          'photo_saved cell=$cellLabel name=${result.name} size=${result.bytes.lengthInBytes} ref=$storedRef storage=$storageLabel',
    );
    final sizeLabel = _formatBytes(result.bytes.lengthInBytes);
    _showActionSnack(
      'Foto guardada en celda $cellLabel ($sizeLabel).',
      isError: false,
      icon: Icons.photo_outlined,
    );
    _updatePhotoFlowStatus(
      'Destino $cellLabel · guardada',
      target: _CellTarget(r, c),
    );
    _clearPhotoFlowStatusSoon();
  }

  void _addPhotoToCell(int r, int c, PhotoAttachment attachment) {
    final key = CellKey(r, c).toKey();
    final current = _cellMeta[key];
    final photos = <PhotoAttachment>[
      ...?current?.photos,
      attachment,
    ];
    final next = CellMeta(
      gps: current?.gps,
      photos: photos,
      audios: current?.audios ?? const <AudioAttachment>[],
    );
    _setCellMetaEntry(r, c, next, markDirty: true);
    _refreshCellAfterSave(r, c);
  }

  Future<void> _deletePhotoFromCell(int r, int c, int index) async {
    final key = CellKey(r, c).toKey();
    final current = _cellMeta[key];
    if (current == null) return;
    if (index < 0 || index >= current.photos.length) return;
    final photo = current.photos[index];
    final nextPhotos = List<PhotoAttachment>.from(current.photos)
      ..removeAt(index);
    final next = CellMeta(
      gps: current.gps,
      photos: nextPhotos,
      audios: current.audios,
    );
    _setCellMetaEntry(r, c, next, markDirty: true);
    _refreshCellAfterSave(r, c);

    final path = _photoPathFromRef(photo.storedRef);
    if (path.trim().isNotEmpty) {
      await _photoStore.deletePhoto(path);
    }
  }

  Future<void> _renamePhotoOnCell(
    BuildContext context,
    int r,
    int c,
    int index,
  ) async {
    final key = CellKey(r, c).toKey();
    final current = _cellMeta[key];
    if (current == null) return;
    if (index < 0 || index >= current.photos.length) return;

    final original = current.photos[index];
    final controller = TextEditingController(text: original.filename);
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final pal = _palette(ctx);
        return AlertDialog(
          backgroundColor: pal.menuBg,
          title: const Text('Renombrar foto'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nombre'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    final nextName = (picked ?? '').trim();
    if (nextName.isEmpty || nextName == original.filename) return;

    final updated = original.copyWith(filename: nextName);
    final nextPhotos = List<PhotoAttachment>.from(current.photos);
    nextPhotos[index] = updated;
    final next = CellMeta(
      gps: current.gps,
      photos: nextPhotos,
      audios: current.audios,
    );
    _setCellMetaEntry(r, c, next, markDirty: true);
    _refreshCellAfterSave(r, c);
  }

  Future<Uint8List?> _loadPhotoBytesFromAttachment(
    PhotoAttachment photo, {
    bool preferThumb = false,
  }) async {
    final path = _photoPathFromRef(photo.storedRef);
    final data = _photoDataFromRef(photo.storedRef);
    final thumb = photo.thumbRef;
    return PhotoBytesResolver.resolve(
      path: preferThumb ? '' : path,
      dataB64: preferThumb ? '' : data,
      thumbB64: thumb,
      readFromPath: _photoStore.readPhotoBytes,
      debugTag: photo.filename,
    );
  }

  bool _isPreviewableMime(String mime, String name) {
    final m = mime.toLowerCase();
    if (m.contains('png') ||
        m.contains('jpeg') ||
        m.contains('jpg') ||
        m.contains('webp') ||
        m.contains('gif')) {
      return true;
    }
    final n = name.toLowerCase();
    return n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.webp') ||
        n.endsWith('.gif');
  }

  bool _canPreviewPhoto(PhotoAttachment photo) {
    return _isPreviewableMime(photo.mime, photo.filename);
  }

  Future<void> _downloadPhotoAttachment(PhotoAttachment photo) async {
    final bytes = await _loadPhotoBytesFromAttachment(photo);
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      _showSnack('No se pudo descargar la foto.', isError: true);
      return;
    }
    final name = photo.filename.trim().isEmpty ? 'foto' : photo.filename.trim();
    final mime = photo.mime.trim().isEmpty
        ? 'application/octet-stream'
        : photo.mime.trim();
    await _saveExportBytes(name: name, mime: mime, bytes: bytes, share: false);
  }

  Future<void> _openPhotoPreview(
    BuildContext context,
    PhotoAttachment photo,
  ) async {
    final bytes = await _loadPhotoBytesFromAttachment(photo);
    if (!context.mounted) return;
    if (bytes == null || bytes.isEmpty) {
      _showSnack('No se pudo cargar la foto.', isError: true);
      return;
    }
    final previewable = _canPreviewPhoto(photo);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final pal = _palette(ctx);
        if (!previewable) {
          final mimeLabel = photo.mime.trim().isEmpty
              ? 'mime desconocido'
              : photo.mime.trim();
          return AlertDialog(
            backgroundColor: pal.menuBg,
            title: const Text('Adjunto guardado'),
            content: Text('Guardado sin vista previa (mime=$mimeLabel).'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cerrar'),
              ),
              TextButton(
                onPressed: () => unawaited(_downloadPhotoAttachment(photo)),
                child: const Text('Descargar'),
              ),
            ],
          );
        }
        final preview = kIsWeb
            ? Center(
                child: WebBlobImage(
                  bytes: bytes,
                  mime: photo.mime,
                  fit: BoxFit.contain,
                ),
              )
            : InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              );
        return Dialog(
          backgroundColor: pal.menuBg,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              preview,
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: Icon(Icons.close_rounded, color: pal.fg),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openPhotosSheetForCell(int r, int c) {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    final photos = _cellMetaAt(r, c)?.photos ?? const <PhotoAttachment>[];
    if (photos.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Fotos - ${CellKey(r, c).a1}',
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
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: photos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx2, idx) {
                      final p = photos[idx];
                      final previewable = _canPreviewPhoto(p);
                      final mimeLabel = p.mime.trim().isEmpty
                          ? 'mime desconocido'
                          : p.mime.trim();

                      Widget placeholderIcon() {
                        return Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: pal.cellBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: pal.border, width: pal.hairline),
                          ),
                          child: Icon(
                            previewable
                                ? Icons.photo_outlined
                                : Icons.insert_drive_file_outlined,
                            color: pal.fgMuted,
                          ),
                        );
                      }

                      Widget thumbWidget() {
                        if (!previewable) return placeholderIcon();
                        return FutureBuilder<Uint8List?>(
                          future: _loadPhotoBytesFromAttachment(p),
                          builder: (ctx3, snap) {
                            final bytes = snap.data;
                            if (bytes == null || bytes.isEmpty) {
                              return placeholderIcon();
                            }
                            final child = kIsWeb
                                ? WebBlobImage(
                                    bytes: bytes,
                                    mime: p.mime,
                                    fit: BoxFit.cover,
                                  )
                                : Image.memory(
                                    bytes,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.low,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox.shrink(),
                                  );
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child:
                                  SizedBox(width: 48, height: 48, child: child),
                            );
                          },
                        );
                      }

                      final title = p.filename.trim().isEmpty
                          ? 'Adjunto'
                          : p.filename.trim();
                      final subtitle = previewable
                          ? p.addedAt.toIso8601String()
                          : 'Guardado sin vista previa (mime=$mimeLabel)';

                      return InkWell(
                        onTap: () => unawaited(_openPhotoPreview(ctx2, p)),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: pal.headerBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: pal.border, width: pal.hairline),
                          ),
                          child: Row(
                            children: [
                              thumbWidget(),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: pal.fg,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        color: pal.fgMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    unawaited(_downloadPhotoAttachment(p)),
                                icon: Icon(Icons.download_rounded,
                                    color: pal.fgMuted),
                              ),
                              IconButton(
                                onPressed: () => unawaited(
                                    _renamePhotoOnCell(ctx2, r, c, idx)),
                                icon: Icon(Icons.edit_rounded,
                                    color: pal.fgMuted),
                              ),
                              IconButton(
                                onPressed: () {
                                  Navigator.of(ctx2).pop();
                                  unawaited(_deletePhotoFromCell(r, c, idx));
                                },
                                icon: Icon(Icons.delete_outline_rounded,
                                    color: pal.fgMuted),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

// ------------------------------ Audio -----------------------------------

  String _audioStoredRefFrom(StoredAudio stored) {
    final key = stored.storageKey.trim();
    if (key.isEmpty) return '';
    if (key.startsWith('file:') ||
        key.startsWith('key:') ||
        key.startsWith('mem:')) return key;
    final hasSlash = key.contains('\\') || key.contains('/');
    if (key.contains(':') && !hasSlash) return 'key:$key';
    return hasSlash ? 'file:$key' : 'key:$key';
  }

  String _audioKeyFromRef(String storedRef) {
    final raw = storedRef.trim();
    if (raw.startsWith('file:')) return raw.substring(5);
    if (raw.startsWith('mem:')) return raw;
    if (raw.startsWith('key:')) return raw.substring(4);
    return raw;
  }

  bool _audioIsFileRef(String storedRef) {
    final raw = storedRef.trim();
    if (raw.startsWith('file:')) return true;
    if (raw.startsWith('key:') || raw.startsWith('mem:')) return false;
    return raw.contains('\\') || raw.contains('/') || raw.contains(':');
  }

  String _formatDuration(Duration d) {
    final totalSec = d.inSeconds;
    final min = (totalSec ~/ 60).toString().padLeft(2, '0');
    final sec = (totalSec % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  String _audioStartErrorMessage(Object e) {
    final raw = e.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('notallowed') ||
        lower.contains('permission') ||
        lower.contains('denied')) {
      return 'Permiso de microfono denegado.';
    }
    if (lower.contains('notsupported') || lower.contains('not supported')) {
      return 'Grabacion de audio no disponible en este navegador.';
    }
    if (lower.contains('insecure') || lower.contains('secure')) {
      return 'Necesitas HTTPS para grabar audio.';
    }
    if (lower.contains('media') && lower.contains('devices')) {
      return 'MediaDevices no disponible.';
    }
    return 'No se pudo iniciar la grabacion de audio.';
  }

  Future<void> _startAudioRecordingForCell(int r, int c) async {
    if (_audioRecording) {
      final cell = _recordingAudioCell;
      final label = cell == null ? '' : _cellLabelRc(cell.row, cell.col);
      _showActionSnack(
        label.isEmpty
            ? 'Ya hay una grabacion en curso.'
            : 'Ya hay una grabacion en curso en celda $label.',
        isError: false,
        icon: Icons.mic_rounded,
      );
      return;
    }

    if (_guardInAppBrowser(DiagnosticActionType.audio)) return;
    if (_guardInsecureContext(DiagnosticActionType.audio)) return;

    try {
      await _audioService.startRecording(sheetId: widget.sheetId);
    } catch (e) {
      if (!mounted) return;
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.audio,
        ok: false,
        message: 'audio_start_failed $e',
      );
      _showActionSnack('No se pudo iniciar la grabacion de audio.',
          isError: true, icon: Icons.mic_off_rounded);
      return;
    }

    if (!mounted) return;
    setState(() {
      _audioRecording = true;
      _recordingAudioCell = CellKey(r, c);
    });
    final cellLabel = _cellLabelRc(r, c);
    _showActionSnack('Grabando audio en celda $cellLabel...',
        isError: false, icon: Icons.mic_rounded);
  }

  Future<void> _stopAudioRecording() async {
    if (!_audioRecording) return;
    final target = _recordingAudioCell;
    final recording = await _audioService.stopRecording();
    if (!mounted) return;

    setState(() {
      _audioRecording = false;
      _recordingAudioCell = null;
    });

    if (recording == null || target == null) {
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.audio,
        ok: false,
        message: 'audio_save_empty',
      );
      _showActionSnack('No se guardo el audio.',
          isError: true, icon: Icons.mic_off_rounded);
      return;
    }

    final attachmentId = _genAttachmentId('au_');
    final stored = await _audioStore.saveRecording(
      sheetId: widget.sheetId,
      cellKey: target.toKey(),
      attachmentId: attachmentId,
      recording: recording,
    );
    if (!mounted) return;
    if (stored == null) {
      DiagnosticsLog.I.record(
        type: DiagnosticActionType.audio,
        ok: false,
        message: 'audio_save_failed (storage returned null)',
      );
      _showActionSnack('No se pudo guardar el audio. Revisa permisos.',
          isError: true, icon: Icons.mic_off_rounded);
      return;
    }

    final storedRef = _audioStoredRefFrom(stored);
    if (storedRef.startsWith('mem:')) {
      _warnStorageFallbackOnce('audio');
    }

    final attachment = AudioAttachment(
      id: attachmentId,
      filename: recording.fileName,
      mime: recording.mime,
      size: stored.bytesLength,
      durationMs: recording.duration.inMilliseconds,
      storedRef: storedRef,
      addedAt: DateTime.now(),
    );

    _addAudioToCell(target.row, target.col, attachment);
    final cellLabel = _cellLabelRc(target.row, target.col);
    DiagnosticsLog.I.record(
      type: DiagnosticActionType.audio,
      ok: true,
      message:
          'audio_saved cell=$cellLabel name=${recording.fileName} size=${stored.bytesLength} ref=$storedRef',
    );
    _showActionSnack('Guardado en celda $cellLabel (audio).',
        isError: false, icon: Icons.mic_rounded);
  }

  void _addAudioToCell(int r, int c, AudioAttachment attachment) {
    final key = CellKey(r, c).toKey();
    final current = _cellMeta[key];
    final audios = <AudioAttachment>[
      ...?current?.audios,
      attachment,
    ];
    final next = CellMeta(
      gps: current?.gps,
      photos: current?.photos ?? const <PhotoAttachment>[],
      audios: audios,
    );
    _setCellMetaEntry(r, c, next, markDirty: true);
    _refreshCellAfterSave(r, c);
  }

  Future<void> _deleteAudioFromCell(int r, int c, int index) async {
    final key = CellKey(r, c).toKey();
    final current = _cellMeta[key];
    if (current == null) return;
    if (index < 0 || index >= current.audios.length) return;
    final audio = current.audios[index];
    final nextAudios = List<AudioAttachment>.from(current.audios)
      ..removeAt(index);
    final next = CellMeta(
      gps: current.gps,
      photos: current.photos,
      audios: nextAudios,
    );
    _setCellMetaEntry(r, c, next, markDirty: true);
    _refreshCellAfterSave(r, c);

    if (_playingAudioId == audio.id) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _playingAudioId = null);
    }

    final keyRef = _audioKeyFromRef(audio.storedRef);
    if (keyRef.trim().isNotEmpty) {
      await _audioStore.deleteAudio(keyRef);
    }
  }

  Future<void> _renameAudioOnCell(
    BuildContext context,
    int r,
    int c,
    int index,
  ) async {
    final key = CellKey(r, c).toKey();
    final current = _cellMeta[key];
    if (current == null) return;
    if (index < 0 || index >= current.audios.length) return;

    final original = current.audios[index];
    final controller = TextEditingController(text: original.filename);
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final pal = _palette(ctx);
        return AlertDialog(
          backgroundColor: pal.menuBg,
          title: const Text('Renombrar audio'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nombre'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    final nextName = (picked ?? '').trim();
    if (nextName.isEmpty || nextName == original.filename) return;

    final updated = original.copyWith(filename: nextName);
    final nextAudios = List<AudioAttachment>.from(current.audios);
    nextAudios[index] = updated;
    final next = CellMeta(
      gps: current.gps,
      photos: current.photos,
      audios: nextAudios,
    );
    _setCellMetaEntry(r, c, next, markDirty: true);
    _refreshCellAfterSave(r, c);
  }

  Future<void> _playAudioAttachment(AudioAttachment audio) async {
    if (_audioRecording) {
      _showSnack('Detén la grabación para reproducir.', isError: false);
      return;
    }

    if (_playingAudioId == audio.id) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _playingAudioId = null);
      return;
    }

    await _audioPlayer.stop();
    if (!mounted) return;

    final keyRef = _audioKeyFromRef(audio.storedRef);
    if (keyRef.trim().isEmpty) return;

    if (_audioIsFileRef(audio.storedRef) && !kIsWeb) {
      await _audioPlayer.play(DeviceFileSource(keyRef));
    } else {
      final bytes = await _audioStore.readAudioBytes(keyRef);
      if (bytes == null || bytes.isEmpty) return;
      await _audioPlayer.play(BytesSource(bytes));
    }

    if (!mounted) return;
    setState(() => _playingAudioId = audio.id);
  }

  void _openAudiosSheetForCell(int r, int c) {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    final audios = _cellMetaAt(r, c)?.audios ?? const <AudioAttachment>[];
    if (audios.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Audios - ${CellKey(r, c).a1}',
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
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: audios.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx2, idx) {
                      final a = audios[idx];
                      final playing = _playingAudioId == a.id;
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: pal.headerBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: pal.border, width: pal.hairline),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  unawaited(_playAudioAttachment(a)),
                              icon: Icon(
                                playing
                                    ? Icons.stop_circle_rounded
                                    : Icons.play_circle_fill_rounded,
                                color: pal.accent,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.filename,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: pal.fg,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDuration(
                                      Duration(milliseconds: a.durationMs),
                                    ),
                                    style: TextStyle(
                                      color: pal.fgMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => unawaited(
                                  _renameAudioOnCell(ctx2, r, c, idx)),
                              icon:
                                  Icon(Icons.edit_rounded, color: pal.fgMuted),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.of(ctx2).pop();
                                unawaited(_deleteAudioFromCell(r, c, idx));
                              },
                              icon: Icon(Icons.delete_outline_rounded,
                                  color: pal.fgMuted),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMobileHeaderMenu(
    BuildContext context,
    _SheetPalette pal,
  ) async {
    Future<void> runAndClose(VoidCallback action) async {
      Navigator.of(context).pop();
      action();
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: pal.menuBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: const Text('Guardar'),
                onTap: () => runAndClose(() => unawaited(_saveLocalNow())),
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: const Text('Exportar / Compartir'),
                onTap: () => runAndClose(() => unawaited(_openExportMenu())),
              ),
              ListTile(
                leading: const Icon(Icons.science_outlined),
                title: const Text('Smoke Test (GPS/Foto/Audio)'),
                onTap: () =>
                    runAndClose(() => unawaited(_runAttachmentSmokeTest())),
              ),
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: const Text('Agregar fila'),
                onTap: () => runAndClose(() => _insertRow(_rows.length)),
              ),
              ListTile(
                leading: const Icon(Icons.undo_rounded),
                title: const Text('Undo'),
                onTap: () => runAndClose(_undoOnce),
              ),
              ListTile(
                leading: const Icon(Icons.redo_rounded),
                title: const Text('Redo'),
                onTap: () => runAndClose(_redoOnce),
              ),
              ListTile(
                leading: Icon(pal.isLight
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined),
                title: Text(pal.isLight ? 'Modo noche' : 'Modo blanco'),
                onTap: () => runAndClose(_toggleTheme),
              ),
              ListTile(
                leading: const Icon(Icons.functions_rounded),
                title: Text(_engineHasBase ? 'Calcular' : 'Calcular (local)'),
                enabled: !_engineBusy,
                onTap: !_engineBusy
                    ? () => runAndClose(
                          () => unawaited(_computeEngine()),
                        )
                    : null,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Uint8List? _compressThumb(Uint8List bytes,
      {required int maxW, required int maxH, required int quality}) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final oriented = img.bakeOrientation(decoded);
      final resized = img.copyResize(
        oriented,
        width: oriented.width > oriented.height ? maxW : null,
        height: oriented.height >= oriented.width ? maxH : null,
        interpolation: img.Interpolation.average,
      );

      final jpg = img.encodeJpg(resized, quality: quality);
      return Uint8List.fromList(jpg);
    } catch (_) {
      return null;
    }
  }

// ------------------------------ Export/Share -----------------------------

  Future<void> _openExportMenu() async {
    if (!mounted) return;
    final pal = _palette(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: pal.menuBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      showDragHandle: true,
      builder: (ctx) {
        Future<void> runAndClose(Future<void> Function() fn) async {
          Navigator.of(ctx).pop();
          await fn();
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.table_view_rounded),
                title: const Text('Exportar XLSX'),
                onTap: () => runAndClose(_exportXlsxOnly),
              ),
              ListTile(
                leading: const Icon(Icons.folder_zip_rounded),
                title: const Text('Exportar ZIP (adjuntos)'),
                onTap: () => runAndClose(
                  () => _exportZipBundle(share: false),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: const Text('Compartir ZIP'),
                onTap: () => runAndClose(
                  () => _exportZipBundle(share: true),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportXlsxOnly() async {
    try {
      final prep = await _prepareExportPayload(includeZip: false);
      if (!mounted) return;

      final xlsxBytes = await _buildXlsxBytesForExport(
        embeddedPhotos: prep.embeddedPhotos,
        attachments: prep.attachments,
      );
      if (!mounted || xlsxBytes == null) return;

      final now = DateTime.now();
      final baseName =
          '${_safeFile(_sheetName)}_bitacora_pro_${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}';

      await _saveExportBytes(
        name: '$baseName.xlsx',
        mime:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        bytes: xlsxBytes,
        share: false,
      );
    } catch (_) {}
  }

  Future<void> _exportZipBundle({required bool share}) async {
    try {
      final prep = await _prepareExportPayload(includeZip: true);
      if (!mounted) return;

      final xlsxBytes = await _buildXlsxBytesForExport(
        embeddedPhotos: prep.embeddedPhotos,
        attachments: prep.attachments,
      );
      if (!mounted || xlsxBytes == null) return;

      final zipBytes = await _buildAttachmentsZip(
        xlsxBytes: xlsxBytes,
        photoItems: prep.photoItems,
        audioItems: prep.audioItems,
        manifest: prep.manifest,
      );
      if (!mounted || zipBytes == null) return;

      final now = DateTime.now();
      final baseName =
          '${_safeFile(_sheetName)}_bitacora_pro_${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}';

      await _saveExportBytes(
        name: '$baseName.zip',
        mime: 'application/zip',
        bytes: zipBytes,
        share: share,
      );
    } catch (_) {}
  }

  Future<Uint8List?> _buildXlsxBytesForExport({
    required List<EmbeddedPhoto> embeddedPhotos,
    required List<AttachmentRow> attachments,
  }) async {
    final dataCols = math.max(0, _headers.length - 1); // sin Photos
    final columns = List<String>.generate(dataCols, (i) => _headerLabel(i));
    final rows = <List<String>>[];
    for (final row in _rows) {
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

  Future<_ExportPrep> _prepareExportPayload({required bool includeZip}) async {
    final attachments = <AttachmentRow>[];
    final embeddedPhotos = <EmbeddedPhoto>[];
    final photoItems = <_ZipPhotoItem>[];
    final audioItems = <_ZipAudioItem>[];
    final manifestCells = <String, Map<String, dynamic>>{};
    final dataCols = math.max(0, _headers.length - 1);

    final entries = _cellMeta.entries.toList();
    entries.sort((a, b) {
      final ca = CellKey.fromKey(a.key);
      final cb = CellKey.fromKey(b.key);
      if (ca == null && cb == null) return 0;
      if (ca == null) return 1;
      if (cb == null) return -1;
      final r = ca.row.compareTo(cb.row);
      if (r != 0) return r;
      return ca.col.compareTo(cb.col);
    });

    for (final entry in entries) {
      final cell = CellKey.fromKey(entry.key);
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
          final photo = meta.photos[i];
          final fileName = _exportPhotoFileName(cellRef, photo, index: i + 1);
          final relPath = 'attachments/photos/$fileName';

          attachments.add(
            AttachmentRow(
              cellRef: cellRef,
              type: 'photo',
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
            manifestPhotos.add({
              'id': photo.id,
              'fileName': fileName,
              'mime': photo.mime,
              'size': photo.size,
              'path': relPath,
              'addedAt': photo.addedAt.toIso8601String(),
            });
          }
        }
        if (includeZip && manifestPhotos.isNotEmpty) {
          cellManifest['photos'] = manifestPhotos;
        }
      }

      if (meta.audios.isNotEmpty) {
        final manifestAudios = <Map<String, dynamic>>[];
        for (int i = 0; i < meta.audios.length; i++) {
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
            manifestAudios.add({
              'id': audio.id,
              'fileName': fileName,
              'mime': audio.mime,
              'size': audio.size,
              'durationMs': audio.durationMs,
              'path': relPath,
              'addedAt': audio.addedAt.toIso8601String(),
            });
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

    final manifest = includeZip
        ? <String, dynamic>{
            'sheet': {
              'name': _sheetName,
              'exportedAt': DateTime.now().toIso8601String(),
            },
            'cells': manifestCells,
          }
        : const <String, dynamic>{};

    return _ExportPrep(
      attachments: attachments,
      embeddedPhotos: embeddedPhotos,
      photoItems: photoItems,
      audioItems: audioItems,
      manifest: manifest,
    );
  }

  Future<Uint8List?> _buildAttachmentsZip({
    required Uint8List xlsxBytes,
    required List<_ZipPhotoItem> photoItems,
    required List<_ZipAudioItem> audioItems,
    required Map<String, dynamic> manifest,
  }) async {
    final archive = Archive();
    archive.addFile(ArchiveFile('Sheet.xlsx', xlsxBytes.length, xlsxBytes));

    for (final item in photoItems) {
      final bytes = await _loadPhotoBytesFromAttachment(item.photo);
      if (bytes == null || bytes.isEmpty) continue;
      archive.addFile(
        ArchiveFile(item.pathInZip, bytes.length, bytes),
      );
    }

    for (final item in audioItems) {
      final bytes = await _loadAudioBytesFromAttachment(item.audio);
      if (bytes == null || bytes.isEmpty) continue;
      archive.addFile(
        ArchiveFile(item.pathInZip, bytes.length, bytes),
      );
    }

    final manifestBytes = Uint8List.fromList(utf8.encode(jsonEncode(manifest)));
    archive.addFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    final encoder = ZipEncoder();
    final zipData = encoder.encode(archive);
    return Uint8List.fromList(zipData);
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
  }) async {
    final xf = XFile.fromData(bytes, name: name, mimeType: mime);

    if (kIsWeb) {
      try {
        await xf.saveTo(name);
        return;
      } catch (_) {}
    }

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      if (share) {
        try {
          await Share.shareXFiles([xf], subject: 'BitFlow Export');
          return;
        } catch (_) {}
      } else {
        try {
          await Share.shareXFiles([xf], subject: 'BitFlow Export');
          return;
        } catch (_) {}
      }
    }

    final typeGroup = XTypeGroup(
      label: 'Export',
      extensions: name.endsWith('.zip') ? const ['zip'] : const ['xlsx'],
    );
    final loc = await getSaveLocation(
        suggestedName: name, acceptedTypeGroups: [typeGroup]);
    if (loc == null) return;
    await xf.saveTo(loc.path);
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _safeFile(String s) {
    final t = s.trim().isEmpty ? 'Sheet' : s.trim();
    return t.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
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

    final cellLabel = _cellLabelRc(r, c);
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
    final storedPhoto = await _photoStore.savePhoto(
      sheetId: widget.sheetId,
      cellKey: CellKey(r, c).toKey(),
      attachmentId: phId,
      bytes: pngBytes,
      originalName: 'smoke.png',
      mime: 'image/png',
    );
    if (!mounted) return;

    String photoRef;
    if (storedPhoto != null) {
      photoRef = _photoStoredRefFrom(storedPhoto);
      if (photoRef.startsWith('mem:')) {
        _warnStorageFallbackOnce('foto');
      }
      photoOk = true;
    } else {
      photoRef = 'b64:${base64Encode(pngBytes)}';
      photoOk = true;
    }

    final thumbBytes =
        _compressThumb(pngBytes, maxW: 320, maxH: 320, quality: 70) ?? pngBytes;
    final photoAttachment = PhotoAttachment(
      id: phId,
      filename: 'smoke.png',
      mime: 'image/png',
      size: pngBytes.lengthInBytes,
      storedRef: photoRef,
      thumbRef: base64Encode(thumbBytes),
      addedAt: DateTime.now(),
    );
    _addPhotoToCell(r, c, photoAttachment);

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
      cellKey: CellKey(r, c).toKey(),
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
      _addAudioToCell(r, c, audioAttachment);
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
            normalized.add(_RowModel(cells: cells, photos: photos));
          }
        }

        setState(() {
          _rows = normalized.isNotEmpty ? normalized : _rows;
          _engineStatus = (map['message'] ?? 'Listo').toString();
          _engineStatusIsError = false;
          _isDirty = true;
          _rev++;
        });

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

class _PremiumAppleHeader extends StatelessWidget {
  const _PremiumAppleHeader({
    required this.palette,
    required this.titleController,
    required this.titleFocus,
    required this.savedText,
    required this.isDirty,
    required this.onTitleChanged,
    required this.onToggleTheme,
    required this.onUndo,
    required this.onRedo,
    required this.onAddRow,
    required this.onSave,
    required this.onExport,
    required this.onSmokeTest,
    required this.onCompute,
    required this.onGps,
    required this.onPhoto,
    required this.onAudio,
    required this.onShare,
    required this.onPalette,
    required this.onGpsMode,
    required this.onDensity,
    required this.sensorsEnabled,
  });

  final _SheetPalette palette;
  final bool sensorsEnabled;

  final TextEditingController titleController;
  final FocusNode titleFocus;
  final String savedText;
  final bool isDirty;

  final ValueChanged<String> onTitleChanged;

  final VoidCallback onToggleTheme;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onAddRow;

  final VoidCallback onSave;
  final VoidCallback onExport;
  final VoidCallback onSmokeTest;
  final VoidCallback? onCompute;

  final VoidCallback onGps;
  final VoidCallback onPhoto;
  final VoidCallback onAudio;
  final VoidCallback onShare;
  final VoidCallback onPalette;
  final VoidCallback onGpsMode;
  final VoidCallback onDensity;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final top = math.max(10.0, pad.top);

    final sigma = palette.isLight ? 14.0 : 12.0;

    final glassGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: palette.isLight
          ? [
              const Color(0xFFFFFFFF).withOpacity(0.88),
              const Color(0xFFF5F5F7).withOpacity(0.74),
            ]
          : [
              Colors.white.withOpacity(0.12),
              Colors.white.withOpacity(0.06),
            ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(14, top + 8, 14, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
                child: const SizedBox(),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: palette.headerCardBg,
                gradient: glassGradient,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                    color: palette.headerCardBorder, width: palette.hairline),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withOpacity(palette.isLight ? 0.10 : 0.55),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (ctx, cs) {
                  final compact = cs.maxWidth < 720;
                  final veryCompact = cs.maxWidth < 520;

                  final titleSize = veryCompact ? 30.0 : 34.0;
                  final pillGap = veryCompact ? 8.0 : 10.0;

                  final iconRow = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      _IconCircleButton(
                        palette: palette,
                        icon: palette.isLight
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        onTap: onToggleTheme,
                        tooltip: palette.isLight ? 'Modo noche' : 'Modo blanco',
                      ),
                      _IconCircleButton(
                        palette: palette,
                        icon: Icons.undo_rounded,
                        onTap: onUndo,
                        tooltip: 'Undo',
                      ),
                      _IconCircleButton(
                        palette: palette,
                        icon: Icons.redo_rounded,
                        onTap: onRedo,
                        tooltip: 'Redo',
                      ),
                      _IconCircleButton(
                        palette: palette,
                        icon: Icons.add_rounded,
                        onTap: onAddRow,
                        tooltip: 'Agregar fila',
                      ),
                    ],
                  );

                  final titleField = TextField(
                    controller: titleController,
                    focusNode: titleFocus,
                    onChanged: onTitleChanged,
                    maxLines: 1,
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w900,
                      height: 1.02,
                      letterSpacing: -0.6,
                    ),
                    cursorColor: palette.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Sheet',
                      hintStyle: TextStyle(color: palette.fgMuted),
                    ),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!compact)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: titleField),
                            const SizedBox(width: 10),
                            iconRow,
                          ],
                        )
                      else ...[
                        titleField,
                        const SizedBox(height: 10),
                        Align(alignment: Alignment.centerRight, child: iconRow),
                      ],
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            savedText,
                            style: TextStyle(
                              color: palette.fgMuted,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ),
                          ),
                          if (isDirty) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: palette.accent
                                    .withOpacity(palette.isLight ? 0.08 : 0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                    color: palette.accent.withOpacity(0.18),
                                    width: palette.hairline),
                              ),
                              child: Text(
                                'Dirty',
                                style: TextStyle(
                                  color: palette.accent.withOpacity(0.95),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  height: 1.05,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: pillGap,
                        runSpacing: 10,
                        children: [
                          _PillButton(
                            palette: palette,
                            filled: true,
                            icon: Icons.check_circle_outline_rounded,
                            label: 'Save',
                            onTap: onSave,
                          ),
                          _PillButton(
                            palette: palette,
                            filled: false,
                            icon: Icons.ios_share_rounded,
                            label: 'Export',
                            onTap: onExport,
                          ),
                          _PillButton(
                            palette: palette,
                            filled: false,
                            icon: Icons.science_outlined,
                            label: 'Smoke',
                            onTap: onSmokeTest,
                          ),
                          _PillButton(
                            palette: palette,
                            filled: false,
                            icon: Icons.functions_rounded,
                            label: 'Calcular',
                            onTap: onCompute,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppleToolbar(
                        items: [
                          AppleToolbarItem(
                            icon: Icons.my_location_rounded,
                            label: 'GPS',
                            shortcut: 'G',
                            onTap: onGps,
                            enabled: sensorsEnabled,
                            onDisabledTap: onGps,
                          ),
                          AppleToolbarItem(
                            icon: Icons.tune_rounded,
                            label: 'Modo GPS',
                            onTap: onGpsMode,
                          ),
                          AppleToolbarItem(
                            icon: Icons.format_line_spacing_rounded,
                            label: 'Densidad',
                            onTap: onDensity,
                          ),
                          AppleToolbarItem(
                            icon: Icons.photo_camera_outlined,
                            label: 'Camara',
                            shortcut: 'P',
                            onTap: onPhoto,
                            enabled: sensorsEnabled,
                            onDisabledTap: onPhoto,
                          ),
                          AppleToolbarItem(
                            icon: Icons.mic_none_rounded,
                            label: 'Audio',
                            shortcut: 'A',
                            onTap: onAudio,
                            enabled: sensorsEnabled,
                            onDisabledTap: onAudio,
                          ),
                          AppleToolbarItem(
                            icon: Icons.download_rounded,
                            label: 'Exportar',
                            shortcut: 'Ctrl/Cmd+E',
                            onTap: onExport,
                          ),
                          AppleToolbarItem(
                            icon: Icons.ios_share_rounded,
                            label: 'Compartir',
                            shortcut: 'Ctrl/Cmd+Shift+E',
                            onTap: onShare,
                          ),
                          AppleToolbarItem(
                            icon: Icons.keyboard,
                            label: 'Atajos',
                            shortcut: 'Ctrl/Cmd+K',
                            onTap: onPalette,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(palette.isLight ? 0.18 : 0.12),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.35],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileCompactHeader extends StatelessWidget {
  const _MobileCompactHeader({
    required this.palette,
    required this.title,
    required this.savedText,
    required this.isDirty,
    required this.pendingRequired,
    required this.onSave,
    required this.onExport,
    required this.onMenu,
  });

  final _SheetPalette palette;
  final String title;
  final String savedText;
  final bool isDirty;
  final int pendingRequired;
  final VoidCallback onSave;
  final VoidCallback onExport;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final label = title.trim().isEmpty ? 'Sheet' : title.trim();
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.appBarBg,
        border: Border(
          bottom:
              BorderSide(color: palette.borderStrong, width: palette.hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.fg,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      savedText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.fgMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        height: 1.05,
                      ),
                    ),
                    if (isDirty) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: palette.accent.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    if (pendingRequired > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.4), width: 1),
                        ),
                        child: Text(
                          'Pend: $pendingRequired',
                          style: TextStyle(
                            color: Colors.red.withOpacity(0.85),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Guardar',
            onPressed: onSave,
            icon: Icon(Icons.check_circle_outline_rounded, color: palette.fg),
            splashRadius: 18,
          ),
          IconButton(
            tooltip: 'Exportar',
            onPressed: onExport,
            icon: Icon(Icons.ios_share_rounded, color: palette.fg),
            splashRadius: 18,
          ),
          IconButton(
            tooltip: 'Más',
            onPressed: onMenu,
            icon: Icon(Icons.more_horiz_rounded, color: palette.fg),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({
    required this.palette,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final _SheetPalette palette;
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.pillBtnBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: palette.pillBtnBorder, width: palette.hairline),
          ),
          child: Icon(icon, size: 18, color: palette.fg),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.palette,
    required this.filled,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final _SheetPalette palette;
  final bool filled;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    final bg = filled
        ? (palette.isLight ? const Color(0xFF0B0B0C) : const Color(0xFFFFFFFF))
        : palette.pillBtnBg;

    final fg = filled
        ? (palette.isLight ? const Color(0xFFFFFFFF) : const Color(0xFF0B0B0C))
        : palette.fg;

    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: palette.pillBtnBorder, width: palette.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================== UI: Grid ==================================

typedef _SelectCell = void Function(int r, int c);
typedef _EditCell = void Function(int r, int c, double cellWidth);
typedef _EditHeader = void Function(int c, double headerWidth);
typedef _ContextMenu = void Function(Offset pos, int r, int c, bool isHeader);

class _GridMetrics {
  const _GridMetrics({
    required this.rowH,
    required this.headerH,
    required this.cellPadding,
    required this.headerPadding,
    required this.cellFontSize,
    required this.headerFontSize,
    required this.indexFontSize,
  });

  final double rowH;
  final double headerH;
  final EdgeInsets cellPadding;
  final EdgeInsets headerPadding;
  final double cellFontSize;
  final double headerFontSize;
  final double indexFontSize;
}

_GridMetrics _gridMetricsFor(_GridDensity density) {
  switch (density) {
    case _GridDensity.compact:
      return const _GridMetrics(
        rowH: 55,
        headerH: 50,
        cellPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        headerPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        cellFontSize: 13.6,
        headerFontSize: 13.0,
        indexFontSize: 12.3,
      );
    case _GridDensity.roomy:
      return const _GridMetrics(
        rowH: 68,
        headerH: 62,
        cellPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        headerPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        cellFontSize: 15.6,
        headerFontSize: 14.6,
        indexFontSize: 13.8,
      );
    case _GridDensity.normal:
    default:
      return const _GridMetrics(
        rowH: 62,
        headerH: 57,
        cellPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        headerPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        cellFontSize: 15.0,
        headerFontSize: 14.2,
        indexFontSize: 13.4,
      );
  }
}

class _GridView extends StatelessWidget {
  const _GridView({
    required this.palette,
    required this.metrics,
    required this.headers,
    required this.rowModels,
    required this.cellTextAt,
    required this.cellHasGps,
    required this.cellHasAudios,
    required this.cellPhotoThumb,
    required this.cellPhotoCount,
    required this.isInvalid,
    required this.vScroll,
    required this.hScroll,
    required this.selRow,
    required this.selCol,
    required this.blink,
    required this.editorLink,
    required this.overlayTargetCell,
    required this.overlayTargetHeaderCol,
    required this.onSelect,
    required this.onEditRequested,
    required this.onHeaderEditRequested,
    required this.onContextMenu,
    required this.onDeleteRow,
    required this.onPickPhoto,
  });

  final _SheetPalette palette;
  final _GridMetrics metrics;
  final List<String> headers;
  final List<_RowModel> rowModels;
  final String Function(int r, int c) cellTextAt;
  final bool Function(int r, int c) cellHasGps;
  final bool Function(int r, int c) cellHasAudios;
  final String Function(int r, int c) cellPhotoThumb;
  final int Function(int r, int c) cellPhotoCount;
  final bool Function(int r, int c) isInvalid;

  final ScrollController vScroll;
  final ScrollController hScroll;

  final int selRow;
  final int selCol;

  final ValueListenable<_CellRef?> blink;

  final LayerLink editorLink;
  final _CellRef? overlayTargetCell;
  final int? overlayTargetHeaderCol;

  final _SelectCell onSelect;
  final _EditCell onEditRequested;
  final _EditHeader onHeaderEditRequested;
  final _ContextMenu onContextMenu;

  final ValueChanged<int> onDeleteRow;
  final ValueChanged<int> onPickPhoto;

// ??? Apple-ish sizing
  static const double indexW = 54;

  @override
  Widget build(BuildContext context) {
// ??? FIX: un solo listener para blink (evita ValueListenableBuilder por celda).
    return ValueListenableBuilder<_CellRef?>(
      valueListenable: blink,
      builder: (ctx, blinkRef, _) {
        final colW = _idealColWidth(context);
        const photosW = 140.0;

        final totalW = indexW + (headers.length - 1) * colW + photosW;

        return LayoutBuilder(
          builder: (ctx2, c) {
            final viewSize = MediaQuery.sizeOf(ctx2);
            final safeH = (c.hasBoundedHeight && c.maxHeight.isFinite)
                ? c.maxHeight
                : viewSize.height;

            return Container(
              color: palette.bg,
              child: SingleChildScrollView(
                controller: hScroll,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: totalW,
                  height: safeH,
                  child: Column(
                    children: [
                      SizedBox(
                        height: metrics.headerH,
                        child: Row(
                          children: [
                            _rowIndexHeader(width: indexW),
                            for (int col = 0; col < headers.length; col++)
                              _HeaderCell(
                                palette: palette,
                                metrics: metrics,
                                width:
                                    col == headers.length - 1 ? photosW : colW,
                                text: _labelHeader(headers, col),
                                isPhotos: col == headers.length - 1,
                                isOverlayTarget: overlayTargetHeaderCol == col,
                                editorLink: editorLink,
                                onTap: () => onHeaderEditRequested(
                                  col,
                                  col == headers.length - 1 ? photosW : colW,
                                ),
                                onSecondaryTapDown: (d) => onContextMenu(
                                    d.globalPosition, -1, col, true),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Scrollbar(
                          controller: vScroll,
                          thumbVisibility: false,
                          child: ListView.builder(
                            controller: vScroll,
                            physics: const BouncingScrollPhysics(),
                            itemCount: rowModels.length,
                            itemBuilder: (ctx3, r) {
                              return SizedBox(
                                height: metrics.rowH,
                                child: Row(
                                  children: [
                                    _RowIndexCell(
                                      palette: palette,
                                      metrics: metrics,
                                      width: indexW,
                                      index: r + 1,
                                      selected: r == selRow,
                                      onTap: () => onSelect(r, selCol),
                                      onSecondaryTapDown: (d) => onContextMenu(
                                          d.globalPosition, r, selCol, false),
                                    ),
                                    for (int col = 0;
                                        col < headers.length;
                                        col++)
                                      Builder(
                                        builder: (_) {
                                          final ref = _CellRef(r, col);
                                          final invalid = isInvalid(r, col);
                                          final isPhotos =
                                              col == headers.length - 1;
                                          final photosCount =
                                              cellPhotoCount(r, col);
                                          final thumbB64 =
                                              cellPhotoThumb(r, col);
                                          return _DataCell(
                                            palette: palette,
                                            metrics: metrics,
                                            width: col == headers.length - 1
                                                ? photosW
                                                : colW,
                                            text: cellTextAt(r, col),
                                            hasGps: cellHasGps(r, col),
                                            hasAudio: cellHasAudios(r, col),
                                            photoThumbB64: thumbB64,
                                            photosCount: photosCount,
                                            zebra: r.isEven,
                                            thumbB64: thumbB64,
                                            selected:
                                                r == selRow && col == selCol,
                                            isPhotos: isPhotos,
                                            blinkRef: blinkRef,
                                            cellRef: ref,
                                            invalid: invalid,
                                            isOverlayTarget:
                                                overlayTargetCell == ref,
                                            editorLink: editorLink,
                                            onTap: () => onEditRequested(
                                              r,
                                              col,
                                              col == headers.length - 1
                                                  ? photosW
                                                  : colW,
                                            ),
                                            onLongPress: () {
                                              onSelect(r, col);
                                              final box =
                                                  ctx3.findRenderObject();
                                              if (box is RenderBox) {
                                                final pos = box
                                                    .localToGlobal(Offset.zero);
                                                onContextMenu(
                                                  pos + const Offset(120, 12),
                                                  r,
                                                  col,
                                                  false,
                                                );
                                              }
                                            },
                                            onSecondaryTapDown: (d) {
                                              onSelect(r, col);
                                              onContextMenu(d.globalPosition, r,
                                                  col, false);
                                            },
                                            onDeleteRow: () => onDeleteRow(r),
                                            onPickPhoto: () => onPickPhoto(r),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _idealColWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 420) return 126;
    if (w < 760) return 150;
    return 178;
  }

  String _labelHeader(List<String> headers, int c) {
    final t = headers[c].trim();
    if (t.isNotEmpty) return t;
    if (c == headers.length - 1) return kPhotosHeader;
    return 'Col ${c + 1}';
  }

  Widget _rowIndexHeader({required double width}) {
    return Container(
      width: width,
      height: metrics.headerH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.headerBg,
        border: Border(
          right:
              BorderSide(color: palette.borderStrong, width: palette.hairline),
          bottom:
              BorderSide(color: palette.borderStrong, width: palette.hairline),
        ),
      ),
      child: Text('#',
          style: TextStyle(
            color: palette.fgMuted,
            fontWeight: FontWeight.w900,
            fontSize: metrics.indexFontSize,
          )),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.palette,
    required this.metrics,
    required this.width,
    required this.text,
    required this.isPhotos,
    required this.isOverlayTarget,
    required this.editorLink,
    required this.onTap,
    required this.onSecondaryTapDown,
  });

  final _SheetPalette palette;
  final _GridMetrics metrics;
  final double width;
  final String text;
  final bool isPhotos;

  final bool isOverlayTarget;
  final LayerLink editorLink;

  final VoidCallback onTap;
  final ValueChanged<TapDownDetails> onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    final t =
        text.trim().isEmpty ? (isPhotos ? kPhotosHeader : '') : text.trim();
    final radius = BorderRadius.circular(12);
    final borderColor =
        palette.borderStrong.withOpacity(palette.isLight ? 0.55 : 0.45);

    final cell = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: palette.headerBg,
            borderRadius: radius,
            border: Border(
              right: BorderSide(color: borderColor, width: palette.hairline),
              bottom: BorderSide(color: borderColor, width: palette.hairline),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            hoverColor: palette.hoverBg,
            splashColor: palette.pressedBg,
            borderRadius: radius,
            child: Container(
              width: width,
              height: metrics.headerH,
              padding: metrics.headerPadding,
              alignment: Alignment.centerLeft,
              child: Text(
                t.isEmpty ? ' ' : t,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.fg,
                  fontWeight: FontWeight.w800,
                  fontSize: metrics.headerFontSize,
                  height: 1.05,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!isOverlayTarget) return cell;
    return CompositedTransformTarget(link: editorLink, child: cell);
  }
}

class _RowIndexCell extends StatelessWidget {
  const _RowIndexCell({
    required this.palette,
    required this.metrics,
    required this.width,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.onSecondaryTapDown,
  });

  final _SheetPalette palette;
  final _GridMetrics metrics;
  final double width;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<TapDownDetails> onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    final neutralRing = palette.isLight
        ? Colors.black.withOpacity(0.12)
        : Colors.white.withOpacity(0.18);

    final glow = palette.accent.withOpacity(palette.isLight ? 0.10 : 0.18);
    final bg = selected
        ? palette.accent.withOpacity(palette.isLight ? 0.08 : 0.18)
        : palette.indexBg;
    final radius = BorderRadius.circular(10);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border(
              right: BorderSide(
                  color: palette.borderStrong, width: palette.hairline),
              bottom:
                  BorderSide(color: palette.border, width: palette.hairline),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: glow,
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    )
                  ]
                : null,
          ),
          child: InkWell(
            onTap: onTap,
            hoverColor: palette.hoverBg,
            splashColor: palette.pressedBg,
            borderRadius: radius,
            child: Container(
              width: width,
              height: metrics.rowH,
              alignment: Alignment.center,
              foregroundDecoration: selected
                  ? BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                          color: neutralRing,
                          width: math.max(palette.hairline, 1.2)),
                    )
                  : null,
              child: Text(
                index.toString(),
                style: TextStyle(
                  color: selected ? palette.fg : palette.fgMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: metrics.indexFontSize,
                  height: 1.05,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  const _DataCell({
    required this.palette,
    required this.metrics,
    required this.width,
    required this.text,
    required this.hasGps,
    required this.hasAudio,
    required this.photoThumbB64,
    required this.photosCount,
    required this.zebra,
    required this.thumbB64,
    required this.selected,
    required this.invalid,
    required this.isPhotos,
    required this.blinkRef,
    required this.cellRef,
    required this.isOverlayTarget,
    required this.editorLink,
    required this.onTap,
    required this.onLongPress,
    required this.onSecondaryTapDown,
    required this.onDeleteRow,
    required this.onPickPhoto,
  });

  final _SheetPalette palette;
  final _GridMetrics metrics;
  final double width;
  final String text;
  final bool hasGps;
  final bool hasAudio;
  final String photoThumbB64;
  final int photosCount;
  final bool zebra;
  final String thumbB64;
  final bool selected;
  final bool invalid;
  final bool isPhotos;

  final _CellRef? blinkRef;
  final _CellRef cellRef;

  final bool isOverlayTarget;
  final LayerLink editorLink;

  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<TapDownDetails> onSecondaryTapDown;

  final VoidCallback onDeleteRow;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    final isActive = blinkRef == cellRef;
    final focus = selected || isOverlayTarget;
    final baseBg = zebra ? palette.zebraBg : palette.cellBg;
    final selectedBg =
        palette.accent.withOpacity(palette.isLight ? 0.10 : 0.18);
    final bg = isActive ? palette.blinkBg : (selected ? selectedBg : baseBg);

    final borderColor = invalid
        ? Colors.red.withOpacity(palette.isLight ? 0.85 : 0.75)
        : focus
            ? palette.accent.withOpacity(palette.isLight ? 0.45 : 0.65)
            : palette.border.withOpacity(palette.isLight ? 0.55 : 0.40);

    final radius = BorderRadius.circular(10);

    final decoration = BoxDecoration(
      color: bg,
      borderRadius: radius,
      border: Border.all(
          color: borderColor, width: math.max(palette.hairline, 0.8)),
      boxShadow: focus
          ? [
              BoxShadow(
                color:
                    palette.accent.withOpacity(palette.isLight ? 0.10 : 0.16),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withOpacity(palette.isLight ? 0.03 : 0.16),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
    );

    final cellBody = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            hoverColor: palette.hoverBg,
            splashColor: palette.pressedBg,
            borderRadius: radius,
            child: Container(
              width: width,
              height: metrics.rowH,
              padding: metrics.cellPadding,
              child: _buildCellBody(context),
            ),
          ),
        ),
      ),
    );

    if (!isOverlayTarget) return cellBody;
    return CompositedTransformTarget(link: editorLink, child: cellBody);
  }

  Widget _badge(Widget child) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: palette.accent.withOpacity(palette.isLight ? 0.12 : 0.20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: palette.accent.withOpacity(0.35),
          width: palette.hairline,
        ),
      ),
      child: child,
    );
  }

  Widget _buildCellBody(BuildContext context) {
    final content = isPhotos
        ? _PhotosCell(
            palette: palette,
            count: photosCount,
            thumbB64: thumbB64,
            onAdd: onPickPhoto,
            onDeleteRow: onDeleteRow,
          )
        : Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text.trim().isEmpty ? ' ' : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.fg,
                fontSize: metrics.cellFontSize,
                height: 1.1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          );

    final badges = <Widget>[];
    if (!isPhotos && (photoThumbB64.trim().isNotEmpty || photosCount > 0)) {
      final bytes = _tryDecodeB64(photoThumbB64);
      if (bytes != null) {
        badges.add(
          _badge(
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Image.memory(
                bytes,
                width: 12,
                height: 12,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
              ),
            ),
          ),
        );
      } else if (photosCount > 0) {
        badges.add(
          _badge(
            Icon(
              Icons.photo_rounded,
              size: 12,
              color: palette.accent.withOpacity(0.8),
            ),
          ),
        );
      }
    }
    if (hasAudio) {
      badges.add(
        _badge(
          Icon(
            Icons.graphic_eq_rounded,
            size: 12,
            color: palette.accent.withOpacity(0.8),
          ),
        ),
      );
    }
    if (hasGps) {
      badges.add(
        _badge(
          Icon(
            Icons.my_location_rounded,
            size: 12,
            color: palette.accent.withOpacity(0.8),
          ),
        ),
      );
    }

    if (badges.isEmpty) return content;

    return Stack(
      children: [
        content,
        Positioned(
          top: 2,
          right: 2,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < badges.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                badges[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotosCell extends StatelessWidget {
  const _PhotosCell({
    required this.palette,
    required this.count,
    required this.thumbB64,
    required this.onAdd,
    required this.onDeleteRow,
  });

  final _SheetPalette palette;
  final int count;
  final String thumbB64;
  final VoidCallback onAdd;
  final VoidCallback onDeleteRow;

  @override
  Widget build(BuildContext context) {
    final thumbBytes = _tryDecodeB64(thumbB64);
    final hasThumb = thumbBytes != null;
    return Row(
      children: [
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Icon(Icons.add_photo_alternate_outlined,
                size: 18, color: palette.fg),
          ),
        ),
        const SizedBox(width: 6),
        if (hasThumb)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(
              thumbBytes!,
              width: 26,
              height: 26,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
            ),
          ),
        if (hasThumb) const SizedBox(width: 6),
        Expanded(
          child: Text(
            count == 0 ? '0' : '$count',
            style: TextStyle(
                color: palette.fg, fontWeight: FontWeight.w900, height: 1.05),
          ),
        ),
        InkWell(
          onTap: onDeleteRow,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Icon(Icons.delete_outline_rounded,
                size: 18, color: palette.fgMuted),
          ),
        ),
      ],
    );
  }
}

// ============================== UI: Status =================================

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.text, required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(text,
          style:
              TextStyle(color: fg, fontWeight: FontWeight.w900, height: 1.05)),
    );
  }
}

class _MobileQuickActionsBar extends StatelessWidget {
  const _MobileQuickActionsBar({
    required this.palette,
    required this.sensorsEnabled,
    required this.onGps,
    required this.onPhoto,
    required this.onAudio,
    required this.onExport,
    required this.onShare,
    required this.onDensity,
  });

  final _SheetPalette palette;
  final bool sensorsEnabled;
  final VoidCallback onGps;
  final VoidCallback onPhoto;
  final VoidCallback onAudio;
  final VoidCallback onExport;
  final VoidCallback onShare;
  final VoidCallback onDensity;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final bg =
        t.colors.surfaceElevated.withOpacity(palette.isLight ? 0.92 : 0.78);

    return AppleCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      radius: t.radii.xl,
      color: bg,
      borderColor: t.colors.border,
      shadows: t.shadows.soft,
      child: SizedBox(
        height: _kMobileQuickBarH,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              AppleButton(
                icon: Icons.my_location_rounded,
                label: 'GPS',
                dense: true,
                onPressed: onGps,
                enabled: sensorsEnabled,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.photo_camera_outlined,
                label: 'Camara',
                dense: true,
                onPressed: onPhoto,
                enabled: sensorsEnabled,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.mic_none_rounded,
                label: 'Audio',
                dense: true,
                onPressed: onAudio,
                enabled: sensorsEnabled,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.format_line_spacing_rounded,
                label: 'Densidad',
                dense: true,
                onPressed: onDensity,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.download_rounded,
                label: 'Exportar',
                dense: true,
                onPressed: onExport,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.ios_share_rounded,
                label: 'Compartir',
                dense: true,
                onPressed: onShare,
                variant: AppleButtonVariant.tonal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ========================= Mobile inline editor bar ========================

class _MobileInlineEditorBar extends StatelessWidget {
  const _MobileInlineEditorBar({
    required this.palette,
    required this.density,
    required this.barKey,
    required this.fieldKey,
    required this.isOpen,
    required this.title,
    required this.controller,
    required this.focusNode,
    required this.actions,
    required this.keyboardInset,
    required this.panelHeight,
    required this.canCopyPaste,
    required this.onGpsRow,
    required this.onPrev,
    required this.onNext,
    required this.onCopy,
    required this.onPaste,
    required this.onOverflow,
    required this.onCancel,
    required this.onDone,
  });

  final _SheetPalette palette;
  final _GridDensity density;
  final Key barKey;
  final Key fieldKey;
  final bool isOpen;
  final String title;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<_MobileAction> actions;

// inset real de teclado (dp)
  final double keyboardInset;
  final double panelHeight;
  final bool canCopyPaste;
  final VoidCallback? onGpsRow;

  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onOverflow;

  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final bindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.escape): onCancel,
      const SingleActivator(LogicalKeyboardKey.enter, meta: true): onDone,
      const SingleActivator(LogicalKeyboardKey.enter, control: true): onDone,
      if (onNext != null)
        const SingleActivator(LogicalKeyboardKey.tab): onNext!,
      if (onPrev != null)
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): onPrev!,
    };

// ??? iOS Web: 0 exacto puede hacer que Safari ???no considere??? el input visible.
    final opacity = isOpen ? 1.0 : 0.01;

    final label = title.trim().isEmpty ? 'Editar' : title.trim();
    final metrics = _gridMetricsFor(density);
    final editorFont = (metrics.cellFontSize + 2).clamp(13.0, 17.0);
    final hPad = math.max(10.0, metrics.cellPadding.horizontal / 2);
    final vPad = math.max(10.0, metrics.cellPadding.vertical / 2);
    final editorPadding =
        EdgeInsets.symmetric(horizontal: hPad, vertical: vPad);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SafeArea(
          top: false,
          bottom: true,
          child: AbsorbPointer(
            absorbing: !isOpen,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              opacity: opacity,
              child: CallbackShortcuts(
                bindings: bindings,
                child: Container(
                  key: barKey,
                  height: panelHeight,
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: BoxDecoration(
                    color: palette.appBarBg,
                    border: Border(
                      top: BorderSide(
                          color: palette.borderStrong, width: palette.hairline),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: palette.isLight ? 10 : 14,
                        sigmaY: palette.isLight ? 10 : 14,
                        tileMode: TileMode.decal,
                      ),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        decoration: BoxDecoration(
                          color: palette.editorBg
                              .withOpacity(palette.isLight ? 0.96 : 0.70),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: palette.borderStrong,
                              width: palette.hairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.fgMuted,
                                      fontWeight: FontWeight.w900,
                                      fontSize: metrics.headerFontSize,
                                      height: 1.05,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                                _MobilePanelIconButton(
                                  icon: Icons.chevron_left_rounded,
                                  tooltip: 'Anterior',
                                  onTap: onPrev,
                                  palette: palette,
                                  iconSize: 18,
                                  splashRadius: 16,
                                  padding: const EdgeInsets.all(4),
                                ),
                                _MobilePanelIconButton(
                                  icon: Icons.chevron_right_rounded,
                                  tooltip: 'Siguiente',
                                  onTap: onNext,
                                  palette: palette,
                                  iconSize: 18,
                                  splashRadius: 16,
                                  padding: const EdgeInsets.all(4),
                                ),
                                _MobilePanelIconButton(
                                  icon: Icons.check_rounded,
                                  tooltip: 'Done',
                                  onTap: onDone,
                                  palette: palette,
                                  iconSize: 18,
                                  splashRadius: 16,
                                  padding: const EdgeInsets.all(4),
                                ),
                                _MobilePanelIconButton(
                                  icon: Icons.more_horiz_rounded,
                                  tooltip: 'Acciones',
                                  onTap: onOverflow,
                                  palette: palette,
                                  iconSize: 18,
                                  splashRadius: 16,
                                  padding: const EdgeInsets.all(4),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 46,
                              child: KeyedSubtree(
                                key: fieldKey,
                                child: _MobileEditorField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  palette: palette,
                                  onNext: onNext,
                                  onDone: onDone,
                                  fontSize: editorFont,
                                  contentPadding: editorPadding,
                                ),
                              ),
                            ),
                            // Acciones solo via overflow sheet
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobilePanelIconButton extends StatelessWidget {
  const _MobilePanelIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.palette,
    this.iconSize = 20,
    this.splashRadius = 18,
    this.padding = const EdgeInsets.all(6),
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final _SheetPalette palette;
  final double iconSize;
  final double splashRadius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = enabled ? palette.fg : palette.fgMuted.withOpacity(0.5);
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: fg, size: iconSize),
      padding: padding,
      splashRadius: splashRadius,
    );
  }
}

class _MobileEditorField extends StatelessWidget {
  const _MobileEditorField({
    required this.controller,
    required this.focusNode,
    required this.palette,
    required this.onNext,
    required this.onDone,
    required this.fontSize,
    required this.contentPadding,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final _SheetPalette palette;
  final VoidCallback? onNext;
  final VoidCallback onDone;
  final double fontSize;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: false,
      minLines: 1,
      maxLines: 2,
      enabled: true,
      textAlignVertical: TextAlignVertical.center,
      textInputAction:
          onNext == null ? TextInputAction.done : TextInputAction.next,
      keyboardAppearance: palette.isLight ? Brightness.light : Brightness.dark,
      scrollPadding: EdgeInsets.zero,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      style: TextStyle(
        color: palette.fg,
        fontSize: fontSize,
        height: 1.08,
        fontWeight: FontWeight.w800, // ??? nitidez
        letterSpacing: -0.15,
      ),
      cursorColor: palette.accent,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
// ??? dark: vidrio visible
        fillColor: palette.mobileInputBg,
        contentPadding: contentPadding,
        hintText: 'Escribir???',
        hintStyle: TextStyle(color: palette.fgMuted),
        border: InputBorder.none,
      ),
      onSubmitted: (_) => onNext == null ? onDone() : onNext!(),
    );
  }
}

class _MobileAction {
  const _MobileAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _EngineConfig {
  const _EngineConfig({required this.baseUrl, required this.apiKey});
  final String? baseUrl;
  final String? apiKey;
}

class _EngineErrorDetails {
  const _EngineErrorDetails({
    required this.message,
    this.statusCode,
    this.isCors = false,
    this.isTimeout = false,
  });

  final String message;
  final int? statusCode;
  final bool isCors;
  final bool isTimeout;

  @override
  String toString() =>
      'EngineErrorDetails(message: $message, statusCode: $statusCode, cors: $isCors, timeout: $isTimeout)';
}

class _EngineComputeOutcome {
  const _EngineComputeOutcome({
    required this.ok,
    required this.hadUpdates,
    this.errorDetails,
  });

  final bool ok;
  final bool hadUpdates;
  final _EngineErrorDetails? errorDetails;
}

// ============================== Modelo =====================================

class _SheetModel {
  _SheetModel({
    required this.headers,
    required this.rows,
    this.name,
    this.savedAt,
    this.cellMeta = const <String, CellMeta>{},
  });

  final String? name;
  final DateTime? savedAt;
  final List<String> headers;
  final List<_RowModel> rows;
  final Map<String, CellMeta> cellMeta;

  Map<String, dynamic> toJson() => {
        'name': name,
        'savedAt': savedAt?.toIso8601String(),
        'headers': headers,
        'rows': rows.map((r) => r.toJson()).toList(),
        if (cellMeta.isNotEmpty)
          'cellMeta': cellMeta.map(
            (key, value) => MapEntry(key, value.toJson()),
          ),
      };

  static _SheetModel fromJson(Map<String, dynamic> map) {
    final name = (map['name'] as String?)?.toString();
    final savedAt = DateTime.tryParse((map['savedAt'] ?? '').toString());

    final headers =
        (map['headers'] as List?)?.map((e) => (e ?? '').toString()).toList() ??
            const <String>[];

    final rowsRaw = (map['rows'] as List?) ?? const [];
    final rowModels = <_RowModel>[];

    for (final it in rowsRaw) {
      if (it is Map) {
        rowModels.add(_RowModel.fromJson(it.cast<String, dynamic>()));
      } else if (it is List) {
        final cells = it.map((e) => (e ?? '').toString()).toList();
        rowModels.add(_RowModel.fromCells(cells));
      }
    }

    final metaRaw = map['cellMeta'];
    final cellMeta = <String, CellMeta>{};
    if (metaRaw is Map) {
      metaRaw.forEach((key, value) {
        final meta = CellMeta.fromJson(value);
        if (meta != null) {
          cellMeta[key.toString()] = meta;
        }
      });
    }

    return _SheetModel(
      name: name,
      savedAt: savedAt,
      headers: headers,
      rows: rowModels,
      cellMeta: cellMeta,
    );
  }
}

class _RowModel {
  _RowModel({
    required this.cells,
    required this.photos,
    this.gpsLat,
    this.gpsLng,
    this.gpsAccuracyM,
    this.gpsTs,
    this.gpsIsLastKnown = false,
  });

  final List<String> cells;
  final List<_RowPhoto> photos;
  final double? gpsLat;
  final double? gpsLng;
  final double? gpsAccuracyM;
  final DateTime? gpsTs;
  final bool gpsIsLastKnown;

  factory _RowModel.empty(int cols) => _RowModel(
        cells: List<String>.filled(cols, ''),
        photos: <_RowPhoto>[],
      );

  factory _RowModel.fromCells(List<String> cells) =>
      _RowModel(cells: cells, photos: <_RowPhoto>[]);

  _RowModel copy() => _RowModel(
        cells: List<String>.from(cells),
        photos: photos.map((p) => p.copy()).toList(),
        gpsLat: gpsLat,
        gpsLng: gpsLng,
        gpsAccuracyM: gpsAccuracyM,
        gpsTs: gpsTs,
        gpsIsLastKnown: gpsIsLastKnown,
      );

// ??? Snapshot para Undo/Redo: copia fotos SIN thumbs (liviano).
  _RowModel copyForSnapshot() => _RowModel(
        cells: List<String>.from(cells),
        photos: photos.map((p) => p.copyWithoutThumb()).toList(growable: false),
        gpsLat: gpsLat,
        gpsLng: gpsLng,
        gpsAccuracyM: gpsAccuracyM,
        gpsTs: gpsTs,
        gpsIsLastKnown: gpsIsLastKnown,
      );

  _RowModel copyWithCells(List<String> newCells) => _RowModel(
        cells: List<String>.from(newCells),
        photos: photos.map((p) => p.copy()).toList(),
        gpsLat: gpsLat,
        gpsLng: gpsLng,
        gpsAccuracyM: gpsAccuracyM,
        gpsTs: gpsTs,
        gpsIsLastKnown: gpsIsLastKnown,
      );

  _RowModel copyWithLocation({
    required double lat,
    required double lng,
    required double accuracyM,
    required DateTime ts,
    required bool isLastKnown,
  }) =>
      _RowModel(
        cells: List<String>.from(cells),
        photos: photos.map((p) => p.copy()).toList(),
        gpsLat: lat,
        gpsLng: lng,
        gpsAccuracyM: accuracyM,
        gpsTs: ts,
        gpsIsLastKnown: isLastKnown,
      );

  Map<String, dynamic> toJson() => {
        'cells': cells,
// ??? Persistencia segura: sin thumbs base64 (evita overflow prefs/localStorage).
        'photos': photos
            .map((p) => p.toJson(persistThumb: _kPersistPhotoThumbs))
            .toList(),
        if (gpsLat != null && gpsLng != null)
          'gps': {
            'lat': gpsLat,
            'lng': gpsLng,
            'accuracyM': gpsAccuracyM,
            'ts': gpsTs?.toIso8601String(),
            'lastKnown': gpsIsLastKnown,
          },
      };

  static _RowModel fromJson(Map<String, dynamic> map) {
    final cells =
        (map['cells'] as List?)?.map((e) => (e ?? '').toString()).toList() ??
            const <String>[];
    final photosRaw = (map['photos'] as List?) ?? const [];
    final photos = <_RowPhoto>[];
    for (final it in photosRaw) {
      if (it is Map) photos.add(_RowPhoto.fromJson(it.cast<String, dynamic>()));
    }
    final gps = map['gps'];
    if (gps is Map) {
      return _RowModel(
        cells: cells,
        photos: photos,
        gpsLat: (gps['lat'] as num?)?.toDouble(),
        gpsLng: (gps['lng'] as num?)?.toDouble(),
        gpsAccuracyM: (gps['accuracyM'] as num?)?.toDouble(),
        gpsTs: DateTime.tryParse((gps['ts'] ?? '').toString()),
        gpsIsLastKnown: (gps['lastKnown'] as bool?) ?? false,
      );
    }
    return _RowModel(cells: cells, photos: photos);
  }
}

class _RowPhoto {
  _RowPhoto({
    required this.name,
    required this.mime,
    required this.thumbB64,
    required this.addedAt,
    required this.path,
    this.lat,
    this.lng,
    this.accuracyM,
    this.isLastKnown = false,
    this.dataB64 = '',
  });

  final String name;
  final String mime;
  final String thumbB64;
  final DateTime addedAt;
  final String path;
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final bool isLastKnown;
  final String dataB64;

  _RowPhoto copy() => _RowPhoto(
        name: name,
        mime: mime,
        thumbB64: thumbB64,
        addedAt: addedAt,
        path: path,
        lat: lat,
        lng: lng,
        accuracyM: accuracyM,
        isLastKnown: isLastKnown,
        dataB64: dataB64,
      );

  _RowPhoto copyWithoutThumb() => _RowPhoto(
        name: name,
        mime: mime,
        thumbB64: '',
        addedAt: addedAt,
        path: path,
        lat: lat,
        lng: lng,
        accuracyM: accuracyM,
        isLastKnown: isLastKnown,
        dataB64: dataB64,
      );

  Map<String, dynamic> toJson({required bool persistThumb}) => {
        ...PhotoJson(
          name: name,
          mime: mime,
          thumbB64: thumbB64,
          addedAt: addedAt,
          path: path,
          dataB64: dataB64,
          lat: lat,
          lng: lng,
          accuracyM: accuracyM,
          isLastKnown: isLastKnown,
        ).toJson(persistThumb: persistThumb),
      };

  static _RowPhoto fromJson(Map<String, dynamic> map) {
    final decoded = PhotoJson.fromJson(map);
    return _RowPhoto(
      name: decoded.name,
      mime: decoded.mime,
      thumbB64: decoded.thumbB64,
      addedAt: decoded.addedAt,
      path: decoded.path,
      dataB64: decoded.dataB64,
      lat: decoded.lat,
      lng: decoded.lng,
      accuracyM: decoded.accuracyM,
      isLastKnown: decoded.isLastKnown,
    );
  }
}

class _ZipPhotoItem {
  _ZipPhotoItem({
    required this.cell,
    required this.photo,
    required this.fileName,
    required this.pathInZip,
  });

  final CellKey cell;
  final PhotoAttachment photo;
  final String fileName;
  final String pathInZip;
}

class _ZipAudioItem {
  _ZipAudioItem({
    required this.cell,
    required this.audio,
    required this.fileName,
    required this.pathInZip,
  });

  final CellKey cell;
  final AudioAttachment audio;
  final String fileName;
  final String pathInZip;
}

class _ExportPrep {
  const _ExportPrep({
    required this.attachments,
    required this.embeddedPhotos,
    required this.photoItems,
    required this.audioItems,
    required this.manifest,
  });

  final List<AttachmentRow> attachments;
  final List<EmbeddedPhoto> embeddedPhotos;
  final List<_ZipPhotoItem> photoItems;
  final List<_ZipAudioItem> audioItems;
  final Map<String, dynamic> manifest;
}

class _SheetSnapshot {
  _SheetSnapshot({
    required this.name,
    required this.headers,
    required this.rowModels,
    required this.cellMeta,
    required this.selRow,
    required this.selCol,
  });

  final String name;
  final List<String> headers;
  final List<_RowModel> rowModels;
  final Map<String, CellMeta> cellMeta;
  final int selRow;
  final int selCol;
}

class _CellRef {
  const _CellRef(this.r, this.c);
  final int r;
  final int c;

  @override
  bool operator ==(Object other) =>
      other is _CellRef && other.r == r && other.c == c;

  @override
  int get hashCode => Object.hash(r, c);
}

enum _ColType { text, number, date, photos }

Uint8List? _tryDecodeB64(String raw) {
  try {
    if (raw.trim().isEmpty) return null;
    return base64Decode(raw);
  } catch (_) {
    return null;
  }
}

class _GpsFix {
  const _GpsFix({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.ts,
    required this.source,
    required this.provider,
  });

  final double lat;
  final double lng;
  final double accuracyM;
  final DateTime ts;
  final String source;
  final String provider;
}

class _GpsOutcome {
  const _GpsOutcome({this.fix, this.error, this.code});
  final _GpsFix? fix;
  final String? error;
  final String? code;

  bool get ok => fix != null;
}

// ============================== Paleta =====================================

class _SheetPalette {
  _SheetPalette({
    required this.isLight,
    required this.hairline,
    required this.bg,
    required this.fg,
    required this.fgMuted,
    required this.appBarBg,
    required this.headerBg,
    required this.indexBg,
    required this.cellBg,
    required this.blinkBg,
    required this.border,
    required this.borderStrong,
    required this.menuBg,
    required this.editorBg,
    required this.mobileInputBg,
    required this.accent,
    required this.statusBg,
    required this.statusFg,
    required this.hintBg,
    required this.headerCardBg,
    required this.headerCardBorder,
    required this.pillBtnBg,
    required this.pillBtnBorder,
    Color? hoverBg,
    Color? pressedBg,
    Color? zebraBg,
  })  : hoverBg = hoverBg ??
            (isLight
                ? Colors.black.withOpacity(0.04)
                : Colors.white.withOpacity(0.08)),
        pressedBg = pressedBg ??
            (isLight
                ? Colors.black.withOpacity(0.08)
                : Colors.white.withOpacity(0.14)),
        zebraBg = zebraBg ??
            (isLight
                ? const Color(0xFFF9F9FB)
                : Colors.white.withOpacity(0.02));

  final bool isLight;
  final double hairline;

  final Color bg;
  final Color fg;
  final Color fgMuted;

  final Color appBarBg;
  final Color headerBg;
  final Color indexBg;

  final Color cellBg;
  final Color blinkBg;

  final Color border;
  final Color borderStrong;

  final Color menuBg;
  final Color editorBg;

  final Color mobileInputBg;

  final Color accent;

  final Color statusBg;
  final Color statusFg;

  final Color hintBg;

  final Color headerCardBg;
  final Color headerCardBorder;

  final Color pillBtnBg;
  final Color pillBtnBorder;

  final Color hoverBg;
  final Color pressedBg;
  final Color zebraBg;

  factory _SheetPalette.fromApp(AppThemeData t, {required double hairline}) {
    final c = t.colors;
    final card = c.surfaceElevated;

    return _SheetPalette(
      isLight: c.isLight,
      hairline: hairline,
      bg: c.bg,
      fg: c.textPrimary,
      fgMuted: c.textSecondary,
      appBarBg: c.bg,
      headerBg: card,
      indexBg: card,
      cellBg: c.surface,
      blinkBg: c.accentMuted,
      border: c.border,
      borderStrong: c.borderStrong,
      menuBg: c.surfaceElevated,
      editorBg: c.surfaceElevated,
      mobileInputBg: c.surfaceElevated.withOpacity(c.isLight ? 0.96 : 0.72),
      accent: c.accent,
      statusBg: c.statusBg,
      statusFg: c.statusFg,
      hintBg: c.surfaceMuted,
      headerCardBg: c.surfaceElevated.withOpacity(c.isLight ? 0.9 : 0.65),
      headerCardBorder: c.border,
      pillBtnBg: c.surfaceMuted,
      pillBtnBorder: c.border,
      hoverBg: c.hover,
      pressedBg: c.pressed,
      zebraBg: c.surfaceMuted.withOpacity(c.isLight ? 0.6 : 0.12),
    );
  }
}

// ============================== Context actions ============================

class _CtxAction {
  _CtxAction(this.label, this.icon, this.run, {this.runOnTap = false});
  final String label;
  final IconData icon;
  final VoidCallback run;
  final bool runOnTap;
}

// ============================== Backdrop / Scroll ==========================

class _WarmBackdrop extends StatelessWidget {
  const _WarmBackdrop({required this.palette});
  final _SheetPalette palette;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.7),
            radius: 1.2,
            colors: [
              const Color(0xFFFFF1D6).withOpacity(0.30),
              Colors.transparent,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.8, 0.6),
              radius: 1.3,
              colors: [
                const Color(0xFFEFF6FF).withOpacity(0.40),
                Colors.transparent,
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child; // sin glow Android
  }
}

// ============================== Helpers ====================================

// Compat simple: evita warning de "unawaited" sin depender de SDK.
void unawaited(Future<void>? f) {}
