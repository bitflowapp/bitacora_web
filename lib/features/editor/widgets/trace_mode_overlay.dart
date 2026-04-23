// lib/features/editor/widgets/trace_mode_overlay.dart
//
// Modo trazo inteligente sobre la grilla: el usuario puede dibujar a mano
// alzada un trazo que selecciona celdas tocadas o encerradas, y luego
// resolver una operacion (Sumar, Promediar, Contar) e insertar el resultado.
//
// Diseñado como widget standalone (no es part-of) para mantener el archivo
// principal del editor sin cambios estructurales grandes y para poder testear
// la geometria del trazo de forma aislada.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// Operaciones que el modo trazo puede realizar sobre la seleccion numerica.
enum TraceOperation { sum, average, count }

extension TraceOperationLabel on TraceOperation {
  String get label {
    switch (this) {
      case TraceOperation.sum:
        return 'Sumar';
      case TraceOperation.average:
        return 'Promediar';
      case TraceOperation.count:
        return 'Contar';
    }
  }

  IconData get icon {
    switch (this) {
      case TraceOperation.sum:
        return Icons.add_rounded;
      case TraceOperation.average:
        return Icons.percent_rounded;
      case TraceOperation.count:
        return Icons.format_list_numbered_rounded;
    }
  }
}

/// Geometria minima que necesita el overlay para mapear trazo → celdas.
///
/// Las posiciones se entregan en coordenadas LOCALES del overlay (que
/// idealmente cubre exactamente la zona de la grilla incluyendo header e
/// indice). El overlay calcula los rects sumando los offsets de scroll en
/// cada cuadro.
class TraceGridGeometry {
  const TraceGridGeometry({
    required this.rowCount,
    required this.dataColumnCount,
    required this.indexWidth,
    required this.headerHeight,
    required this.rowHeight,
    required this.dataColumnWidth,
    required this.lastColumnWidth,
    required this.horizontalScrollOffset,
    required this.verticalScrollOffset,
  });

  final int rowCount;

  /// Cantidad total de columnas EDITABLES por trazo (excluye la columna final
  /// reservada a fotos). El overlay solo selecciona en este rango.
  final int dataColumnCount;

  final double indexWidth;
  final double headerHeight;
  final double rowHeight;

  /// Ancho de cada columna de datos.
  final double dataColumnWidth;

  /// Ancho reservado para la columna final (fotos). Se ignora para seleccion
  /// pero impacta en el layout horizontal.
  final double lastColumnWidth;

  final double horizontalScrollOffset;
  final double verticalScrollOffset;

  Rect cellRect(int row, int col) {
    final left = indexWidth + col * dataColumnWidth - horizontalScrollOffset;
    final top =
        headerHeight + row * rowHeight - verticalScrollOffset;
    return Rect.fromLTWH(left, top, dataColumnWidth, rowHeight);
  }

  /// Devuelve la celda (row, col) bajo un punto local. null si esta sobre el
  /// header, sobre el indice o fuera del rango editable.
  ({int row, int col})? cellAtLocal(Offset local) {
    if (local.dy < headerHeight) return null;
    if (local.dx < indexWidth) return null;
    final relX = local.dx - indexWidth + horizontalScrollOffset;
    final relY = local.dy - headerHeight + verticalScrollOffset;
    if (rowHeight <= 0 || dataColumnWidth <= 0) return null;
    final col = relX ~/ dataColumnWidth;
    final row = relY ~/ rowHeight;
    if (row < 0 || row >= rowCount) return null;
    if (col < 0 || col >= dataColumnCount) return null;
    return (row: row, col: col);
  }
}

/// Resultado calculado a partir de la seleccion para previa e insercion.
class TraceComputation {
  const TraceComputation({
    required this.numericCount,
    required this.totalCount,
    required this.sum,
    required this.average,
  });

  final int numericCount;
  final int totalCount;
  final double sum;
  final double average;

  bool get hasNumeric => numericCount > 0;

  String formattedFor(TraceOperation op) {
    switch (op) {
      case TraceOperation.sum:
        return _fmt(sum);
      case TraceOperation.average:
        return _fmt(average);
      case TraceOperation.count:
        return numericCount.toString();
    }
  }

  String _fmt(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    final isInt = value == value.roundToDouble() && value.abs() < 1e12;
    if (isInt) return value.toStringAsFixed(0);
    final s = value.toStringAsFixed(6);
    var trimmed = s;
    while (trimmed.endsWith('0')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.endsWith('.')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed.isEmpty ? '0' : trimmed;
  }
}

/// Tema visual del overlay; toma del palette del editor para mantener la
/// estetica y funcionar en claro/oscuro sin tocar los tokens existentes.
class TraceOverlayTheme {
  const TraceOverlayTheme({
    required this.accent,
    required this.background,
    required this.surface,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.divider,
    required this.invalid,
    required this.isLight,
  });

  final Color accent;
  final Color background;
  final Color surface;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color divider;
  final Color invalid;
  final bool isLight;
}

/// Callback para leer texto crudo de una celda (antes de cualquier formato).
typedef TraceCellTextProvider = String Function(int row, int col);

/// Callback de insercion del resultado en una celda destino.
typedef TraceCellInsert = void Function(
  int row,
  int col,
  String value,
);

/// Overlay principal del modo trazo. Vivela arriba de la grilla.
class TraceModeOverlay extends StatefulWidget {
  const TraceModeOverlay({
    super.key,
    required this.active,
    required this.geometryBuilder,
    required this.theme,
    required this.cellText,
    required this.onInsertResult,
    required this.onClose,
    this.scrollListenables = const <Listenable>[],
    this.preferredTargetRow,
    this.preferredTargetCol,
  });

  final bool active;
  final TraceGridGeometry Function() geometryBuilder;
  final TraceOverlayTheme theme;
  final TraceCellTextProvider cellText;
  final TraceCellInsert onInsertResult;
  final VoidCallback onClose;

  /// Listenables que disparan rebuild del overlay (tipicamente los
  /// ScrollControllers horizontal/vertical de la grilla).
  final List<Listenable> scrollListenables;

  /// Celda activa antes de entrar al modo trazo. Se sugiere como destino del
  /// "Insertar resultado". null si no habia seleccion.
  final int? preferredTargetRow;
  final int? preferredTargetCol;

  @override
  State<TraceModeOverlay> createState() => _TraceModeOverlayState();
}

class _TraceModeOverlayState extends State<TraceModeOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _entryAnim = CurvedAnimation(
    parent: _entryCtrl,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  late final AnimationController _resultFlyCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  // Trazo en curso (ancla a coordenadas LOGICAS del contenido, no visibles).
  // Asi funciona aunque el usuario haga scroll mientras dibuja.
  final List<Offset> _logicalPath = <Offset>[];
  bool _drawing = false;
  Set<({int row, int col})> _selected = <({int row, int col})>{};
  TraceOperation _operation = TraceOperation.sum;
  TraceComputation _computation = const TraceComputation(
    numericCount: 0,
    totalCount: 0,
    sum: 0,
    average: 0,
  );

  // Insertion fly animation
  Offset? _flyStart;
  Offset? _flyEnd;
  String? _flyValue;

  Listenable? _scroll;
  void _onScrollTick() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _entryCtrl.value = 1;
    }
    _attachScroll();
  }

  void _attachScroll() {
    _detachScroll();
    if (widget.scrollListenables.isEmpty) return;
    _scroll = Listenable.merge(widget.scrollListenables);
    _scroll!.addListener(_onScrollTick);
  }

  void _detachScroll() {
    _scroll?.removeListener(_onScrollTick);
    _scroll = null;
  }

  @override
  void didUpdateWidget(TraceModeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _entryCtrl.forward(from: 0);
      _logicalPath.clear();
      _selected = <({int row, int col})>{};
      _computation = const TraceComputation(
        numericCount: 0,
        totalCount: 0,
        sum: 0,
        average: 0,
      );
      _flyValue = null;
    } else if (!widget.active && oldWidget.active) {
      _entryCtrl.reverse();
    }
    if (widget.scrollListenables != oldWidget.scrollListenables) {
      _attachScroll();
    }
  }

  @override
  void dispose() {
    _detachScroll();
    _entryCtrl.dispose();
    _resultFlyCtrl.dispose();
    super.dispose();
  }

  Offset _toLogical(Offset local) {
    final geo = widget.geometryBuilder();
    return Offset(
      local.dx + geo.horizontalScrollOffset,
      local.dy + geo.verticalScrollOffset,
    );
  }

  Offset _toLocal(Offset logical) {
    final geo = widget.geometryBuilder();
    return Offset(
      logical.dx - geo.horizontalScrollOffset,
      logical.dy - geo.verticalScrollOffset,
    );
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.active) return;
    _logicalPath
      ..clear()
      ..add(_toLogical(details.localPosition));
    _drawing = true;
    _selected = <({int row, int col})>{};
    final c = widget.geometryBuilder().cellAtLocal(details.localPosition);
    if (c != null) _selected = {c};
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.active || !_drawing) return;
    _logicalPath.add(_toLogical(details.localPosition));
    final c = widget.geometryBuilder().cellAtLocal(details.localPosition);
    if (c != null && _selected.add(c)) {
      _maybeHaptic();
    }
    setState(() {});
  }

  DateTime _lastHapticAt = DateTime.fromMillisecondsSinceEpoch(0);
  void _maybeHaptic() {
    final now = DateTime.now();
    if (now.difference(_lastHapticAt) < const Duration(milliseconds: 36)) {
      return;
    }
    _lastHapticAt = now;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  void _onPanEnd(DragEndDetails _) {
    if (!_drawing) return;
    _drawing = false;
    // Si el trazo es lo bastante cerrado (lazo), incluir todas las celdas
    // cuyo centro caiga dentro del area cerrada.
    if (_logicalPath.length >= 12) {
      final closed = _looksClosed(_logicalPath);
      if (closed) {
        final extra = _cellsInsideLasso(_logicalPath);
        _selected = {..._selected, ...extra};
      }
    }
    _computation = _compute(_selected);
    setState(() {});
  }

  bool _looksClosed(List<Offset> path) {
    if (path.length < 8) return false;
    final start = path.first;
    final end = path.last;
    final delta = (start - end).distance;
    // Considerar cerrado si la distancia entre primer y ultimo punto es
    // pequenia comparada con el bounding box.
    final box = _bounding(path);
    final diag = math.sqrt(
      box.width * box.width + box.height * box.height,
    );
    return delta <= math.max(28.0, diag * 0.18);
  }

  Rect _bounding(List<Offset> points) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    if (!minX.isFinite) return Rect.zero;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Set<({int row, int col})> _cellsInsideLasso(List<Offset> logicalPath) {
    final box = _bounding(logicalPath);
    if (box.isEmpty) return <({int row, int col})>{};

    final geo = widget.geometryBuilder();
    final result = <({int row, int col})>{};

    final firstRow = math.max(
      0,
      ((box.top - geo.headerHeight) / geo.rowHeight).floor(),
    );
    final lastRow = math.min(
      geo.rowCount - 1,
      ((box.bottom - geo.headerHeight) / geo.rowHeight).ceil(),
    );
    final firstCol = math.max(
      0,
      ((box.left - geo.indexWidth) / geo.dataColumnWidth).floor(),
    );
    final lastCol = math.min(
      geo.dataColumnCount - 1,
      ((box.right - geo.indexWidth) / geo.dataColumnWidth).ceil(),
    );

    if (firstRow > lastRow || firstCol > lastCol) return result;

    final path = Path();
    if (logicalPath.isNotEmpty) {
      path.moveTo(logicalPath.first.dx, logicalPath.first.dy);
      for (var i = 1; i < logicalPath.length; i++) {
        path.lineTo(logicalPath[i].dx, logicalPath[i].dy);
      }
      path.close();
    }

    for (var r = firstRow; r <= lastRow; r++) {
      for (var c = firstCol; c <= lastCol; c++) {
        final centerX =
            geo.indexWidth + c * geo.dataColumnWidth + geo.dataColumnWidth / 2;
        final centerY =
            geo.headerHeight + r * geo.rowHeight + geo.rowHeight / 2;
        if (path.contains(Offset(centerX, centerY))) {
          result.add((row: r, col: c));
        }
      }
    }
    return result;
  }

  TraceComputation _compute(Set<({int row, int col})> cells) {
    var sum = 0.0;
    var num = 0;
    for (final cell in cells) {
      final raw = widget.cellText(cell.row, cell.col);
      final v = _parseNumber(raw);
      if (v != null) {
        sum += v;
        num++;
      }
    }
    final avg = num == 0 ? 0.0 : sum / num;
    return TraceComputation(
      numericCount: num,
      totalCount: cells.length,
      sum: sum,
      average: avg,
    );
  }

  static final RegExp _numberRe =
      RegExp(r'[-+]?\d{1,3}(?:[.,]\d{3})*(?:[.,]\d+)?|[-+]?\d+(?:[.,]\d+)?');

  double? _parseNumber(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final m = _numberRe.firstMatch(s);
    if (m == null) return null;
    var token = m.group(0)!;
    // Heuristica simple para "1.234,56" (es-AR) vs "1,234.56" (en-US):
    final hasDot = token.contains('.');
    final hasComma = token.contains(',');
    if (hasDot && hasComma) {
      // El ultimo separador suele ser el decimal.
      final lastDot = token.lastIndexOf('.');
      final lastComma = token.lastIndexOf(',');
      if (lastComma > lastDot) {
        token = token.replaceAll('.', '').replaceAll(',', '.');
      } else {
        token = token.replaceAll(',', '');
      }
    } else if (hasComma) {
      // Solo coma: si parece decimal (un solo grupo final), tratar como decimal.
      final parts = token.split(',');
      if (parts.length == 2 && parts[1].length <= 3 && parts[0].length <= 4) {
        token = '${parts[0]}.${parts[1]}';
      } else {
        token = token.replaceAll(',', '');
      }
    }
    return double.tryParse(token);
  }

  bool _canInsert() {
    if (_selected.isEmpty) return false;
    if (_operation == TraceOperation.count) return true;
    return _computation.hasNumeric;
  }

  void _clear() {
    setState(() {
      _logicalPath.clear();
      _selected = <({int row, int col})>{};
      _computation = const TraceComputation(
        numericCount: 0,
        totalCount: 0,
        sum: 0,
        average: 0,
      );
      _flyValue = null;
    });
  }

  Future<void> _insertResult() async {
    if (_selected.isEmpty) return;
    final value = _computation.formattedFor(_operation);
    int? targetRow = widget.preferredTargetRow;
    int? targetCol = widget.preferredTargetCol;

    // Si no hay celda activa preferida o no es editable, elegir la celda mas
    // cercana al final del trazo dentro de la seleccion.
    final geo = widget.geometryBuilder();
    if (targetRow == null ||
        targetCol == null ||
        targetRow < 0 ||
        targetCol < 0 ||
        targetCol >= geo.dataColumnCount) {
      final last = _selected.last;
      targetRow = last.row;
      targetCol = last.col;
    }

    // Animar el resultado: desde la barra de acciones hacia la celda destino.
    final targetRect = geo.cellRect(targetRow, targetCol);
    final size = MediaQuery.of(context).size;
    final start = Offset(size.width / 2, size.height - 110);
    final end = targetRect.center;

    setState(() {
      _flyStart = start;
      _flyEnd = end;
      _flyValue = value;
    });
    _resultFlyCtrl.value = 0;
    try {
      await _resultFlyCtrl.animateTo(
        1.0,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {}
    if (!mounted) return;
    widget.onInsertResult(targetRow, targetCol, value);
    setState(() {
      _flyValue = null;
    });
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active && _entryCtrl.isDismissed) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _entryAnim,
      builder: (context, _) {
        final t = _entryAnim.value;
        if (t <= 0.001 && !widget.active) return const SizedBox.shrink();
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: !widget.active,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.18 * t,
                    child: ColoredBox(color: widget.theme.accent),
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: CustomPaint(
                      painter: _TracePainter(
                        path: _logicalPath
                            .map(_toLocal)
                            .toList(growable: false),
                        drawing: _drawing,
                        selectedRects: _selected.map((c) {
                          final geo = widget.geometryBuilder();
                          return geo.cellRect(c.row, c.col);
                        }).toList(growable: false),
                        accent: widget.theme.accent,
                        appear: t,
                      ),
                    ),
                  ),
                ),
                if (_flyValue != null && _flyStart != null && _flyEnd != null)
                  AnimatedBuilder(
                    animation: _resultFlyCtrl,
                    builder: (context, _) {
                      final p = Curves.easeOutCubic
                          .transform(_resultFlyCtrl.value);
                      final dx =
                          _flyStart!.dx + (_flyEnd!.dx - _flyStart!.dx) * p;
                      final dy =
                          _flyStart!.dy + (_flyEnd!.dy - _flyStart!.dy) * p;
                      final scale = 1.0 - 0.45 * p;
                      final opacity = 1.0 - 0.30 * p;
                      return Positioned(
                        left: dx - 36,
                        top: dy - 18,
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.scale(
                            scale: scale,
                            child: _ResultPill(
                              text: _flyValue!,
                              theme: widget.theme,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 16,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 28),
                    child: Opacity(
                      opacity: t,
                      child: _TraceActionBar(
                        theme: widget.theme,
                        operation: _operation,
                        computation: _computation,
                        selectedCount: _selected.length,
                        onOperation: (op) => setState(() => _operation = op),
                        onClear: _clear,
                        onCancel: () {
                          _clear();
                          widget.onClose();
                        },
                        onInsert: _canInsert()
                            ? () => unawaitedSafe(_insertResult())
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void unawaitedSafe(Future<void> f) {
  // ignore: discarded_futures
  f.catchError((_) {});
}

class _TracePainter extends CustomPainter {
  _TracePainter({
    required this.path,
    required this.drawing,
    required this.selectedRects,
    required this.accent,
    required this.appear,
  });

  final List<Offset> path;
  final bool drawing;
  final List<Rect> selectedRects;
  final Color accent;
  final double appear;

  @override
  void paint(Canvas canvas, Size size) {
    // Resaltar celdas seleccionadas.
    final fillPaint = Paint()
      ..color = accent.withValues(alpha: 0.16 * appear);
    final borderPaint = Paint()
      ..color = accent.withValues(alpha: 0.66 * appear)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final r in selectedRects) {
      final rr = RRect.fromRectAndRadius(
        r.deflate(0.5),
        const Radius.circular(4),
      );
      canvas.drawRRect(rr, fillPaint);
      canvas.drawRRect(rr, borderPaint);
    }

    if (path.length < 2) return;
    final p = Path()..moveTo(path.first.dx, path.first.dy);
    for (var i = 1; i < path.length; i++) {
      p.lineTo(path[i].dx, path[i].dy);
    }

    // Halo suave debajo del trazo (mas bonito que un solo trazo).
    final halo = Paint()
      ..color = accent.withValues(alpha: 0.18 * appear)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 18;
    canvas.drawPath(p, halo);

    final stroke = Paint()
      ..color = accent.withValues(alpha: drawing ? 0.95 : 0.78)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.2;
    canvas.drawPath(p, stroke);

    // Punta animada del trazo (puntito que sigue al dedo).
    if (drawing && path.isNotEmpty) {
      final tip = path.last;
      final pulse = Paint()
        ..color = accent.withValues(alpha: 0.30 * appear);
      canvas.drawCircle(tip, 14, pulse);
      final dot = Paint()..color = accent;
      canvas.drawCircle(tip, 5.5, dot);
    }

    // Si el trazo "se cerro" suficientemente, dibujar guia visual del lazo.
    if (!drawing && path.length >= 8) {
      final start = path.first;
      final end = path.last;
      final guide = Paint()
        ..color = accent.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawLine(end, start, guide);
    }
  }

  @override
  bool shouldRepaint(covariant _TracePainter oldDelegate) {
    return oldDelegate.path != path ||
        oldDelegate.drawing != drawing ||
        oldDelegate.selectedRects.length != selectedRects.length ||
        oldDelegate.appear != appear ||
        oldDelegate.accent != accent;
  }
}

class _TraceActionBar extends StatelessWidget {
  const _TraceActionBar({
    required this.theme,
    required this.operation,
    required this.computation,
    required this.selectedCount,
    required this.onOperation,
    required this.onClear,
    required this.onCancel,
    required this.onInsert,
  });

  final TraceOverlayTheme theme;
  final TraceOperation operation;
  final TraceComputation computation;
  final int selectedCount;
  final ValueChanged<TraceOperation> onOperation;
  final VoidCallback onClear;
  final VoidCallback onCancel;
  final VoidCallback? onInsert;

  String _resultText() {
    if (selectedCount == 0) return '—';
    if (operation == TraceOperation.count) {
      return computation.numericCount.toString();
    }
    if (!computation.hasNumeric) return '—';
    return computation.formattedFor(operation);
  }

  @override
  Widget build(BuildContext context) {
    final result = _resultText();
    final hasSelection = selectedCount > 0;
    final canInsert = onInsert != null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Material(
          elevation: 0,
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.divider,
                width: theme.isLight ? 0.6 : 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: theme.isLight ? 0.10 : 0.42,
                  ),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _Chip(
                      icon: Icons.gesture_rounded,
                      label: 'Modo trazo',
                      color: theme.accent,
                      isLight: theme.isLight,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasSelection
                            ? '$selectedCount celda${selectedCount == 1 ? '' : 's'} · '
                                '${computation.numericCount} numerica${computation.numericCount == 1 ? '' : 's'}'
                            : 'Dibuja sobre la grilla para seleccionar celdas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.onSurfaceMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Salir',
                      child: IconButton(
                        onPressed: onCancel,
                        icon: Icon(
                          Icons.close_rounded,
                          color: theme.onSurfaceMuted,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _OperationSegment(
                        theme: theme,
                        operation: operation,
                        onChanged: onOperation,
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.18),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Container(
                        key: ValueKey<String>('${operation.label}|$result'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.accent.withValues(
                            alpha: theme.isLight ? 0.10 : 0.20,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.accent.withValues(alpha: 0.30),
                          ),
                        ),
                        child: Text(
                          result,
                          style: TextStyle(
                            color: theme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: hasSelection ? onClear : null,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Limpiar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.onSurface,
                          side: BorderSide(color: theme.divider),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: canInsert ? onInsert : null,
                        icon: const Icon(
                          Icons.south_west_rounded,
                          size: 18,
                        ),
                        label: Text('Insertar ${operation.label.toLowerCase()}'),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.accent,
                          foregroundColor:
                              theme.isLight ? Colors.white : Colors.black,
                          disabledBackgroundColor: theme.accent.withValues(
                            alpha: 0.22,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isLight,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isLight ? 0.10 : 0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationSegment extends StatelessWidget {
  const _OperationSegment({
    required this.theme,
    required this.operation,
    required this.onChanged,
  });

  final TraceOverlayTheme theme;
  final TraceOperation operation;
  final ValueChanged<TraceOperation> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.divider),
      ),
      child: Row(
        children: [
          for (final op in TraceOperation.values)
            Expanded(
              child: _SegmentTile(
                theme: theme,
                op: op,
                selected: op == operation,
                onTap: () => onChanged(op),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
    required this.theme,
    required this.op,
    required this.selected,
    required this.onTap,
  });

  final TraceOverlayTheme theme;
  final TraceOperation op;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? theme.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: theme.isLight ? 0.05 : 0.30,
                  ),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  op.icon,
                  size: 14,
                  color: selected ? theme.accent : theme.onSurfaceMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  op.label,
                  style: TextStyle(
                    color: selected ? theme.onSurface : theme.onSurfaceMuted,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.text, required this.theme});

  final String text;
  final TraceOverlayTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.accent,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: theme.accent.withValues(alpha: 0.40),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: theme.isLight ? Colors.white : Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

