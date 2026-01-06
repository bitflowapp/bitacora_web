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
import 'dart:typed_data';
import 'dart:ui' show ImageFilter, TileMode;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:url_launcher/url_launcher.dart';
import 'package:bitacora_web/services/photo_acquire_service.dart';
import 'package:bitacora_web/services/keyboard_insets_controller.dart';
import 'package:bitacora_web/services/engine_api.dart';
import 'package:bitacora_web/services/engine_config.dart';

// ============================== Constantes globales ========================

const int kDefaultCols = 15; // 14 + Photos
const String kPhotosHeader = 'Photos';

// ??? Persistencia segura: NO guardar thumbs base64 en prefs/localStorage.
const bool _kPersistPhotoThumbs = false;
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
  static const Duration _saveDebounce = Duration(milliseconds: 650);
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

// Blink visual
  final ValueNotifier<_CellRef?> _blinkCell = ValueNotifier<_CellRef?>(null);

// ??? FIX: blink timer cancelable (evita callback tras dispose)
  Timer? _blinkT;

// Scroll
  final ScrollController _vScroll = ScrollController();
  final ScrollController _hScroll = ScrollController();

// Guardado
  Timer? _saveT;
  bool _saving = false;

// ??? Teclado m??vil: controlador robusto de insets
  late final KeyboardInsetsController _kbController =
  KeyboardInsetsController(onLog: kDebugMode ? debugPrint : null);
  Timer? _kbEnsureDebounceT;
  Timer? _mobileEnsureLateT;
  Timer? _mobileFocusRetryT;

// Undo/Redo
  final List<_SheetSnapshot> _undo = <_SheetSnapshot>[];
  final List<_SheetSnapshot> _redo = <_SheetSnapshot>[];

// Engine compute (opcional)
  bool _engineBusy = false;
  String? _engineStatus;
  String? _engineBaseResolved;
  String? _engineKeyResolved;
  bool _engineAvailable = false;
  late final EngineApi _engineApi = EngineApi();

// ---------------- Mobile inline editor (FIJO arriba del teclado) --------

  bool _mobileEditorOpen = false;
  _MobileEditPhase _mobilePhase = _MobileEditPhase.closed;
  bool _mobileEditingHeader = false;
  int _mobileRow = -1;
  int _mobileCol = 0;
  String _mobileTitle = '';
  String _mobileOriginal = '';

  final TextEditingController _mobileEC = TextEditingController();
  final FocusNode _mobileFocus =
  FocusNode(debugLabel: 'MobileInlineEditorFocus');

  List<_MobileAction> _mobileActions = const [];
  final GlobalKey _mobileBarKey = GlobalKey();
  final Key _mobileFieldKey = const ValueKey('mobileInlineEditorField');
  double _mobileBarH = 0.0;
  bool _mobileBarMeasureScheduled = false;

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

    _rev = 0;
    _lastSavedRev = 0;
    _savePending = false;

    _pushUndoSnapshot(); // estado inicial
    unawaited(_loadLocal());
    unawaited(_initEngineConnection());
  }

  @override
  void didUpdateWidget(covariant EditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

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

    _vScroll.dispose();
    _hScroll.dispose();

    _cellEC.dispose();
    _cellFocus.dispose();

    _mobileEC.dispose();
    _mobileFocus.dispose();

// ??? primero removemos overlay sin setState
    _removeCellEditor(notifyState: false);

    _blinkCell.dispose();

    _nameEC.dispose();
    _nameFocus.dispose();
    _engineApi.dispose();

    super.dispose();
  }

  void _handleKbInsetChanged() {
    if (_mobileEditorOpen && _mobileRow >= 0) {
      _debouncedEnsureRowVisible(_mobileRow);
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

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.trim().isEmpty) return;

      final map = json.decode(raw) as Map<String, dynamic>;
      final loaded = _SheetModel.fromJson(map);

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

      if (!_nameFocus.hasFocus) {
        _nameEC.text = _sheetName;
      }

      _undo
        ..clear()
        ..add(_snapshot());
      _redo.clear();
    } catch (e) {
      if (kDebugMode) debugPrint('[EditorScreen] load failed: $e');
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
      final model = _SheetModel(
        name: _sheetName,
        headers: List<String>.from(_headers),
        rows: _rows
            .map((r) => _RowModel(
          cells: List<String>.from(r.cells),
          photos: r.photos
              .map((p) => p.copyWithoutThumb())
              .toList(growable: false),
        ))
            .toList(growable: false),
        savedAt: savedAt,
      );

      await prefs.setString(_prefsKey, json.encode(model.toJson()));

      _lastSavedRev = startRev;

      if (!mounted) return;
      setState(() {
        _lastSavedAt = savedAt;
// ??? Solo limpio Dirty si no cambi?? mientras guardaba
        _isDirty = _rev != _lastSavedRev;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[EditorScreen] save failed: $e');
    } finally {
      _saving = false;
      if (!mounted) return;

      setState(() {}); // refresca ???Saved??????

// ??? Si entraron cambios mientras guardabas, re-encol??.
      if (_savePending || _rev != _lastSavedRev) {
        _savePending = false;
        _queueSave();
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

  String _savedLabel(_SheetPalette pal) {
    if (_saving) return 'Saving???';
    final d = _lastSavedAt;
    if (d == null) return _isDirty ? 'Not saved' : ' ';
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return 'Saved $hh:$mm';
  }

// ------------------------------ Build -----------------------------------

  @override
  Widget build(BuildContext context) {
    final pal = _palette(context);
    return ValueListenableBuilder<double>(
      valueListenable: _kbController.kbInsetDp,
      builder: (ctx, kbInset, _) {
        final isDesktop = _isDesktopUi(ctx, kbInset);

        if (!isDesktop) {
          _scheduleMobileBarMeasure();
        }

// Evitar escalados raros de texto (iOS / Web).
        final mq = MediaQuery.of(ctx);
        final fixedMq = mq.copyWith(textScaler: const TextScaler.linear(1.0));

        final mqInset = MediaQuery.viewInsetsOf(ctx).bottom;
        _kbController.reportMediaQueryInset(mqInset);

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
                    Column(
                      children: [
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
                        ),
                        if (_engineStatus != null)
                          _StatusBar(
                            text: _engineStatus!,
                            bg: pal.statusBg,
                            fg: pal.statusFg,
                          ),
                        Expanded(
                          child: isDesktop
                              ? Focus(
                            autofocus: true,
                            onKeyEvent: _onKeyEvent,
                            child: RepaintBoundary(
                              child: _GridView(
                                palette: pal,
                                headers: _headers,
                                rowModels: _rows,
                                vScroll: _vScroll,
                                hScroll: _hScroll,
                                selRow: _selRow,
                                selCol: _selCol,
                                blink: _blinkCell,
                                editorLink: _editorLink,
                                overlayTargetCell: _overlayTargetCell,
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
                                    _beginEditCell(context, pal, r, c, w),
                                onHeaderEditRequested: (c, w) =>
                                    _beginEditHeader(context, pal, c, w),
                                onContextMenu: (pos, r, c, isHeader) =>
                                    _openContextMenu(context, pal, pos, r,
                                        c, isHeader),
                                onDeleteRow: (r) => _deleteRow(r),
                                onPickPhoto: (r) => _pickPhotoForRow(r),
                              ),
                            ),
                          )
                              : RepaintBoundary(
                            child: _GridView(
                              palette: pal,
                              headers: _headers,
                              rowModels: _rows,
                              vScroll: _vScroll,
                              hScroll: _hScroll,
                              selRow: _selRow,
                              selCol: _selCol,
                              blink: _blinkCell,
                              editorLink: _editorLink,
                              overlayTargetCell: _overlayTargetCell,
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
                                  _beginEditCell(context, pal, r, c, w),
                              onHeaderEditRequested: (c, w) =>
                                  _beginEditHeader(context, pal, c, w),
                              onContextMenu: (pos, r, c, isHeader) =>
                                  _openContextMenu(
                                      context, pal, pos, r, c, isHeader),
                              onDeleteRow: (r) => _deleteRow(r),
                              onPickPhoto: (r) => _pickPhotoForRow(r),
                            ),
                          ),
                        ),
                        if (!isDesktop && !_mobileEditorOpen)
                          _MobileHintBar(palette: pal),
                      ],
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
                        keyboardInset: kbInset,
                        onPrev: _canMobileNav ? _mobileMovePrev : null,
                        onNext: _canMobileNav ? _mobileMoveNext : null,
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

    return KeyEventResult.ignored;
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
        initial: _headers[c],
        actions: const [],
      );
      return;
    }

    _scheduleOverlayAtHeader(
      col: c,
      width: headerWidth,
      context: context,
      pal: pal,
      initial: _headers[c],
      onCommit: (v) {
        final nv = v.trim();
        if (nv == _headers[c]) return;
        _headers[c] = nv;
        _markDirty(snapshot: true);
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
      BuildContext context, _SheetPalette pal, int r, int c, double cellWidth) {
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
      unawaited(_pickPhotoForRow(r));
      return;
    }

    final isDesktop = _isDesktopUi(context, _kbController.kbInsetDp.value);
    if (!isDesktop) {
      _openMobileInlineEditor(
        isHeader: false,
        row: r,
        col: c,
        title: _headerLabel(c),
        initial: _rows[r].cells[c],
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
      initial: _rows[r].cells[c],
      onCommit: (v) => _setCell(r, c, v),
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
    final t = _headers[c].trim();
    if (t.isNotEmpty) return t;
    if (c == _headers.length - 1) return kPhotosHeader;
    return 'Col ${c + 1}';
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
        final nv = v.trim();
        if (nv != _headers[c]) {
          _headers[c] = nv;
          _markDirty(snapshot: true);
        }
      }
      return;
    }

    final r = _mobileRow;
    final c = _mobileCol;
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    if (c == _headers.length - 1) return;
    if (_rows[r].cells[c] == v) return;

    _setCell(r, c, v);
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
    _mobileOriginal = initial;
    _mobileActions = actions;

    _mobileEC.text = initial;
    _mobileEC.selection =
        TextSelection(baseOffset: 0, extentOffset: _mobileEC.text.length);

    if (!_mobileEditorOpen) {
      setState(() {
        _mobileEditorOpen = true;
        _mobilePhase = _MobileEditPhase.opening;
      });
    } else {
      setState(() => _mobilePhase = _MobileEditPhase.switching);
    }

    _requestMobileFocusWithRetry();

    if (row >= 0) {
      _scheduleEnsureRowVisiblePostFrame(row);
      _scheduleEnsureRowVisibleLate(row);
    }
  }

  List<_MobileAction> _mobileActionsForCell(int r, int c) {
    if (c == _headers.length - 1) return const [];
    return [
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
    if (!_mobileEditorOpen || _mobileRow < 0) return;
    _scheduleEnsureRowVisiblePostFrame(_mobileRow);
    _scheduleEnsureRowVisibleLate(_mobileRow);
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
    _mobileEnsureLateT = Timer(const Duration(milliseconds: 120), () {
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

  void _cancelMobileEnsureTimers() {
    _kbEnsureDebounceT?.cancel();
    _mobileEnsureLateT?.cancel();
    _mobileFocusRetryT?.cancel();
  }

  static const double _kMobileBarFallbackH = 78.0;

  void _ensureRowVisibleForKeyboard(int row) {
    if (!mounted) return;
    if (!_vScroll.hasClients) return;
    if (row < 0) return;

    final kb = _kbController.kbInsetDp.value;

    final viewport = _vScroll.position.viewportDimension;
    final barH = _mobileEditorOpen
        ? (_mobileBarH > 0 ? _mobileBarH : _kMobileBarFallbackH)
        : 0.0;
    final reserve = kb + barH + 8.0;

    final rowTop = row * _GridView.rowH;
    final rowBottom = rowTop + _GridView.rowH;

    final visibleTop = _vScroll.offset;
    final visibleBottom = _vScroll.offset + math.max(0.0, viewport - reserve);

    double? target;
    if (rowBottom > visibleBottom) {
      target = rowBottom - math.max(0.0, viewport - reserve);
    } else if (rowTop < visibleTop) {
      target = rowTop;
    }

    if (target == null) {
      _ensureColumnVisibleForMobile();
      return;
    }

    final clamped = target.clamp(
        _vScroll.position.minScrollExtent, _vScroll.position.maxScrollExtent);
    if ((clamped - _vScroll.offset).abs() < 6.0) {
      _ensureColumnVisibleForMobile();
      return;
    }
    _vScroll.animateTo(
      clamped.toDouble(),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );

    _ensureColumnVisibleForMobile();
  }

  void _ensureColumnVisibleForMobile() {
    if (!_mobileEditorOpen) return;
    if (!_hScroll.hasClients) return;
    if (_mobileCol < 0 || _mobileCol >= _headers.length) return;

    final colW = _idealColWidth(context);
    const photosW = 140.0;
    final col = _mobileCol;

    final colLeft = _GridView.indexW + (col * colW);
    final colWidth = col == _headers.length - 1 ? photosW : colW;
    final colRight = colLeft + colWidth;

    final viewport = _hScroll.position.viewportDimension;
    final visibleLeft = _hScroll.offset;
    final visibleRight = visibleLeft + viewport;
    const pad = 16.0;

    double? target;
    if (colLeft - pad < visibleLeft) {
      target = colLeft - pad;
    } else if (colRight + pad > visibleRight) {
      target = colRight + pad - viewport;
    }

    if (target == null) return;

    final clamped = target.clamp(
        _hScroll.position.minScrollExtent, _hScroll.position.maxScrollExtent);
    if ((clamped - _hScroll.offset).abs() < 6.0) return;
    _hScroll.animateTo(
      clamped.toDouble(),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  double _idealColWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 420) return 126;
    if (w < 760) return 150;
    return 178;
  }

  bool get _canMobileNav {
    return _mobileEditorOpen && !_mobileEditingHeader && _headers.length >= 2;
  }

  int get _lastEditableCol => math.max(0, _headers.length - 2);

  void _mobileCommitDraftToModel() {
    if (!_mobileEditorOpen) return;

    final v = _mobileEC.text;
    if (_mobileEditingHeader) return;

    if (_mobileRow < 0 || _mobileRow >= _rows.length) return;
    if (_mobileCol < 0 || _mobileCol >= _headers.length) return;
    if (_mobileCol == _headers.length - 1) return;
    if (_rows[_mobileRow].cells[_mobileCol] == v) return;

    _setCell(_mobileRow, _mobileCol, v);
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

    _mobileEC.text = _rows[r].cells[c];
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

    _mobileEC.text = _rows[r].cells[c];
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
    setState(() {
      _mobileEditorOpen = false;
      _mobilePhase = _MobileEditPhase.closing;
    });
    _mobileEditingHeader = false;
    _mobileRow = -1;
    _mobileCol = 0;
    _mobileTitle = '';
    _mobileOriginal = '';
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
    final v = _mobileEC.text;

    if (_mobileEditingHeader) {
      final c = _mobileCol;
      if (c >= 0 && c < _headers.length - 1) {
        final nv = v.trim();
        if (nv != _headers[c]) {
          _headers[c] = nv;
          _markDirty(snapshot: true);
        }
      }
      _closeMobileEditor();
      return;
    }

    final r = _mobileRow;
    final c = _mobileCol;

    _closeMobileEditor();
    _setCell(r, c, v);
  }

  void _closeMobileEditor() {
    _cancelMobileEnsureTimers();
    setState(() {
      _mobileEditorOpen = false;
      _mobilePhase = _MobileEditPhase.closing;
    });
    _mobileEditingHeader = false;
    _mobileRow = -1;
    _mobileCol = 0;
    _mobileTitle = '';
    _mobileOriginal = '';
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
        if (_rows.isEmpty) _rows.add(_RowModel.empty(_headers.length));
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

    _cellEC.text = initial;
    _cellEC.selection =
        TextSelection(baseOffset: 0, extentOffset: _cellEC.text.length);

    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

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

    Timer(const Duration(milliseconds: 20), () {
      if (!mounted) return;
      _cellFocus.requestFocus();
    });
  }

  void _removeCellEditor({bool notifyState = true}) {
    _cellEditorEntry?.remove();
    _cellEditorEntry = null;

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
          'Borrar fila', Icons.delete_outline_rounded, () => _deleteRow(r)));
    }

    if (actions.isEmpty) return;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

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
    _pushUndoSnapshot();
    _queueSave();
  }

  void _deleteRow(int r) {
    if (_rows.isEmpty) return;
    final idx = r.clamp(0, _rows.length - 1);

    setState(() {
      _rows.removeAt(idx);
      if (_rows.isEmpty) _rows.add(_RowModel.empty(_headers.length));
      _selRow = _selRow.clamp(0, _rows.length - 1);

      _isDirty = true;
      _rev++;
    });

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
    final fix = await _getGpsFix();
    if (!mounted) return;
    if (fix == null) return;

    final text =
        '${fix.lat.toStringAsFixed(6)}, ${fix.lng.toStringAsFixed(6)} ??${fix.accuracyM.round()} m';
    _setCell(r, c, text);
  }

  Future<_GpsFix?> _getGpsFix() async {
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

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );

      return _GpsFix(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyM: pos.accuracy,
        ts: pos.timestamp ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
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

  Future<void> _pickPhotoForRow(int r) async {
    if (r < 0 || r >= _rows.length) return;

    try {
      final result = _isAndroidDevice
          ? await PhotoAcquireService.I.captureFromCamera()
          : await PhotoAcquireService.I.pickFromGallery();
      if (!mounted) return;
      if (result == null) return;

      final thumb =
      _compressThumb(result.bytes, maxW: 560, maxH: 560, quality: 78);
      final b64 = base64Encode(thumb);

// ??? thumb runtime s?? (para futuro visor), persistencia no.
      _rows[r].photos.add(
        _RowPhoto(
          name: result.name,
          mime: result.mime,
          thumbB64: b64,
          addedAt: DateTime.now(),
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

      final thumb =
      _compressThumb(result.bytes, maxW: 560, maxH: 560, quality: 78);
      final b64 = base64Encode(thumb);

      _rows[r].photos.add(
        _RowPhoto(
          name: result.name,
          mime: result.mime,
          thumbB64: b64,
          addedAt: DateTime.now(),
        ),
      );

      _markDirty(snapshot: true);
    } catch (_) {}
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
      final wb = xlsio.Workbook();
      final sheet = wb.worksheets[0];
      sheet.name = _sheetName;

      for (int c = 0; c < _headers.length; c++) {
        final text = _headerLabel(c);
        final cell = sheet.getRangeByIndex(1, c + 1);
        cell.setText(text);
        cell.cellStyle.bold = true;
      }

      for (int r = 0; r < _rows.length; r++) {
        for (int c = 0; c < _headers.length; c++) {
          if (c == _headers.length - 1) continue; // Photos no export texto
          final v = _rows[r].cells[c];
          if (v.trim().isEmpty) continue;
          sheet.getRangeByIndex(r + 2, c + 1).setText(v);
        }
      }

      for (int c = 0; c < _headers.length; c++) {
        try {
          sheet.autoFitColumn(c + 1);
        } catch (_) {}
      }

      final bytes = wb.saveAsStream();
      wb.dispose();

      final now = DateTime.now();
      final filename =
          '${_safeFile(_sheetName)}_${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}.xlsx';

      final xf = XFile.fromData(
        Uint8List.fromList(bytes),
        name: filename,
        mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

// ??? Web: getSaveLocation puede no estar disponible -> fallback a ???download???.
      if (kIsWeb) {
        try {
          await xf.saveTo(filename);
          return;
        } catch (_) {
// seguimos con getSaveLocation
        }
      }

      final typeGroup = XTypeGroup(label: 'Excel', extensions: const ['xlsx']);
      final loc = await getSaveLocation(
          suggestedName: filename, acceptedTypeGroups: [typeGroup]);
      if (loc == null) return;
      await xf.saveTo(loc.path);
    } catch (_) {}
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
      } else {
        _engineStatus = null;
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
    if (error is EngineApiException) {
      return 'Engine error HTTP ${error.statusCode}: ${error.bodySnippet}';
    }
    final text = error.toString();
    if (kIsWeb &&
        (text.contains('XMLHttpRequest') || text.contains('Failed to fetch'))) {
      return 'CORS bloqueado: habilitar allow_origins en FastAPI para el dominio del tunel.';
    }
    return 'Engine no responde. En movil fisico, 127.0.0.1 es el telefono: usa IP LAN o tunel.';
  }

  Future<void> _computeEngine() async {
    final base = _engineBaseResolved;
    if (base == null || base.trim().isEmpty) return;
    if (_engineBusy) return;

    setState(() {
      _engineBusy = true;
      _engineStatus = 'Computando...';
    });

    try {
      final payload = <String, dynamic>{
        // Requerido por tu backend
        'sheet_id': widget.sheetId,
        // Recomendado (te evita heur??sticas raras)
        'operation': 'calc',
        'headers': _headers,
        'rows': _rows.map((r) => r.cells).toList(),
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

      if (!mounted) return;

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
          _isDirty = true;
          _rev++;
        });

        _pushUndoSnapshot();
        _queueSave();
        return;
      }

      if (updatedCells.isNotEmpty) {
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
          }
          _engineStatus = (map['message'] ?? 'Listo').toString();
          _isDirty = true;
          _rev++;
        });

        _pushUndoSnapshot();
        _queueSave();
        return;
      }

      setState(() => _engineStatus = (map['message'] ?? 'Sin cambios').toString());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _engineStatus = _engineErrorMessage(e);
        _engineAvailable = false;
      });
    } finally {
      if (!mounted) return;
      setState(() => _engineBusy = false);

      Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _engineStatus = null);
      });
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
                                          return _DataCell(
                                            palette: palette,
                                            width: col == headers.length - 1
                                                ? photosW
                                                : colW,
                                            text: rowModels[r].cells[col],
                                            photosCount:
                                            rowModels[r].photos.length,
                                            selected:
                                            r == selRow && col == selCol,
                                            isPhotos: col == headers.length - 1,
                                            blinkRef: blinkRef,
                                            cellRef: ref,
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
    required this.selected,
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
  final bool selected;
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
    final blinking = blinkRef == cellRef;

// ??? Noche: blink no azul ???plastificado???; es un flash suave.
    final bg = blinking ? palette.blinkBg : palette.cellBg;

    final cellBody = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Container(
        width: width,
        height: _GridView.rowH,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            right: BorderSide(color: palette.border, width: palette.hairline),
            bottom: BorderSide(color: palette.border, width: palette.hairline),
          ),
        ),
        child: isPhotos
            ? _PhotosCell(
          palette: palette,
          count: photosCount,
          onAdd: onPickPhoto,
          onDeleteRow: onDeleteRow,
        )
            : _PillText(
// ??? siempre visible (aunque est?? vac??a)
          text: text.trim().isEmpty ? ' ' : text,
          palette: palette,
          selected: selected,
        ),
      ),
    );

    if (!isOverlayTarget) return cellBody;
    return CompositedTransformTarget(link: editorLink, child: cellBody);
  }
}

class _PillText extends StatelessWidget {
  const _PillText({
    required this.text,
    required this.palette,
    required this.selected,
  });

  final String text;
  final _SheetPalette palette;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isLight = palette.isLight;

// ??? ???Glass??? m??s legible en dark (sin matar OLED).
    final Color top = isLight
        ? const Color(0xFFFFFFFF).withOpacity(0.92)
        : Colors.white.withOpacity(selected ? 0.26 : 0.18);

    final Color bottom = isLight
        ? const Color(0xFFF5F5F7).withOpacity(0.86)
        : Colors.white.withOpacity(selected ? 0.18 : 0.12);

    final Color edge = isLight
        ? const Color(0xFFE5E5EA).withOpacity(0.95)
        : Colors.white.withOpacity(selected ? 0.34 : 0.22);

// ??? Selecci??n ???Apple???: borde neutro + halo sutil (menos azul duro).
    final Color neutralRing = isLight
        ? Colors.black.withOpacity(selected ? 0.18 : 0.12)
        : Colors.white.withOpacity(selected ? 0.30 : 0.20);

    final Color tint = selected
        ? palette.accent.withOpacity(isLight ? 0.06 : 0.10)
        : Colors.transparent;

    final Color shadow = isLight
        ? Colors.black.withOpacity(0.06)
        : Colors.black.withOpacity(0.62);

    final Color glow = palette.accent.withOpacity(isLight ? 0.14 : 0.22);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? neutralRing : edge,
          width: math.max(palette.hairline, selected ? 1.2 : 1.0),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom, tint],
          stops: const [0.0, 0.86, 1.0],
        ),
        boxShadow: [
// ??? highlight suave ???glass???
          if (!isLight)
            BoxShadow(
              color: Colors.white.withOpacity(selected ? 0.08 : 0.05),
              blurRadius: 10,
              offset: const Offset(-2, -2),
            ),
          BoxShadow(
            color: shadow,
            blurRadius: selected ? 14 : 9,
            offset: const Offset(0, 4),
          ),
          if (selected)
            BoxShadow(
              color: glow,
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: palette.fg,
          fontSize: 15.0,
          height: 1.08,
          fontWeight: FontWeight.w800, // ??? nitidez
          letterSpacing: -0.15,
        ),
      ),
    );
  }
}

class _PhotosCell extends StatelessWidget {
  const _PhotosCell({
    required this.palette,
    required this.count,
    required this.onAdd,
    required this.onDeleteRow,
  });

  final _SheetPalette palette;
  final int count;
  final VoidCallback onAdd;
  final VoidCallback onDeleteRow;

  @override
  Widget build(BuildContext context) {
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

class _MobileHintBar extends StatelessWidget {
  const _MobileHintBar({required this.palette});
  final _SheetPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.hintBg,
        border: Border(
          top: BorderSide(color: palette.borderStrong, width: palette.hairline),
        ),
      ),
      child: Text(
        'Tap = editar. Mantener = men??.',
        style: TextStyle(
            color: palette.fgMuted,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            height: 1.05),
      ),
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
    required this.onPrev,
    required this.onNext,
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

  final VoidCallback? onPrev;
  final VoidCallback? onNext;

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
          bottom: false,
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
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: palette.appBarBg,
                    border: Border(
                      top: BorderSide(
                          color: palette.borderStrong, width: palette.hairline),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
// ??? glass del editor m??vil (se nota m??s en dark)
                      filter: ImageFilter.blur(
                        sigmaX: palette.isLight ? 14 : 16,
                        sigmaY: palette.isLight ? 14 : 16,
                        tileMode: TileMode.decal,
                      ),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: palette.editorBg
                              .withOpacity(palette.isLight ? 0.88 : 0.62),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: palette.borderStrong,
                              width: palette.hairline),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(palette.isLight ? 0.08 : 0.42),
                              blurRadius: 16,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Cancelar (Esc)',
                              onPressed: onCancel,
                              icon: Icon(Icons.close_rounded,
                                  color: palette.fgMuted),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: palette.headerBg
                                    .withOpacity(palette.isLight ? 1.0 : 0.72),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                    color: palette.border,
                                    width: palette.hairline),
                              ),
                              child: Text(
                                title.isEmpty ? 'Editar' : title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.fgMuted,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  height: 1.05,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
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
                            if (onPrev != null)
                              IconButton(
                                tooltip: 'Anterior',
                                onPressed: onPrev,
                                icon: Icon(Icons.chevron_left_rounded,
                                    color: palette.fg),
                              ),
                            if (onNext != null)
                              IconButton(
                                tooltip: 'Siguiente',
                                onPressed: onNext,
                                icon: Icon(Icons.chevron_right_rounded,
                                    color: palette.fg),
                              ),
                            for (final a in actions)
                              IconButton(
                                tooltip: a.label,
                                onPressed: a.onTap,
                                icon: Icon(a.icon, color: palette.fg),
                              ),
                            IconButton(
                              tooltip: 'OK',
                              onPressed: onDone,
                              icon:
                              Icon(Icons.check_rounded, color: palette.fg),
                            ),
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
      maxLines: 1,
      enabled: true,
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
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
  _RowModel({required this.cells, required this.photos});

  final List<String> cells;
  final List<_RowPhoto> photos;

  factory _RowModel.empty(int cols) => _RowModel(
    cells: List<String>.filled(cols, ''),
    photos: <_RowPhoto>[],
  );

  factory _RowModel.fromCells(List<String> cells) =>
      _RowModel(cells: cells, photos: <_RowPhoto>[]);

  _RowModel copy() => _RowModel(
    cells: List<String>.from(cells),
    photos: photos.map((p) => p.copy()).toList(),
  );

// ??? Snapshot para Undo/Redo: copia fotos SIN thumbs (liviano).
  _RowModel copyForSnapshot() => _RowModel(
    cells: List<String>.from(cells),
    photos: photos.map((p) => p.copyWithoutThumb()).toList(growable: false),
  );

  _RowModel copyWithCells(List<String> newCells) => _RowModel(
    cells: List<String>.from(newCells),
    photos: photos.map((p) => p.copy()).toList(),
  );

  Map<String, dynamic> toJson() => {
    'cells': cells,
// ??? Persistencia segura: sin thumbs base64 (evita overflow prefs/localStorage).
    'photos': photos
        .map((p) => p.toJson(persistThumb: _kPersistPhotoThumbs))
        .toList(),
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
    return _RowModel(cells: cells, photos: photos);
  }
}

class _RowPhoto {
  _RowPhoto({
    required this.name,
    required this.mime,
    required this.thumbB64,
    required this.addedAt,
  });

  final String name;
  final String mime;
  final String thumbB64;
  final DateTime addedAt;

  _RowPhoto copy() =>
      _RowPhoto(name: name, mime: mime, thumbB64: thumbB64, addedAt: addedAt);

  _RowPhoto copyWithoutThumb() =>
      _RowPhoto(name: name, mime: mime, thumbB64: '', addedAt: addedAt);

  Map<String, dynamic> toJson({required bool persistThumb}) => {
    'name': name,
    'mime': mime,
// ??? NO guardamos thumb por defecto (evita que se rompa la carga por tama??o).
    'thumbB64': persistThumb ? thumbB64 : '',
    'addedAt': addedAt.toIso8601String(),
  };

  static _RowPhoto fromJson(Map<String, dynamic> map) {
    return _RowPhoto(
      name: (map['name'] ?? '').toString(),
      mime: (map['mime'] ?? 'image/jpeg').toString(),
      thumbB64: (map['thumbB64'] ?? '').toString(),
      addedAt: DateTime.tryParse((map['addedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
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

class _GpsFix {
  const _GpsFix({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.ts,
  });

  final double lat;
  final double lng;
  final double accuracyM;
  final DateTime ts;
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
