// lib/screens/editor_screen.dart
//
// BitFlow / Gridnote — EditorScreen
// Grilla editable “tipo Notes”: 1 toque => parpadeo => editar.
// Mobile (incluye Web iOS/Android): editor inferior FIJO arriba del teclado.
// Desktop: edición in-cell con overlay anclado a la celda (no modal centrado).
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
// © 2025

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:url_launcher/url_launcher.dart';

// ============================== Constantes globales ========================

const int kDefaultCols = 15; // 14 + Photos
const String kPhotosHeader = 'Photos';

// ============================== Pantalla principal =========================

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.sheetId,
    this.initialName,
    this.initialHeaders,
    this.initialRows,
    this.engineBaseUrl,
    this.isLight, // ✅ para compat con StartPage
    this.onToggleTheme, // ✅ compat con StartPage
  });

  final String sheetId;
  final String? initialName;
  final List<String>? initialHeaders;
  final List<List<String>>? initialRows;
  final String? engineBaseUrl;

  /// Si StartPage te lo pasa, lo respetamos; si no, usamos platform brightness.
  final bool? isLight;

  /// Si StartPage lo maneja global, lo dispara desde acá.
  final VoidCallback? onToggleTheme;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with TickerProviderStateMixin {
  // ------------------------------ Constantes -------------------------------

  static const int kMaxUndo = 50;
  static const Duration _blinkDuration = Duration(milliseconds: 110);
  static const Duration _saveDebounce = Duration(milliseconds: 650);

  // ------------------------------ Estado ----------------------------------

  late String _sheetName;

  late List<String> _headers;
  late List<_RowModel> _rows;

  bool _isLight = true;
  bool _isDirty = false;

  int _selRow = 0;
  int _selCol = 0;

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

  // Scroll
  final ScrollController _vScroll = ScrollController();
  final ScrollController _hScroll = ScrollController();

  // Guardado
  Timer? _saveT;
  bool _saving = false;

  // Undo/Redo
  final List<_SheetSnapshot> _undo = <_SheetSnapshot>[];
  final List<_SheetSnapshot> _redo = <_SheetSnapshot>[];

  // Engine compute (opcional)
  bool _engineBusy = false;
  String? _engineStatus;

  // ---------------- Mobile inline editor (FIJO arriba del teclado) --------

  bool _mobileEditorOpen = false;
  bool _mobileEditingHeader = false;
  int _mobileRow = -1;
  int _mobileCol = 0;
  String _mobileTitle = '';
  String _mobileOriginal = '';

  final TextEditingController _mobileEC = TextEditingController();
  final FocusNode _mobileFocus = FocusNode(debugLabel: 'MobileInlineEditorFocus');

  List<_MobileAction> _mobileActions = const [];

  // ------------------------------ Init/Dispose ----------------------------

  @override
  void initState() {
    super.initState();

    _sheetName = (widget.initialName?.trim().isNotEmpty ?? false) ? widget.initialName!.trim() : 'Sheet';

    _isLight = widget.isLight ??
        (WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.light);

    final initial = _buildInitialState();
    _headers = initial.headers;
    _rows = initial.rows;

    _pushUndoSnapshot(); // estado inicial
    unawaited(_loadLocal());
  }

  @override
  void didUpdateWidget(covariant EditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si el padre cambia isLight, lo reflejamos localmente.
    final newLight = widget.isLight;
    if (newLight != null && newLight != oldWidget.isLight && newLight != _isLight) {
      setState(() => _isLight = newLight);
    }
  }

  @override
  void dispose() {
    _saveT?.cancel();

    _vScroll.dispose();
    _hScroll.dispose();

    _cellEC.dispose();
    _cellFocus.dispose();

    _mobileEC.dispose();
    _mobileFocus.dispose();

    _blinkCell.dispose();
    _removeCellEditor();

    super.dispose();
  }

  // ------------------------------ Construcción inicial --------------------

  _SheetModel _buildInitialState() {
    final headers = (widget.initialHeaders != null && widget.initialHeaders!.isNotEmpty)
        ? _normalizeHeaders(widget.initialHeaders!)
        : _defaultHeaders();

    final rowModels = <_RowModel>[];

    if (widget.initialRows != null && widget.initialRows!.isNotEmpty) {
      for (final r in widget.initialRows!) {
        rowModels.add(_RowModel.fromCells(_normalizeRow(r, headers.length)));
      }
    } else {
      // 3 filas vacías por defecto (mobile-friendly)
      for (int i = 0; i < 3; i++) {
        rowModels.add(_RowModel.empty(headers.length));
      }
    }

    return _SheetModel(headers: headers, rows: rowModels, name: _sheetName);
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

    // Photos al final sí o sí
    if (h.isNotEmpty) h[h.length - 1] = kPhotosHeader;
    return h;
  }

  // ✅ FIX: aceptar List<String> y List<dynamic> (Iterable es covariante).
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
        _sheetName = (loaded.name?.trim().isNotEmpty ?? false) ? loaded.name!.trim() : _sheetName;
        _headers = loadedHeaders;
        _rows = normalizedRows.isNotEmpty ? normalizedRows : <_RowModel>[_RowModel.empty(_headers.length)];
        _isDirty = false;
      });

      _undo
        ..clear()
        ..add(_snapshot());
      _redo.clear();
    } catch (_) {
      // si rompe, no matamos la UX
    }
  }

  Future<void> _saveLocalNow() async {
    if (_saving) return;
    _saving = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final model = _SheetModel(name: _sheetName, headers: _headers, rows: _rows);
      await prefs.setString(_prefsKey, json.encode(model.toJson()));

      if (!mounted) return;
      setState(() => _isDirty = false);
    } catch (_) {
      // silencio
    } finally {
      _saving = false;
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
    rowModels: _rows.map((r) => r.copy()).toList(),
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
      _rows = prev.rowModels.map((r) => r.copy()).toList();
      _selRow = prev.selRow.clamp(0, _rows.length - 1);
      _selCol = prev.selCol.clamp(0, _headers.length - 1);
      _isDirty = true;
    });
    _queueSave();
  }

  void _redoOnce() {
    if (_redo.isEmpty) return;
    final snap = _redo.removeLast();
    _undo.add(snap);

    setState(() {
      _sheetName = snap.name;
      _headers = List<String>.from(snap.headers);
      _rows = snap.rowModels.map((r) => r.copy()).toList();
      _selRow = snap.selRow.clamp(0, _rows.length - 1);
      _selCol = snap.selCol.clamp(0, _headers.length - 1);
      _isDirty = true;
    });
    _queueSave();
  }

  // ------------------------------ Tema / Paleta ---------------------------

  _SheetPalette _palette(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final hair = math.max(0.5, 1.0 / dpr);
    return _isLight ? _SheetPalette.light(hairline: hair) : _SheetPalette.dark(hairline: hair);
  }

  // ✅ FIX: compat tema global (StartPage) + feedback local.
  void _toggleTheme() {
    widget.onToggleTheme?.call();
    setState(() => _isLight = !_isLight);
  }

  // ------------------------------ Utilidades UI ---------------------------

  bool _isMobileWeb() {
    if (!kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;
  }

  bool _isDesktopUi(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // ✅ PARCHE: teléfonos (iPhone/Android) SIEMPRE UI móvil (evita overlay editor y bugs de teclado)
    if (size.shortestSide < 600) return false;

    // ✅ blindaje extra: si el teclado está abierto, no uses desktop overlay
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return false;

    if (_isMobileWeb()) return false;

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
      return false;
    }

    final w = size.width;

    bool mouse = false;
    try {
      mouse = RendererBinding.instance.mouseTracker.mouseIsConnected;
    } catch (_) {
      mouse = false;
    }

    return w >= 900 || mouse;
  }

  void _blink(int r, int c) {
    final ref = _CellRef(r, c);
    _blinkCell.value = ref;

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
    }

    Timer(_blinkDuration, () {
      if (_blinkCell.value == ref) _blinkCell.value = null;
    });
  }

  void _markDirty({bool snapshot = true}) {
    if (snapshot) _pushUndoSnapshot();
    setState(() => _isDirty = true);
    _queueSave();
  }

  // ------------------------------ Build -----------------------------------

  @override
  Widget build(BuildContext context) {
    final pal = _palette(context);
    final isDesktop = _isDesktopUi(context);

    return Scaffold(
      resizeToAvoidBottomInset: false, // ✅ clave iOS Web
      backgroundColor: pal.bg,
      appBar: AppBar(
        backgroundColor: pal.appBarBg,
        foregroundColor: pal.fg,
        elevation: 0,
        titleSpacing: 12,
        title: _TitleField(
          initial: _sheetName,
          color: pal.fg,
          hintColor: pal.fgMuted,
          onChanged: (v) {
            final nv = v.trim();
            if (nv.isEmpty) return;
            _sheetName = nv;
            _markDirty(snapshot: false);
          },
        ),
        actions: [
          IconButton(
            tooltip: _isLight ? 'Modo noche' : 'Modo blanco',
            onPressed: _toggleTheme,
            icon: Icon(_isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
          ),
          IconButton(tooltip: 'Undo', onPressed: _undoOnce, icon: const Icon(Icons.undo_rounded)),
          IconButton(tooltip: 'Redo', onPressed: _redoOnce, icon: const Icon(Icons.redo_rounded)),
          IconButton(
            tooltip: 'Agregar fila',
            onPressed: () => _insertRow(_rows.length),
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: 'Export XLSX',
            onPressed: _exportXlsx,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: 'Compute',
            onPressed: widget.engineBaseUrl == null ? null : _computeEngine,
            icon: const Icon(Icons.bolt_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Stack(
          children: [
            Column(
              children: [
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
                        overlayTargetHeaderCol: _overlayTargetHeaderCol,
                        onSelect: (r, c) {
                          setState(() {
                            _selRow = r;
                            _selCol = c;
                          });
                          _blink(r, c);
                        },
                        onEditRequested: (r, c, w) => _beginEditCell(context, pal, r, c, w),
                        onHeaderEditRequested: (c, w) => _beginEditHeader(context, pal, c, w),
                        onContextMenu: (pos, r, c, isHeader) =>
                            _openContextMenu(context, pal, pos, r, c, isHeader),
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
                      overlayTargetHeaderCol: _overlayTargetHeaderCol,
                      onSelect: (r, c) {
                        setState(() {
                          _selRow = r;
                          _selCol = c;
                        });
                        _blink(r, c);
                      },
                      onEditRequested: (r, c, w) => _beginEditCell(context, pal, r, c, w),
                      onHeaderEditRequested: (c, w) => _beginEditHeader(context, pal, c, w),
                      onContextMenu: (pos, r, c, isHeader) =>
                          _openContextMenu(context, pal, pos, r, c, isHeader),
                      onDeleteRow: (r) => _deleteRow(r),
                      onPickPhoto: (r) => _pickPhotoForRow(r),
                    ),
                  ),
                ),
                if (!isDesktop && !_mobileEditorOpen) _MobileHintBar(palette: pal),
              ],
            ),
            if (!isDesktop && _mobileEditorOpen)
              _MobileInlineEditorBar(
                palette: pal,
                title: _mobileTitle,
                controller: _mobileEC,
                focusNode: _mobileFocus,
                actions: _mobileActions,
                onCancel: _cancelMobileEdit,
                onDone: _commitMobileEdit,
              ),
          ],
        ),
      ),
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
      final pal = _palette(context);
      _beginEditCell(context, pal, _selRow, _selCol, 340);
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

    if (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
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

  // ------------------------------ Edición Header --------------------------

  void _beginEditHeader(BuildContext context, _SheetPalette pal, int c, double headerWidth) {
    if (c < 0 || c >= _headers.length) return;
    if (c == _headers.length - 1) return; // Photos no editable

    _removeCellEditor();
    _blink(-1, c);

    final isDesktop = _isDesktopUi(context);
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
        _headers[c] = v.trim();
        _markDirty(snapshot: true);
        setState(() {});
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

  // ------------------------------ Edición Celda ---------------------------

  void _beginEditCell(BuildContext context, _SheetPalette pal, int r, int c, double cellWidth) {
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

    final isDesktop = _isDesktopUi(context);
    if (!isDesktop) {
      _openMobileInlineEditor(
        isHeader: false,
        row: r,
        col: c,
        title: _headerLabel(c),
        initial: _rows[r].cells[c],
        actions: [
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
        ],
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
    setState(() {});
  }

  // ------------------------- Mobile inline editor -------------------------

  void _openMobileInlineEditor({
    required bool isHeader,
    required int row,
    required int col,
    required String title,
    required String initial,
    required List<_MobileAction> actions,
  }) {
    if (_mobileEditorOpen) {
      _commitMobileEdit();
    }

    _mobileEditingHeader = isHeader;
    _mobileRow = row;
    _mobileCol = col;
    _mobileTitle = title;
    _mobileOriginal = initial;
    _mobileActions = actions;

    _mobileEC.text = initial;
    _mobileEC.selection = TextSelection(baseOffset: 0, extentOffset: _mobileEC.text.length);

    setState(() => _mobileEditorOpen = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mobileFocus.requestFocus();
      Future<void>.delayed(const Duration(milliseconds: 60), () {
        if (!mounted) return;
        _mobileFocus.requestFocus();
      });
    });
  }

  void _cancelMobileEdit() {
    setState(() => _mobileEditorOpen = false);
    _mobileEditingHeader = false;
    _mobileRow = -1;
    _mobileCol = 0;
    _mobileTitle = '';
    _mobileOriginal = '';
    _mobileActions = const [];
    try {
      _mobileFocus.unfocus();
    } catch (_) {}
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
    setState(() => _mobileEditorOpen = false);
    _mobileEditingHeader = false;
    _mobileRow = -1;
    _mobileCol = 0;
    _mobileTitle = '';
    _mobileOriginal = '';
    _mobileActions = const [];
    try {
      _mobileFocus.unfocus();
    } catch (_) {}
  }

  // ------------------------------ Overlay Editor (Desktop) ----------------

  void _showOverlayEditor({
    required BuildContext context,
    required _SheetPalette pal,
    required String initial,
    required double width,
    required ValueChanged<String> onCommit,
  }) {
    _removeCellEditor();

    _cellEC.text = initial;
    _cellEC.selection = TextSelection(baseOffset: 0, extentOffset: _cellEC.text.length);

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
                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                      _removeCellEditor();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Container(
                    width: width,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: pal.editorBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: pal.borderStrong, width: pal.hairline),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(pal.isLight ? 0.10 : 0.42),
                          blurRadius: 18,
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
                            style: TextStyle(color: pal.fg, fontSize: 15, height: 1.15),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Escribir…',
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Icon(Icons.check_rounded, color: pal.fg, size: 20),
                          ),
                        ),
                      ],
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

  void _removeCellEditor() {
    _cellEditorEntry?.remove();
    _cellEditorEntry = null;

    if (mounted && (_overlayTargetCell != null || _overlayTargetHeaderCol != null)) {
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
        actions.add(_CtxAction('Editar encabezado', Icons.edit_outlined, () => _beginEditHeader(context, pal, c, 220)));
        actions.add(_CtxAction('Limpiar encabezado', Icons.clear_rounded, () {
          _headers[c] = '';
          _markDirty(snapshot: true);
          setState(() {});
        }));
      }
    } else {
      actions.add(_CtxAction('Editar', Icons.edit_outlined, () => _beginEditCell(context, pal, r, c, 320)));
      actions.add(_CtxAction('Copiar', Icons.copy_rounded, () => unawaited(_copySelectionToClipboard())));
      actions.add(_CtxAction('Pegar', Icons.paste_rounded, () => unawaited(_pasteFromClipboard())));
      actions.add(_CtxAction('Limpiar celda', Icons.backspace_outlined, () => _setCell(r, c, '')));

      if (c != _headers.length - 1) {
        actions.add(_CtxAction('GPS -> celda', Icons.my_location_outlined, () => unawaited(_pasteGpsIntoCell(r, c))));
        actions.add(_CtxAction('Maps', Icons.map_outlined, () => unawaited(_openMapsForCell(r, c))));
      } else {
        actions.add(_CtxAction('Agregar foto', Icons.add_photo_alternate_outlined, () => unawaited(_pickPhotoForRow(r))));
      }

      actions.add(_CtxAction('Insertar fila arriba', Icons.arrow_upward_rounded, () => _insertRow(r)));
      actions.add(_CtxAction('Insertar fila abajo', Icons.arrow_downward_rounded, () => _insertRow(r + 1)));
      actions.add(_CtxAction('Borrar fila', Icons.delete_outline_rounded, () => _deleteRow(r)));
    }

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
                Expanded(child: Text(actions[i].label, style: TextStyle(color: pal.fg))),
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

    final startR = _selRow;
    final startC = _selCol;
    final maxCols = _headers.length - 1; // no pegamos sobre Photos

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
        if (cc >= maxCols) break;
        _rows[rr].cells[cc] = row[dc];
      }
    }

    _markDirty(snapshot: true);
    setState(() {});
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
    if (fix == null) return;

    final text = '${fix.lat.toStringAsFixed(6)}, ${fix.lng.toStringAsFixed(6)} ±${fix.accuracyM.round()} m';
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
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
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

    final m = RegExp(r'(-?\d+(?:\.\d+)?)[,\s]+(-?\d+(?:\.\d+)?)').firstMatch(txt);
    if (m == null) return;

    final lat = double.tryParse(m.group(1) ?? '');
    final lng = double.tryParse(m.group(2) ?? '');
    if (lat == null || lng == null) return;

    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // ------------------------------ Fotos (sin image_picker) ----------------

  Future<void> _pickPhotoForRow(int r) async {
    if (r < 0 || r >= _rows.length) return;

    try {
      final typeGroup = XTypeGroup(
        label: 'Images',
        extensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );

      final xf = await openFile(acceptedTypeGroups: [typeGroup]);
      if (xf == null) return;

      final bytes = await xf.readAsBytes();
      final thumb = _compressThumb(bytes, maxW: 560, maxH: 560, quality: 76);
      final b64 = base64Encode(thumb);

      _rows[r].photos.add(
        _RowPhoto(
          name: xf.name,
          mime: _guessMime(xf.name),
          thumbB64: b64,
          addedAt: DateTime.now(),
        ),
      );

      _markDirty(snapshot: true);
      setState(() {});
    } catch (_) {}
  }

  String _guessMime(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Uint8List _compressThumb(Uint8List bytes, {required int maxW, required int maxH, required int quality}) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;

      final resized = img.copyResize(
        decoded,
        width: decoded.width > decoded.height ? maxW : null,
        height: decoded.height >= decoded.width ? maxH : null,
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
          if (c == _headers.length - 1) continue;
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

      final typeGroup = XTypeGroup(label: 'Excel', extensions: const ['xlsx']);
      final loc = await getSaveLocation(suggestedName: filename, acceptedTypeGroups: [typeGroup]);
      if (loc == null) return;

      final xf = XFile.fromData(
        Uint8List.fromList(bytes),
        name: filename,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      await xf.saveTo(loc.path);
    } catch (_) {}
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _safeFile(String s) {
    final t = s.trim().isEmpty ? 'Sheet' : s.trim();
    return t.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  // ------------------------------ Engine compute (opcional) ----------------

  Future<void> _computeEngine() async {
    final base = widget.engineBaseUrl;
    if (base == null || base.trim().isEmpty) return;

    if (_engineBusy) return;
    setState(() {
      _engineBusy = true;
      _engineStatus = 'Computando…';
    });

    try {
      final payload = {
        'headers': _headers,
        'rows': _rows.map((r) => r.cells).toList(),
        'name': _sheetName,
        'savedAt': DateTime.now().toIso8601String(),
      };

      final uri = Uri.parse('${base.replaceAll(RegExp(r'\/+$'), '')}/engine/compute');
      final resp = await http
          .post(
        uri,
        headers: {'content-type': 'application/json'},
        body: json.encode(payload),
      )
          .timeout(const Duration(seconds: 18));

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final map = json.decode(resp.body) as Map<String, dynamic>;
        final out = (map['rows'] as List?) ?? const [];

        if (out.isNotEmpty) {
          final normalized = <_RowModel>[];
          for (final rr in out) {
            if (rr is List) {
              normalized.add(_RowModel.fromCells(_normalizeRow(rr, _headers.length)));
            }
          }
          setState(() {
            _rows = normalized.isNotEmpty ? normalized : _rows;
            _engineStatus = 'Listo';
            _isDirty = true;
          });
          _pushUndoSnapshot();
          _queueSave();
        } else {
          setState(() => _engineStatus = 'Sin cambios');
        }
      } else {
        setState(() => _engineStatus = 'Error compute: ${resp.statusCode}');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _engineStatus = 'Engine no responde');
    } finally {
      if (!mounted) return;
      setState(() => _engineBusy = false);
      Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _engineStatus = null);
      });
    }
  }

  bool get _debugDirty => _isDirty;
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

  static const double _rowH = 38;
  static const double _headerH = 44;
  static const double _indexW = 54;

  @override
  Widget build(BuildContext context) {
    final colW = _idealColWidth(context);
    const photosW = 140.0;

    final totalW = _indexW + (headers.length - 1) * colW + photosW;

    return LayoutBuilder(
      builder: (ctx, c) {
        return Container(
          color: palette.bg,
          child: SingleChildScrollView(
            controller: hScroll,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: totalW,
              height: c.maxHeight,
              child: Column(
                children: [
                  SizedBox(
                    height: _headerH,
                    child: Row(
                      children: [
                        _rowIndexHeader(width: _indexW),
                        for (int col = 0; col < headers.length; col++)
                          _HeaderCell(
                            palette: palette,
                            width: col == headers.length - 1 ? photosW : colW,
                            text: _labelHeader(headers, col),
                            isPhotos: col == headers.length - 1,
                            isOverlayTarget: overlayTargetHeaderCol == col,
                            editorLink: editorLink,
                            onTap: () => onHeaderEditRequested(col, col == headers.length - 1 ? photosW : colW),
                            onSecondaryTapDown: (d) => onContextMenu(d.globalPosition, -1, col, true),
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
                        itemBuilder: (ctx2, r) {
                          return SizedBox(
                            height: _rowH,
                            child: Row(
                              children: [
                                _RowIndexCell(
                                  palette: palette,
                                  width: _indexW,
                                  index: r + 1,
                                  selected: r == selRow,
                                  onTap: () => onSelect(r, selCol),
                                  onSecondaryTapDown: (d) => onContextMenu(d.globalPosition, r, selCol, false),
                                ),
                                for (int col = 0; col < headers.length; col++)
                                  _DataCell(
                                    palette: palette,
                                    width: col == headers.length - 1 ? photosW : colW,
                                    text: rowModels[r].cells[col],
                                    photosCount: rowModels[r].photos.length,
                                    selected: r == selRow && col == selCol,
                                    isPhotos: col == headers.length - 1,
                                    blink: blink,
                                    cellRef: _CellRef(r, col),
                                    isOverlayTarget: overlayTargetCell == _CellRef(r, col),
                                    editorLink: editorLink,
                                    onTap: () => onEditRequested(r, col, col == headers.length - 1 ? photosW : colW),
                                    onLongPress: () {
                                      onSelect(r, col);
                                      final box = ctx2.findRenderObject();
                                      if (box is RenderBox) {
                                        final pos = box.localToGlobal(Offset.zero);
                                        onContextMenu(pos + const Offset(120, 12), r, col, false);
                                      }
                                    },
                                    onSecondaryTapDown: (d) {
                                      onSelect(r, col);
                                      onContextMenu(d.globalPosition, r, col, false);
                                    },
                                    onDeleteRow: () => onDeleteRow(r),
                                    onPickPhoto: () => onPickPhoto(r),
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
  }

  double _idealColWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 420) return 118;
    if (w < 760) return 140;
    return 170;
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
      height: _headerH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.headerBg,
        border: Border(
          right: BorderSide(color: palette.borderStrong, width: palette.hairline),
          bottom: BorderSide(color: palette.borderStrong, width: palette.hairline),
        ),
      ),
      child: Text('#', style: TextStyle(color: palette.fgMuted, fontWeight: FontWeight.w600)),
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
    final t = text.trim().isEmpty ? (isPhotos ? kPhotosHeader : '') : text.trim();

    final cell = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Container(
        width: width,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: palette.headerBg,
          border: Border(
            right: BorderSide(color: palette.borderStrong, width: palette.hairline),
            bottom: BorderSide(color: palette.borderStrong, width: palette.hairline),
          ),
        ),
        child: Text(
          t.isEmpty ? ' ' : t,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.fg,
            fontWeight: FontWeight.w700,
            fontSize: 13,
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Container(
        width: width,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.selIndexBg : palette.indexBg,
          border: Border(
            right: BorderSide(color: palette.borderStrong, width: palette.hairline),
            bottom: BorderSide(color: palette.border, width: palette.hairline),
          ),
        ),
        child: Text(
          index.toString(),
          style: TextStyle(
            color: selected ? palette.fg : palette.fgMuted,
            fontWeight: FontWeight.w600,
            fontSize: 12,
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
    required this.blink,
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

  final ValueListenable<_CellRef?> blink;
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
    return ValueListenableBuilder<_CellRef?>(
      valueListenable: blink,
      builder: (ctx, b, _) {
        final blinking = b == cellRef;
        final bg = selected
            ? palette.selBg
            : blinking
            ? palette.blinkBg
            : palette.cellBg;

        final cellBody = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTapDown: onSecondaryTapDown,
          child: Container(
            width: width,
            height: 38,
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
                : Align(
              alignment: Alignment.centerLeft,
              child: Text(
                text.isEmpty ? ' ' : text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.fg, fontSize: 14, height: 1.1),
              ),
            ),
          ),
        );

        if (!isOverlayTarget) return cellBody;
        return CompositedTransformTarget(link: editorLink, child: cellBody);
      },
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
            child: Icon(Icons.add_photo_alternate_outlined, size: 18, color: palette.fg),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            count == 0 ? '—' : '$count',
            style: TextStyle(color: palette.fg, fontWeight: FontWeight.w700),
          ),
        ),
        InkWell(
          onTap: onDeleteRow,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Icon(Icons.delete_outline_rounded, size: 18, color: palette.fgMuted),
          ),
        ),
      ],
    );
  }
}

// ============================== UI: Title =================================

class _TitleField extends StatefulWidget {
  const _TitleField({
    required this.initial,
    required this.color,
    required this.hintColor,
    required this.onChanged,
  });

  final String initial;
  final Color color;
  final Color hintColor;
  final ValueChanged<String> onChanged;

  @override
  State<_TitleField> createState() => _TitleFieldState();
}

class _TitleFieldState extends State<_TitleField> {
  late final TextEditingController _ec = TextEditingController(text: widget.initial);
  late final FocusNode _fn = FocusNode(debugLabel: 'SheetNameFocus');

  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    _ec.dispose();
    _fn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _ec,
        focusNode: _fn,
        style: TextStyle(color: widget.color, fontSize: 16, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Nombre',
          hintStyle: TextStyle(color: widget.hintColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        onChanged: (v) {
          _t?.cancel();
          _t = Timer(const Duration(milliseconds: 420), () => widget.onChanged(v));
        },
      ),
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
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
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
        border: Border(top: BorderSide(color: palette.borderStrong, width: palette.hairline)),
      ),
      child: Text(
        'Tap = editar. Mantener = menú.',
        style: TextStyle(color: palette.fgMuted, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ========================= Mobile inline editor bar ========================

class _MobileInlineEditorBar extends StatelessWidget {
  const _MobileInlineEditorBar({
    required this.palette,
    required this.title,
    required this.controller,
    required this.focusNode,
    required this.actions,
    required this.onCancel,
    required this.onDone,
  });

  final _SheetPalette palette;
  final String title;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<_MobileAction> actions;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: palette.appBarBg,
            border: Border(top: BorderSide(color: palette.borderStrong, width: palette.hairline)),
          ),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: palette.editorBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.borderStrong, width: palette.hairline),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(palette.isLight ? 0.08 : 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Cancelar',
                  onPressed: onCancel,
                  icon: Icon(Icons.close_rounded, color: palette.fgMuted),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: palette.headerBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: palette.border, width: palette.hairline),
                  ),
                  child: Text(
                    title.isEmpty ? 'Editar' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.fgMuted, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,
                    maxLines: 1,
                    textInputAction: TextInputAction.done,
                    keyboardAppearance: palette.isLight ? Brightness.light : Brightness.dark,
                    scrollPadding: EdgeInsets.zero,
                    style: TextStyle(color: palette.fg, fontSize: 16, height: 1.15),
                    cursorColor: palette.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: palette.mobileInputBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      hintText: 'Escribir…',
                      hintStyle: TextStyle(color: palette.fgMuted),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => onDone(),
                  ),
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
                  icon: Icon(Icons.check_rounded, color: palette.fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileAction {
  const _MobileAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

// ============================== Modelo =====================================

class _SheetModel {
  _SheetModel({required this.headers, required this.rows, this.name});

  final String? name;
  final List<String> headers;
  final List<_RowModel> rows;

  Map<String, dynamic> toJson() => {
    'name': name,
    'headers': headers,
    'rows': rows.map((r) => r.toJson()).toList(),
  };

  static _SheetModel fromJson(Map<String, dynamic> map) {
    final name = (map['name'] as String?)?.toString();
    final headers = (map['headers'] as List?)?.map((e) => (e ?? '').toString()).toList() ?? const <String>[];

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

    return _SheetModel(name: name, headers: headers, rows: rowModels);
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

  factory _RowModel.fromCells(List<String> cells) => _RowModel(cells: cells, photos: <_RowPhoto>[]);

  _RowModel copy() => _RowModel(
    cells: List<String>.from(cells),
    photos: photos.map((p) => p.copy()).toList(),
  );

  _RowModel copyWithCells(List<String> newCells) => _RowModel(
    cells: List<String>.from(newCells),
    photos: photos.map((p) => p.copy()).toList(),
  );

  Map<String, dynamic> toJson() => {
    'cells': cells,
    'photos': photos.map((p) => p.toJson()).toList(),
  };

  static _RowModel fromJson(Map<String, dynamic> map) {
    final cells = (map['cells'] as List?)?.map((e) => (e ?? '').toString()).toList() ?? const <String>[];
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

  _RowPhoto copy() => _RowPhoto(name: name, mime: mime, thumbB64: thumbB64, addedAt: addedAt);

  Map<String, dynamic> toJson() => {
    'name': name,
    'mime': mime,
    'thumbB64': thumbB64,
    'addedAt': addedAt.toIso8601String(),
  };

  static _RowPhoto fromJson(Map<String, dynamic> map) {
    return _RowPhoto(
      name: (map['name'] ?? '').toString(),
      mime: (map['mime'] ?? 'image/jpeg').toString(),
      thumbB64: (map['thumbB64'] ?? '').toString(),
      addedAt: DateTime.tryParse((map['addedAt'] ?? '').toString()) ?? DateTime.now(),
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
  bool operator ==(Object other) => other is _CellRef && other.r == r && other.c == c;

  @override
  int get hashCode => Object.hash(r, c);
}

class _GpsFix {
  const _GpsFix({required this.lat, required this.lng, required this.accuracyM, required this.ts});

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
    required this.selIndexBg,
    required this.cellBg,
    required this.selBg,
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
  });

  final bool isLight;
  final double hairline;

  final Color bg;
  final Color fg;
  final Color fgMuted;

  final Color appBarBg;
  final Color headerBg;
  final Color indexBg;
  final Color selIndexBg;

  final Color cellBg;
  final Color selBg;
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

  static _SheetPalette light({required double hairline}) {
    return _SheetPalette(
      isLight: true,
      hairline: hairline,
      bg: const Color(0xFFFFFFFF),
      fg: const Color(0xFF0B0B0C),
      fgMuted: const Color(0xFF6B6B72),
      appBarBg: const Color(0xFFF6F6F8),
      headerBg: const Color(0xFFF7F7F9),
      indexBg: const Color(0xFFF7F7F9),
      selIndexBg: const Color(0xFFEFF0F3),
      cellBg: const Color(0xFFFFFFFF),
      selBg: const Color(0xFFE9F0FF),
      blinkBg: const Color(0xFFE3EEFF),
      border: const Color(0xFF0B0B0C).withOpacity(0.12),
      borderStrong: const Color(0xFF0B0B0C).withOpacity(0.20),
      menuBg: const Color(0xFFFFFFFF),
      editorBg: const Color(0xFFFFFFFF),
      mobileInputBg: const Color(0xFFFFFFFF),
      accent: const Color(0xFF3B82F6),
      statusBg: const Color(0xFFEFF6FF),
      statusFg: const Color(0xFF1D4ED8),
      hintBg: const Color(0xFFF6F6F8),
    );
  }

  static _SheetPalette dark({required double hairline}) {
    return _SheetPalette(
      isLight: false,
      hairline: hairline,
      bg: const Color(0xFF0B0B0C),
      fg: const Color(0xFFF5F5F7),
      fgMuted: const Color(0xFF9A9AA4),
      appBarBg: const Color(0xFF111113),
      headerBg: const Color(0xFF121216),
      indexBg: const Color(0xFF121216),
      selIndexBg: const Color(0xFF1B1B21),
      cellBg: const Color(0xFF17171C),
      selBg: const Color(0xFF1F2A44),
      blinkBg: const Color(0xFF263556),
      border: const Color(0xFFFFFFFF).withOpacity(0.10),
      borderStrong: const Color(0xFFFFFFFF).withOpacity(0.16),
      menuBg: const Color(0xFF15151A),
      editorBg: const Color(0xFF15151A),
      mobileInputBg: const Color(0xFF15151A),
      accent: const Color(0xFF60A5FA),
      statusBg: const Color(0xFF0F172A),
      statusFg: const Color(0xFF93C5FD),
      hintBg: const Color(0xFF111113),
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

// ============================== Helpers ====================================

void unawaited(Future<void>? f) {}
