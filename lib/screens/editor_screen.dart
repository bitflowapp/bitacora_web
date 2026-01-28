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
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:url_launcher/url_launcher.dart';
import 'package:bitacora_web/services/photo_acquire_service.dart';
import 'package:bitacora_web/services/keyboard_insets_controller.dart';
import 'package:bitacora_web/services/photo_storage_service.dart';
import 'package:bitacora_web/services/photo_bytes_resolver.dart';
import 'package:bitacora_web/services/photo_json_codec.dart';
import 'package:bitacora_web/services/engine_api.dart';
import 'package:bitacora_web/services/engine_config.dart';
import 'package:bitacora_web/utils/viewport_insets.dart' as vv;

part '../widgets/mobile_notes_grid.dart';

// ============================== Constantes globales ========================

const int kDefaultCols = 15; // 14 + Photos
const String kPhotosHeader = 'Photos';

// ??? Persistencia segura: NO guardar thumbs base64 en prefs/localStorage.
const bool _kPersistPhotoThumbs = true;
const String _kPrefEngineApiKey = 'bitflow.engine_api_key';
const String _kPrefEngineApiKeyAlt = 'bitflow_engine_api_key';

enum _OverlayMove { none, next, prev, down, up }

enum _MobileEditPhase { closed, opening, open, switching, closing }

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
// ------------------------------ Estado ----------------------------------

  late String _sheetName;
  DateTime? _lastSavedAt;

  late List<String> _headers;
  late List<_RowModel> _rows;

  bool _isLight = true;
  bool _isDirty = false;

  int _selRow = 0;
  int _selCol = 0;

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
  String? _engineBaseResolved;
  String? _engineKeyResolved;
  bool _engineAvailable = false;
  late final EngineApi _engineApi = EngineApi();

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

    final initial = _buildInitialState();
    _headers = initial.headers;
    _rows = initial.rows;
    _resetMobileRowCaches();
    _recomputeValidation();

    _rev = 0;
    _lastSavedRev = 0;
    _savePending = false;

    _pushUndoSnapshot(); // estado inicial
    _smokeRequested = _isSmokeRequested();
    unawaited(_loadLocal().whenComplete(() => unawaited(_maybeRunSmoke())));
    unawaited(_initEngineConnection().whenComplete(() => unawaited(_maybeRunSmoke())));
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

// ------------------------------ Local persistence -----------------------

  String get _prefsKey => 'bitflow:sheet:${widget.sheetId}';
  String get _backupListKey => '$_prefsKey:bk:list';
  String _backupKey(DateTime ts) => '$_prefsKey:bk:${ts.millisecondsSinceEpoch}';

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

    setState(() {
      _sheetName = (loaded.name?.trim().isNotEmpty ?? false)
          ? loaded.name!.trim()
          : _sheetName;
      _headers = loadedHeaders;
      _rows = normalizedRows.isNotEmpty
          ? normalizedRows
          : <_RowModel>[_RowModel.empty(_headers.length)];
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
      final trimmed =
          updated.length > _maxBackups ? updated.sublist(0, _maxBackups) : updated;

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

  _SheetSnapshot _snapshot() => _SheetSnapshot(
    name: _sheetName,
    headers: List<String>.from(_headers),
// ??? Undo incluye metadata de fotos SIN thumbs (revierte count/filas, sin lag).
    rowModels:
    _rows.map((r) => r.copyForSnapshot()).toList(growable: false),
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
    return _isLight
        ? _SheetPalette.light(hairline: hair)
        : _SheetPalette.dark(hairline: hair);
  }

// ??? FIX: si el tema viene controlado desde arriba, no ???doble toggles???.
  void _toggleTheme() {
    widget.onToggleTheme?.call();
    if (widget.isLight != null) return; // controlado por StartPage
    setState(() => _isLight = !_isLight);
  }

// ------------------------------ Utilidades UI ---------------------------

  bool _isMobileWeb() {
    if (!kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

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
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? _errorBg(pal) : pal.statusBg,
          duration: const Duration(seconds: 3),
        ),
      );
    });
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

        if (!isDesktop) {
          _scheduleMobileBarMeasure();
        }

// Evitar escalados raros de texto (iOS / Web).
        final mq = MediaQuery.of(ctx);
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
                ? (_mobileBarH > 0 &&
                        (_mobileBarH - desiredPanelH).abs() < 8)
                    ? _mobileBarH
                    : desiredPanelH
                : 0.0);
        final bodyBottomPad =
            isDesktop ? 0.0 : (editorActive ? panelH + keyboardInset : 0.0);

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
            child: Scaffold(
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
                                onExport: () => unawaited(_exportXlsx()),
                                onCompute: (!_engineAvailable || _engineBusy)
                                    ? null
                                    : () => unawaited(_computeEngine()),
                              )
                            else
                              _MobileCompactHeader(
                                palette: pal,
                                title: _sheetName,
                                savedText: _savedLabel(pal),
                                isDirty: _isDirty,
                                pendingRequired: _pendingRequired,
                                onSave: () => unawaited(_saveLocalNow()),
                                onExport: () => unawaited(_exportXlsx()),
                                onMenu: () => _openMobileHeaderMenu(
                                  context,
                                  pal,
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
                                              headers: List<String>.generate(
                                                  _headers.length,
                                                  _effectiveHeader),
                                              rowModels: _rows,
                                              cellTextAt: (r, c) =>
                                                  _effectiveCell(r, c),
                                              isInvalid: (r, c) =>
                                                  _invalidCells
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
                                                      _openContextMenu(context,
                                                          pal, pos, r, c, isHeader),
                                              onDeleteRow: (r) => _deleteRow(r),
                                              onPickPhoto: (r) =>
                                                  _pickPhotoForRow(r),
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
                                          final cardW =
                                              _mobileCardWidthForScreen(
                                                  MediaQuery.of(ctx)
                                                      .size
                                                      .width);
                                          return _MobileNotesGrid(
                                            palette: pal,
                                            headers: List<String>.generate(
                                                _headers.length,
                                                _effectiveHeader),
                                            rowModels: _rows,
                                            cellTextAt: (r, c) =>
                                                _effectiveCell(r, c),
                                            isInvalid: (r, c) =>
                                                _invalidCells
                                                    .contains(_CellRef(r, c)),
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
                                                _pickPhotoForRow(r),
                                          );
                                        },
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

    if (_cellEditorEntry != null || _mobileEditorOpen) {
      return KeyEventResult.ignored;
    }

    final isCmd = HardwareKeyboard.instance.isMetaPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
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
      unawaited(_handlePhotosCellTap(r));
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
        icon: Icons.my_location_outlined,
        label: 'GPS',
        onTap: () => unawaited(_pasteGpsIntoCell(r, c)),
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
                  title: const Text('Fotos de la fila'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openPhotosSheet(row);
                  },
                ),
              if (row >= 0)
                ListTile(
                  leading: const Icon(Icons.my_location_outlined),
                  title: const Text('Guardar ubicación'),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(_captureGpsForRow(row));
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
    return _kMobileHeaderRowH + (row * _kMobileRowH);
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
    final stride = cardW + _kMobileCardGap;
    final col = _mobileCol;
    final cardLeft = _kMobileRowPadH + (col * stride);
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
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
                                  fontSize: 16,
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
      actions.add(_CtxAction('Rellenar abajo...', Icons.vertical_align_bottom_rounded,
              () => unawaited(_promptFillDown(context, r, c))));
      actions.add(_CtxAction('Incrementar...', Icons.exposure_plus_1_rounded,
              () => unawaited(_promptIncrement(context, r, c))));
      actions.add(_CtxAction('Guardar ubicaci??n en fila', Icons.my_location_outlined,
              () => unawaited(_captureGpsForRow(r))));
      actions.add(_CtxAction(
          'Limpiar celda', Icons.backspace_outlined, () => _setCell(r, c, '')));

      if (c != _headers.length - 1) {
        actions.add(_CtxAction('GPS -> celda', Icons.my_location_outlined,
                () => unawaited(_pasteGpsIntoCell(r, c))));
        actions.add(_CtxAction('Maps', Icons.map_outlined,
                () => unawaited(_openMapsForCell(r, c))));
      } else {
        final isAndroid = _isAndroidDevice;
        actions.add(_CtxAction(
            isAndroid ? 'C??mara' : 'Agregar foto',
            Icons.add_photo_alternate_outlined,
                () => unawaited(_pickPhotoForRow(r))));
        if (isAndroid) {
          actions.add(_CtxAction(
              'Elegir de galer??a',
              Icons.photo_library_outlined,
                  () => unawaited(_pickPhotoFromGalleryForRow(r))));
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
    actions[res].run();
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
    final controller =
        TextEditingController(text: _fillDownCount.toString());
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
    final value =
        (_mobileEditorOpen && _mobileRow == r && _mobileCol == c && !_mobileEditingHeader)
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
    final countCtrl =
        TextEditingController(text: _incrementCount.toString());
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
    final baseRaw =
        (_mobileEditorOpen && _mobileRow == r && _mobileCol == c && !_mobileEditingHeader)
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
    final raw =
        (_mobileEditorOpen && _mobileRow == r && _mobileCol == c && !_mobileEditingHeader)
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

  double? _evalExpression(String raw) {
    final src = raw.trim();
    if (src.isEmpty) return null;

    final output = <double>[];
    final ops = <String>[];
    int i = 0;
    bool expectUnary = true;

    int precedence(String op) {
      if (op == '+' || op == '-') return 1;
      if (op == '*' || op == '/') return 2;
      return 0;
    }

    void applyOp() {
      if (ops.isEmpty) return;
      final op = ops.removeLast();
      if (output.length < 2) return;
      final b = output.removeLast();
      final a = output.removeLast();
      switch (op) {
        case '+':
          output.add(a + b);
        case '-':
          output.add(a - b);
        case '*':
          output.add(a * b);
        case '/':
          output.add(b == 0 ? a : a / b);
      }
    }

    while (i < src.length) {
      final ch = src[i];
      if (ch == ' ' || ch == '\t' || ch == '\n') {
        i++;
        continue;
      }
      if (ch == '(') {
        ops.add(ch);
        i++;
        expectUnary = true;
        continue;
      }
      if (ch == ')') {
        while (ops.isNotEmpty && ops.last != '(') {
          applyOp();
        }
        if (ops.isNotEmpty && ops.last == '(') {
          ops.removeLast();
        }
        i++;
        expectUnary = false;
        continue;
      }
      if ('+-*/'.contains(ch)) {
        if (ch == '-' && expectUnary) {
          int j = i + 1;
          while (j < src.length && src[j] == ' ') {
            j++;
          }
          final numBuf = StringBuffer('-');
          int k = j;
          while (k < src.length &&
              (RegExp(r'[0-9\\.]').hasMatch(src[k]))) {
            numBuf.write(src[k]);
            k++;
          }
          final v = double.tryParse(numBuf.toString());
          if (v == null) return null;
          output.add(v);
          i = k;
          expectUnary = false;
          continue;
        }
        while (ops.isNotEmpty &&
            precedence(ops.last) >= precedence(ch)) {
          applyOp();
        }
        ops.add(ch);
        i++;
        expectUnary = true;
        continue;
      }

      final buf = StringBuffer();
      while (i < src.length && RegExp(r'[0-9\\.]').hasMatch(src[i])) {
        buf.write(src[i]);
        i++;
      }
      if (buf.isEmpty) return null;
      final v = double.tryParse(buf.toString());
      if (v == null) return null;
      output.add(v);
      expectUnary = false;
    }

    while (ops.isNotEmpty) {
      if (ops.last == '(') {
        ops.removeLast();
        continue;
      }
      applyOp();
    }
    if (output.isEmpty) return null;
    return output.last;
  }

// ------------------------------ Filas -----------------------------------

  void _insertRow(int index) {
    final idx = index.clamp(0, _rows.length);
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

  Future<void> _pasteGpsIntoCell(int r, int c) async {
    final fix = await _getGpsFixWithFallback();
    if (!mounted) return;
    if (fix == null) return;

    final tag = fix.isLastKnown ? ' (last)' : '';
    final text =
        '${fix.lat.toStringAsFixed(6)}, ${fix.lng.toStringAsFixed(6)} ??${fix.accuracyM.round()} m$tag';
    _setCell(r, c, text);
  }

  Future<_GpsFix?> _getGpsFixWithFallback(
      {Duration timeout = const Duration(seconds: 10)}) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }

      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: timeout,
        );

        return _GpsFix(
          lat: pos.latitude,
          lng: pos.longitude,
          accuracyM: pos.accuracy,
          ts: pos.timestamp,
          isLastKnown: false,
        );
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) return null;
        return _GpsFix(
          lat: last.latitude,
          lng: last.longitude,
          accuracyM: last.accuracy,
          ts: last.timestamp,
          isLastKnown: true,
        );
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _captureGpsForRow(int r) async {
    if (r < 0 || r >= _rows.length) return;
    final fix = await _getGpsFixWithFallback(
        timeout: const Duration(seconds: 12));
    if (!mounted) return;
    if (fix == null) return;

    setState(() {
      _rows[r] = _rows[r].copyWithLocation(
        lat: fix.lat,
        lng: fix.lng,
        accuracyM: fix.accuracyM,
        ts: fix.ts,
        isLastKnown: fix.isLastKnown,
      );
      _isDirty = true;
      _rev++;
    });

    _pushUndoSnapshot();
    _queueSave();

    final msg = fix.isLastKnown
        ? 'GPS guardado (last known)'
        : 'GPS guardado';
    setState(() {
      _engineStatus = msg;
      _engineStatusIsError = false;
    });
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_engineStatus == msg) {
        setState(() => _engineStatus = null);
      }
    });
  }

  Future<void> _openMapsForCell(int r, int c) async {
    final txt = _getCellText(r, c);
    if (txt.trim().isEmpty) return;

    final m =
    RegExp(r'(-?\d+(?:\.\d+)?)[,\s]+(-?\d+(?:\.\d+)?)').firstMatch(txt);
    if (m == null) return;

    final lat = double.tryParse(m.group(1) ?? '');
    final lng = double.tryParse(m.group(2) ?? '');
    if (lat == null || lng == null) return;

    final uri =
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

// ------------------------------ Fotos -----------------------------------

  Future<void> _handlePhotosCellTap(int r) async {
    if (r < 0 || r >= _rows.length) return;
    if (_rows[r].photos.isNotEmpty) {
      _openPhotosSheet(r);
      return;
    }
    await _pickPhotoForRow(r);
  }

  Future<void> _pickPhotoForRow(int r) async {
    if (r < 0 || r >= _rows.length) return;

    try {
      final result = _isAndroidDevice
          ? await PhotoAcquireService.I.captureFromCamera()
          : await PhotoAcquireService.I.pickFromGallery();
      if (!mounted) return;
      if (result == null) return;

      final stored = await _photoStore.savePhoto(
        sheetId: widget.sheetId,
        bytes: result.bytes,
        originalName: result.name,
        mime: result.mime,
      );
      if (!mounted) return;
      if (stored == null) return;

      final thumb =
      _compressThumb(result.bytes, maxW: 560, maxH: 560, quality: 78);
      final b64 = base64Encode(thumb);

      final fix = await _getGpsFixWithFallback(
          timeout: const Duration(seconds: 8));
      if (!mounted) return;

// ??? thumb runtime s?? (para visor), persistencia s??.
      _rows[r].photos.add(
        _RowPhoto(
          name: result.name,
          mime: result.mime,
          thumbB64: b64,
          addedAt: DateTime.now(),
          path: stored.path,
          lat: fix?.lat,
          lng: fix?.lng,
          accuracyM: fix?.accuracyM,
          isLastKnown: fix?.isLastKnown ?? false,
          dataB64: stored.dataB64,
        ),
      );

      _markDirty(snapshot: true);
    } catch (_) {}
  }

  Future<void> _pickPhotoFromGalleryForRow(int r) async {
    if (r < 0 || r >= _rows.length) return;

    try {
      final result = await PhotoAcquireService.I.pickFromGallery();
      if (!mounted) return;
      if (result == null) return;

      final stored = await _photoStore.savePhoto(
        sheetId: widget.sheetId,
        bytes: result.bytes,
        originalName: result.name,
        mime: result.mime,
      );
      if (!mounted) return;
      if (stored == null) return;

      final thumb =
      _compressThumb(result.bytes, maxW: 560, maxH: 560, quality: 78);
      final b64 = base64Encode(thumb);

      final fix = await _getGpsFixWithFallback(
          timeout: const Duration(seconds: 8));
      if (!mounted) return;

      _rows[r].photos.add(
        _RowPhoto(
          name: result.name,
          mime: result.mime,
          thumbB64: b64,
          addedAt: DateTime.now(),
          path: stored.path,
          lat: fix?.lat,
          lng: fix?.lng,
          accuracyM: fix?.accuracyM,
          isLastKnown: fix?.isLastKnown ?? false,
          dataB64: stored.dataB64,
        ),
      );

      _markDirty(snapshot: true);
    } catch (_) {}
  }

  Future<void> _deletePhotoFromRow(int r, int index) async {
    if (r < 0 || r >= _rows.length) return;
    if (index < 0 || index >= _rows[r].photos.length) return;
    final photo = _rows[r].photos[index];
    _rows[r].photos.removeAt(index);
    await _photoStore.deletePhoto(photo.path);
    if (!mounted) return;
    _markDirty(snapshot: true);
  }

  void _openPhotosSheet(int r) {
    if (r < 0 || r >= _rows.length) return;
    final photos = _rows[r].photos;
    if (photos.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _palette(ctx).menuBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Fotos - Fila ${r + 1}',
                      style: TextStyle(
                        color: _palette(ctx).fg,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: Icon(Icons.close_rounded,
                          color: _palette(ctx).fgMuted),
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
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _palette(ctx2).headerBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _palette(ctx2).border,
                              width: _palette(ctx2).hairline),
                        ),
                        child: Row(
                          children: [
                            if (p.thumbB64.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  base64Decode(p.thumbB64),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.low,
                                ),
                              )
                            else
                              Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _palette(ctx2).cellBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: _palette(ctx2).border,
                                      width: _palette(ctx2).hairline),
                                ),
                                child: Icon(Icons.photo,
                                    color: _palette(ctx2).fgMuted),
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _palette(ctx2).fg,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p.addedAt.toIso8601String(),
                                    style: TextStyle(
                                      color: _palette(ctx2).fgMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.of(ctx2).pop();
                                unawaited(_deletePhotoFromRow(r, idx));
                              },
                              icon: Icon(Icons.delete_outline_rounded,
                                  color: _palette(ctx2).fgMuted),
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
                onTap: () => runAndClose(() => unawaited(_exportXlsx())),
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
                title: const Text('Calcular'),
                enabled: _engineAvailable && !_engineBusy,
                onTap: (_engineAvailable && !_engineBusy)
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

  Uint8List _compressThumb(Uint8List bytes,
      {required int maxW, required int maxH, required int quality}) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;

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
      return bytes;
    }
  }

// ------------------------------ Export XLSX -----------------------------

  Future<void> _exportXlsx() async {
    try {
      final photoItems = _collectPhotoItems();
      final photosByRow = await _loadPhotoBytesByRow(photoItems);
      final wb = _buildWorkbook(
        photoItems: photoItems,
        photosByRow: photosByRow,
      );
      final xlsxBytes = Uint8List.fromList(wb.saveAsStream());
      wb.dispose();

      final now = DateTime.now();
      final baseName =
          '${_safeFile(_sheetName)}_bitacora_pro_${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}';

      await _saveExportBytes(
        name: '$baseName.xlsx',
        mime:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        bytes: xlsxBytes,
      );
    } catch (_) {}
  }

  List<_PhotoExportItem> _collectPhotoItems() {
    final out = <_PhotoExportItem>[];
    for (int r = 0; r < _rows.length; r++) {
      final row = _rows[r];
      for (int i = 0; i < row.photos.length; i++) {
        out.add(_PhotoExportItem(
          row: r,
          col: _headers.length - 1,
          photo: row.photos[i],
          rowLat: row.gpsLat,
          rowLng: row.gpsLng,
          rowAccuracy: row.gpsAccuracyM,
          rowIsLastKnown: row.gpsIsLastKnown,
        ));
      }
    }
    return out;
  }

  Future<Map<int, List<Uint8List>>> _loadPhotoBytesByRow(
    List<_PhotoExportItem> photoItems,
  ) async {
    final Map<int, List<Uint8List>> out = {};
    for (final item in photoItems) {
      final bytes = await _loadPhotoBytes(item.photo);
      final list = out.putIfAbsent(item.row, () => <Uint8List>[]);
      list.add(bytes ?? Uint8List(0));
    }
    return out;
  }

  xlsio.Workbook _buildWorkbook({
    required List<_PhotoExportItem> photoItems,
    required Map<int, List<Uint8List>> photosByRow,
  }) {
    final wb = xlsio.Workbook();
    final sheet = wb.worksheets[0];
    sheet.name = _sheetName;

    final dataCols = math.max(0, _headers.length - 1); // sin Photos
    final hasGps = _rows.any((r) => r.gpsLat != null && r.gpsLng != null);
    final gpsCols = hasGps ? 5 : 0;
    final maxPhotosPerRow = photosByRow.values
        .fold<int>(0, (prev, list) => math.max(prev, list.length));
    final photoCols = maxPhotosPerRow;
    final photoStart = dataCols + gpsCols + 1;
    final lastCol = math.max(1, dataCols + gpsCols + photoCols);

    for (int c = 0; c < dataCols; c++) {
      final text = _headerLabel(c);
      final cell = sheet.getRangeByIndex(1, c + 1);
      cell.setText(text);
    }

    int gpsStart = dataCols + 1;
    if (hasGps) {
      final headers = [
        'GPS Lat',
        'GPS Lon',
        'GPS Acc (m)',
        'GPS Time',
        'GPS Source'
      ];
      for (int i = 0; i < headers.length; i++) {
        sheet.getRangeByIndex(1, gpsStart + i).setText(headers[i]);
      }
    }

    if (photoCols > 0) {
      for (int p = 0; p < photoCols; p++) {
        sheet.getRangeByIndex(1, photoStart + p).setText('Foto ${p + 1}');
        sheet.setColumnWidthInPixels(photoStart + p, 112);
      }
    }

    for (int r = 0; r < _rows.length; r++) {
      for (int c = 0; c < dataCols; c++) {
        final v = _rows[r].cells[c];
        if (v.trim().isEmpty) continue;
        _setSheetValue(sheet, r + 2, c + 1, v);
      }
      if (hasGps) {
        final row = _rows[r];
        if (row.gpsLat != null && row.gpsLng != null) {
          sheet.getRangeByIndex(r + 2, gpsStart).setNumber(row.gpsLat ?? 0);
          sheet.getRangeByIndex(r + 2, gpsStart + 1).setNumber(row.gpsLng ?? 0);
          sheet.getRangeByIndex(r + 2, gpsStart + 2).setNumber(row.gpsAccuracyM ?? 0);
          if (row.gpsTs != null) {
            sheet.getRangeByIndex(r + 2, gpsStart + 3)
                .setDateTime(row.gpsTs!);
          }
          sheet.getRangeByIndex(r + 2, gpsStart + 4)
              .setText(row.gpsIsLastKnown ? 'lastKnown' : 'current');
        }
      }

      if (photoCols > 0) {
        final picsForRow = photosByRow[r] ?? const <Uint8List>[];
        if (picsForRow.isNotEmpty) {
          sheet.setRowHeightInPixels(r + 2, 90);
          for (int p = 0; p < picsForRow.length && p < photoCols; p++) {
            final bytes = picsForRow[p];
            if (bytes.isEmpty) {
              sheet.getRangeByIndex(r + 2, photoStart + p).setText('N/D');
              continue;
            }
            try {
              final picture = sheet.pictures.addBase64(
                r + 2,
                photoStart + p,
                base64Encode(bytes),
              );
              picture.width = 100;
              picture.height = 80;
            } catch (_) {
              sheet.getRangeByIndex(r + 2, photoStart + p).setText('N/D');
            }
          }
        }
      }
    }

    if (lastCol > 0) {
      final headerRange = sheet.getRangeByIndex(1, 1, 1, lastCol);
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.backColor = '#F4F0E6';
    }
    if (_rows.isNotEmpty && lastCol > 0) {
      final bodyRange =
          sheet.getRangeByIndex(1, 1, _rows.length + 1, lastCol);
      bodyRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    }

    final autoFitCols = dataCols + gpsCols;
    for (int c = 0; c < autoFitCols; c++) {
      try {
        sheet.autoFitColumn(c + 1);
      } catch (_) {}
    }

    _buildCoverSheet(wb);
    _buildSummarySheet(
      wb,
      rowsCount: _rows.length,
      photosCount: photoItems.length,
      gpsCount: _rows.where((r) => r.gpsLat != null && r.gpsLng != null).length,
    );

    if (photoItems.isNotEmpty) {
      final photosSheet = wb.worksheets.addWithName('Fotos');
      final headers = [
        'Row',
        'Col',
        'File',
        'AddedAt',
        'Lat',
        'Lon',
        'Accuracy',
        'Source',
        'Foto'
      ];
      for (int c = 0; c < headers.length; c++) {
        photosSheet.getRangeByIndex(1, c + 1).setText(headers[c]);
      }
      final previewCol = headers.length;
      photosSheet.setColumnWidthInPixels(previewCol, 112);

      final rowPhotoCursor = <int, int>{};
      for (int i = 0; i < photoItems.length; i++) {
        final item = photoItems[i];
        final row = i + 2;
        final lat = item.lat;
        final lng = item.lng;
        final acc = item.accuracy;
        final source = item.sourceLabel;
        final idxInRow = rowPhotoCursor[item.row] ?? 0;
        rowPhotoCursor[item.row] = idxInRow + 1;
        final photoList = photosByRow[item.row];
        final bytes = (photoList != null && idxInRow < photoList.length)
            ? photoList[idxInRow]
            : null;

        photosSheet.getRangeByIndex(row, 1).setNumber(item.row + 1);
        photosSheet.getRangeByIndex(row, 2).setNumber(item.col + 1);
        photosSheet.getRangeByIndex(row, 3).setText('');
        photosSheet.getRangeByIndex(row, 4)
            .setText(item.photo.addedAt.toIso8601String());
        if (lat != null) photosSheet.getRangeByIndex(row, 5).setNumber(lat);
        if (lng != null) photosSheet.getRangeByIndex(row, 6).setNumber(lng);
        if (acc != null) photosSheet.getRangeByIndex(row, 7).setNumber(acc);
        photosSheet.getRangeByIndex(row, 8).setText(source);
        if (bytes != null && bytes.isNotEmpty) {
          try {
            photosSheet.setRowHeightInPixels(row, 96);
            final picture = photosSheet.pictures.addBase64(
              row,
              previewCol,
              base64Encode(bytes),
            );
            picture.width = 110;
            picture.height = 82;
          } catch (_) {
            photosSheet.getRangeByIndex(row, previewCol).setText('N/D');
          }
        } else {
          photosSheet.getRangeByIndex(row, previewCol).setText('N/D');
        }
      }
      final lastPhotoRow = photoItems.length + 1;
      final lastPhotoCol = headers.length;
      final headerRange =
          photosSheet.getRangeByIndex(1, 1, 1, lastPhotoCol);
      headerRange.cellStyle.bold = true;
      headerRange.cellStyle.backColor = '#F4F0E6';
      if (photoItems.isNotEmpty) {
        final bodyRange =
          photosSheet.getRangeByIndex(1, 1, lastPhotoRow, lastPhotoCol);
        bodyRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      }
      for (int c = 0; c < lastPhotoCol - 1; c++) {
        try {
          photosSheet.autoFitColumn(c + 1);
        } catch (_) {}
      }
    }

    return wb;
  }

  void _setSheetValue(xlsio.Worksheet sheet, int r, int c, String v) {
    final trimmed = v.trim();
    final numVal = double.tryParse(trimmed);
    if (numVal != null && RegExp(r'^-?\\d+(?:\\.\\d+)?$').hasMatch(trimmed)) {
      sheet.getRangeByIndex(r, c).setNumber(numVal);
      return;
    }
    final dt = DateTime.tryParse(trimmed);
    if (dt != null) {
      sheet.getRangeByIndex(r, c).setDateTime(dt);
      return;
    }
    sheet.getRangeByIndex(r, c).setText(v);
  }

  void _buildCoverSheet(xlsio.Workbook wb) {
    final cover = wb.worksheets.addWithName('Caratula');
    final labels = ['Obra', 'Cliente', 'Responsable', 'Fecha'];
    for (int i = 0; i < labels.length; i++) {
      cover.getRangeByIndex(i + 1, 1).setText(labels[i]);
      cover.getRangeByIndex(i + 1, 2).setText('');
    }
    final title = cover.getRangeByIndex(1, 4);
    title.setText('Bitácora PRO');
    title.cellStyle.bold = true;
    cover.autoFitColumn(1);
    cover.autoFitColumn(2);
  }

  void _buildSummarySheet(
    xlsio.Workbook wb, {
    required int rowsCount,
    required int photosCount,
    required int gpsCount,
  }) {
    final summary = wb.worksheets.addWithName('Resumen');
    final data = [
      ['Filas', rowsCount],
      ['Fotos', photosCount],
      ['Ubicaciones', gpsCount],
    ];
    for (int i = 0; i < data.length; i++) {
      summary.getRangeByIndex(i + 1, 1).setText(data[i][0].toString());
      summary.getRangeByIndex(i + 1, 2).setNumber(
        (data[i][1] is num) ? (data[i][1] as num).toDouble() : 0,
      );
    }
    summary.autoFitColumn(1);
    summary.autoFitColumn(2);
  }

  String _photoExportName(_RowPhoto photo, int row, int idx) {
    final base = _safeFile(photo.name.isNotEmpty ? photo.name : 'photo');
    if (base.trim().isEmpty) {
      return 'photo_${row + 1}_$idx.jpg';
    }
    return '${row + 1}_${idx}_$base';
  }

  Future<Uint8List?> _buildPhotosZip({
    required Uint8List xlsxBytes,
    required List<_PhotoExportItem> photoItems,
  }) async {
    final archive = Archive();
    archive.addFile(ArchiveFile('sheet.xlsx', xlsxBytes.length, xlsxBytes));

    final manifestLines = <String>[
      'row,col,file,added_at,lat,lon,accuracy,source,zip_path'
    ];

    for (int i = 0; i < photoItems.length; i++) {
      final item = photoItems[i];
      final bytes = await _loadPhotoBytes(item.photo);
      if (bytes == null) continue;
      final fileName = _photoExportName(item.photo, item.row, i);
      final pathInZip = 'photos/$fileName';
      archive.addFile(ArchiveFile(pathInZip, bytes.length, bytes));

      final lat = item.lat;
      final lng = item.lng;
      final acc = item.accuracy;
      final source = item.sourceLabel;
      manifestLines.add(
          '${item.row + 1},${item.col + 1},$fileName,${item.photo.addedAt.toIso8601String()},${lat ?? ''},${lng ?? ''},${acc ?? ''},$source,$pathInZip');
    }

    final manifest = manifestLines.join('\\n');
    final manifestBytes = Uint8List.fromList(utf8.encode(manifest));
    archive.addFile(
        ArchiveFile('manifest.csv', manifestBytes.length, manifestBytes));

    final encoder = ZipEncoder();
    final zipData = encoder.encode(archive);
    return Uint8List.fromList(zipData);
  }

  Future<Uint8List?> _loadPhotoBytes(_RowPhoto photo) async {
    return PhotoBytesResolver.resolve(
      path: photo.path,
      dataB64: photo.dataB64,
      thumbB64: photo.thumbB64,
      readFromPath: _photoStore.readPhotoBytes,
      debugTag: 'row_photo',
    );
  }

  Future<void> _saveExportBytes({
    required String name,
    required String mime,
    required Uint8List bytes,
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
      try {
        await Share.shareXFiles([xf], subject: 'BitFlow Export');
        return;
      } catch (_) {}
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
    final resolved = await _resolveEngineConfig();
    if (!mounted) return;

    _engineBaseResolved = resolved.baseUrl;
    _engineKeyResolved = resolved.apiKey;

    if (_engineBaseResolved == null || _engineBaseResolved!.isEmpty) {
      setState(() {
        _engineAvailable = false;
        _engineStatus = null;
        _engineStatusIsError = false;
      });
      return;
    }

    final ok = await _checkEngineHealth(_engineBaseResolved!);
    if (!mounted) return;
    setState(() {
      _engineAvailable = ok;
      if (!ok) {
        _engineStatus =
        'Engine no accesible. En iPhone/Android us?? IP LAN o t??nel (no 127.0.0.1).';
        _engineStatusIsError = true;
      } else {
        _engineStatus = null;
        _engineStatusIsError = false;
      }
    });
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
      '/',
    ];

    for (final path in candidates) {
      try {
        await _engineApi.getJsonFromBase(normalized, path);
        return true;
      } catch (_) {
        // try next endpoint
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

  Future<_EngineComputeOutcome> _computeEngine() async {
    _syncActiveDrafts();

    final base = _engineBaseResolved;
    if (base == null || base.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _engineStatus = 'Engine no disponible.';
          _engineStatusIsError = true;
        });
      } else {
        _engineStatus = 'Engine no disponible.';
        _engineStatusIsError = true;
      }
      return const _EngineComputeOutcome(
        ok: false,
        hadUpdates: false,
        errorDetails: _EngineErrorDetails(
          message: 'Engine base URL vacia',
        ),
      );
    }
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
        _engineAvailable = false;
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
    required this.onCompute,
  });

  final _SheetPalette palette;

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
  final VoidCallback? onCompute;

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
                            icon: Icons.functions_rounded,
                            label: 'Calcular',
                            onTap: onCompute,
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
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
            icon: Icon(Icons.check_circle_outline_rounded,
                color: palette.fg),
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

class _GridView extends StatelessWidget {
  const _GridView({
    required this.palette,
    required this.headers,
    required this.rowModels,
    required this.cellTextAt,
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
  final List<String> headers;
  final List<_RowModel> rowModels;
  final String Function(int r, int c) cellTextAt;
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
  static const double rowH = 44;
  static const double headerH = 48;
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
                        height: headerH,
                        child: Row(
                          children: [
                            _rowIndexHeader(width: indexW),
                            for (int col = 0; col < headers.length; col++)
                              _HeaderCell(
                                palette: palette,
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
                                height: rowH,
                                child: Row(
                                  children: [
                                    _RowIndexCell(
                                      palette: palette,
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
                                              final invalid =
                                                  isInvalid(r, col);
                                              return _DataCell(
                                                palette: palette,
                                                width: col == headers.length - 1
                                                    ? photosW
                                                    : colW,
                                                text: cellTextAt(r, col),
                                                photosCount:
                                                rowModels[r].photos.length,
                                                thumbB64: rowModels[r]
                                                    .photos
                                                    .isNotEmpty
                                                    ? rowModels[r]
                                                        .photos
                                                        .last
                                                        .thumbB64
                                                    : '',
                                                selected:
                                                r == selRow && col == selCol,
                                                isPhotos: col == headers.length - 1,
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
      height: headerH,
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
          style:
          TextStyle(color: palette.fgMuted, fontWeight: FontWeight.w900)),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.palette,
    required this.width,
    required this.text,
    required this.isPhotos,
    required this.isOverlayTarget,
    required this.editorLink,
    required this.onTap,
    required this.onSecondaryTapDown,
  });

  final _SheetPalette palette;
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

    final cell = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Container(
        width: width,
        height: _GridView.headerH,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: palette.headerBg,
          border: Border(
            right: BorderSide(
                color: palette.borderStrong, width: palette.hairline),
            bottom: BorderSide(
                color: palette.borderStrong, width: palette.hairline),
          ),
        ),
        child: Text(
          t.isEmpty ? ' ' : t,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.fg,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            height: 1.05,
            letterSpacing: 0.1,
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
    required this.width,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.onSecondaryTapDown,
  });

  final _SheetPalette palette;
  final double width;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<TapDownDetails> onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
// ??? Menos ???azul gen??rico???: borde m??s neutro, con halo sutil al seleccionar.
    final neutralRing = palette.isLight
        ? Colors.black.withOpacity(0.14)
        : Colors.white.withOpacity(0.20);

    final glow = palette.accent.withOpacity(palette.isLight ? 0.10 : 0.18);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Container(
        width: width,
        height: _GridView.rowH,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.indexBg,
          border: Border(
            right: BorderSide(
                color: palette.borderStrong, width: palette.hairline),
            bottom: BorderSide(color: palette.border, width: palette.hairline),
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
        foregroundDecoration: selected
            ? BoxDecoration(
          border: Border.all(
              color: neutralRing, width: math.max(palette.hairline, 1.5)),
        )
            : null,
        child: Text(
          index.toString(),
          style: TextStyle(
            color: selected ? palette.fg : palette.fgMuted,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            height: 1.05,
          ),
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  const _DataCell({
    required this.palette,
    required this.width,
    required this.text,
    required this.photosCount,
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
  final double width;
  final String text;
  final int photosCount;
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
    final bg = isActive ? palette.blinkBg : palette.cellBg;
    final borderColor = invalid
        ? Colors.red.withOpacity(palette.isLight ? 0.85 : 0.75)
        : (isActive || selected)
            ? palette.accent.withOpacity(palette.isLight ? 0.55 : 0.7)
            : palette.border;

    final cellBody = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Container(
        width: width,
        height: _GridView.rowH,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            left: BorderSide(color: borderColor, width: palette.hairline),
            top: BorderSide(color: borderColor, width: palette.hairline),
            right: BorderSide(color: borderColor, width: palette.hairline),
            bottom: BorderSide(color: borderColor, width: palette.hairline),
          ),
        ),
        child: isPhotos
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
                    fontSize: 13.5,
                    height: 1.1,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
      ),
    );

    if (!isOverlayTarget) return cellBody;
    return CompositedTransformTarget(link: editorLink, child: cellBody);
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
    final hasThumb = thumbB64.trim().isNotEmpty;
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
              base64Decode(thumbB64),
              width: 26,
              height: 26,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
            ),
          ),
        if (hasThumb) const SizedBox(width: 6),
        Expanded(
          child: Text(
            count == 0 ? '???' : '$count',
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

// ========================= Mobile inline editor bar ========================

class _MobileInlineEditorBar extends StatelessWidget {
  const _MobileInlineEditorBar({
    required this.palette,
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
                                      fontSize: 12.5,
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
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final _SheetPalette palette;
  final VoidCallback? onNext;
  final VoidCallback onDone;

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
        fontSize: 16,
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
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
  });

  final String? name;
  final DateTime? savedAt;
  final List<String> headers;
  final List<_RowModel> rows;

  Map<String, dynamic> toJson() => {
    'name': name,
    'savedAt': savedAt?.toIso8601String(),
    'headers': headers,
    'rows': rows.map((r) => r.toJson()).toList(),
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

    return _SheetModel(
        name: name, savedAt: savedAt, headers: headers, rows: rowModels);
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

  _RowPhoto copyWithoutThumb() =>
      _RowPhoto(
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

class _PhotoExportItem {
  _PhotoExportItem({
    required this.row,
    required this.col,
    required this.photo,
    this.rowLat,
    this.rowLng,
    this.rowAccuracy,
    this.rowIsLastKnown = false,
  });

  final int row;
  final int col;
  final _RowPhoto photo;
  final double? rowLat;
  final double? rowLng;
  final double? rowAccuracy;
  final bool rowIsLastKnown;

  double? get lat => photo.lat ?? rowLat;
  double? get lng => photo.lng ?? rowLng;
  double? get accuracy => photo.accuracyM ?? rowAccuracy;

  String get sourceLabel {
    if (lat == null && lng == null) return '';
    if (photo.lat != null || photo.lng != null) {
      return photo.isLastKnown ? 'lastKnown' : 'current';
    }
    return rowIsLastKnown ? 'lastKnown' : 'current';
  }
}

class _SheetSnapshot {
  _SheetSnapshot({
    required this.name,
    required this.headers,
    required this.rowModels,
    required this.selRow,
    required this.selCol,
  });

  final String name;
  final List<String> headers;
  final List<_RowModel> rowModels;
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

class _GpsFix {
  const _GpsFix({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.ts,
    required this.isLastKnown,
  });

  final double lat;
  final double lng;
  final double accuracyM;
  final DateTime ts;
  final bool isLastKnown;
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
  });

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

// Header Apple card
  final Color headerCardBg;
  final Color headerCardBorder;

// Pills / icon circles
  final Color pillBtnBg;
  final Color pillBtnBorder;

  static _SheetPalette light({required double hairline}) {
    const iosBlue = Color(0xFF0A84FF);

// Apple limpio
    const bg = Color(0xFFF5F5F7);
    const card = Color(0xFFFFFFFF);
    const cell = Color(0xFFFFFFFF);
    const separator = Color(0xFFE5E5EA);
    const ink = Color(0xFF0B0B0C);

    return _SheetPalette(
      isLight: true,
      hairline: hairline,
      bg: bg,
      fg: ink,
      fgMuted: const Color(0xFF6B6B72),
      appBarBg: bg,
      headerBg: card,
      indexBg: card,
      cellBg: cell,
      blinkBg: iosBlue.withOpacity(0.10),
      border: ink.withOpacity(0.10),
      borderStrong: ink.withOpacity(0.14),
      menuBg: card,
      editorBg: card,
      mobileInputBg: const Color(0xFFFFFFFF),
      accent: iosBlue,
      statusBg: iosBlue.withOpacity(0.10),
      statusFg: iosBlue.withOpacity(0.95),
      hintBg: bg,
      headerCardBg: card.withOpacity(0.86),
      headerCardBorder: separator.withOpacity(0.95),
      pillBtnBg: card.withOpacity(0.92),
      pillBtnBorder: separator.withOpacity(0.95),
    );
  }

  static _SheetPalette dark({required double hairline}) {
    const iosBlue = Color(0xFF0A84FF);

// OLED: negro real (apaga p??xel)
    const oledBlack = Color(0xFF000000);

// Header ???tinted gray???
    const headerTint = Color(0xFF121216);

// Blanco Apple (texto primario)
    const appleWhite = Color(0xFFFFFFFF);

    return _SheetPalette(
      isLight: false,
      hairline: hairline,
      bg: oledBlack,
      fg: appleWhite,
      fgMuted: const Color(0xFFB3B3BA),
      appBarBg: oledBlack,
      headerBg: headerTint,
      indexBg: headerTint,
      cellBg: oledBlack,
// ??? blink m??s Apple (no azul fuerte)
      blinkBg: Colors.white.withOpacity(0.06),
      border: const Color(0xFFFFFFFF).withOpacity(0.08),
      borderStrong: const Color(0xFFFFFFFF).withOpacity(0.14),
      menuBg: const Color(0xFF15151A),
      editorBg: const Color(0xFF101014),
// ??? vidrio visible en dark
      mobileInputBg: Colors.white.withOpacity(0.06),
      accent: iosBlue,
      statusBg: const Color(0xFF0F172A),
      statusFg: const Color(0xFF93C5FD),
      hintBg: oledBlack,
      headerCardBg: const Color(0xFF0B0B0C).withOpacity(0.28),
      headerCardBorder: const Color(0xFFFFFFFF).withOpacity(0.14),
      pillBtnBg: const Color(0xFFFFFFFF).withOpacity(0.06),
      pillBtnBorder: const Color(0xFFFFFFFF).withOpacity(0.14),
    );
  }
}

// ============================== Context actions ============================

class _CtxAction {
  _CtxAction(this.label, this.icon, this.run);
  final String label;
  final IconData icon;
  final VoidCallback run;
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
