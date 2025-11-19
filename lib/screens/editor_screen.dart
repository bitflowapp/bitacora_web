// lib/screens/editor_screen.dart
// Editor tipo Excel. Android / iOS / Windows / Web.
// - Encabezados editables (vacíos por defecto), auto-fit, resize con drag
// - Filas alternas, foco visible, edición al tocar
// - Adjuntos por fila y exportación XLSX real con fotos
// - Barra de adjuntos bajo encabezados, por fila enfocada
// - GPS y Dictado a celda (con mic naranja animado por fila enfocada)
// - Backup/Import JSON, Undo/Redo, Agregar/Borrar fila/columna
// - Enviar por correo vía backend (Resend) con adjunto XLSX
//   usando microservicio Node (CloudMailer / send-xlsx) [desactivado en la beta]
// - Scroll con física tipo iOS en iOS/macOS y clamping en el resto
// - Atajos: Tab/Shift+Tab, Ctrl/Cmd+S, Ctrl/Cmd+Z/Y, Ctrl/Cmd+N, Ctrl/Cmd+E
// - Atajos extra: Ctrl+D (duplicar fila), Ctrl+L (limpiar fila),
//   Ctrl+B (backup JSON local), Ctrl+Shift+B (backup nube),
//   Ctrl+O (importar), Ctrl+Shift+N (nueva columna)
// - Home/End/PageUp/PageDown para moverse rápido
// - Botón lateral "Inicio" con animación arcoíris

import 'dart:async';
import 'dart:convert' show base64Encode;
import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:file_selector/file_selector.dart';
import 'package:geolocator/geolocator.dart'
    show LocationAccuracy, Geolocator, LocationPermission;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:url_launcher/url_launcher.dart';
import 'package:image/image.dart' as img;

import '../models/table_state.dart';
import '../services/local_store.dart';
import '../services/sheet_store.dart';
import '../services/attachments_service_web.dart';
import '../services/location_service.dart';
import '../services/speech_service.dart';
import '../services/xlsx_saver_io.dart'
if (dart.library.html) '../services/xlsx_saver_web.dart';
import '../services/fotoclean_client.dart';
import '../services/firestore_sheet_store.dart';
import '../services/mail_report_service.dart';
import '../utils/debouncer.dart';
import '../utils/history.dart';
import '../widgets/speech_mic_button.dart';

/// EditorScreen muestra una planilla editable con múltiples
/// funciones como adjuntos, exportación, backups y envío por mail.
///
/// Este archivo fue adaptado para:
/// - Permitir generar XLSX con fotos (para descarga/local).
/// - Generar un XLSX liviano sin fotos para enviar por mail
///   usando el microservicio Node + Resend (CloudMailer)
///   a través de MailReportService (no expuesto en la barra en la beta).
/// - Mostrar un overlay (_BusyOverlay) cuando hay operaciones largas.
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
  // Constantes de UI
  static const double _indexColW = 56.0;
  static const double _minColW = 90.0;
  static const double _maxColW = 620.0;
  static const double _rowH = 44.0;
  static const double _hdrH = 46.0;
  static const double _attBarH = 88.0;

  // Tamaño mínimo de la planilla (nueva o restaurada).
  // Bajado a 40 filas para que nazca más liviana.
  static const int _initialCols = 20;
  static const int _initialRows = 40;

  // Encabezados por defecto para planillas nuevas: todos vacíos.
  // Los nombres visibles vienen del hint "Col X" en el TextField.
  static const List<String> _defaultHeaders = [];

  static const String _fcBaseUrl =
  String.fromEnvironment('FOTOCLEAN_URL', defaultValue: '');
  static const String _fcApiKey =
  String.fromEnvironment('FOTOCLEAN_KEY', defaultValue: '');

  FotoCleanClient? _fc;

  @pragma('vm:prefer-inline')
  int _clampi(int x, int lo, int hi) {
    if (x < lo) return lo;
    if (x > hi) return hi;
    return x;
  }

  late TableState _state;
  bool _loading = true;
  bool _busy = false;
  String? _busyMessage;

  (int r, int c) _focus = (0, 0);
  bool _isEditing = false;

  final TextEditingController _cellEC = TextEditingController();
  final FocusNode _cellFN = FocusNode();
  final FocusNode _gridFN = FocusNode(debugLabel: 'gridFN');

  final Map<int, TextEditingController> _hdrCtl = {};
  late List<double> _colW;
  late List<double> _prefix;

  int _firstCol = 0;
  int _lastCol = 0;
  static const int _bufCols = 2;
  double _lastViewportW = 0;
  bool _autoFitOnce = false;

  bool _layoutOpsScheduled = false;
  double? _pendingViewportW;

  final ScrollController _vIdx = ScrollController();
  final ScrollController _vBody = ScrollController();
  bool _syncingV = false;

  final ScrollController _hHdr = ScrollController();
  final ScrollController _hBody = ScrollController();
  bool _syncingH = false;

  final History<TableState> _history = History<TableState>(cap: 200);
  final Debouncer _persistDebounce =
  Debouncer(const Duration(milliseconds: 250));

  final Map<int, int> _attachCounts = {};
  final Debouncer _attachDebounce =
  Debouncer(const Duration(milliseconds: 200));
  final Debouncer _attUiDebounce =
  Debouncer(const Duration(milliseconds: 120));
  bool _attachmentsEverUsed = false;

  List<_AttItem> _attOfFocused = const [];
  bool _attLoading = false;

  String? _lastSavedName;
  bool _saving = false;
  DateTime? _lastSavedAt;

  String? _lastEmail;

  late final AnimationController _rainbowCtrl;

  // Animación onda de voz (mic naranja)
  late final AnimationController _micCtrl;
  bool _dictationActive = false;

  @override
  void initState() {
    super.initState();
    _state = TableState.empty();
    _colW = List<double>.filled(0, 180);
    _prefix = List<double>.filled(0, 0);

    if (_fcBaseUrl.isNotEmpty && _fcApiKey.isNotEmpty) {
      _fc = FotoCleanClient(baseUrl: _fcBaseUrl, apiKey: _fcApiKey);
    }

    _rainbowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _micCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

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
    _rainbowCtrl.dispose();
    _micCtrl.dispose();
    _cellEC.dispose();
    _cellFN.dispose();
    _gridFN.dispose();
    for (final c in _hdrCtl.values) {
      c.dispose();
    }
    _vIdx.removeListener(_syncFromIdx);
    _vBody.removeListener(_syncFromBodyV);
    _hHdr.removeListener(_syncFromHdr);
    _hBody.removeListener(_syncFromBodyH);
    _vIdx.dispose();
    _vBody.dispose();
    _hHdr.dispose();
    _hBody.dispose();
    _persistDebounce.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    final raw = await _loadRawCompat(widget.sheetId);
    if (!mounted) return;

    // Caso 1: no hay nada guardado → hoja nueva con template grande.
    if (raw == null) {
      final headers = _buildInitialHeaders();
      final rows = List.generate(
        _initialRows,
            (_) => List.filled(headers.length, ''),
      );
      final now = DateTime.now();
      final normalized = _normalizeState(
        TableState(headers: headers, rows: rows, savedAt: now),
      );
      setState(() {
        _state = normalized;
        _lastSavedAt = now;
        _colW = List<double>.filled(normalized.headers.length, 180.0);
        _rebuildPrefix();
        _loading = false;
      });
      await _loadFocusedRowAttachments();
      return;
    }

    // Caso 2: había planilla guardada → se normaliza a mínimo filas/columnas.
    final parsed = TableState.fromJsonString(raw) ?? TableState.empty();
    final normalized = _normalizeState(parsed);

    if (!mounted) return;
    setState(() {
      _state = normalized;
      _lastSavedAt = normalized.savedAt;
      _colW = List<double>.filled(_state.headers.length, 180.0);
      _rebuildPrefix();
      _loading = false;
    });
    await _loadFocusedRowAttachments();
  }

  // Encabezados iniciales: todos vacíos, se ven sólo los hints "Col X".
  List<String> _buildInitialHeaders() {
    return List<String>.filled(_initialCols, '');
  }

  // Normaliza cualquier TableState (local/nube/import) a un mínimo de
  // columnas y filas, para que la planilla vieja también "crezca".
  TableState _normalizeState(TableState s) {
    var headers = List<String>.from(s.headers);

    if (headers.isEmpty) {
      headers = _buildInitialHeaders();
    } else if (headers.length < _initialCols) {
      headers.addAll(List.filled(_initialCols - headers.length, ''));
    }

    final rows = <List<String>>[];
    for (final r in s.rows) {
      final row = List<String>.from(r);
      if (row.length < headers.length) {
        row.addAll(List.filled(headers.length - row.length, ''));
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

  // Compat con SheetStore IO/Web (loadRaw es síncrono, pero mantenemos Future)
  Future<String?> _loadRawCompat(String id) async {
    try {
      return SheetStore.loadRaw(id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCompat(TableState s) async {
    await LocalStore.save(s);
    SheetStore.saveState(widget.sheetId, s);
  }

  void _updateState(TableState s, {bool snapshot = true}) {
    setState(() => _state = s);
    if (snapshot) _history.push(s);

    _persistDebounce(() {
      if (!mounted) return;
      setState(() => _saving = true);
      () async {
        try {
          await _saveCompat(s);
          if (!mounted) return;
          setState(() {
            _saving = false;
            _lastSavedAt = DateTime.now();
          });
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _saving = false;
          });
        }
      }();
    });

    if (_colW.length != s.headers.length) {
      _resetHdrCtl();
      _colW = List<double>.filled(
        s.headers.length,
        (_lastViewportW > 0 && s.headers.isNotEmpty)
            ? (_lastViewportW / s.headers.length)
            .clamp(_minColW, _maxColW)
            .toDouble()
            : 180.0,
      );
      _rebuildPrefix();
      _autoFitOnce = false;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _recomputeVisibleCols());
    }
  }

  void _resetHdrCtl() {
    for (final c in _hdrCtl.values) {
      c.dispose();
    }
    _hdrCtl.clear();
  }

  String _formatTimeShort(DateTime d) {
    final now = DateTime.now();
    String hhmm(DateTime x) =>
        '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';

    if (now.year == d.year && now.month == d.month && now.day == d.day) {
      return 'hoy ${hhmm(d)}';
    }
    final day = d.day.toString().padLeft(2, '0');
    final mon = d.month.toString().padLeft(2, '0');
    return '$day/$mon ${hhmm(d)}';
  }

  void _rebuildPrefix() {
    _prefix = List<double>.filled(_colW.length + 1, 0);
    for (int i = 0; i < _colW.length; i++) {
      _prefix[i + 1] = _prefix[i] + _colW[i];
    }
  }

  void _maybeAutoFitViewport(double vw) {
    if (_autoFitOnce || _colW.isEmpty) return;
    final total = _prefix.last;
    if (total >= vw) return;
    final per = (vw / _colW.length).clamp(_minColW, _maxColW).toDouble();
    setState(() {
      for (int i = 0; i < _colW.length; i++) {
        _colW[i] = per;
      }
      _rebuildPrefix();
      _autoFitOnce = true;
    });
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
    start = _clampi(start - _bufCols, 0, _colW.isNotEmpty ? _colW.length - 1 : 0);
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
      if (x != null) {
        _recomputeVisibleCols(x);
        _maybeAutoFitViewport(x);
      }
    });
  }

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
    _attachDebounce(_refreshAttachForVisible);
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

  int get _rowCount => _state.rows.length;
  int get _colCount => _state.headers.length;

  void _ensureColumn(int index) {
    if (index < _colCount) return;
    final add = index - _colCount + 1;
    final newH = List<String>.from(_state.headers)
      ..addAll(List.filled(add, ''));
    final newR = _state.rows
        .map((r) => (List<String>.from(r)..addAll(List.filled(add, ''))))
        .toList();
    _updateState(
      TableState(headers: newH, rows: newR, savedAt: DateTime.now()),
    );
  }

  void _addColumnRightOfFocus() {
    final c = _clampi(_focus.$2 + 1, 0, _colCount);
    final newH = <String>[];
    for (int i = 0; i < _colCount; i++) {
      newH.add(_state.headers[i]);
      if (i == _focus.$2) newH.add('');
    }
    final newR = _state.rows.map((r) {
      final nr = <String>[];
      for (int i = 0; i < r.length; i++) {
        nr.add(r[i]);
        if (i == _focus.$2) nr.add('');
      }
      return nr;
    }).toList();

    _updateState(
      TableState(headers: newH, rows: newR, savedAt: DateTime.now()),
    );
    if (!mounted) return;
    setState(() {
      _colW.insert(c, 180.0);
      _rebuildPrefix();
    });
  }

  void _addRow() => _updateState(_state.withNewEmptyRow());

  // CORREGIDO: ya no entra en modo edición, sólo enfoca la nueva fila.
  void _addRowAndFocus() {
    final newIndex = _rowCount;
    _addRow();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final safeC = _clampi(_focus.$2, 0, math.max(0, _colCount - 1));
      final nextR = newIndex;
      final safeR = nextR >= _rowCount ? _rowCount - 1 : nextR;
      _setFocus(safeR, safeC);
      // Importante: no llamamos _startEditing para no levantar el teclado.
    });
  }

  void _duplicateRow(int r) {
    if (_rowCount == 0) return;
    final src = _clampi(r, 0, _rowCount - 1);

    final newRows = <List<String>>[];
    for (var i = 0; i < _rowCount; i++) {
      newRows.add(_state.rows[i].toList());
      if (i == src) {
        newRows.add(_state.rows[i].toList());
      }
    }

    _updateState(
      TableState(
        headers: _state.headers.toList(),
        rows: newRows,
        savedAt: DateTime.now(),
      ),
    );

    _setFocus(
      src + 1,
      _clampi(_focus.$2, 0, math.max(0, _colCount - 1)),
    );
  }

  void _deleteFocusedRow() {
    if (_rowCount <= 1) return;
    final r = _clampi(_focus.$1, 0, _rowCount - 1);
    final nextRows = <List<String>>[
      for (int i = 0; i < _rowCount; i++)
        if (i != r) _state.rows[i].toList(),
    ];
    _updateState(
      TableState(
        headers: _state.headers.toList(),
        rows: nextRows,
        savedAt: DateTime.now(),
      ),
    );
    _setFocus(_clampi(r - 1, 0, _rowCount - 1), _focus.$2);
  }

  void _clearRow(int r) {
    if (_rowCount == 0) return;
    r = _clampi(r, 0, _rowCount - 1);
    final rows = <List<String>>[];
    for (int i = 0; i < _rowCount; i++) {
      if (i == r) {
        rows.add(List<String>.filled(_colCount, ''));
      } else {
        rows.add(_state.rows[i].toList());
      }
    }
    _updateState(
      TableState(
        headers: _state.headers.toList(),
        rows: rows,
        savedAt: DateTime.now(),
      ),
    );
    _setFocus(r, _clampi(_focus.$2, 0, math.max(0, _colCount - 1)));
  }

  /// Limpia toda la planilla previa confirmación del usuario.
  /// Mantiene encabezados y deja _initialRows filas vacías.
  Future<void> _clearAll() async {
    if (_rowCount == 0) return;
    final ok = await _confirmDestructive(
      title: 'Vaciar planilla',
      message:
      'Se limpiarán todas las filas de la planilla actual.\n\n'
          'Los encabezados se mantienen, pero el contenido de las celdas se perderá (podés deshacer con Ctrl+Z).',
      confirmLabel: 'Vaciar planilla',
    );
    if (!ok) return;

    final cols = _state.headers.length;
    _updateState(
      TableState(
        headers: _state.headers.toList(),
        rows: List.generate(
          _initialRows,
              (_) => List<String>.filled(cols, ''),
        ),
        savedAt: DateTime.now(),
      ),
    );
    _resetHdrCtl();
  }

  void _undo() {
    final s = _history.undo();
    if (s != null) {
      _updateState(s, snapshot: false);
      _resetHdrCtl();
    }
  }

  void _redo() {
    final s = _history.redo();
    if (s != null) {
      _updateState(s, snapshot: false);
      _resetHdrCtl();
    }
  }

  void _setFocus(int r, int c) {
    r = _clampi(r, 0, math.max(0, _rowCount - 1));
    c = _clampi(c, 0, math.max(0, _colCount - 1));
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
    _ensureVisible(r, c);
    _attUiDebounce(_loadFocusedRowAttachments);
  }

  void _startEditing(int r, int c) {
    _setFocus(r, c);
    if (_isEditing) return;
    _gridFN.unfocus();
    _cellEC.text = _state.rows[r][c];
    setState(() => _isEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cellFN.requestFocus();
      _cellEC.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _cellEC.text.length,
      );
    });
  }

  void _commitCell(int r, int c, String v) {
    if (!_isEditing) return;
    setState(() => _isEditing = false);
    if (_state.rows[r][c] == v) {
      _gridFN.requestFocus();
      return;
    }
    _updateState(_state.withCell(r, c, v));
    _gridFN.requestFocus();
  }

  void _commitAndMoveDown(int r, int c) {
    _commitCell(r, c, _cellEC.text);
    final nextR = r + 1;
    if (nextR >= _rowCount) {
      _addRow();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final safeR = (nextR >= _rowCount) ? _rowCount - 1 : nextR;
      _startEditing(_clampi(safeR, 0, _rowCount - 1), c);
    });
  }

  void _beginCharEdit(String ch) {
    final (r, c) = _focus;
    _startEditing(r, c);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cellEC
        ..text = ch
        ..selection = TextSelection.collapsed(offset: ch.length);
    });
  }

  TextEditingController _hdrController(int col) {
    final existing = _hdrCtl[col];
    if (existing != null) return existing;
    final ctl = TextEditingController(text: _state.headers[col]);
    ctl.addListener(() {
      final newH = List<String>.from(_state.headers)..[col] = ctl.text;
      _updateState(
        _state.withHeaders(newH),
        snapshot: false,
      );
    });
    _hdrCtl[col] = ctl;
    return ctl;
  }

  void _autoFitCol(int c) {
    final cellStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    const hdrStyle = TextStyle(fontWeight: FontWeight.w700);
    double maxW = 0;
    final hdr =
    _state.headers[c].isEmpty ? 'Col ${c + 1}' : _state.headers[c];
    maxW = math.max(maxW, _measureText(hdr, hdrStyle));
    for (final r in _state.rows) {
      maxW = math.max(maxW, _measureText(r[c], cellStyle));
    }
    final target =
    (maxW + 28.0).clamp(_minColW, _maxColW).toDouble();
    setState(() {
      _colW[c] = target;
      _rebuildPrefix();
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _recomputeVisibleCols());
  }

  double _measureText(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return tp.width;
  }

  double _sumRange(int a, int bExclusive) {
    if (_prefix.isEmpty) return 0;
    a = _clampi(a, 0, _colCount);
    bExclusive = _clampi(bExclusive, 0, _colCount);
    if (bExclusive < a) return 0;
    return _prefix[bExclusive] - _prefix[a];
  }

  void _ensureVisible(int r, int c) {
    if (_vBody.hasClients) {
      final top = r * _rowH;
      final bottom = top + _rowH;
      final viewTop = _vBody.offset;
      final viewBottom =
          viewTop + _vBody.position.viewportDimension;
      if (top < viewTop) {
        _vBody.animateTo(
          top,
          duration: const Duration(milliseconds: 70),
          curve: Curves.easeOutCubic,
        );
      } else if (bottom > viewBottom) {
        _vBody.animateTo(
          bottom - _vBody.position.viewportDimension,
          duration: const Duration(milliseconds: 70),
          curve: Curves.easeOutCubic,
        );
      }
    }
    if (_hBody.hasClients) {
      final x = _prefix[c];
      final w = _colW[c];
      final vx = _hBody.offset;
      final vw = _hBody.position.viewportDimension;
      if (x < vx) {
        _hBody.animateTo(
          x,
          duration: const Duration(milliseconds: 70),
          curve: Curves.easeOutCubic,
        );
      } else if (x + w > vx + vw) {
        _hBody.animateTo(
          x + w - vw,
          duration: const Duration(milliseconds: 70),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  Future<void> _refreshAttachForVisible() async {
    if (_rowCount == 0) return;
    // Optimización: si nunca hubo adjuntos, no escaneamos filas.
    if (!_attachmentsEverUsed) return;

    final start = _firstVisibleRow();
    final end = (_rowCount - 1) < (start + _visibleRowCount() + 4)
        ? (_rowCount - 1)
        : (start + _visibleRowCount() + 4);
    for (var r = start; r <= end; r++) {
      final xs =
      await AttachmentsServiceWeb.I.listFor(sheetId: widget.sheetId, row: r);
      if (!mounted) return;
      final n = xs.length;
      if (_attachCounts[r] != n) {
        setState(() => _attachCounts[r] = n);
      }
    }
  }

  Future<void> _refreshAttachRow(int r) async {
    final xs =
    await AttachmentsServiceWeb.I.listFor(sheetId: widget.sheetId, row: r);
    if (!mounted) return;
    setState(() => _attachCounts[r] = xs.length);
  }

  int _firstVisibleRow() {
    if (!_vBody.hasClients) return 0;
    final off = _vBody.offset;
    return off <= 0
        ? 0
        : _clampi((off / _rowH).floor(), 0, _rowCount - 1);
  }

  int _visibleRowCount() {
    if (!_vBody.hasClients) return 0;
    final vh = _vBody.position.viewportDimension;
    if (vh <= 0) return 0;
    return (vh / _rowH).ceil();
  }

  // CORREGIDO: hacemos commit de la celda si está en edición
  // antes de insertar el GPS en la misma celda.
  Future<void> _insertGpsHere() async {
    if (_isEditing) {
      _commitCell(_focus.$1, _focus.$2, _cellEC.text);
    }
    final (r, c) = _focus;
    await _insertGpsAt(r, c);
  }

  // También hacemos commit antes de insertar a la derecha,
  // para que no queden cambios pendientes en la celda actual.
  Future<void> _insertGpsRight() async {
    if (_isEditing) {
      _commitCell(_focus.$1, _focus.$2, _cellEC.text);
    }
    final (r, c) = _focus;
    await _insertGpsAt(r, c + 1);
  }

  Future<void> _insertGpsAt(int r, int cTarget) async {
    _ensureColumn(cTarget);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _busy = true;
      _busyMessage = 'Obteniendo ubicación…';
    });
    try {
      // Permisos de ubicación para Android / iOS / Web.
      bool serviceEnabled;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (_) {
        // En caso de duda, no bloqueamos en web/escritorio.
        serviceEnabled = true;
      }

      if (!serviceEnabled) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(
              'Servicio de ubicación desactivado. Activá el GPS y volvé a intentar.',
            ),
          ),
        );
        return;
      }

      LocationPermission permission;
      try {
        permission = await Geolocator.checkPermission();
      } catch (_) {
        // Si falla el chequeo, dejamos seguir y que LocationService maneje.
        permission = LocationPermission.always;
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          messenger?.showSnackBar(
            const SnackBar(
              content: Text(
                'Permiso de ubicación denegado. No se pudo obtener la posición.',
              ),
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(
              'Permiso de ubicación denegado permanentemente. Revisá los ajustes del dispositivo.',
            ),
          ),
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
        const SnackBar(content: Text('Ubicación insertada')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Error de ubicación: $e')),
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

  Future<void> _dictateHere() async {
    final (r, c) = _focus;
    await _dictateAt(r, c);
  }

  Future<void> _dictateRight() async {
    final (r, c) = _focus;
    await _dictateAt(r, c + 1);
  }

  void _setDictationActive(bool active) {
    if (!mounted) return;
    if (_dictationActive == active) return;
    setState(() {
      _dictationActive = active;
    });
    if (active) {
      _micCtrl.repeat(reverse: true);
    } else {
      _micCtrl.stop();
      _micCtrl.reset();
    }
  }

  Future<void> _dictateAt(int r, int cTarget) async {
    _ensureColumn(cTarget);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _busy = true;
      _busyMessage = 'Escuchando dictado…';
    });
    _setDictationActive(true);
    try {
      final ok = await SpeechService.I.init(preferredLocale: 'es_AR');
      if (!mounted) {
        _setDictationActive(false);
        return;
      }
      if (!ok) {
        _setDictationActive(false);
        messenger?.showSnackBar(
          const SnackBar(content: Text('Micrófono no disponible')),
        );
        return;
      }
      final text = await SpeechService.I.listenOnce(
        localeId: SpeechService.I.currentLocale,
        autoTimeout: const Duration(seconds: 60),
      );
      if (!mounted) {
        _setDictationActive(false);
        return;
      }
      if (text != null && text.trim().isNotEmpty) {
        _updateState(_state.withCell(r, cTarget, text.trim()));
        _setFocus(r, cTarget);
      }
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Error dictado: $e')),
      );
    } finally {
      if (mounted) {
        _setDictationActive(false);
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      } else {
        _setDictationActive(false);
      }
    }
  }

  Future<void> _openLocationForCell(int r, int c) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final txt = _state.rows[r][c];
    final link = _mapsLinkOrNull(txt);
    if (link == null) {
      messenger?.showSnackBar(const SnackBar(
        content: Text('La celda no contiene una ubicación reconocible'),
      ));
      return;
    }
    try {
      final uri = Uri.parse(link);
      final ok = await canLaunchUrl(uri);
      if (!ok) {
        messenger?.showSnackBar(const SnackBar(
          content: Text('No se pudo abrir el mapa'),
        ));
        return;
      }
      await launchUrl(uri);
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Error abriendo mapa: $e')),
      );
    }
  }

  void _copyLocationForCell(int r, int c) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final txt = _state.rows[r][c];
    final link = _mapsLinkOrNull(txt);
    if (link == null) {
      messenger?.showSnackBar(const SnackBar(
        content: Text('La celda no contiene una ubicación reconocible'),
      ));
      return;
    }
    var coords = link;
    final idx = link.indexOf('?q=');
    if (idx != -1 && idx + 3 < link.length) {
      coords = link.substring(idx + 3);
    }
    Clipboard.setData(ClipboardData(text: coords));
    messenger?.showSnackBar(
      const SnackBar(content: Text('Ubicación copiada')),
    );
  }

  Future<String?> _promptEmail() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final controller = TextEditingController(
      text: _lastEmail ?? 'marcoantoniolunavillegas@gmail.com',
    );

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Enviar por correo'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo destino',
              hintText: 'nombre@empresa.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final t = controller.text.trim();
                if (t.isEmpty) {
                  Navigator.of(ctx).pop();
                  return;
                }
                Navigator.of(ctx).pop(t);
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );

    if (result == null || result.trim().isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Envío cancelado')),
      );
      return null;
    }

    final clean = result.trim();
    _lastEmail = clean;
    return clean;
  }

  Future<void> _sendEmailWithBytes(
      Uint8List bytes, {
        String? fileName,
        String? to,
      }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final fname = fileName ?? 'Gridnote_${_timestamp()}.xlsx';
    final subject =
        'Mediciones Gridnote ${DateTime.now().toIso8601String().substring(0, 10)}';

    String? dest = to ?? _lastEmail;
    if (dest == null || dest.trim().isEmpty) {
      dest = await _promptEmail();
      if (!mounted) return;
    }

    if (dest == null || dest.trim().isEmpty) {
      return;
    }

    try {
      await MailReportService.I.sendReport(
        to: dest.trim(),
        subject: subject,
        message: 'Adjunto XLSX generado desde Gridnote.',
        fileName: fname,
        xlsxBytes: bytes,
        sheetId: widget.sheetId,
        deviceInfo: _deviceLabel(),
      );
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Correo enviado a $dest')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Error enviando correo: $e')),
      );
    }
  }

  Future<void> _backupToCloud() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _busy = true;
      _busyMessage = 'Subiendo backup a la nube…';
    });
    try {
      final data = _stateToFirestoreData();
      await FirestoreSheetStore.instance.saveSheet(
        sheetId: widget.sheetId,
        data: data,
        name: _lastSavedName ?? 'Hoja ${widget.sheetId}',
        deviceInfo: _deviceLabel(),
      );
      if (!mounted) return;
      messenger?.showSnackBar(
        const SnackBar(content: Text('Backup en la nube guardado')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Error guardando en la nube: $e')),
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
    final messenger = ScaffoldMessenger.maybeOf(context);

    final ok = await _confirmDestructive(
      title: 'Restaurar desde la nube',
      message:
      'Se va a reemplazar la planilla actual con el backup almacenado en la nube (Firestore) para este ID.\n\n'
          'Los datos actuales se perderán y sólo quedarán los del backup (podés intentar deshacer si algo no salió bien).',
      confirmLabel: 'Restaurar',
    );
    if (!ok) return;

    setState(() {
      _busy = true;
      _busyMessage = 'Restaurando desde la nube…';
    });
    try {
      final json =
      await FirestoreSheetStore.instance.loadSheet(widget.sheetId);
      if (!mounted) return;
      if (json == null) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('No hay backup en la nube para esta planilla'),
          ),
        );
        return;
      }

      final headersRaw = json['headers'];
      final rowsRaw = json['rows'];

      if (headersRaw is! List || rowsRaw is! List) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('Backup en la nube inválido')),
        );
        return;
      }

      final headers =
      headersRaw.map((e) => e.toString()).toList().cast<String>();

      final rows = <List<String>>[];
      for (final row in rowsRaw) {
        if (row is List) {
          rows.add(row.map((e) => e.toString()).toList());
        }
      }

      DateTime? savedAt;
      final rawSaved = json['savedAt'];
      if (rawSaved is String) {
        savedAt = DateTime.tryParse(rawSaved);
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
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _recomputeVisibleCols());
      _attachDebounce(_refreshAttachForVisible);
      await _loadFocusedRowAttachments();

      messenger?.showSnackBar(
        const SnackBar(content: Text('Planilla restaurada desde la nube')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Error restaurando desde la nube: $e')),
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

  /// SOLO descargar/guardar XLSX con fotos (sin abrir email).
  /// Ideal para después compartir manualmente por WhatsApp, mail, etc.
  Future<void> _downloadXlsxOnly() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _busy = true;
      _busyMessage = 'Generando XLSX…';
    });
    try {
      final bytes = await _buildXlsxBytes(withPhotos: true);
      if (!mounted) return;

      setState(() {
        _busyMessage =
        kIsWeb ? 'Descargando archivo…' : 'Guardando archivo…';
      });

      final ts = _timestamp();
      final baseName = 'Gridnote_$ts';
      final savedPath = await saveXlsx(baseName, bytes);
      _lastSavedName = '$baseName.xlsx';

      if (!mounted) return;
      final msg = kIsWeb
          ? 'Descargado: $_lastSavedName'
          : (savedPath != null ? 'Guardado: $savedPath' : 'Guardado');
      messenger?.showSnackBar(SnackBar(content: Text(msg)));

      // No tocamos los datos, sólo backup silencioso opcional.
      _saveCloudSilently();
    } catch (e) {
      if (mounted) {
        messenger?.showSnackBar(
          SnackBar(content: Text('Error exportando: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  /// Exporta el XLSX y lo descarga localmente.
  /// Alias de [_downloadXlsxOnly] para compatibilidad.
  Future<void> _exportXlsx() async {
    await _downloadXlsxOnly();
  }

  /// Envía un correo con el XLSX sin fotos (versión liviana).
  /// No se expone en la beta (no hay botón "Enviar").
  Future<void> _sendEmail() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyMessage = 'Generando XLSX y enviando correo…';
    });
    try {
      final dest = await _promptEmail();
      if (!mounted || dest == null || dest.isEmpty) return;
      // Versión liviana sin fotos
      final bytes = await _buildXlsxBytes(withPhotos: false);
      final fname = 'Gridnote_${_timestamp()}.xlsx';
      await _sendEmailWithBytes(bytes, fileName: fname, to: dest);
      _saveCloudSilently();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  // Convierte cualquier imagen a JPG (compatible con xlsio).
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

  /// Genera un XLSX con o sin fotos según [withPhotos].
  Future<Uint8List> _buildXlsxBytes({required bool withPhotos}) async {
    final book = xlsio.Workbook();
    try {
      final sh = book.worksheets[0];

      // 1) Config básica de libro/hoja
      sh.showGridlines = false;

      final headers = _state.headers;
      final rows = _state.rows;
      final rowCount = rows.length;
      final colCount = headers.length;

      // Propiedades del archivo
      try {
        final p = book.builtInProperties;
        p.author = 'Gridnote';
        p.company = 'Gridnote';
        p.title = 'Mediciones Gridnote';
        p.subject = 'Planilla de campo';
      } catch (_) {}

      // 2) Encabezados
      if (colCount > 0) {
        for (var c = 0; c < colCount; c++) {
          final cell = sh.getRangeByIndex(1, c + 1);
          cell.setText(headers[c]);
          final st = cell.cellStyle;
          st.bold = true;
          st.vAlign = xlsio.VAlignType.center;
          st.hAlign = xlsio.HAlignType.left;
        }
      } else {
        final cell = sh.getRangeByIndex(1, 1);
        cell.setText('Gridnote');
        final st = cell.cellStyle;
        st.bold = true;
        st.vAlign = xlsio.VAlignType.center;
        st.hAlign = xlsio.HAlignType.left;
      }

      // 3) Datos
      for (var r = 0; r < rowCount; r++) {
        final row = rows[r];
        for (var c = 0; c < colCount && c < row.length; c++) {
          final v = row[c];
          if (v.isEmpty) continue;

          final cell = sh.getRangeByIndex(r + 2, c + 1);
          final link = _mapsLinkOrNull(v);
          if (link != null) {
            cell.setText(v);
            sh.hyperlinks.add(cell, xlsio.HyperlinkType.url, link);
          } else {
            final raw = v.trim();
            if (raw.isEmpty) {
              cell.setText('');
              continue;
            }
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

      // Congelamos encabezado
      try {
        sh.unfreezePanes();
      } catch (_) {}
      try {
        sh.getRangeByIndex(2, 1).freezePanes();
      } catch (_) {}

      // 4) Fotos por fila (solo si withPhotos == true)
      final Map<int, List<Uint8List>> byRow = {};
      int maxPhotos = 0;
      List<double> rowHeightsPx = List<double>.filled(rowCount, 0);

      if (withPhotos && rowCount > 0) {
        for (var r = 0; r < rowCount; r++) {
          final xs = await AttachmentsServiceWeb.I
              .listFor(sheetId: widget.sheetId, row: r);

          final imgs = <Uint8List>[];
          for (final a in xs) {
            final dyn = (a as dynamic);
            final mimeAny = dyn.mime;
            final bytesAny = dyn.bytes;

            if (bytesAny is! Uint8List) continue;

            final mime = (mimeAny is String) ? mimeAny.toLowerCase() : '';

            if (!mime.startsWith('image/')) continue;

            if (mime.contains('jpeg') || mime.contains('jpg')) {
              if (bytesAny.isNotEmpty) imgs.add(bytesAny);
            } else {
              final safe = _toExcelSafeImage(bytesAny);
              if (safe.isNotEmpty) imgs.add(safe);
            }
          }

          if (imgs.isNotEmpty) {
            byRow[r] = imgs;
          }
        }

        maxPhotos = _maxPhotos(byRow, 3);
        const double kWpx = 160;
        const double kHpx = 120;
        rowHeightsPx = List<double>.filled(rowCount, 0);

        final firstPhotoCol = colCount + 1;

        if (maxPhotos > 0) {
          // Encabezados de columnas de foto
          for (var p = 0; p < maxPhotos; p++) {
            final col = firstPhotoCol + p;
            final hdrCell = sh.getRangeByIndex(1, col);
            hdrCell.setText('Foto ${p + 1}');
            final st = hdrCell.cellStyle;
            st.bold = true;
            st.hAlign = xlsio.HAlignType.center;
            st.vAlign = xlsio.VAlignType.center;
            _columnRange(sh, col).columnWidth = 22.0;
          }

          // Insertamos imágenes
          byRow.forEach((r, list) {
            final take = list.length < maxPhotos ? list.length : maxPhotos;
            for (var p = 0; p < take; p++) {
              final col = firstPhotoCol + p;
              final pic = sh.pictures.addStream(r + 2, col, list[p]);
              pic.width = kWpx.toInt();
              pic.height = kHpx.toInt();

              final needed = kHpx + 8;
              if (rowHeightsPx[r] < needed) {
                rowHeightsPx[r] = needed;
              }
            }
          });

          // Ajustamos alto de filas con fotos
          for (var r = 0; r < rowCount; r++) {
            final px = rowHeightsPx[r];
            if (px > 0) {
              final pt = (px * 0.75) + 6.0;
              _rowRange(sh, r + 2).rowHeight = pt;
            }
          }
        }
      }

      // 5) Estética de tabla
      final lastCol =
          (colCount > 0 ? colCount : 1) + (withPhotos ? maxPhotos : 0);
      final lastRow = (rowCount > 0 ? rowCount : 0) + 1;

      if (lastCol > 0 && lastRow > 0) {
        // Header
        final headerRange = sh.getRangeByIndex(1, 1, 1, lastCol);
        final headerStyle = headerRange.cellStyle;
        headerStyle.backColor = '#111827';
        headerStyle.fontColor = '#FFFFFF';
        headerStyle.bold = true;
        headerStyle.hAlign = xlsio.HAlignType.center;
        headerStyle.vAlign = xlsio.VAlignType.center;

        // Datos
        if (rowCount > 0) {
          final dataRange = sh.getRangeByIndex(2, 1, lastRow, lastCol);
          final dataStyle = dataRange.cellStyle;
          dataStyle.vAlign = xlsio.VAlignType.center;
        }

        // Zebra suave
        for (var r = 0; r < rowCount; r++) {
          if (r.isOdd) {
            final excelRow = r + 2;
            final rowRange =
            sh.getRangeByIndex(excelRow, 1, excelRow, lastCol);
            rowRange.cellStyle.backColor = '#F9FAFB';
          }
        }

        // Bordes
        try {
          final used = sh.getRangeByIndex(1, 1, lastRow, lastCol);
          used.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        } catch (_) {}
      }

      // 6) Auto-fit columnas de datos
      for (var c = 1; c <= colCount; c++) {
        try {
          sh.autoFitColumn(c);
        } catch (_) {
          try {
            _columnRange(sh, c).columnWidth = 18.0;
          } catch (_) {}
        }
      }

      // 7) Rango como tabla
      if (lastCol > 0 && lastRow > 0) {
        try {
          sh.tableCollection
              .create('Datos', sh.getRangeByIndex(1, 1, lastRow, lastCol));
        } catch (_) {}
      }

      final list = book.saveAsStream();
      return Uint8List.fromList(list);
    } finally {
      book.dispose();
    }
  }

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

  Map<String, dynamic> _stateToFirestoreData() {
    return <String, dynamic>{
      'headers': _state.headers,
      'rows': _state.rows,
      'savedAt': (_lastSavedAt ?? DateTime.now()).toIso8601String(),
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
        name: _lastSavedName ?? 'Hoja ${widget.sheetId}',
        deviceInfo: _deviceLabel(),
      );
    } catch (_) {
      // Silencioso
    }
  }

  /// Diálogo genérico para confirmar operaciones destructivas grandes.
  Future<bool> _confirmDestructive({
    required String title,
    required String message,
    String confirmLabel = 'Continuar',
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
              child: const Text('Cancelar'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final sheetId = widget.sheetId;
    final shortId = sheetId.length <= 10
        ? sheetId
        : '${sheetId.substring(0, 6)}…${sheetId.substring(sheetId.length - 4)}';

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );
    final subtitleStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.hintColor,
    );

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cs.surface,
        titleSpacing: 12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gridnote', style: titleStyle),
            Text(
              'Planilla $shortId',
              style: subtitleStyle,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: widget.isLight ? 'Modo oscuro' : 'Modo claro',
            icon:
            Icon(widget.isLight ? Icons.dark_mode : Icons.light_mode),
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const _Skeleton()
          : Stack(
        children: [
          ScrollConfiguration(
            behavior: const _PlatformScrollBehavior(),
            child: Column(
              children: [
                _buildHeader(cs),
                _buildToolbar(cs),
                _buildAttachmentsBar(cs),
                const Divider(height: 1),
                Expanded(child: _buildBody(cs)),
              ],
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _HomeDockButton(
                  onTap: _goHome,
                  anim: _rainbowCtrl,
                ),
              ),
            ),
          ),
          if (_busy)
            _BusyOverlay(
              message: _busyMessage,
              waveAnimation: _dictationActive ? _micCtrl : null,
            ),
        ],
      ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
        onPressed: _addRowAndFocus,
        label: const Text('Fila'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _goHome() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
        return;
      }
      nav.pushNamed('/sheets');
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('No se pudo ir a Inicio: $e')),
      );
    }
  }

  // Header de columnas con auto-fit y scroll horizontal sincronizado
  Widget _buildHeader(ColorScheme cs) {
    final theme = Theme.of(context);
    final baseBg = theme.brightness == Brightness.light
        ? const Color(0xFFF7F7FA)
        : const Color(0xFF111827);
    final bg = baseBg.withValues(alpha: 0.96);

    return Container(
      height: _hdrH,
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _indexHeader(cs),
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
                          _headerCell(c, cs, bg),
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
    );
  }

  Widget _indexHeader(ColorScheme cs) {
    final theme = Theme.of(context);
    return Container(
      width: _indexColW,
      height: _hdrH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
          right: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Text(
        '#',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: theme.textTheme.titleMedium?.color,
        ),
      ),
    );
  }

  Widget _headerCell(int c, ColorScheme cs, Color bg) {
    final theme = Theme.of(context);
    final titleColor = theme.textTheme.titleMedium?.color;
    final hintColor = titleColor?.withValues(alpha: 0.55);
    final w = _colW[c];
    final ctl = _hdrController(c);

    return SizedBox(
      width: w,
      height: _hdrH,
      child: Stack(
        children: [
          Positioned.fill(
            right: 10,
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: bg,
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor),
                  right: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: TextField(
                controller: ctl,
                maxLines: 1,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Col ${c + 1}',
                  hintStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: hintColor,
                  ),
                ),
                style: const TextStyle(fontWeight: FontWeight.w700),
                onSubmitted: (_) => _setFocus(0, c),
              ),
            ),
          ),
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
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _recomputeVisibleCols());
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

  Widget _buildToolbar(ColorScheme cs) {
    final theme = Theme.of(context);

    final toolbarChild = ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      children: [
        // Grupo: adjuntos / GPS / dictado
        _toolbarButton(
          cs,
          icon: Icons.attach_file,
          label: 'Adjuntar',
          onTap: _pickAttachmentsForFocusedRow,
        ),
        _toolbarButton(
          cs,
          icon: Icons.my_location,
          label: 'GPS aquí',
          onTap: _busy ? null : _insertGpsHere,
        ),
        _toolbarButton(
          cs,
          icon: Icons.place,
          label: 'GPS der.',
          onTap: _busy ? null : _insertGpsRight,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SpeechMicButton(
            port: SpeechService.I,
            enabled: !_busy,
            activeRowIndex: _rowCount == 0 ? null : _focus.$1,
            rowLabelBuilder: (row) => 'Dictar en fila ${row + 1}',
            onResult: (text) {
              if (_rowCount == 0 || _colCount == 0) return;
              final (r, c) = _focus;
              final clean = text.trim();
              if (clean.isEmpty) return;
              _ensureColumn(c);
              if (_isEditing &&
                  r == _focus.$1 &&
                  c == _focus.$2) {
                _cellEC.text = clean;
                _cellEC.selection = TextSelection.collapsed(
                    offset: _cellEC.text.length);
              }
              _updateState(_state.withCell(r, c, clean));
            },
          ),
        ),
        _toolbarDividerWidget(theme),

        // Grupo: filas / columnas
        _toolbarButton(
          cs,
          icon: Icons.add,
          label: 'Fila',
          onTap: _addRowAndFocus,
        ),
        _toolbarButton(
          cs,
          icon: Icons.view_week_outlined,
          label: 'Columna',
          onTap: _addColumnRightOfFocus,
        ),
        _toolbarButton(
          cs,
          icon: Icons.delete_outline,
          label: 'Borrar fila',
          onTap: _deleteFocusedRow,
        ),
        _toolbarDividerWidget(theme),

        // Grupo: undo/redo
        _toolbarButton(
          cs,
          icon: Icons.undo,
          label: 'Deshacer',
          onTap: _undo,
        ),
        _toolbarButton(
          cs,
          icon: Icons.redo,
          label: 'Rehacer',
          onTap: _redo,
        ),
        _toolbarDividerWidget(theme),

        // Grupo: backups locales / importar
        _toolbarButton(
          cs,
          icon: Icons.download,
          label: 'Backup',
          onTap: () => LocalStore.downloadBackup(_state),
        ),
        _toolbarButton(
          cs,
          icon: Icons.upload_file,
          label: 'Importar',
          onTap: _importBackup,
        ),
        _toolbarDividerWidget(theme),

        // Grupo: nube
        _toolbarButton(
          cs,
          icon: Icons.cloud_upload,
          label: 'Nube',
          onTap: _busy ? null : _backupToCloud,
        ),
        _toolbarButton(
          cs,
          icon: Icons.cloud_download,
          label: 'Traer nube',
          onTap: _busy ? null : _restoreFromCloud,
        ),
        _toolbarDividerWidget(theme),

        // Grupo: limpieza / exportar (beta: solo descarga local)
        _toolbarButton(
          cs,
          icon: Icons.cleaning_services,
          label: 'Limpiar',
          onTap: _clearAll,
        ),
        _toolbarButton(
          cs,
          icon: Icons.file_download_outlined,
          label: 'Descargar XLSX',
          onTap: _busy ? null : _downloadXlsxOnly,
        ),
        _toolbarDividerWidget(theme),

        // Ayuda
        _toolbarButton(
          cs,
          icon: Icons.help_outline,
          label: 'Atajos',
          onTap: _showShortcutsHelp,
        ),
      ],
    );

    return AnimatedBuilder(
      animation: _rainbowCtrl,
      builder: (context, child) {
        final dividerColor =
        Theme.of(context).dividerColor.withValues(alpha: 0.7);
        return Container(
          height: 64,
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: const [
                  Colors.red,
                  Colors.orange,
                  Colors.yellow,
                  Colors.green,
                  Colors.cyan,
                  Colors.blue,
                  Colors.indigo,
                  Colors.purple,
                  Colors.red,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                transform: GradientRotation(
                    2 * math.pi * _rainbowCtrl.value),
              ),
              border: Border.all(color: dividerColor, width: 0.7),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: child!,
            ),
          ),
        );
      },
      child: toolbarChild,
    );
  }

  Widget _toolbarDividerWidget(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      color:
      Colors.white.withValues(alpha: isDark ? 0.28 : 0.35),
    );
  }

  Widget _toolbarButton(
      ColorScheme cs, {
        required IconData icon,
        required String label,
        required VoidCallback? onTap,
      }) {
    final enabled = onTap != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final fg =
    enabled ? Colors.white : Colors.white.withValues(alpha: 0.7);
    final bgBase = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.24);
    final bg = enabled ? bgBase : bgBase.withValues(alpha: 0.5);
    final borderColor = Colors.white.withValues(alpha: 0.32);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor, width: 0.7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showShortcutsHelp() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final small = theme.textTheme.bodySmall;

        return AlertDialog(
          title: const Text('Atajos de Gridnote'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: DefaultTextStyle(
                style: theme.textTheme.bodyMedium ??
                    const TextStyle(fontSize: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sugerencia: en macOS usá Cmd donde diga Ctrl.',
                      style: small?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _shortcutGroup(
                      'Navegación básica',
                      const [
                        'Flechas: mover el foco entre celdas y empezar a editar.',
                        'Home / End: ir al inicio / final de la fila.',
                        'PageUp / PageDown: saltar varias filas hacia arriba / abajo.',
                      ],
                    ),
                    _shortcutGroup(
                      'Edición en la grilla',
                      const [
                        'Enter: editar la celda seleccionada.',
                        'Tab: mover a la celda de la derecha y editar.',
                        'Shift+Tab: mover a la celda de la izquierda y editar.',
                        'Backspace: limpiar y empezar a escribir en la celda.',
                        'Delete: borrar el contenido de la celda.',
                        'Escribir cualquier letra o número: entra en modo edición directamente.',
                      ],
                    ),
                    _shortcutGroup(
                      'Copiar / pegar',
                      const [
                        'Ctrl+C: copiar texto de la celda.',
                        'Ctrl+V: pegar texto en la celda seleccionada.',
                      ],
                    ),
                    _shortcutGroup(
                      'Filas',
                      const [
                        'Ctrl+N: agregar nueva fila y enfocarla.',
                        'Ctrl+D: duplicar la fila actual.',
                        'Ctrl+L: limpiar toda la fila actual.',
                      ],
                    ),
                    _shortcutGroup(
                      'Columnas',
                      const [
                        'Ctrl+Shift+N: agregar una columna a la derecha.',
                        'Doble clic en el borde del encabezado: auto-ajusta el ancho de esa columna.',
                        'Drag en el borde del encabezado: cambiar ancho de la columna.',
                      ],
                    ),
                    _shortcutGroup(
                      'Backups y nube',
                      const [
                        'Ctrl+B: descargar backup JSON local.',
                        'Ctrl+Shift+B: backup en la nube (Firestore).',
                        'Ctrl+O: importar backup JSON.',
                      ],
                    ),
                    _shortcutGroup(
                      'Exportar y guardar',
                      const [
                        'Ctrl+E: exportar a XLSX (descarga local).',
                        'Ctrl+S: exportar a XLSX (atajo extra, descarga local).',
                      ],
                    ),
                    _shortcutGroup(
                      'Extras',
                      const [
                        'Click largo en una celda: menú rápido (GPS, dictado, mapa, duplicar fila, etc.).',
                        'Click en el número de fila: selecciona fila y muestra cantidad de adjuntos.',
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _shortcutGroup(String title, List<String> lines) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(line)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsBar(ColorScheme cs) {
    final theme = Theme.of(context);
    final baseBg = theme.brightness == Brightness.light
        ? const Color(0xFFF9FAFB)
        : const Color(0xFF0D1320);
    final bg = baseBg.withValues(alpha: 0.96);
    final r = _focus.$1;
    final cnt = _attOfFocused.length;

    return Container(
      height: _attBarH,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.8),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              SizedBox(
                width: _indexColW,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Fila',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.hintColor,
                      ),
                    ),
                    Text(
                      '${r + 1}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _pickAttachmentsForFocusedRow,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child:
                        Icon(Icons.add_photo_alternate, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 10),
              Expanded(
                child: _attLoading
                    ? const Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2),
                  ),
                )
                    : (_attOfFocused.isEmpty
                    ? Row(
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 18,
                      color: theme.hintColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sin fotos en la fila ${r + 1}. Tocá el ícono para adjuntar.',
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed:
                      _pickAttachmentsForFocusedRow,
                      icon: const Icon(
                          Icons.attach_file,
                          size: 18),
                      label: const Text('Adjuntar'),
                    ),
                  ],
                )
                    : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0;
                      i < _attOfFocused.length;
                      i++)
                        _thumb(_attOfFocused[i]),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed:
                        _pickAttachmentsForFocusedRow,
                        icon: const Icon(Icons.add),
                        label:
                        const Text('Agregar'),
                        style: OutlinedButton.styleFrom(
                          minimumSize:
                          const Size(96, 36),
                        ),
                      ),
                    ],
                  ),
                )),
              ),
              const SizedBox(width: 6),
              _buildStatusPill(cs),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.attach_file,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$cnt',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(ColorScheme cs) {
    String text;
    IconData icon;
    if (_saving) {
      text = 'Guardando';
      icon = Icons.sync;
    } else if (_lastSavedAt != null) {
      text = 'Guardado ${_formatTimeShort(_lastSavedAt!)}';
      icon = Icons.check_circle;
    } else {
      text = 'Aún sin guardar';
      icon = Icons.info_outline;
    }

    final theme = Theme.of(context);
    final bg =
    cs.surfaceContainerHighest.withValues(alpha: 0.9);
    final border =
    cs.outline.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_saving)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 1.6),
            )
          else
            Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb(_AttItem a) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: InkWell(
        onTap: () => _showImageDialog(a.bytes, a.name),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            border:
            Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).cardColor,
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.memory(
            a.bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: 144,
            cacheHeight: 144,
            filterQuality: FilterQuality.low,
          ),
        ),
      ),
    );
  }

  Future<void> _showImageDialog(Uint8List bytes, String name) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              alignment: Alignment.centerLeft,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 420,
              height: 320,
              child: InteractiveViewer(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _cell(int r, int c, ColorScheme cs, Color rowBg) {
    final theme = Theme.of(context);
    final isFocused = _focus.$1 == r && _focus.$2 == c;

    String value = '';
    if (r >= 0 && r < _state.rows.length) {
      final row = _state.rows[r];
      if (c >= 0 && c < row.length) value = row[c];
    }

    final isLocation = _mapsLinkOrNull(value) != null;
    final borderColor = theme.dividerColor;
    final focusColor = cs.primary;

    return SizedBox(
      width: _colW[c],
      height: _rowH,
      child: Stack(
        children: [
          // Fondo y texto
          Positioned.fill(
            child: Material(
              color: rowBg,
              child: InkWell(
                onTap: () {
                  _setFocus(r, c);
                  _startEditing(r, c);
                },
                onLongPress: () => _showCellMenu(r, c),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: borderColor),
                      right: BorderSide(color: borderColor),
                    ),
                  ),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isLocation
                          ? cs.primary
                          : theme.textTheme.bodyMedium?.color,
                      decoration: isLocation
                          ? TextDecoration.underline
                          : TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Borde de foco (cuando no está editando)
          if (isFocused && !_isEditing)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: focusColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),

          // Campo de texto cuando está editando la celda
          if (isFocused && _isEditing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: focusColor,
                    width: 2,
                  ),
                  color: theme.colorScheme.surface,
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Center(
                  child: TextField(
                    controller: _cellEC,
                    focusNode: _cellFN,
                    autofocus: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    ),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _commitAndMoveDown(r, c),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showCellMenu(int r, int c) async {
    _setFocus(r, c);
    final isLocation = _mapsLinkOrNull(_state.rows[r][c]) != null;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.my_location),
                title: const Text('Insertar GPS aquí'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _insertGpsHere();
                },
              ),
              ListTile(
                leading: const Icon(Icons.place),
                title: const Text('Insertar GPS a la derecha'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _insertGpsRight();
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('Dictar aquí'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _dictateHere();
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic_none),
                title: const Text('Dictar a la derecha'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _dictateRight();
                },
              ),
              if (isLocation) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.map),
                  title: const Text('Abrir en Mapas'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openLocationForCell(r, c);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Copiar ubicación'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _copyLocationForCell(r, c);
                  },
                ),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.copy_all),
                title: const Text('Duplicar fila'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _duplicateRow(r);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services),
                title: const Text('Limpiar fila'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _clearRow(r);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Borrar fila'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _deleteFocusedRow();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Body con estado vacío, scroll sync y edición cómoda
  Widget _buildBody(ColorScheme cs) {
    final theme = Theme.of(context);
    final bgOdd = theme.brightness == Brightness.light
        ? const Color(0xFFFDFDFE)
        : const Color(0xFF0F1522);

    return Row(
      children: [
        // Columna de índices
        SizedBox(
          width: _indexColW,
          child: ListView.builder(
            controller: _vIdx,
            keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
            itemExtent: _rowH,
            itemCount: _rowCount,
            itemBuilder: (context, r) {
              final selected = r == _focus.$1;
              final rowBg = r.isOdd ? bgOdd : Colors.transparent;
              final cnt = _attachCounts[r] ?? 0;

              return InkWell(
                onTap: () {
                  _setFocus(r, _focus.$2);
                  _gridFN.requestFocus();
                },
                child: Container(
                  color: rowBg,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: theme.dividerColor,
                            ),
                            right: BorderSide(
                              color: theme.dividerColor,
                            ),
                          ),
                        ),
                        child: Text(
                          '${r + 1}',
                          style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (selected)
                        IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: cs.primary, width: 2),
                            ),
                          ),
                        ),
                      if (cnt > 0)
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius:
                              BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.attach_file,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '$cnt',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Cuerpo de la grilla
        Expanded(
          child: LayoutBuilder(
            builder: (_, cons) {
              final vw = cons.maxWidth > 0
                  ? cons.maxWidth
                  : MediaQuery.of(context).size.width;
              _scheduleViewportOps(vw);

              final contentWidth =
              _prefix.isEmpty ? vw : math.max(_prefix.last, vw);

              // Estado vacío
              if (_rowCount == 0) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.table_view,
                        size: 40,
                        color: theme.hintColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sin filas todavía',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Agregá una fila nueva para empezar a cargar datos.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _addRowAndFocus,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar fila'),
                      ),
                    ],
                  ),
                );
              }

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
                      keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                      itemExtent: _rowH,
                      itemCount: _rowCount,
                      itemBuilder: (context, r) {
                        final rowBg =
                        r.isOdd ? bgOdd : Colors.transparent;
                        return Container(
                          color: Colors.transparent,
                          child: Row(
                            children: [
                              SizedBox(width: _sumRange(0, _firstCol)),
                              for (int c = _firstCol; c <= _lastCol; c++)
                                _cell(r, c, cs, rowBg),
                              SizedBox(
                                width:
                                _sumRange(_lastCol + 1, _colCount),
                              ),
                            ],
                          ),
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
    );
  }

  // Helper para mover foco y entrar en modo edición
  void _moveFocusAndEdit(int r, int c) {
    if (_rowCount == 0 || _colCount == 0) return;
    final safeR = _clampi(r, 0, math.max(0, _rowCount - 1));
    final safeC = _clampi(c, 0, math.max(0, _colCount - 1));
    _setFocus(safeR, safeC);
    _startEditing(safeR, safeC);
  }

  // Handler de teclado refinado
  KeyEventResult _handleGridKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isEditing) return KeyEventResult.ignored;
    if (_rowCount == 0 || _colCount == 0) {
      return KeyEventResult.ignored;
    }

    final (r, c) = _focus;

    final keys =
        HardwareKeyboard.instance.logicalKeysPressed;
    final hasCtrl =
        keys.contains(LogicalKeyboardKey.controlLeft) ||
            keys.contains(LogicalKeyboardKey.controlRight) ||
            keys.contains(LogicalKeyboardKey.metaLeft) ||
            keys.contains(LogicalKeyboardKey.metaRight);
    final hasShift =
        keys.contains(LogicalKeyboardKey.shiftLeft) ||
            keys.contains(LogicalKeyboardKey.shiftRight);

    // Flechas
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveFocusAndEdit(r + 1, c);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveFocusAndEdit(r - 1, c);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _moveFocusAndEdit(r, c + 1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _moveFocusAndEdit(r, c - 1);
      return KeyEventResult.handled;
    }

    // Home/End/PageUp/PageDown
    if (e.logicalKey == LogicalKeyboardKey.home) {
      _moveFocusAndEdit(r, 0);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.end) {
      final lastCol = math.max(0, _colCount - 1);
      _moveFocusAndEdit(r, lastCol);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.pageUp) {
      final jump = math.max(1, _visibleRowCount() - 1);
      final target =
      _clampi(r - jump, 0, math.max(0, _rowCount - 1));
      _moveFocusAndEdit(target, c);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.pageDown) {
      final jump = math.max(1, _visibleRowCount() - 1);
      final target =
      _clampi(r + jump, 0, math.max(0, _rowCount - 1));
      _moveFocusAndEdit(target, c);
      return KeyEventResult.handled;
    }

    // Enter: entrar a edición en la celda actual (sin Ctrl).
    if (e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (!hasCtrl) {
        _startEditing(r, c);
        return KeyEventResult.handled;
      }
    }

    // Tab / Shift+Tab
    if (e.logicalKey == LogicalKeyboardKey.tab) {
      if (hasShift) {
        _moveFocusAndEdit(r, c - 1);
      } else {
        _moveFocusAndEdit(r, c + 1);
      }
      return KeyEventResult.handled;
    }

    // Copiar / Pegar
    if (hasCtrl && e.logicalKey == LogicalKeyboardKey.keyC) {
      Clipboard.setData(
          ClipboardData(text: _state.rows[r][c]));
      return KeyEventResult.handled;
    }
    if (hasCtrl && e.logicalKey == LogicalKeyboardKey.keyV) {
      Clipboard.getData('text/plain').then((data) {
        if (!mounted) return;
        final t = data?.text;
        if (t == null) return;
        _updateState(_state.withCell(r, c, t));
      });
      return KeyEventResult.handled;
    }

    // Caracter de texto
    final String? ch = e.character;
    if (!hasCtrl &&
        ch != null &&
        ch.isNotEmpty &&
        ch.runes.length == 1) {
      _beginCharEdit(ch);
      return KeyEventResult.handled;
    }

    // Delete / Backspace
    if (e.logicalKey == LogicalKeyboardKey.delete) {
      _updateState(_state.withCell(r, c, ''));
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _startEditing(r, c);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _cellEC.text = '';
      });
      return KeyEventResult.handled;
    }

    // Undo / Redo
    if (hasCtrl && e.logicalKey == LogicalKeyboardKey.keyZ) {
      _undo();
      return KeyEventResult.handled;
    }
    if (hasCtrl && e.logicalKey == LogicalKeyboardKey.keyY) {
      _redo();
      return KeyEventResult.handled;
    }

    // Fila: duplicar / limpiar
    if (hasCtrl && e.logicalKey == LogicalKeyboardKey.keyD) {
      _duplicateRow(r);
      return KeyEventResult.handled;
    }
    if (hasCtrl && e.logicalKey == LogicalKeyboardKey.keyL) {
      _clearRow(r);
      return KeyEventResult.handled;
    }

    // Backup nube / JSON / Importar
    if (hasCtrl && hasShift && e.logicalKey == LogicalKeyboardKey.keyB) {
      _backupToCloud();
      return KeyEventResult.handled;
    }
    if (hasCtrl && !hasShift && e.logicalKey == LogicalKeyboardKey.keyB) {
      LocalStore.downloadBackup(_state);
      return KeyEventResult.handled;
    }
    if (hasCtrl && e.logicalKey == LogicalKeyboardKey.keyO) {
      _importBackup();
      return KeyEventResult.handled;
    }

    // Nueva fila / columna
    if (hasCtrl && !hasShift && e.logicalKey == LogicalKeyboardKey.keyN) {
      _addRowAndFocus();
      return KeyEventResult.handled;
    }
    if (hasCtrl && hasShift && e.logicalKey == LogicalKeyboardKey.keyN) {
      _addColumnRightOfFocus();
      return KeyEventResult.handled;
    }

    // Exportar / Guardar (beta: sólo descarga XLSX local)
    if (hasCtrl && e.logicalKey == LogicalKeyboardKey.keyE) {
      _downloadXlsxOnly();
      return KeyEventResult.handled;
    }
    if (hasCtrl && e.logicalKey == LogicalKeyboardKey.keyS) {
      _downloadXlsxOnly();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _pickAttachmentsForFocusedRow() async {
    if (_rowCount == 0) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(content: Text('No hay filas')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final r = _focus.$1;
    try {
      final groupExt = XTypeGroup(
        label: 'Imágenes',
        extensions: const ['png', 'jpg', 'jpeg', 'webp', 'heic'],
      );
      final groupMime = XTypeGroup(
        label: 'Imágenes',
        mimeTypes: const ['image/*'],
      );
      final files =
      await openFiles(acceptedTypeGroups: [groupExt, groupMime]);
      if (files.isEmpty) return;

      // Desde el primer uso real de adjuntos, habilitamos el refresco de contadores.
      _attachmentsEverUsed = true;

      for (final f in files) {
        try {
          await _attachmentsAddBytes(r: r, file: f);
        } catch (_) {}
      }
      if (!mounted) return;
      await _refreshAttachRow(r);
      await _loadFocusedRowAttachments();
      messenger?.showSnackBar(
        SnackBar(content: Text('Adjuntos agregados: ${files.length}')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('No se pudo abrir el selector: $e')),
      );
    }
  }

  Future<void> _attachmentsAddBytes({
    required int r,
    required XFile file,
  }) async {
    final raw = await file.readAsBytes();
    final name = file.name;
    final mime = _guessMime(name);

    Uint8List bytes = raw;
    final fc = _fc;
    if (fc != null) {
      try {
        final batch = await fc.autoClean(
          images: [
            FotoInput.fromBase64(
                name: name, base64: base64Encode(raw)),
          ],
          quality: 85,
          maxWidth: 1600,
          format: mime == 'image/webp' ? 'webp' : 'jpeg',
          dedup: false,
          hashThreshold: 6,
          blurMin: 0,
        );
        if (batch.kept.isNotEmpty) {
          bytes = batch.kept.first.bytes;
        }
      } catch (_) {
        // FotoClean opcional
      }
    }

    final svc = AttachmentsServiceWeb.I;
    try {
      await (svc as dynamic).addBytes(
        sheetId: widget.sheetId,
        row: r,
        name: name,
        mime: mime,
        bytes: bytes,
      );
      return;
    } catch (_) {}
    try {
      await (svc as dynamic).add(
        sheetId: widget.sheetId,
        row: r,
        name: name,
        mime: mime,
        bytes: bytes,
      );
    } catch (_) {}
  }

  String _guessMime(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.heic')) return 'image/heic';
    return 'application/octet-stream';
  }

  Future<void> _importBackup() async {
    final ok = await _confirmDestructive(
      title: 'Importar backup JSON',
      message:
      'Se va a importar un backup JSON (archivo .json) y se reemplazará la planilla actual con los datos del backup.\n\n'
          'Los datos actuales se perderán y sólo quedarán los del archivo importado (podés deshacer si algo no salió bien).',
      confirmLabel: 'Importar backup',
    );
    if (!ok) return;

    final ts = await LocalStore.importBackup();
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
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _recomputeVisibleCols());
    _attachDebounce(_refreshAttachForVisible);
    await _loadFocusedRowAttachments();
  }

  Future<void> _loadFocusedRowAttachments() async {
    setState(() {
      _attLoading = true;
    });
    try {
      final r =
      _clampi(_focus.$1, 0, math.max(0, _rowCount - 1));
      final xs = await AttachmentsServiceWeb.I
          .listFor(sheetId: widget.sheetId, row: r);
      final list = <_AttItem>[];
      for (final a in xs) {
        final name = (a as dynamic).name as String;
        final mime = (a as dynamic).mime as String;
        final bytes = (a as dynamic).bytes as Uint8List;
        list.add(_AttItem(name: name, mime: mime, bytes: bytes));
      }
      if (!mounted) return;
      setState(() {
        _attOfFocused = list;
        if (list.isNotEmpty) {
          _attachmentsEverUsed = true;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _attOfFocused = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _attLoading = false;
        });
      }
    }
  }
}

/// Skeleton mientras carga la planilla.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: cs.surfaceContainerHighest,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 20,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: List.generate(4, (index) {
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
                        height: 20,
                        decoration: BoxDecoration(
                          color:
                          cs.surfaceContainerLow.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) {
              return Container(
                height: 44,
                margin: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Representa un ítem de adjunto con nombre, mime y bytes.
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

/// Overlay que se muestra cuando la app está ocupada.
class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay({this.message, this.waveAnimation});

  final String? message;
  final Animation<double>? waveAnimation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = message ?? 'Procesando…';
    return AbsorbPointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.24),
        child: Center(
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        text,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                if (waveAnimation != null) ...[
                  const SizedBox(height: 10),
                  _VoiceWave(animation: waveAnimation!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Onda naranja para indicar captura de voz.
class _VoiceWave extends StatelessWidget {
  const _VoiceWave({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final bars = <double>[
            0.3 + 0.7 * animation.value,
            0.5 + 0.5 * animation.value,
            0.9 * animation.value,
            0.5 + 0.5 * animation.value,
            0.3 + 0.7 * animation.value,
          ];
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: bars.map((h) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 4,
                  height: 6 + 18 * h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.orange,
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

/// Comportamiento de scroll adaptado a la plataforma.
class _PlatformScrollBehavior extends ScrollBehavior {
  const _PlatformScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final platform = Theme.of(context).platform;
    switch (platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
      default:
        return const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
    }
  }

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

/// Botón para regresar a la pantalla de inicio con animación arcoíris.
class _HomeDockButton extends StatelessWidget {
  const _HomeDockButton({required this.onTap, required this.anim});
  final VoidCallback onTap;
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context)
        .colorScheme
        .outline
        .withValues(alpha: 0.35);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: const [
                    Colors.red,
                    Colors.orange,
                    Colors.yellow,
                    Colors.green,
                    Colors.cyan,
                    Colors.blue,
                    Colors.indigo,
                    Colors.purple,
                    Colors.red,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  transform:
                  GradientRotation(2 * math.pi * anim.value),
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.apps,
                  size: 20, color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}
