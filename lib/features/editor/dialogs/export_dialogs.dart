part of '../editor_screen.dart';

const String _kExportProgressTitle = 'Generando archivo…';
const String _kExportProgressSubtitle = 'Preparando planilla y evidencias.';
const String _kExportProgressDetail =
    'Esto puede tardar unos segundos si hay fotos o videos.';

class _PlanillaSignatureResult {
  _PlanillaSignatureResult({
    required this.pngBytes,
    required this.signedBy,
    required this.signedAt,
  });

  final Uint8List pngBytes;
  final String signedBy;
  final DateTime signedAt;
}

extension _EditorExportDialogs on _EditorScreenState {
  Future<void> _openExportMenu() async {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    var format = _lastExportPreset == 'xlsx' ? 'xlsx' : 'pdf';

    await showAppModal<void>(
      context: context,
      title: 'Exportar',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final fileName = _buildCommercialExportFileName(format);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Formato',
                style: TextStyle(
                  color: AppTheme.of(context).colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'XLSX',
                      variant: format == 'xlsx'
                          ? AppButtonVariant.primary
                          : AppButtonVariant.ghost,
                      onPressed: () => setModalState(() => format = 'xlsx'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      label: 'PDF',
                      variant: format == 'pdf'
                          ? AppButtonVariant.primary
                          : AppButtonVariant.ghost,
                      onPressed: () => setModalState(() => format = 'pdf'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.of(context).colors.border,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.attachment_rounded,
                      size: 18,
                      color: AppTheme.of(context).colors.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Se incluyen siempre fotos, ubicaciones, audio, '
                        'transcripciones, videos y archivos adjuntos.',
                        style: TextStyle(
                          color: AppTheme.of(context).colors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Archivo: $fileName',
                style: TextStyle(
                  color: AppTheme.of(context).colors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Descargar',
                icon: Icons.download_rounded,
                variant: AppButtonVariant.primary,
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(
                    _triggerSheetExport(
                      format: format,
                      includeAttachments: true,
                      share: false,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Compartir',
                icon: Icons.ios_share_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(
                    _triggerSheetExport(
                      format: format,
                      includeAttachments: true,
                      share: true,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.18),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Cerrar y firmar planilla',
                icon: Icons.draw_outlined,
                variant: AppButtonVariant.primary,
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(_startCloseAndSignFlow());
                },
              ),
              const SizedBox(height: 4),
              Text(
                'Genera un PDF con la firma del responsable y marca la planilla como cerrada.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
            ],
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

  Future<void> _triggerSheetExport({
    required String format,
    required bool includeAttachments,
    required bool share,
  }) async {
    if (_longOperation != null) return;
    await _setExportPresetPref(format == 'pdf' ? 'pdf' : 'xlsx');
    if (format == 'pdf') {
      await _exportPdf(
        includeAttachments: true,
        share: share,
      );
      return;
    }
    await _exportXlsxOnly(
      includeAttachments: true,
      share: share,
    );
  }

  Future<void> _startCloseAndSignFlow() async {
    if (!mounted) return;
    final result = await showAppModal<_PlanillaSignatureResult>(
      context: context,
      title: 'Cerrar y firmar planilla',
      barrierDismissible: false,
      child: _CloseAndSignModalBody(
        sheetName: _sheetName.trim().isEmpty ? 'Planilla' : _sheetName.trim(),
      ),
    );
    if (!mounted) return;
    if (result == null) return;
    unawaited(_setExportPresetPref('pdf'));
    unawaited(
      _exportPdf(
        includeAttachments: true,
        share: true,
        signature: result,
      ),
    );
  }
}

class _CloseAndSignModalBody extends StatefulWidget {
  const _CloseAndSignModalBody({required this.sheetName});

  final String sheetName;

  @override
  State<_CloseAndSignModalBody> createState() => _CloseAndSignModalBodyState();
}

class _CloseAndSignModalBodyState extends State<_CloseAndSignModalBody> {
  final GlobalKey<_SignaturePadCanvasState> _padKey =
      GlobalKey<_SignaturePadCanvasState>();
  final TextEditingController _nameCtrl = TextEditingController();
  bool _certified = false;
  bool _hasStrokes = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      !_submitting &&
      _hasStrokes &&
      _certified &&
      _nameCtrl.text.trim().isNotEmpty;

  Future<void> _onConfirm() async {
    if (!_canConfirm) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final bytes = await _padKey.currentState?.exportPngBytes();
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _submitting = false;
          _error = 'No se pudo capturar la firma. Intenta nuevamente.';
        });
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        _PlanillaSignatureResult(
          pngBytes: bytes,
          signedBy: _nameCtrl.text.trim(),
          signedAt: DateTime.now(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Error al firmar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Planilla: ${widget.sheetName}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Responsable / Firmante',
              hintText: 'Nombre y apellido',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Text(
            'Firma (trazá con el dedo)',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 6),
          _SignaturePadCanvas(
            key: _padKey,
            onStrokesChanged: (hasStrokes) {
              if (hasStrokes != _hasStrokes) {
                setState(() => _hasStrokes = hasStrokes);
              }
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: _submitting
                    ? null
                    : () {
                        _padKey.currentState?.clear();
                      },
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Limpiar firma'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _submitting
                ? null
                : () => setState(() => _certified = !_certified),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: _certified,
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _certified = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Certifico que los datos relevados en esta planilla son correctos y fueron verificados en campo.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancelar',
                  variant: AppButtonVariant.ghost,
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Firmar y exportar',
                  icon: Icons.verified_rounded,
                  variant: AppButtonVariant.primary,
                  loading: _submitting,
                  onPressed: _canConfirm ? _onConfirm : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignaturePadCanvas extends StatefulWidget {
  const _SignaturePadCanvas({
    super.key,
    required this.onStrokesChanged,
  });

  final ValueChanged<bool> onStrokesChanged;

  @override
  State<_SignaturePadCanvas> createState() => _SignaturePadCanvasState();
}

class _SignaturePadCanvasState extends State<_SignaturePadCanvas> {
  final List<List<Offset>> _strokes = <List<Offset>>[];
  final GlobalKey _canvasKey = GlobalKey();
  Size _canvasSize = Size.zero;

  void clear() {
    if (_strokes.isEmpty) return;
    setState(_strokes.clear);
    widget.onStrokesChanged(false);
  }

  Future<Uint8List?> exportPngBytes() async {
    final size = _canvasSize;
    if (size.width <= 0 || size.height <= 0) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bg = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);
    final ink = Paint()
      ..color = const Color(0xFF0B0D1A)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in _strokes) {
      if (stroke.length < 2) {
        if (stroke.isNotEmpty) {
          canvas.drawCircle(stroke.first, 1.4, ink..style = PaintingStyle.fill);
          ink.style = PaintingStyle.stroke;
        }
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, ink);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.ceil(),
      size.height.ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  void _addPoint(Offset p, {required bool newStroke}) {
    setState(() {
      if (newStroke || _strokes.isEmpty) {
        _strokes.add(<Offset>[p]);
      } else {
        _strokes.last.add(p);
      }
    });
    widget.onStrokesChanged(_strokes.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (ctx, cs) {
            _canvasSize = Size(cs.maxWidth, cs.maxHeight);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => _addPoint(d.localPosition, newStroke: true),
              onPanUpdate: (d) => _addPoint(d.localPosition, newStroke: false),
              onPanEnd: (_) {},
              child: CustomPaint(
                key: _canvasKey,
                size: Size(cs.maxWidth, cs.maxHeight),
                painter: _SignaturePadPainter(strokes: _strokes),
                child: _strokes.isEmpty
                    ? Center(
                        child: Text(
                          'Firmá acá',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.35),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const SizedBox.expand(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SignaturePadPainter extends CustomPainter {
  _SignaturePadPainter({required this.strokes});

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = const Color(0xFF0B0D1A)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.isNotEmpty) {
          canvas.drawCircle(
            stroke.first,
            1.4,
            Paint()..color = const Color(0xFF0B0D1A),
          );
        }
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, ink);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePadPainter old) =>
      old.strokes != strokes || old.strokes.length != strokes.length;
}
