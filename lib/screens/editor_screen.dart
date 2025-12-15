// lib/screens/editor_screen.dart
//
// BitFlow / Gridnote — EditorScreen (MVP vendible, corporativo Apple, sin circo)
// Android / iOS / Windows / Web.
//
// OBJETIVO VISUAL (como la imagen):
// - Título grande arriba (ej: “Inventory Sheet”).
// - 3 botones “píldora”: Save / Export / More.
// - Grilla blanca minimal ocupando toda la pantalla, líneas finas, tipografía limpia.
// - Columna Photos muestra miniaturas redondeadas + botón “+” si está vacío.
// - Columna Status muestra “pill/chip” (ej: In stock / Missing).
//
// OBJETIVO FUNCIONAL:
// - Edición cómoda: móvil = tap y teclado (sin rebote/bounce, sin saltos torpes).
// - Desktop/Web: click selecciona; Enter/doble click edita; atajos Ctrl/Cmd.
// - Guardado local + autosave (debounced) + botón Save para “flush” inmediato.
// - Fotos por fila (adjuntos) + export XLSX real con fotos embebidas.
// - GPS: insertar coordenadas en celda / abrir en Maps si detecta lat,lon.
// - Backup JSON local + importar JSON.
// - (Opcional en “More”): backup nube Firestore y restore si tu proyecto lo usa.
//
// NOTA:
// Este archivo asume que ya existen tus servicios/modelos:
// - ../models/table_state.dart
// - ../services/local_store.dart
// - ../services/sheet_store.dart
// - ../services/attachments_service_web.dart
// - ../services/location_service.dart
// - ../services/firestore_sheet_store.dart (opcional)
// - ../services/xlsx_saver_io.dart / ../services/xlsx_saver_web.dart
//
// Si alguno difiere en tu proyecto, avisame el archivo/firmas y lo adapto.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:file_selector/file_selector.dart';
import 'package:geolocator/geolocator.dart'
    show LocationAccuracy, Geolocator, LocationPermission;
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:url_launcher/url_launcher.dart';

import '../models/table_state.dart';
import '../services/attachments_service_web.dart';
import '../services/firestore_sheet_store.dart';
import '../services/local_store.dart';
import '../services/location_service.dart';
import '../services/sheet_store.dart';
import '../services/xlsx_saver_io.dart'
if (dart.library.html) '../services/xlsx_saver_web.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.isLight,
    required this.onToggleTheme,
    required this.sheetId,
  });

  final bool isLight;
  final VoidCallback onToggleTheme;
  final String sheetId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with TickerProviderStateMixin {
  // ------------------------------ Config ----------------------------------

  // Tamaño “tipo iOS” agradable: líneas finas, celdas equilibradas.
  static const double _indexColW = 54.0;
  static const double _rowH = 54.0;
  static const double _hdrH = 54.0;

  // Columnas: arrancamos como el mock (Item / Location / Photos / Status).
  // Podés agregar columnas desde More.
  static const int _initialCols = 4;
  static const int _initialRows = 30;

  static const double _minColW = 88.0;
  static const double _maxColW = 640.0;

  static const List<String> _templateHeaders = <String>[
    'Item',
    'Location',
    'Photos',
    'Status',
  ];

  // Fotos: máximo de miniaturas visibles en la celda (como la imagen).
  static const int _maxThumbsInCell = 10;

  // XLSX: máximo de fotos por fila al exportar.
  static const int _maxPhotosPerRowExport = 10;
  static const int _maxPhotosPerCell = 10;

  // Debounces
  final _persistDebounce = _Debouncer(const Duration(milliseconds: 250));
  final _thumbDebounce = _Debouncer(const Duration(milliseconds: 150));

  // Guardado serializado (evita carreras entre autosave/manual/export)
  Future<void> _saveQueue = Future.value();

  // ------------------------------ Estado ----------------------------------

  late TableState _state;
  bool _loading = true;

  bool _busy = false;
  String? _busyMessage;

  bool _saving = false;
  DateTime? _lastSavedAt;

  String _sheetName = 'Inventory Sheet';

  // Foco / edición
  (int r, int c) _focus = (0, 0);
  bool _isEditing = false;

  // Hover (desktop) — para affordances sutiles (sin “ripple” Material).
  (int r, int c)? _hoverCell;

  // Editor (celda) — usamos el MISMO controller para mobile y desktop.
  final TextEditingController _cellEC = TextEditingController();
  final FocusNode _cellFN = FocusNode(debugLabel: 'cellFN');
  final FocusNode _gridFN = FocusNode(debugLabel: 'gridFN');

  // Header controllers
  final Map<int, TextEditingController> _hdrCtl = <int, TextEditingController>{};

  // Layout de columnas (scroll horizontal)
  late List<double> _colW;
  late List<double> _prefix; // prefix sum widths

  int _firstCol = 0;
  int _lastCol = 0;
  static const int _bufCols = 2;
  double _lastViewportW = 0;
  bool _autoFitOnce = false;

  bool _layoutOpsScheduled = false;
  double? _pendingViewportW;

  // Scroll sync
  final ScrollController _vIdx = ScrollController();
  final ScrollController _vBody = ScrollController();
  bool _syncingV = false;

  final ScrollController _hHdr = ScrollController();
  final ScrollController _hBody = ScrollController();
  bool _syncingH = false;

  // Undo/Redo simple (cap 200)
  final _History<TableState> _history = _History<TableState>(cap: 200);

  // Columnas “especiales” (por nombre, case-insensitive)
  int _photosCol = -1;
  int _statusCol = -1;

  // Adjuntos (por fila)
  bool _attachmentsEverUsed = false;

  // Cache de miniaturas por fila para pintar rápido Photos column.
  final Map<int, List<_AttItem>> _rowThumbs = <int, List<_AttItem>>{};
  final Map<int, List<String>> _rowPhotoIds = <int, List<String>>{};
  final Map<int, int> _rowThumbsVer = <int, int>{}; // simple versioning
  final Map<int, int> _attachCounts = <int, int>{};

  // ------------------------------ Lifecycle --------------------------------

  @override
  void initState() {
    super.initState();
    _state = TableState.empty();
    _colW = <double>[];
    _prefix = <double>[0];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _vIdx.addListener(_syncFromIdx);
      _vBody.addListener(_syncFromBodyV);
      _hHdr.addListener(_syncFromHdr);
      _hBody.addListener(_syncFromBodyH);

      _hydrate();
    });
  }

  @override
  void dispose() {
    _persistDebounce.dispose();
    _thumbDebounce.dispose();

    _cellEC.dispose();
    _cellFN.dispose();
    _gridFN.dispose();

    for (final c in _hdrCtl.values) {
      c.dispose();
    }
    _hdrCtl.clear();

    _vIdx.removeListener(_syncFromIdx);
    _vBody.removeListener(_syncFromBodyV);
    _hHdr.removeListener(_syncFromHdr);
    _hBody.removeListener(_syncFromBodyH);

    _vIdx.dispose();
    _vBody.dispose();
    _hHdr.dispose();
    _hBody.dispose();

    super.dispose();
  }

  // ------------------------------ Hydrate / Save ---------------------------

  Future<void> _hydrate() async {
    try {
      // Nota: lo de loadName por reflexión de static no es confiable en Dart.
      // Mantenemos el nombre en memoria y lo guardamos en el backup/cloud.
      final raw = await _loadRawCompat(widget.sheetId);
      if (!mounted) return;

      if (raw == null) {
        final now = DateTime.now();
        final normalized = _normalizeState(
          TableState(
            headers: _buildInitialHeaders(),
            rows: List.generate(
              _initialRows,
                  (_) => List<String>.filled(_initialCols, ''),
            ),
            savedAt: now,
          ),
        );

        setState(() {
          _state = normalized;
          _lastSavedAt = now;
          _colW = _defaultColWidthsForTemplate();
          _rebuildPrefix();
          _recomputeSpecialCols();
          _loading = false;
        });

        _history.push(_cloneState(_state));
        _thumbDebounce(() {
          _refreshVisibleThumbs();
        });
        return;
      }

      final parsed = TableState.fromJsonString(raw) ?? TableState.empty();
      final normalized = _normalizeState(parsed);

      setState(() {
        _state = normalized;
        _lastSavedAt = normalized.savedAt;
        _colW = _defaultColWidthsForState(normalized);
        _rebuildPrefix();
        _recomputeSpecialCols();
        _loading = false;
      });

      _history.push(_cloneState(_state));
      _thumbDebounce(() {
        _refreshVisibleThumbs();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Error cargando planilla: $e')),
      );
    }
  }

  Future<String?> _loadRawCompat(String id) async {
    try {
      return SheetStore.loadRaw(id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLocalCompat(TableState s) async {
    // Compat: LocalStore.save puede ser sync o async, o incluso devolver void/Future<void>.
    // Usamos Function.apply para evitar errores de tipo 'void' en diferentes targets.
    try {
      final dynamic fn = LocalStore.save;
      final dynamic r = Function.apply(fn, [s]);
      if (r is Future) await r;
    } catch (_) {
      // No-op
    }
  }

  Future<void> _saveCompat(TableState s) async {
    // Guardado local + store principal.
    await _saveLocalCompat(s);

    // SheetStore.saveState puede ser void o Future<void>, según target/implementación.
    try {
      final dynamic fn = SheetStore.saveState;
      final dynamic r = Function.apply(fn, [widget.sheetId, s]);
      if (r is Future) await r;
    } catch (_) {
      // fallback: algunas implementaciones podrían tener otra firma
      try {
        final dynamic fn = SheetStore.saveState;
        final dynamic r = Function.apply(fn, [s]);
        if (r is Future) await r;
      } catch (_) {
        // No-op
      }
    }
  }

  Future<void> _enqueueSave(TableState s) {
    _saveQueue = _saveQueue
        .then((_) async {
      await _saveCompat(s);
      if (!mounted) return;
      setState(() => _lastSavedAt = DateTime.now());
    })
        .catchError((_) {
      // evitamos que el queue se "rompa" por un error
    });
    return _saveQueue;
  }

  void _updateState(TableState s, {bool snapshot = true}) {
    setState(() => _state = s);
    if (snapshot) _history.push(_cloneState(s));

    _recomputeSpecialCols();
    _ensureColWAligned();

    _persistDebounce(() {
      if (!mounted) return;
      setState(() => _saving = true);
      _enqueueSave(s).whenComplete(() {
        if (!mounted) return;
        setState(() => _saving = false);
      });
    });
  }

  Future<void> _saveNow() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyMessage = 'Saving…';
    });
    try {
      await _enqueueSave(_state);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  // ------------------------------ Normalize / Headers ----------------------

  List<String> _buildInitialHeaders() {
    // Para verse como la imagen desde el minuto 1.
    // Si querés “vacíos por defecto”, cambiá a List.filled(_initialCols, '').
    return List<String>.from(_templateHeaders);
  }

  TableState _normalizeState(TableState s) {
    var headers = List<String>.from(s.headers);

    if (headers.isEmpty) {
      headers = _buildInitialHeaders();
    } else if (headers.length < _initialCols) {
      // Completa hasta mínimo 4.
      headers.addAll(List.filled(_initialCols - headers.length, ''));
      // Si el usuario venía con 0/1 nombres, respetamos; no forzamos template.
    }

    final rows = <List<String>>[];
    for (final r in s.rows) {
      final row = List<String>.from(r);
      if (row.length < headers.length) {
        row.addAll(List.filled(headers.length - row.length, ''));
      } else if (row.length > headers.length) {
        row.removeRange(headers.length, row.length);
      }
      rows.add(row);
    }

    while (rows.length < _initialRows) {
      rows.add(List<String>.filled(headers.length, ''));
    }

    return TableState(
      headers: headers,
      rows: rows,
      savedAt: s.savedAt ?? DateTime.now(),
    );
  }

  TableState _cloneState(TableState s) {
    return TableState(
      headers: List<String>.from(s.headers),
      rows: s.rows.map((r) => List<String>.from(r)).toList(),
      savedAt: s.savedAt,
    );
  }

  void _recomputeSpecialCols() {
    int photos = -1;
    int status = -1;

    for (int i = 0; i < _state.headers.length; i++) {
      final h = _state.headers[i].trim().toLowerCase();
      if (h == 'photos' || h == 'fotos' || h == 'imagenes' || h == 'images') {
        photos = i;
      }
      if (h == 'status' || h == 'estado') {
        status = i;
      }
    }

    // Fallback: si es template (4 cols), asumimos Photos=2, Status=3.
    if (_state.headers.length >= 4) {
      if (photos == -1) photos = 2;
      if (status == -1) status = 3;
    }

    _photosCol = photos;
    _statusCol = status;
  }

  TextEditingController _hdrController(int col) {
    final existing = _hdrCtl[col];
    if (existing != null) return existing;

    final ctl = TextEditingController(text: _state.headers[col]);
    ctl.addListener(() {
      final next = List<String>.from(_state.headers);
      next[col] = ctl.text;
      _updateState(_state.withHeaders(next), snapshot: false);
    });

    _hdrCtl[col] = ctl;
    return ctl;
  }

  void _ensureColWAligned() {
    if (_colW.length == _state.headers.length) return;
    _resetHdrCtl();

    _colW = _defaultColWidthsForState(_state);
    _rebuildPrefix();
    _autoFitOnce = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recomputeVisibleCols();
      _thumbDebounce(() {
        _refreshVisibleThumbs();
      });
    });
  }

  void _resetHdrCtl() {
    for (final c in _hdrCtl.values) {
      c.dispose();
    }
    _hdrCtl.clear();
  }

  List<double> _defaultColWidthsForTemplate() {
    // Parecido a la imagen.
    // Item más ancho, Location chico, Photos mediano, Status mediano.
    return <double>[
      170.0, // Item
      110.0, // Location
      150.0, // Photos
      140.0, // Status
    ];
  }

  List<double> _defaultColWidthsForState(TableState s) {
    if (s.headers.length == 4) return _defaultColWidthsForTemplate();
    return List<double>.filled(s.headers.length, 160.0);
  }

  // ------------------------------ Grid math --------------------------------

  int get _rowCount => _state.rows.length;
  int get _colCount => _state.headers.length;

  int _clampi(int x, int lo, int hi) {
    if (x < lo) return lo;
    if (x > hi) return hi;
    return x;
  }

  void _rebuildPrefix() {
    _prefix = List<double>.filled(_colW.length + 1, 0);
    for (int i = 0; i < _colW.length; i++) {
      _prefix[i + 1] = _prefix[i] + _colW[i];
    }
  }

  int _lowerBound(double x) {
    int lo = 0, hi = _prefix.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_prefix[mid] < x) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  double _sumRange(int a, int bExclusive) {
    if (_prefix.isEmpty) return 0;
    a = _clampi(a, 0, _colCount);
    bExclusive = _clampi(bExclusive, 0, _colCount);
    if (bExclusive < a) return 0;
    return _prefix[bExclusive] - _prefix[a];
  }

  void _maybeAutoFitViewport(double vw) {
    if (_autoFitOnce || _colW.isEmpty) return;
    final total = _prefix.last;
    if (total >= vw) return;

    final extra = vw - total;
    if (extra <= 0) return;

    // Distribuye un poco para “ocupar toda la pantalla” como la imagen.
    setState(() {
      final add = extra / _colW.length;
      for (int i = 0; i < _colW.length; i++) {
        _colW[i] = (_colW[i] + add).clamp(_minColW, _maxColW).toDouble();
      }
      _rebuildPrefix();
      _autoFitOnce = true;
    });
  }

  void _recomputeVisibleCols([double? viewportW]) {
    if (!mounted) return;
    final hasBody = _hBody.hasClients;
    final vw =
        viewportW ?? (hasBody ? _hBody.position.viewportDimension : _lastViewportW);
    if (vw <= 0) return;

    final scrollX = hasBody ? _hBody.offset : 0.0;
    int start = _lowerBound(scrollX) - 1;
    if (start < 0) start = 0;
    final endLimit = scrollX + vw;
    int end = _lowerBound(endLimit);
    if (end > _colW.length) end = _colW.length;

    start = _clampi(
      start - _bufCols,
      0,
      _colW.isNotEmpty ? _colW.length - 1 : 0,
    );
    end = _clampi(end + _bufCols, 0, _colW.length);

    if (start > end) {
      start = 0;
      end = _colW.isEmpty ? 0 : 1;
    }

    final need =
        start != _firstCol || end - 1 != _lastCol || vw != _lastViewportW;

    if (!need) return;

    setState(() {
      _firstCol = start;
      _lastCol = end - 1;
      _lastViewportW = vw;
    });
  }

  void _scheduleViewportOps(double vw) {
    _pendingViewportW = vw;
    if (_layoutOpsScheduled) return;
    _layoutOpsScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutOpsScheduled = false;
      if (!mounted) return;
      final x = _pendingViewportW;
      _pendingViewportW = null;
      if (x == null) return;
      _recomputeVisibleCols(x);
      _maybeAutoFitViewport(x);
    });
  }

  // ------------------------------ Scroll sync ------------------------------

  void _syncFromIdx() {
    if (_syncingV || !_vBody.hasClients) return;
    final want = _vIdx.offset;
    if ((_vBody.offset - want).abs() < 0.5) return;
    _syncingV = true;
    _vBody.jumpTo(want);
    _syncingV = false;
  }

  void _syncFromBodyV() {
    if (_syncingV || !_vIdx.hasClients) return;
    final want = _vBody.offset;
    if ((_vIdx.offset - want).abs() < 0.5) return;
    _syncingV = true;
    _vIdx.jumpTo(want);
    _syncingV = false;

    _thumbDebounce(() {
      _refreshVisibleThumbs();
    });
  }

  void _syncFromHdr() {
    if (_syncingH || !_hBody.hasClients) return;
    final want = _hHdr.offset;
    if ((_hBody.offset - want).abs() < 0.5) return;
    _syncingH = true;
    _hBody.jumpTo(want);
    _syncingH = false;
    _recomputeVisibleCols();
  }

  void _syncFromBodyH() {
    if (_syncingH || !_hHdr.hasClients) return;
    final want = _hBody.offset;
    if ((_hHdr.offset - want).abs() < 0.5) return;
    _syncingH = true;
    _hHdr.jumpTo(want);
    _syncingH = false;
    _recomputeVisibleCols();
  }

  // ------------------------------ Desktop vs Mobile ------------------------

  bool _isDesktopUi(BuildContext context) {
    final p = Theme.of(context).platform;
    final isDesktopPlatform =
        p == TargetPlatform.macOS || p == TargetPlatform.windows || p == TargetPlatform.linux;
    if (kIsWeb && MediaQuery.of(context).size.width >= 900) return true;
    return isDesktopPlatform;
  }

  // ------------------------------ Focus / Edit -----------------------------

  void _setFocus(int r, int c, {bool ensureVisible = true}) {
    if (_rowCount == 0 || _colCount == 0) return;
    r = _clampi(r, 0, _rowCount - 1);
    c = _clampi(c, 0, _colCount - 1);

    final next = (r, c);

    if (_isEditing) {
      _commitCell(_focus.$1, _focus.$2, _cellEC.text);
    }

    if (_focus == next && !_isEditing) {
      _gridFN.requestFocus();
      return;
    }

    setState(() {
      _focus = next;
      _isEditing = false;
    });

    _gridFN.requestFocus();

    if (ensureVisible) {
      _ensureVisible(r, c);
    }

    _thumbDebounce(() {
      _refreshVisibleThumbs();
    });
  }

  void _startEditing(int r, int c) {
    if (_rowCount == 0 || _colCount == 0) return;

    _setFocus(r, c, ensureVisible: true);

    // Photos no edita texto nunca (UX consistente).
    if (c == _photosCol) return;

    if (_isEditing) return;

    _cellEC.text = _safeCell(r, c);

    setState(() => _isEditing = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cellFN.requestFocus();
      _cellEC.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _cellEC.text.length,
      );
      // Asegura visibilidad con teclado (mobile).
      _ensureVisible(r, c);
    });
  }

  void _commitCell(int r, int c, String v) {
    if (!_isEditing) return;

    setState(() => _isEditing = false);

    final prev = _safeCell(r, c);
    if (prev == v) {
      _gridFN.requestFocus();
      return;
    }

    _updateState(_state.withCell(r, c, v));
    _gridFN.requestFocus();
  }

  void _commitEditing() {
    if (!_isEditing) return;
    final (r, c) = _focus;
    _commitCell(r, c, _cellEC.text);
  }

  // ----------------------- Hover (desktop/web) -----------------------
  // En mobile no existe hover; en web/desktop se usa para feedback sutil.
  void _setHovered(int r, int c) {
    final next = (r, c);
    if (_hoverCell == next) return;
    if (!mounted) return;
    setState(() => _hoverCell = next);
  }

  void _clearHovered() {
    if (_hoverCell == null) return;
    if (!mounted) return;
    setState(() => _hoverCell = null);
  }

  // ----------------------- Alias compat -----------------------
  // Algunas partes del UI llaman a `_beginCellEdit` (doble-tap / teclas).
  // La operación real vive en `_startEditing`.
  void _beginCellEdit(int r, int c) {
    _startEditing(r, c);
  }


  void _commitAndMoveDown(int r, int c) {
    _commitCell(r, c, _cellEC.text);
    final nextR = r + 1;
    if (nextR >= _rowCount) {
      _addRow();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final safeR = nextR >= _rowCount ? _rowCount - 1 : nextR;
      _startEditing(_clampi(safeR, 0, _rowCount - 1), c);
    });
  }

  void _beginCharEdit(String ch) {
    final (r, c) = _focus;
    if (c == _photosCol) return; // no texto en Photos
    _startEditing(r, c);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cellEC
        ..text = ch
        ..selection = TextSelection.collapsed(offset: ch.length);
    });
  }

  String _safeCell(int r, int c) {
    if (r < 0 || r >= _state.rows.length) return '';
    final row = _state.rows[r];
    if (c < 0 || c >= row.length) return '';
    return row[c];
  }

  void _ensureVisible(int r, int c) {
    // Vertical
    if (_vBody.hasClients) {
      final top = r * _rowH;
      final bottom = top + _rowH;

      final viewTop = _vBody.offset;
      final viewport = _vBody.position.viewportDimension;

      // Ajuste por teclado (mobile): restamos viewInsets + editor.
      final insetsBottom = MediaQuery.of(context).viewInsets.bottom;
      final editorH = (!_isDesktopUi(context) && _isEditing) ? 64.0 : 0.0;
      final safeBottom = viewTop + viewport - insetsBottom - editorH - 8.0;

      if (top < viewTop) {
        _vBody.animateTo(
          top,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOutCubic,
        );
      } else if (bottom > safeBottom) {
        final target = (bottom - (viewport - insetsBottom - editorH - 8.0))
            .clamp(0.0, _vBody.position.maxScrollExtent);
        _vBody.animateTo(
          target,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOutCubic,
        );
      }
    }

    // Horizontal
    if (_hBody.hasClients && c >= 0 && c < _colW.length) {
      final x = _prefix[c];
      final w = _colW[c];
      final vx = _hBody.offset;
      final vw = _hBody.position.viewportDimension;

      if (x < vx) {
        _hBody.animateTo(
          x,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOutCubic,
        );
      } else if (x + w > vx + vw) {
        _hBody.animateTo(
          (x + w - vw).clamp(0.0, _hBody.position.maxScrollExtent),
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  // ------------------------------ Row/Col ops ------------------------------

  void _addRow() {
    final newRows = List<List<String>>.from(
      _state.rows.map((r) => List<String>.from(r)),
    )..add(List<String>.filled(_colCount, ''));

    _updateState(
      TableState(
        headers: _state.headers.toList(),
        rows: newRows,
        savedAt: DateTime.now(),
      ),
    );
  }

  void _addRowAndEdit() {
    final newIndex = _rowCount;
    _addRow();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = _clampi(_focus.$2, 0, math.max(0, _colCount - 1));
      final safeR = _clampi(newIndex, 0, math.max(0, _rowCount - 1));
      _startEditing(safeR, c);
    });
  }

  void _addColumnRightOfFocus() {
    final insertAt = _clampi(_focus.$2 + 1, 0, _colCount);

    final newHeaders = <String>[];
    for (int i = 0; i < _colCount; i++) {
      newHeaders.add(_state.headers[i]);
      if (i == insertAt - 1) newHeaders.add('');
    }
    if (insertAt == 0) newHeaders.insert(0, '');

    final newRows = _state.rows.map((r) {
      final nr = <String>[];
      for (int i = 0; i < r.length; i++) {
        nr.add(r[i]);
        if (i == insertAt - 1) nr.add('');
      }
      if (insertAt == 0) nr.insert(0, '');
      return nr;
    }).toList();

    _updateState(
      TableState(headers: newHeaders, rows: newRows, savedAt: DateTime.now()),
    );

    setState(() {
      final w = (_colW.isNotEmpty
          ? _colW[_clampi(insertAt, 0, _colW.length - 1)]
          : 160.0);
      _colW.insert(insertAt, w);
      _rebuildPrefix();
      _autoFitOnce = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recomputeVisibleCols();
      _setFocus(_focus.$1, insertAt);
    });
  }

  Future<void> _deleteAttachmentsForRow(int row) async {
    try {
      final svc = AttachmentsServiceWeb.I;
      await (svc as dynamic).deleteRow(sheetId: widget.sheetId, row: row);
    } catch (_) {
      // si no existe, no rompemos
    }
  }

  Future<void> _shiftAttachmentsAfterDelete(int deletedRow) async {
    try {
      final svc = AttachmentsServiceWeb.I;
      await (svc as dynamic).shiftRows(
        sheetId: widget.sheetId,
        startRow: deletedRow + 1,
        delta: -1,
      );
    } catch (_) {
      // si no existe, no rompemos
    }
  }

  Future<void> _deleteFocusedRow() async {
    if (_rowCount <= 1) return;
    final r = _clampi(_focus.$1, 0, _rowCount - 1);

    final had = (_attachCounts[r] ?? 0) > 0;

    if (had) {
      final ok = await _confirmDestructive(
        title: 'Delete row with photos',
        message:
        'This row has photos.\n\nIf your attachments storage is indexed by row number, deleting may shift/misalign photos below.\n\nContinue?',
        confirmLabel: 'Delete',
      );
      if (!ok) return;
    }

    // Intento best-effort: borrar adjuntos de la fila y reindexar si el servicio lo soporta.
    await _deleteAttachmentsForRow(r);
    await _shiftAttachmentsAfterDelete(r);

    final nextRows = <List<String>>[
      for (int i = 0; i < _rowCount; i++)
        if (i != r) List<String>.from(_state.rows[i]),
    ];

    _updateState(
      TableState(
        headers: _state.headers.toList(),
        rows: nextRows,
        savedAt: DateTime.now(),
      ),
    );

    // Limpieza de caches (evita mostrar thumbs “corridos”)
    _rowThumbs.clear();
    _rowThumbsVer.clear();
    _attachCounts.clear();
    _thumbDebounce(() {
      _refreshVisibleThumbs();
    });

    _setFocus(_clampi(r - 1, 0, math.max(0, _rowCount - 2)), _focus.$2);
  }

  Future<void> _clearRow(int r) async {
    if (_rowCount == 0) return;
    r = _clampi(r, 0, _rowCount - 1);

    final had = (_attachCounts[r] ?? 0) > 0;
    if (had) {
      final ok = await _confirmDestructive(
        title: 'Clear row',
        message:
        'This row has photos. Clearing the row will not necessarily remove photos unless your attachment service supports it.\n\nContinue?',
        confirmLabel: 'Clear',
      );
      if (!ok) return;
      await _deleteAttachmentsForRow(r);
    }

    final nextRows = <List<String>>[];
    for (int i = 0; i < _rowCount; i++) {
      if (i == r) {
        nextRows.add(List<String>.filled(_colCount, ''));
      } else {
        nextRows.add(List<String>.from(_state.rows[i]));
      }
    }

    _updateState(
      TableState(
        headers: _state.headers.toList(),
        rows: nextRows,
        savedAt: DateTime.now(),
      ),
    );

    _rowThumbs.remove(r);
    _rowThumbsVer.remove(r);
    _attachCounts.remove(r);

    _setFocus(r, _clampi(_focus.$2, 0, math.max(0, _colCount - 1)));
  }

  Future<void> _clearAll() async {
    if (_rowCount == 0) return;

    final ok = await _confirmDestructive(
      title: 'Clear sheet',
      message:
      'This will clear all rows. Headers remain.\n\nYou can undo with Ctrl/Cmd+Z.',
      confirmLabel: 'Clear',
    );
    if (!ok) return;

    final cols = _colCount;
    _updateState(
      TableState(
        headers: _state.headers.toList(),
        rows: List.generate(_initialRows, (_) => List<String>.filled(cols, '')),
        savedAt: DateTime.now(),
      ),
    );
    _resetHdrCtl();

    // Caches
    _rowThumbs.clear();
    _rowThumbsVer.clear();
    _attachCounts.clear();
  }

  void _undo() {
    final s = _history.undo();
    if (s != null) {
      _updateState(s, snapshot: false);
      _resetHdrCtl();
      _thumbDebounce(() {
        _refreshVisibleThumbs();
      });
    }
  }

  void _redo() {
    final s = _history.redo();
    if (s != null) {
      _updateState(s, snapshot: false);
      _resetHdrCtl();
      _thumbDebounce(() {
        _refreshVisibleThumbs();
      });
    }
  }

  // ------------------------------ GPS / Maps -------------------------------

  static String? _mapsLinkOrNull(String? t) {
    if (t == null) return null;
    final re = RegExp(
      r'^\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)(?:\s*[±+]\s*\d+\s*m)?\s*$',
      caseSensitive: false,
    );
    final m = re.firstMatch(t.trim());
    final lat = m?.group(1);
    final lon = m?.group(2);
    if (lat == null || lon == null) return null;
    return 'https://maps.google.com/?q=$lat,$lon';
  }

  Future<void> _insertGpsHere() async {
    if (_isEditing) {
      _commitCell(_focus.$1, _focus.$2, _cellEC.text);
    }
    final (r, c) = _focus;
    await _insertGpsAt(r, c);
  }

  Future<void> _insertGpsAt(int r, int cTarget) async {
    if (_busy) return;

    if (cTarget < 0 || cTarget >= _colCount) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _busy = true;
      _busyMessage = 'Getting location…';
    });

    try {
      bool serviceEnabled;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (_) {
        serviceEnabled = true;
      }

      if (!serviceEnabled) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('Location service disabled.')),
        );
        return;
      }

      LocationPermission permission;
      try {
        permission = await Geolocator.checkPermission();
      } catch (_) {
        permission = LocationPermission.always;
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          messenger?.showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('Location permission denied forever.')),
        );
        return;
      }

      final fix = await LocationService.I.getCurrentFix(
        desiredAccuracy: LocationAccuracy.high,
        timeout: const Duration(seconds: 12),
      );

      if (!mounted) return;

      final buf = StringBuffer()
        ..write((fix.latitude as num).toStringAsFixed(6))
        ..write(', ')
        ..write((fix.longitude as num).toStringAsFixed(6));

      try {
        final acc = (fix as dynamic).accuracyMeters;
        if (acc is num && acc > 0) {
          buf.write(' ±${acc.toStringAsFixed(0)} m');
        }
      } catch (_) {}

      _updateState(_state.withCell(r, cTarget, buf.toString()));
      _setFocus(r, cTarget);

      messenger?.showSnackBar(
        const SnackBar(content: Text('Location inserted')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Location error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _openMapForCell(int r, int c) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final txt = _safeCell(r, c);
    final link = _mapsLinkOrNull(txt);
    if (link == null) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('No recognizable coordinates in cell')),
      );
      return;
    }
    try {
      final uri = Uri.parse(link);
      final ok = await canLaunchUrl(uri);
      if (!ok) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('Cannot open maps')),
        );
        return;
      }
      await launchUrl(uri);
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Maps error: $e')),
      );
    }
  }

  // ------------------------------ Attachments ------------------------------

  Future<void> _refreshVisibleThumbs() async {
    if (_rowCount == 0) return;

    // Si existe columna Photos, intentamos refrescar aunque nunca se haya usado en esta sesión.
    if (_photosCol < 0) return;

    final start = _firstVisibleRow();
    final end = math.min(_rowCount - 1, start + _visibleRowCount() + 6);

    for (int r = start; r <= end; r++) {
      await _refreshRowThumbs(r);
    }

    // Evict cache fuera de la ventana (RAM estable).
    _evictThumbCacheOutside(start, end);
  }

  void _evictThumbCacheOutside(int start, int end) {
    final keys = _rowThumbs.keys.toList(growable: false);
    for (final k in keys) {
      if (k < start - 30 || k > end + 30) {
        _rowThumbs.remove(k);
        _rowThumbsVer.remove(k);
        _attachCounts.remove(k);
      }
    }
  }

  Uint8List? _asBytes(Object? any) {
    if (any == null) return null;
    if (any is Uint8List) return any;
    if (any is List<int>) return Uint8List.fromList(any);
    if (any is String) {
      // base64 (data URL o puro)
      final idx = any.indexOf(',');
      final b64 = idx >= 0 ? any.substring(idx + 1) : any;
      try {
        return Uint8List.fromList(base64.decode(b64));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _refreshRowThumbs(int r) async {
    try {
      final xs = await AttachmentsServiceWeb.I.listFor(
        sheetId: widget.sheetId,
        row: r,
      );

      if (!mounted) return;

      final list = <_AttItem>[];
      for (final a in xs) {
        final dyn = a as dynamic;
        final name = (dyn.name as String?) ?? 'photo';
        final mime = (dyn.mime as String?) ?? '';
        final bytesAny = dyn.bytes;        if (!mime.toLowerCase().startsWith('image/')) continue;
        final b = _asBytes(bytesAny);
        if (b == null || b.isEmpty) continue;

        list.add(_AttItem(name: name, mime: mime, bytes: b));
        if (list.length >= _maxThumbsInCell) break;
      }

      final cnt = xs.length;
      if (_attachCounts[r] != cnt || !_listEqualsBytes(_rowThumbs[r], list)) {
        setState(() {
          _attachCounts[r] = cnt;
          _rowThumbs[r] = list;
          _rowPhotoIds[r] = list.map((e) => e.name).toList(growable: false);
          _rowThumbsVer[r] = (_rowThumbsVer[r] ?? 0) + 1;
        });
      }
    } catch (_) {
      // Silencioso
    }
  }

  bool _listEqualsBytes(List<_AttItem>? a, List<_AttItem> b) {
    if (a == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].bytes.length != b[i].bytes.length) return false;
    }
    return true;
  }

  int _firstVisibleRow() {
    if (!_vBody.hasClients) return 0;
    final off = _vBody.offset;
    return off <= 0 ? 0 : _clampi((off / _rowH).floor(), 0, _rowCount - 1);
  }

  int _visibleRowCount() {
    if (!_vBody.hasClients) return 0;
    final vh = _vBody.position.viewportDimension;
    if (vh <= 0) return 0;
    return (vh / _rowH).ceil();
  }

  Future<void> _pickAttachmentsForFocusedRow() async {
    await _pickAttachmentsForRow(_focus.$1);
  }

  Future<void> _pickAttachmentsForRow(int r) async {
    if (_busy) return;
    if (_rowCount == 0) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final groupExt = XTypeGroup(
        label: 'Images',
        extensions: const ['png', 'jpg', 'jpeg', 'webp'],
      );
      final groupMime = XTypeGroup(
        label: 'Images',
        mimeTypes: const ['image/*'],
      );
      final existing = await AttachmentsServiceWeb.I.listFor(
        sheetId: widget.sheetId,
        row: r,
      );
      final remainingCap = (_maxPhotosPerCell - existing.length)
          .clamp(0, _maxPhotosPerCell).toInt();
      if (remainingCap <= 0) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              'Máximo de $_maxPhotosPerCell fotos por celda. '
                  'Eliminá alguna para agregar más.',
            ),
          ),
        );
        return;
      }


      // En mobile, muchos pickers muestran “Cámara” dentro del selector.
      final files = await openFiles(acceptedTypeGroups: [groupExt, groupMime]);
      if (files.isEmpty) return;

      final effectiveFiles = files.length > remainingCap
          ? files.take(remainingCap).toList(growable: false)
          : files;
      final skipped = files.length - effectiveFiles.length;

      _attachmentsEverUsed = true;

      setState(() {
        _busy = true;
        _busyMessage = 'Adding photos…';
      });

      for (final f in effectiveFiles) {
        try {
          await _attachmentsAddBytes(r: r, file: f);
        } catch (_) {}
      }

      if (!mounted) return;

      await _refreshRowThumbs(r);
      _thumbDebounce(() {
        _refreshVisibleThumbs();
      });

      messenger?.showSnackBar(
        SnackBar(content: Text('Added ${effectiveFiles.length} photo(s)')),
      );
      if (skipped > 0) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              'Se ignoraron $skipped foto(s): máximo $_maxPhotosPerCell por celda.',
            ),
          ),
        );
      }

    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Attachment error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _attachmentsAddBytes({
    required int r,
    required XFile file,
  }) async {
    final raw = await file.readAsBytes();
    final name = file.name;
    final mime = _guessMime(name);

    // Guardamos tal cual; xlsx convertirá a JPG si hace falta.
    final svc = AttachmentsServiceWeb.I;

    // Compat: algunos servicios exponen addBytes, otros add.
    try {
      await (svc as dynamic).addBytes(
        sheetId: widget.sheetId,
        row: r,
        name: name,
        mime: mime,
        bytes: raw,
      );
      return;
    } catch (_) {}
    try {
      await (svc as dynamic).add(
        sheetId: widget.sheetId,
        row: r,
        name: name,
        mime: mime,
        bytes: raw,
      );
    } catch (_) {}
  }

  String _guessMime(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  Future<void> _showRowPhotosDialog(int row) async {
    if (_rowCount == 0) return;

    setState(() {
      _busy = true;
      _busyMessage = 'Loading photos…';
    });

    List<_AttItem> list = const [];
    try {
      final xs = await AttachmentsServiceWeb.I.listFor(
        sheetId: widget.sheetId,
        row: row,
      );
      final items = <_AttItem>[];
      for (final a in xs) {
        final dyn = a as dynamic;
        final name = (dyn.name as String?) ?? 'photo';
        final mime = (dyn.mime as String?) ?? '';
        final bytesAny = dyn.bytes;
        if (!mime.toLowerCase().startsWith('image/')) continue;
        final b = _asBytes(bytesAny);
        if (b == null || b.isEmpty) continue;
        items.add(_AttItem(name: name, mime: mime, bytes: b));
      }
      list = items;
    } catch (_) {
      list = const [];
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            width: 520,
            height: 520,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Row(
                    children: [
                      Text(
                        'Row ${row + 1} photos',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _pickAttachmentsForRow(row);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: list.isEmpty
                      ? const Center(child: Text('No photos'))
                      : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final a = list[i];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          child: InkWell(
                            onTap: () =>
                                _showImageDialog(a.bytes, a.name),
                            child: Image.memory(
                              a.bytes,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.low,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showImageDialog(Uint8List bytes, String name) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 680,
          height: 520,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: InteractiveViewer(
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------ XLSX Export ------------------------------

  Uint8List _toExcelSafeImage(Uint8List input) {
    try {
      final decoded = img.decodeImage(input);
      if (decoded == null) return input;
      final jpg = img.encodeJpg(decoded, quality: 85);
      return Uint8List.fromList(jpg);
    } catch (_) {
      return input;
    }
  }

  Future<void> _exportXlsx() async {
    if (_busy) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _busy = true;
      _busyMessage = 'Exporting…';
    });

    try {
      final bytes = await _buildXlsxBytes(withPhotos: true);
      if (!mounted) return;

      setState(() {
        _busyMessage = kIsWeb ? 'Downloading…' : 'Saving…';
      });

      final baseName = _safeFileName(_sheetName.isEmpty ? 'Sheet' : _sheetName);
      final ts = _timestamp();
      final outName = '${baseName}_$ts';

      final savedPath = await _saveXlsxCompat(outName, bytes);

      if (!mounted) return;
      final msg = kIsWeb
          ? 'Downloaded: $outName.xlsx'
          : 'Saved: ${((savedPath == null || savedPath.isEmpty) ? '$outName.xlsx' : savedPath)}';
      messenger?.showSnackBar(SnackBar(content: Text(msg)));

      // Opcional: backup nube silencioso si lo usás.
      _saveCloudSilently();
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Export error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  String _safeFileName(String s) {
    final cleaned = s.trim().replaceAll(RegExp(r'[^\w\s-]'), '');
    final dashed = cleaned.replaceAll(RegExp(r'\s+'), '_');
    return dashed.isEmpty ? 'Sheet' : dashed;
  }

  Future<String?> _saveXlsxCompat(String baseName, Uint8List bytes) async {
    // Compat: xlsx_saver_io.dart puede devolver void/Future<void> o un path String.
    // Evitamos “await” en expresiones que podrían resolverse a 'void'.
    try {
      final dynamic fn = saveXlsx;
      final Object? r = Function.apply(fn, [baseName, bytes]);

      if (r is Future) {
        final Object? v = await r;
        return v is String ? v : null;
      }

      return r is String ? r : null;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _buildXlsxBytes({required bool withPhotos}) async {
    final book = xlsio.Workbook();
    try {
      final sh = book.worksheets[0];

      // Minimal Apple-like: gridlines OFF, usamos bordes finos.
      sh.showGridlines = false;

      final headers = _state.headers;
      final rows = _state.rows;
      final rowCount = rows.length;
      final colCount = headers.length;

      // Properties (opcionales)
      try {
        final p = book.builtInProperties;
        p.author = 'Gridnote';
        p.company = 'Gridnote';
        p.title = _sheetName;
        p.subject = 'Sheet export';
      } catch (_) {}

      // Encabezados (fila 1)
      for (var c = 0; c < colCount; c++) {
        final cell = sh.getRangeByIndex(1, c + 1);
        cell.setText(headers[c]);
        final st = cell.cellStyle;
        st.bold = true;
        st.vAlign = xlsio.VAlignType.center;
        st.hAlign = xlsio.HAlignType.center;
      }

      // Datos (desde fila 2)
      for (var r = 0; r < rowCount; r++) {
        final row = rows[r];
        for (var c = 0; c < colCount && c < row.length; c++) {
          if (c == _photosCol) continue; // Photos se exportan aparte (imágenes)

          final v = row[c];
          if (v.isEmpty) continue;

          final cell = sh.getRangeByIndex(r + 2, c + 1);
          final link = _mapsLinkOrNull(v);
          if (link != null) {
            cell.setText(v);
            sh.hyperlinks.add(cell, xlsio.HyperlinkType.url, link);
          } else {
            final raw = v.trim();
            if (raw.isEmpty) continue;

            // Número simple si aplica
            final normalized = raw.replaceAll(',', '.');
            final d = double.tryParse(normalized);
            if (d != null && !raw.contains(' ')) {
              cell.setNumber(d);
            } else {
              cell.setText(v);
            }
          }
        }
      }

      // Congelar encabezado
      try {
        sh.unfreezePanes();
      } catch (_) {}
      try {
        sh.getRangeByIndex(2, 1).freezePanes();
      } catch (_) {}

      // Estética minimal: header blanco, bordes finos, zebra sutil.
      final lastColBase = math.max(1, colCount);
      final lastRow = math.max(1, rowCount + 1);

      // Header range
      final headerRange = sh.getRangeByIndex(1, 1, 1, lastColBase);
      final hs = headerRange.cellStyle;
      hs.backColor = '#FFFFFF';
      hs.fontColor = '#111111';
      hs.bold = true;
      hs.hAlign = xlsio.HAlignType.center;
      hs.vAlign = xlsio.VAlignType.center;

      // Data range
      if (rowCount > 0) {
        final dataRange = sh.getRangeByIndex(2, 1, lastRow, lastColBase);
        final ds = dataRange.cellStyle;
        ds.vAlign = xlsio.VAlignType.center;
        ds.hAlign = xlsio.HAlignType.left;
      }

      // Zebra muy suave
      for (var r = 0; r < rowCount; r++) {
        if (r.isOdd) {
          final excelRow = r + 2;
          final rowRange =
          sh.getRangeByIndex(excelRow, 1, excelRow, lastColBase);
          rowRange.cellStyle.backColor = '#FAFAFB';
        }
      }

      // Bordes finos para todo el rango usado
      try {
        final used = sh.getRangeByIndex(1, 1, lastRow, lastColBase);
        used.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        used.cellStyle.borders.all.color = '#E5E7EB';
      } catch (_) {}

      // Auto-fit columnas texto
      for (var c = 1; c <= colCount; c++) {
        try {
          sh.autoFitColumn(c);
        } catch (_) {
          // fallback
          try {
            _columnRange(sh, c).columnWidth = 18.0;
          } catch (_) {}
        }
      }

      // Fotos embebidas (a la derecha)
      if (withPhotos && rowCount > 0) {
        final Map<int, List<Uint8List>> byRow = {};
        for (var r = 0; r < rowCount; r++) {
          final xs = await AttachmentsServiceWeb.I
              .listFor(sheetId: widget.sheetId, row: r);
          final imgs = <Uint8List>[];
          for (final a in xs) {
            final dyn = a as dynamic;
            final mimeAny = dyn.mime;
            final bytesAny = dyn.bytes;
            final mime = (mimeAny is String) ? mimeAny.toLowerCase() : '';
            if (!mime.startsWith('image/')) continue;
            final b = _asBytes(bytesAny);
            if (b == null || b.isEmpty) continue;

            if (mime.contains('jpeg') || mime.contains('jpg')) {
              imgs.add(b);
            } else {
              final safe = _toExcelSafeImage(b);
              if (safe.isNotEmpty) imgs.add(safe);
            }

            if (imgs.length >= _maxPhotosPerRowExport) break;
          }
          if (imgs.isNotEmpty) {
            byRow[r] = imgs;
          }
        }

        final maxPhotos = _maxPhotos(byRow, _maxPhotosPerRowExport);
        if (maxPhotos > 0) {
          final firstPhotoCol = colCount + 1;

          // Headers de fotos
          for (var p = 0; p < maxPhotos; p++) {
            final col = firstPhotoCol + p;
            final hdrCell = sh.getRangeByIndex(1, col);
            hdrCell.setText('Photo ${p + 1}');
            final st = hdrCell.cellStyle;
            st.bold = true;
            st.hAlign = xlsio.HAlignType.center;
            st.vAlign = xlsio.VAlignType.center;
            st.backColor = '#FFFFFF';
            st.fontColor = '#111111';
            _columnRange(sh, col).columnWidth = 22.0;
          }

          const double kWpx = 160;
          const double kHpx = 120;
          final rowHeightsPx = List<double>.filled(rowCount, 0);

          // Insertar imágenes
          byRow.forEach((r, list) {
            final take = math.min(list.length, maxPhotos);
            for (var p = 0; p < take; p++) {
              final col = firstPhotoCol + p;
              final pic = sh.pictures.addStream(r + 2, col, list[p]);
              pic.width = kWpx.toInt();
              pic.height = kHpx.toInt();
              final needed = kHpx + 8;
              if (rowHeightsPx[r] < needed) rowHeightsPx[r] = needed;
            }
          });

          // Ajustar alto filas con fotos
          for (var r = 0; r < rowCount; r++) {
            final px = rowHeightsPx[r];
            if (px > 0) {
              final pt = (px * 0.75) + 6.0; // aproximación px->pt
              _rowRange(sh, r + 2).rowHeight = pt;
            }
          }

          // Bordes también en zona fotos
          try {
            final used =
            sh.getRangeByIndex(1, 1, lastRow, colCount + maxPhotos);
            used.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
            used.cellStyle.borders.all.color = '#E5E7EB';
          } catch (_) {}
        }
      }

      final list = book.saveAsStream();
      return Uint8List.fromList(list);
    } finally {
      book.dispose();
    }
  }

  static int _maxPhotos(Map<int, List<Uint8List>> byRow, int maxPerRow) {
    var m = 0;
    byRow.forEach((_, list) {
      final len = list.length;
      if (len > m) m = len;
    });
    if (m < 0) m = 0;
    if (m > maxPerRow) m = maxPerRow;
    return m;
  }

  static xlsio.Range _columnRange(xlsio.Worksheet sh, int col) {
    final name = '${_colName(col)}:${_colName(col)}';
    return sh.getRangeByName(name);
  }

  static xlsio.Range _rowRange(xlsio.Worksheet sh, int row) {
    final name = '$row:$row';
    return sh.getRangeByName(name);
  }

  static String _colName(int idx) {
    var n = idx;
    final sb = StringBuffer();
    while (n > 0) {
      final rem = (n - 1) % 26;
      sb.writeCharCode(65 + rem);
      n = (n - 1) ~/ 26;
    }
    return sb.toString().split('').reversed.join();
  }

  static String _timestamp() {
    final d = DateTime.now();
    String t(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${t(d.month)}${t(d.day)}_${t(d.hour)}${t(d.minute)}${t(d.second)}';
  }

  // ------------------------------ Backup / Cloud ---------------------------

  Future<void> _downloadBackupJson() async {
    try {
      LocalStore.downloadBackup(_state);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Backup downloaded')),
      );
    } catch (e) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Backup error: $e')),
      );
    }
  }

  Future<TableState?> _importBackupCompat() async {
    // Importa un backup JSON desde archivo (Web/Desktop/Mobile).
    // Usa TableState.fromJsonString(...) para compat con backups previos.
    try {
      final XFile? f = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(label: 'JSON', extensions: <String>['json']),
          XTypeGroup(label: 'Text', extensions: <String>['txt']),
        ],
      );
      if (f == null) return null;

      final Uint8List bytes = await f.readAsBytes();
      final String raw = utf8.decode(bytes);

      // Ruta principal: tu modelo.
      try {
        return TableState.fromJsonString(raw);
      } catch (_) {
        // Fallback: algunos backups pueden tener wrapper {state: "..."} o {headers,rows}.
        final dynamic j = jsonDecode(raw);
        if (j is Map<String, dynamic>) {
          if (j['raw'] is String) {
            return TableState.fromJsonString(j['raw'] as String);
          }
          if (j['state'] is String) {
            return TableState.fromJsonString(j['state'] as String);
          }
          // Si ya viene con forma de TableState.
          return TableState.fromJsonString(jsonEncode(j));
        }
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _importBackupJson() async {
    final ok = await _confirmDestructive(
      title: 'Import JSON backup',
      message:
      'This will replace the current sheet with the imported backup.\n\nYou can try undo if needed.',
      confirmLabel: 'Import',
    );
    if (!ok) return;

    try {
      final ts = await _importBackupCompat();
      if (!mounted || ts == null) return;

      final restored = _normalizeState(
        TableState(
          headers: ts.headers.toList(),
          rows: ts.rows.map((r) => r.toList()).toList(),
          savedAt: DateTime.now(),
        ),
      );

      _updateState(restored);
      _resetHdrCtl();
      _rebuildPrefix();
      _autoFitOnce = false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _recomputeVisibleCols();
        _thumbDebounce(() {
          _refreshVisibleThumbs();
        });
      });

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Backup imported')),
      );
    } catch (e) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Import error: $e')),
      );
    }
  }

  Map<String, dynamic> _stateToFirestoreData() {
    return <String, dynamic>{
      'headers': _state.headers,
      'rows': _state.rows,
      'savedAt': (_lastSavedAt ?? DateTime.now()).toIso8601String(),
      'name': _sheetName,
    };
  }

  String _deviceLabel() {
    if (kIsWeb) return 'Web';
    final platform = Theme.of(context).platform;
    switch (platform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  Future<void> _saveCloudSilently() async {
    try {
      final data = _stateToFirestoreData();
      await FirestoreSheetStore.instance.saveSheet(
        sheetId: widget.sheetId,
        data: data,
        name: _sheetName,
        deviceInfo: _deviceLabel(),
      );
    } catch (_) {
      // Silencioso
    }
  }

  Future<void> _backupToCloud() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyMessage = 'Uploading…';
    });
    try {
      final data = _stateToFirestoreData();
      await FirestoreSheetStore.instance.saveSheet(
        sheetId: widget.sheetId,
        data: data,
        name: _sheetName,
        deviceInfo: _deviceLabel(),
      );
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Cloud backup saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Cloud backup error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _restoreFromCloud() async {
    if (_busy) return;

    final ok = await _confirmDestructive(
      title: 'Restore from cloud',
      message:
      'This will replace the current sheet with the cloud backup for this ID.\n\nYou can try undo if needed.',
      confirmLabel: 'Restore',
    );
    if (!ok) return;

    setState(() {
      _busy = true;
      _busyMessage = 'Restoring…';
    });

    try {
      final json = await FirestoreSheetStore.instance.loadSheet(widget.sheetId);
      if (!mounted) return;

      if (json == null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('No cloud backup found')),
        );
        return;
      }

      final headersRaw = json['headers'];
      final rowsRaw = json['rows'];

      if (headersRaw is! List || rowsRaw is! List) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Invalid cloud backup')),
        );
        return;
      }

      final headers = headersRaw.map((e) => e.toString()).toList().cast<String>();
      final rows = <List<String>>[];
      for (final row in rowsRaw) {
        if (row is List) {
          rows.add(row.map((e) => e.toString()).toList());
        }
      }

      DateTime? savedAt;
      final rawSaved = json['savedAt'];
      if (rawSaved is String) savedAt = DateTime.tryParse(rawSaved);

      final nameAny = json['name'];
      if (nameAny is String && nameAny.trim().isNotEmpty) {
        _sheetName = nameAny.trim();
      }

      final restored = _normalizeState(
        TableState(
          headers: headers,
          rows: rows,
          savedAt: savedAt ?? DateTime.now(),
        ),
      );

      _updateState(restored);
      _resetHdrCtl();
      _rebuildPrefix();
      _autoFitOnce = false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _recomputeVisibleCols();
        _thumbDebounce(() {
          _refreshVisibleThumbs();
        });
      });

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Restored from cloud')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Restore error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  // ------------------------------ UI ---------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isDesktop = _isDesktopUi(context);

    // Paleta Apple-like: blanco limpio, divisores suaves.
    // Paleta “Apple cálida”: fondo levemente tibio en modo claro y líneas suaves.
    // (La grilla en sí mantiene blanco puro para que se sienta “Numbers”.)
    final bg = theme.brightness == Brightness.light
        ? const Color(0xFFF5F5F7)
        : cs.surface;
    final divider = theme.brightness == Brightness.light
        ? const Color(0xFFE1E5EA)
        : cs.outline.withOpacity(0.26);

    final titleTextStyle = theme.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.06,
    ) ??
        const TextStyle(fontSize: 36, fontWeight: FontWeight.w700);

    final statusText = _saving
        ? 'Saving…'
        : (_lastSavedAt != null ? 'Saved ${_fmtTime(_lastSavedAt!)}' : '');

    return Scaffold(
      resizeToAvoidBottomInset: false, // clave: evita rebote del teclado
      backgroundColor: bg,
      body: ScrollConfiguration(
        behavior: const _NoGlowClampingScrollBehavior(),
        child: SafeArea(
          bottom: true,
          child: Stack(
            children: [
              Column(
                children: [
                  // Top header (como la imagen): título grande + pill buttons
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 22 : 16,
                      isDesktop ? 16 : 12,
                      isDesktop ? 22 : 16,
                      8,
                    ),
                    child: _TopHeader(
                      title: _sheetName,
                      titleStyle: titleTextStyle,
                      subtitle: statusText,
                      onRename: () {
                        _renameSheet();
                      },
                      actions: [
                        _PillButton(
                          label: 'Save',
                          onTap: _loading || _busy ? null : _saveNow,
                        ),
                        const SizedBox(width: 10),
                        _PillButton(
                          label: 'Export',
                          onTap: _loading || _busy ? null : _exportXlsx,
                        ),
                        const SizedBox(width: 10),
                        _PillButton(
                          label: 'More',
                          onTap: _loading || _busy ? null : _openMoreMenu,
                        ),
                      ],
                    ),
                  ),

                  // Divider fino (como mock)
                  Container(height: 1, color: divider),

                  // Grid ocupa todo.
                  Expanded(
                    child: _loading
                        ? const _Skeleton()
                        : _buildGrid(context, divider),
                  ),
                ],
              ),

              // Mobile editor bar (minimal).
              if (!_isDesktopUi(context) && _isEditing)
                _MobileEditorBar(
                  controller: _cellEC,
                  focusNode: _cellFN,
                  onDone: () =>
                      _commitCell(_focus.$1, _focus.$2, _cellEC.text),
                  onNext: () => _commitAndMoveDown(_focus.$1, _focus.$2),
                  label: _cellLabel(_focus.$1, _focus.$2),
                ),

              if (_busy) _BusyOverlay(message: _busyMessage),

              // Theme toggle discreto (solo en desktop/web; en mobile está en “More”).
              if (isDesktop)
                Positioned(
                  top: 8,
                  right: 10,
                  child: IconButton(
                    tooltip: widget.isLight ? 'Dark mode' : 'Light mode',
                    onPressed: widget.onToggleTheme,
                    icon: Icon(
                        widget.isLight ? Icons.dark_mode : Icons.light_mode),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtTime(DateTime d) {
    String t(int n) => n.toString().padLeft(2, '0');
    return '${t(d.hour)}:${t(d.minute)}';
  }

  String _cellLabel(int r, int c) {
    // Ej: A1, B3…
    final col = _colName(c + 1);
    return '$col${r + 1}';
  }

  Future<void> _renameSheet() async {
    final controller = TextEditingController(text: _sheetName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Rename sheet'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Sheet name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final v = controller.text.trim();
                Navigator.of(ctx).pop(v.isEmpty ? null : v);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (name == null || name.trim().isEmpty) return;

    setState(() => _sheetName = name.trim());
    _saveCloudSilently();
    _persistDebounce(() {
      if (!mounted) return;
      _enqueueSave(_state);
    });
  }

  Future<void> _openMoreMenu() async {
    final isDesktop = _isDesktopUi(context);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final divider = Theme.of(ctx).dividerColor.withOpacity(0.35);

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                _MoreSectionTitle('Sheet'),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Rename'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _renameSheet();
                  },
                ),
                ListTile(
                  leading:
                  Icon(widget.isLight ? Icons.dark_mode : Icons.light_mode),
                  title: Text(
                      widget.isLight ? 'Switch to Dark' : 'Switch to Light'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    widget.onToggleTheme();
                  },
                ),
                Divider(height: 1, color: divider),

                _MoreSectionTitle('Rows & Columns'),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Add row'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _addRowAndEdit();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.view_week_outlined),
                  title: const Text('Add column (right)'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _addColumnRightOfFocus();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete current row'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _deleteFocusedRow();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: const Text('Clear current row'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _clearRow(_focus.$1);
                  },
                ),
                Divider(height: 1, color: divider),

                _MoreSectionTitle('Location & Photos'),
                ListTile(
                  leading: const Icon(Icons.my_location),
                  title: const Text('Insert GPS in this cell'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _insertGpsHere();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Add photos to current row'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickAttachmentsForFocusedRow();
                  },
                ),
                Divider(height: 1, color: divider),

                _MoreSectionTitle('Backup'),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Download JSON backup'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _downloadBackupJson();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file_outlined),
                  title: const Text('Import JSON backup'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _importBackupJson();
                  },
                ),
                if (!isDesktop) const SizedBox(height: 4),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Cloud backup (Firestore)'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _backupToCloud();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('Restore from cloud (Firestore)'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _restoreFromCloud();
                  },
                ),
                Divider(height: 1, color: divider),

                _MoreSectionTitle('Danger zone'),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined),
                  title: const Text('Clear entire sheet'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _clearAll();
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------ Grid build -------------------------------

  Widget _buildGrid(BuildContext context, Color divider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDesktop = _isDesktopUi(context);

    // Grilla blanca con líneas suaves.
    final headerBg = theme.brightness == Brightness.light
        ? const Color(0xFFFFFFFF)
        : cs.surface;

    final cellBg = theme.brightness == Brightness.light
        ? const Color(0xFFFFFFFF)
        : cs.surface;

    final zebraBg = theme.brightness == Brightness.light
        ? const Color(0xFFFAFAFB)
        : cs.surfaceContainerHighest.withOpacity(0.10);

    return Column(
      children: [
        // Header row (column titles)
        SizedBox(
          height: _hdrH,
          child: Row(
            children: [
              _indexHeader(divider),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, cons) {
                    final vw = cons.maxWidth > 0
                        ? cons.maxWidth
                        : MediaQuery.of(context).size.width;
                    _scheduleViewportOps(vw);

                    final contentWidth =
                    _prefix.isEmpty ? vw : math.max(_prefix.last, vw);

                    return SingleChildScrollView(
                      controller: _hHdr,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: contentWidth,
                        height: _hdrH,
                        child: Row(
                          children: [
                            SizedBox(width: _sumRange(0, _firstCol)),
                            for (int c = _firstCol; c <= _lastCol; c++)
                              _headerCell(
                                c,
                                divider: divider,
                                bg: headerBg,
                                isDesktop: isDesktop,
                              ),
                            SizedBox(width: _sumRange(_lastCol + 1, _colCount)),
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

        // Body (rows)
        Expanded(
          child: Row(
            children: [
              // index col
              SizedBox(
                width: _indexColW,
                child: ListView.builder(
                  controller: _vIdx,
                  itemExtent: _rowH,
                  itemCount: _rowCount,
                  itemBuilder: (_, r) {
                    final selected = r == _focus.$1;
                    final bg = r.isOdd ? zebraBg : cellBg;
                    final cnt = _attachCounts[r] ?? 0;

                    return InkWell(
                      onTap: () => _setFocus(r, _focus.$2),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bg,
                          border: Border(
                            right: BorderSide(color: divider, width: 1),
                            bottom: BorderSide(color: divider, width: 1),
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Center(
                              child: Text(
                                '${r + 1}',
                                style: TextStyle(
                                  fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                            ),
                            if (selected)
                              IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: cs.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            if (cnt > 0)
                              Positioned(
                                right: 6,
                                bottom: 6,
                                child: _TinyBadge(
                                  text: '$cnt',
                                  bg: theme.brightness == Brightness.dark
                                      ? const Color(0xFF2A2A32)
                                      : const Color(0xFF1C1C1E),
                                  fg: Colors.white,
                                  icon: Icons.photo,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // main grid
              Expanded(
                child: LayoutBuilder(
                  builder: (_, cons) {
                    final vw = cons.maxWidth > 0
                        ? cons.maxWidth
                        : MediaQuery.of(context).size.width;
                    _scheduleViewportOps(vw);

                    final contentWidth =
                    _prefix.isEmpty ? vw : math.max(_prefix.last, vw);

                    return SingleChildScrollView(
                      controller: _hBody,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: contentWidth,
                        child: Focus(
                          autofocus: true,
                          skipTraversal: true,
                          focusNode: _gridFN,
                          canRequestFocus: !_isEditing,
                          onKeyEvent: _handleGridKey,
                          child: ListView.builder(
                            controller: _vBody,
                            itemExtent: _rowH,
                            itemCount: _rowCount,
                            itemBuilder: (_, r) {
                              final bg = r.isOdd ? zebraBg : cellBg;
                              return Row(
                                children: [
                                  SizedBox(width: _sumRange(0, _firstCol)),
                                  for (int c = _firstCol; c <= _lastCol; c++)
                                    _cell(
                                      r,
                                      c,
                                      divider: divider,
                                      bg: bg,
                                      isDesktop: isDesktop,
                                    ),
                                  SizedBox(
                                      width: _sumRange(_lastCol + 1, _colCount)),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _indexHeader(Color divider) {
    return Container(
      width: _indexColW,
      height: _hdrH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: divider, width: 1),
          bottom: BorderSide(color: divider, width: 1),
        ),
      ),
      child: Text(
        '',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }

  Widget _headerCell(
      int c, {
        required Color divider,
        required Color bg,
        required bool isDesktop,
      }) {
    final theme = Theme.of(context);
    final w = _colW[c];

    final ctl = _hdrController(c);
    final hint = (ctl.text.trim().isEmpty) ? _fallbackHeaderHint(c) : null;

    // Estilo: header centrado, sin “look de TextField”.
    final textStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
    ) ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

    return SizedBox(
      width: w,
      height: _hdrH,
      child: Stack(
        children: [
          Positioned.fill(
            right: isDesktop ? 10 : 0,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                border: Border(
                  bottom: BorderSide(color: divider, width: 1),
                  right: BorderSide(color: divider.withOpacity(0.55), width: 0.6),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: TextField(
                    controller: ctl,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: hint,
                      hintStyle: textStyle.copyWith(
                        color: theme.hintColor.withOpacity(0.65),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 14),
                    ),
                    style: textStyle,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _setFocus(0, c),
                  ),
                ),
              ),
            ),
          ),
          if (isDesktop)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: 10,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (d) {
                      setState(() {
                        _colW[c] = (_colW[c] + d.delta.dx)
                            .clamp(_minColW, _maxColW)
                            .toDouble();
                        _rebuildPrefix();
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _recomputeVisibleCols();
                      });
                    },
                    onDoubleTap: () => _autoFitCol(c),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fallbackHeaderHint(int c) {
    // Para que se vea “como la imagen” aun si el usuario borra texto.
    if (_state.headers.length == 4) {
      if (c >= 0 && c < _templateHeaders.length) return _templateHeaders[c];
    }
    return 'Col ${c + 1}';
  }

  void _autoFitCol(int c) {
    final theme = Theme.of(context);
    final cellStyle = theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    final hdrStyle =
        theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700) ??
            const TextStyle(fontWeight: FontWeight.w700);

    double maxW = 0;
    final hdr = _state.headers[c].trim().isEmpty
        ? _fallbackHeaderHint(c)
        : _state.headers[c];
    maxW = math.max(maxW, _measureText(hdr, hdrStyle));

    for (final r in _state.rows) {
      if (c >= r.length) continue;
      maxW = math.max(maxW, _measureText(r[c], cellStyle));
    }

    final target = (maxW + 34.0).clamp(_minColW, _maxColW).toDouble();
    setState(() {
      _colW[c] = target;
      _rebuildPrefix();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recomputeVisibleCols();
    });
  }

  double _measureText(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return tp.width;
  }

  Widget _cell(
      int r,
      int c, {
        required Color divider,
        required Color bg,
        required bool isDesktop,
      }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    final isFocused = (_focus.$1 == r && _focus.$2 == c);
    final isEditingThis = isFocused && _isEditing;

    // Base: grilla tipo hoja (líneas finas).
    final baseDeco = BoxDecoration(
      color: bg,
      border: Border(
        right: BorderSide(color: divider, width: 1),
        bottom: BorderSide(color: divider, width: 1),
      ),
    );

    // Focus ring tipo iOS (suave, sin “azul Material”).
    final ringColor = isLight
        ? const Color(0xFF2D7BFF).withOpacity(0.22)
        : const Color(0xFF7AA7FF).withOpacity(0.18);
    final ringShadow = isLight
        ? const Color(0xFF2D7BFF).withOpacity(0.10)
        : const Color(0xFF7AA7FF).withOpacity(0.08);

    final focusDeco = isFocused
        ? BoxDecoration(
      color: bg,
      border: Border.all(
        color: (isLight ? const Color(0xFF2D7BFF) : const Color(0xFF7AA7FF))
            .withOpacity(0.35),
        width: 1.2,
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: ringShadow,
          blurRadius: 10,
          spreadRadius: 0.5,
        ),
      ],
    )
        : baseDeco;

    final cellW = _colW[c];
    final cellH = _rowH;

    // Photos col: UI especial (miniaturas + + solo en activo/hover).
    if (c == _photosCol) {
      final maxWidth = cellW - 12;
      final showAdd = isFocused || (isDesktop && _hoverCell == (r, c));
      return MouseRegion(
        onEnter: (_) => _setHovered(r, c),
        onExit: (_) => _clearHovered(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _setFocus(r, c, ensureVisible: true),
          onDoubleTap: () => _showRowPhotosDialog(r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            alignment: Alignment.centerLeft,
            width: cellW,
            height: cellH,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: focusDeco,
            child: _photosCellContent(
              r,
              bg,
              divider,
              maxWidth: maxWidth,
              showAdd: showAdd,
            ),
          ),
        ),
      );
    }

    // Normal cells.
    final val = _state.rows[r][c];

    Widget content;
    if (isEditingThis) {
      content = TextField(
        controller: _cellEC,
        focusNode: _cellFN,
        autofocus: true,
        textInputAction: TextInputAction.next,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isLight ? const Color(0xFF111111) : const Color(0xFFEDEDF2),
          height: 1.2,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: InputBorder.none,
        ),
        onChanged: (s) {
          // Mantener edición fluida; commit en salir / enter / tap afuera.
        },
        onSubmitted: (_) => _commitEditing(),
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          val,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isLight ? const Color(0xFF1C1C1E) : const Color(0xFFEDEDF2),
            height: 1.15,
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => _setHovered(r, c),
      onExit: (_) => _clearHovered(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setFocus(r, c, ensureVisible: true),
        onDoubleTap: () => _beginCellEdit(r, c),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: cellW,
          height: cellH,
          decoration: focusDeco,
          child: content,
        ),
      ),
    );
  }

  Widget _photosCellContent(
      int row,
      Color bg,
      Color divider, {
        required double maxWidth,
        required bool showAdd,
      }) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    final muted = theme.colorScheme.onSurface.withOpacity(isLight ? 0.42 : 0.55);

    final ids = _rowPhotoIds[row] ?? const <String>[];
    final count = ids.length;
    final thumbs = _rowThumbs[row] ?? const <_AttItem>[];

    final canAdd = count < _maxPhotosPerCell;
    final showAddTile = showAdd && canAdd;

    const thumbSize = 34.0;
    const gap = 6.0;

    // Max “slots” visibles en la celda según ancho real.
    final available = math.max(0.0, maxWidth - 14.0);
    var maxSlots = (available / (thumbSize + gap)).floor();
    maxSlots = maxSlots.clamp(1, 10);

    // Reservamos un slot para el “+” (si aplica), así no “ensucia” toda la grilla.
    final reservedForAdd = showAddTile ? 1 : 0;
    var maxThumbs = (maxSlots - reservedForAdd);
    if (maxThumbs < 1) maxThumbs = 1;
    if (maxThumbs > 10) maxThumbs = 10;

    Widget addTile(double size) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isLight
              ? const Color(0xFFF2F4F7)
              : theme.colorScheme.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: divider.withOpacity(isLight ? 0.90 : 0.70),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.add,
          size: size * 0.55,
          color: muted,
        ),
      );
    }

    if (count == 0) {
      // Vacío: placeholder tranquilo. El “+” aparece solo en foco/hover.
      if (!showAddTile) {
        return Center(
          child: Icon(
            Icons.photo_outlined,
            size: 20,
            color: muted,
          ),
        );
      }
      return Center(child: addTile(28));
    }

    // Si todavía no cargaron miniaturas, mostramos icono + contador.
    if (thumbs.isEmpty) {
      final pillBg = isLight
          ? const Color(0xFFF2F4F7)
          : theme.colorScheme.onSurface.withOpacity(0.06);

      final pieces = <Widget>[
        Icon(Icons.photo_outlined, size: 18, color: muted),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: muted,
          ),
        ),
      ];

      if (showAddTile) {
        pieces.add(const SizedBox(width: 10));
        pieces.add(addTile(thumbSize));
      }

      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: divider.withOpacity(isLight ? 0.85 : 0.65),
              width: 1,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: pieces),
        ),
      );
    }

    final shown = thumbs.take(maxThumbs).toList(growable: false);
    final remaining = count - shown.length;

    final tiles = <Widget>[];
    for (int i = 0; i < shown.length; i++) {
      final bytes = shown[i].bytes;

      Widget tile = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          bytes,
          width: thumbSize,
          height: thumbSize,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
      );

      // Si sobran fotos, mostramos “+N” sobre el último thumb visible.
      if (i == shown.length - 1 && remaining > 0) {
        tile = Stack(
          children: <Widget>[
            tile,
            Positioned.fill(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0B0F).withOpacity(isLight ? 0.35 : 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+$remaining',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFFFFF),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ],
        );
      }

      tiles.add(tile);
    }

    if (showAddTile) {
      tiles.add(addTile(thumbSize));
    }

    // Centramos: se siente más “control” y menos “ruido”.
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < tiles.length; i++) ...<Widget>[
              tiles[i],
              if (i != tiles.length - 1) const SizedBox(width: gap),
            ],
          ],
        ),
      ),
    );
  }


  bool _isCtrlPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  bool _isShiftPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
  }

  KeyEventResult _handleGridKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;

    final isDesktop = _isDesktopUi(context);
    if (!isDesktop) return KeyEventResult.ignored;

    if (_rowCount == 0 || _colCount == 0) return KeyEventResult.ignored;

    // Si está editando (inline), dejamos que el TextField maneje.
    if (_isEditing) return KeyEventResult.ignored;

    final (r, c) = _focus;
    final key = e.logicalKey;

    final ctrl = _isCtrlPressed();
    final shift = _isShiftPressed();

    // Navegación
    if (key == LogicalKeyboardKey.arrowDown) {
      _setFocus(r + 1, c);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _setFocus(r - 1, c);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _setFocus(r, c + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _setFocus(r, c - 1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _startEditing(r, c);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.tab) {
      _setFocus(r, shift ? c - 1 : c + 1);
      _startEditing(_focus.$1, _focus.$2);
      return KeyEventResult.handled;
    }

    // Copy / paste
    if (ctrl && key == LogicalKeyboardKey.keyC) {
      Clipboard.setData(ClipboardData(text: _safeCell(r, c)));
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyV) {
      Clipboard.getData('text/plain').then((data) {
        if (!mounted) return;
        final t = data?.text;
        if (t == null) return;
        _updateState(_state.withCell(r, c, t));
      });
      return KeyEventResult.handled;
    }

    // Delete
    if (key == LogicalKeyboardKey.delete) {
      if (c == _photosCol) {
        // No borramos fotos desde delete (evita “oops”).
        return KeyEventResult.handled;
      }
      _updateState(_state.withCell(r, c, ''));
      return KeyEventResult.handled;
    }

    // Undo/Redo
    if (ctrl && key == LogicalKeyboardKey.keyZ) {
      _undo();
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyY) {
      _redo();
      return KeyEventResult.handled;
    }

    // Save / Export
    if (ctrl && key == LogicalKeyboardKey.keyS) {
      _saveNow();
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyE) {
      _exportXlsx();
      return KeyEventResult.handled;
    }

    // Add row / col
    if (ctrl && key == LogicalKeyboardKey.keyN && !shift) {
      _addRowAndEdit();
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyN && shift) {
      _addColumnRightOfFocus();
      return KeyEventResult.handled;
    }

    // Texto directo
    final String? ch = e.character;
    if (!ctrl && ch != null && ch.isNotEmpty && ch.runes.length == 1) {
      _beginCharEdit(ch);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ------------------------------ Menú celda -------------------------------

  Future<void> _showCellMenu(int r, int c) async {
    _setFocus(r, c);
    final value = _safeCell(r, c);
    final isLocation = _mapsLinkOrNull(value) != null;
    final isPhotos = c == _photosCol;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPhotos) ...[
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Add photos to this row'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickAttachmentsForRow(r);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo),
                  title: const Text('View photos'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showRowPhotosDialog(r);
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _startEditing(r, c);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.my_location),
                  title: const Text('Insert GPS here'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _insertGpsAt(r, c);
                  },
                ),
                if (isLocation)
                  ListTile(
                    leading: const Icon(Icons.map_outlined),
                    title: const Text('Open in Maps'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _openMapForCell(r, c);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Copy'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Clipboard.setData(ClipboardData(text: _safeCell(r, c)));
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(content: Text('Copied')),
                    );
                  },
                ),
              ],
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('Clear row'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _clearRow(r);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete row'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _deleteFocusedRow();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------ Confirm dialog ---------------------------

  Future<bool> _confirmDestructive({
    required String title,
    required String message,
    String confirmLabel = 'Continue',
  }) async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}

// ---------------------------------------------------------------------------
// Widgets auxiliares (UI Apple-like minimal)
// ---------------------------------------------------------------------------

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.title,
    required this.titleStyle,
    required this.subtitle,
    required this.onRename,
    required this.actions,
  });

  final String title;
  final TextStyle titleStyle;
  final String subtitle;
  final VoidCallback onRename;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.hintColor,
    ) ??
        TextStyle(color: theme.hintColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onLongPress: onRename,
          child: Text(
            title,
            style: titleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 6),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: subtitleStyle,
          ),
        const SizedBox(height: 14),
        Row(
          children: actions,
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    final bg = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF3F4F6)
        : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.25);

    final border = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFE5E7EB)
        : Theme.of(context).colorScheme.outline.withOpacity(0.35);

    final fg = Theme.of(context).textTheme.bodyMedium?.color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? bg : bg.withOpacity(0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? fg : (fg?.withOpacity(0.55)),
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}

class _MoreSectionTitle extends StatelessWidget {
  const _MoreSectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.hintColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ) ??
              TextStyle(
                color: theme.hintColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({
    required this.text,
    required this.bg,
    required this.fg,
    required this.icon,
  });

  final String text;
  final Color bg;
  final Color fg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileEditorBar extends StatelessWidget {
  const _MobileEditorBar({
    required this.controller,
    required this.focusNode,
    required this.onDone,
    required this.onNext,
    required this.label,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onDone;
  final VoidCallback onNext;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bg = theme.brightness == Brightness.light
        ? const Color(0xFFFFFFFF)
        : theme.colorScheme.surface;

    final border = theme.brightness == Brightness.light
        ? const Color(0xFFE5E7EB)
        : theme.colorScheme.outline.withOpacity(0.35);

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset > 0 ? bottomInset : 0,
      child: Material(
        color: bg,
        elevation: 0,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: border, width: 1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.light
                      ? const Color(0xFFF3F4F6)
                      : theme.colorScheme.surfaceContainerHighest.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: border, width: 1),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Type…',
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onDone(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Next row',
                onPressed: onNext,
                icon: const Icon(Icons.keyboard_return),
              ),
              IconButton(
                tooltip: 'Done',
                onPressed: onDone,
                icon: const Icon(Icons.check),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton + Busy overlay
// ---------------------------------------------------------------------------

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        Container(
          height: 54,
          color: cs.surface,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: 180,
            height: 18,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: 10,
            itemBuilder: (_, __) {
              return Container(
                height: 54,
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = message ?? 'Working…';

    return AbsorbPointer(
      child: Container(
        color: Colors.black.withOpacity(0.18),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.96),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scroll behavior: sin rebote barato, sin glow.
// ---------------------------------------------------------------------------

class _NoGlowClampingScrollBehavior extends ScrollBehavior {
  const _NoGlowClampingScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

// ---------------------------------------------------------------------------
// Model adjunto simple
// ---------------------------------------------------------------------------

class _AttItem {
  final String name;
  final String mime;
  final Uint8List bytes;
  const _AttItem({
    required this.name,
    required this.mime,
    required this.bytes,
  });
}

// ---------------------------------------------------------------------------
// Debouncer simple
// ---------------------------------------------------------------------------

class _Debouncer {
  _Debouncer(this.delay);
  final Duration delay;
  Timer? _t;

  void call(void Function() fn) {
    _t?.cancel();
    _t = Timer(delay, fn);
  }

  void dispose() {
    _t?.cancel();
    _t = null;
  }
}

// ---------------------------------------------------------------------------
// History (undo/redo) simple
// ---------------------------------------------------------------------------

class _History<T> {
  _History({this.cap = 200});

  final int cap;
  final List<T> _stack = <T>[];
  int _idx = -1;

  void push(T v) {
    if (_idx < _stack.length - 1) {
      _stack.removeRange(_idx + 1, _stack.length);
    }
    _stack.add(v);
    if (_stack.length > cap) {
      _stack.removeAt(0);
    }
    _idx = _stack.length - 1;
  }

  T? undo() {
    if (_idx <= 0) return null;
    _idx--;
    return _stack[_idx];
  }

  T? redo() {
    if (_idx >= _stack.length - 1) return null;
    _idx++;
    return _stack[_idx];
  }
}