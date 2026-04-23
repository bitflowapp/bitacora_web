part of '../editor_screen.dart';

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
        rowH: 48,
        headerH: 40,
        cellPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        headerPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        cellFontSize: 13.5,
        headerFontSize: 11.5,
        indexFontSize: 11.5,
      );
    case _GridDensity.roomy:
      return const _GridMetrics(
        rowH: 64,
        headerH: 52,
        cellPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        headerPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        cellFontSize: 15.0,
        headerFontSize: 12.5,
        indexFontSize: 13.0,
      );
    case _GridDensity.normal:
    default:
      return const _GridMetrics(
        rowH: 56,
        headerH: 44,
        cellPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        headerPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        cellFontSize: 14.5,
        headerFontSize: 12.0,
        indexFontSize: 12.5,
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
    required this.cellInlinePreviewAt,
    required this.columnWrapLines,
    required this.columnTextAlign,
    required this.columnVerticalAlign,
    required this.isAttachmentProcessing,
    required this.decodeThumb,
    required this.isInvalid,
    required this.isSearchHit,
    required this.vScroll,
    required this.hScroll,
    required this.selRow,
    required this.selCol,
    required this.selectedRows,
    required this.blink,
    required this.editorLink,
    required this.overlayTargetCell,
    required this.overlayTargetHeaderCol,
    required this.onSelect,
    required this.onRowIndexTap,
    required this.onEditRequested,
    required this.onHeaderEditRequested,
    required this.onContextMenu,
    required this.onDeleteRow,
    required this.onPickPhoto,
    required this.onOpenAttachments,
    required this.rowVersionListenable,
    required this.onRowBuild,
    required this.onCellBuild,
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
  final _CellInlinePreviewData? Function(int r, int c) cellInlinePreviewAt;
  final int Function(int c) columnWrapLines;
  final _GridTextAlignX Function(int c) columnTextAlign;
  final _GridTextAlignY Function(int c) columnVerticalAlign;
  final bool Function(int r, int c) isAttachmentProcessing;
  final Uint8List? Function(String raw) decodeThumb;
  final bool Function(int r, int c) isInvalid;
  final bool Function(int r, int c) isSearchHit;

  final ScrollController vScroll;
  final ScrollController hScroll;

  final int selRow;
  final int selCol;
  final Set<int> selectedRows;

  final ValueListenable<_CellRef?> blink;

  final LayerLink editorLink;
  final _CellRef? overlayTargetCell;
  final int? overlayTargetHeaderCol;

  final _SelectCell onSelect;
  final ValueChanged<int> onRowIndexTap;
  final _EditCell onEditRequested;
  final _EditHeader onHeaderEditRequested;
  final _ContextMenu onContextMenu;

  final ValueChanged<int> onDeleteRow;
  final ValueChanged<int> onPickPhoto;
  final void Function(int r, int c) onOpenAttachments;
  final ValueListenable<int> Function(String rowId) rowVersionListenable;
  final ValueChanged<String> onRowBuild;
  final VoidCallback onCellBuild;

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
            final rawSafeH = (c.hasBoundedHeight && c.maxHeight.isFinite)
                ? c.maxHeight
                : viewSize.height;
            final safeH = rawSafeH < 220 ? 220.0 : rawSafeH;
            if (kDebugMode && rawSafeH <= 1) {
              debugPrint(
                '[editor:grid] zero-ish constraints maxH=${c.maxHeight} maxW=${c.maxWidth} '
                'boundedH=${c.hasBoundedHeight} boundedW=${c.hasBoundedWidth}',
              );
            }
            final shellRadius = BorderRadius.circular(16);
            final shellShadowBase = palette.cellText.withValues(
              alpha: palette.isLight ? 0.06 : 0.22,
            );
            final shellShadowNear = palette.cellText.withValues(
              alpha: palette.isLight ? 0.03 : 0.10,
            );

            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.gridBg,
                  borderRadius: shellRadius,
                  border: Border.all(
                    color: palette.gridBorder,
                    width: 0.75,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: shellShadowBase,
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: shellShadowNear,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: shellRadius,
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
                                    width: col == headers.length - 1
                                        ? photosW
                                        : colW,
                                    text: _labelHeader(headers, col),
                                    isPhotos: col == headers.length - 1,
                                    isOverlayTarget:
                                        overlayTargetHeaderCol == col,
                                    editorLink: editorLink,
                                    onTap: () => onHeaderEditRequested(
                                      col,
                                      col == headers.length - 1
                                          ? photosW
                                          : colW,
                                    ),
                                    onSecondaryTapDown: (d) => onContextMenu(
                                      d.globalPosition,
                                      -1,
                                      col,
                                      true,
                                    ),
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
                                  final row = rowModels[r];
                                  return RepaintBoundary(
                                    child: ValueListenableBuilder<int>(
                                      valueListenable: rowVersionListenable(
                                        row.id,
                                      ),
                                      builder: (context, _, __) {
                                        onRowBuild(row.id);
                                        final rowSelected =
                                            selectedRows.contains(r);
                                        return SizedBox(
                                          height: metrics.rowH,
                                          child: Row(
                                            children: [
                                              _RowIndexCell(
                                                palette: palette,
                                                metrics: metrics,
                                                width: indexW,
                                                index: r + 1,
                                                reviewState: row.reviewState,
                                                selected:
                                                    rowSelected || r == selRow,
                                                onTap: () => onRowIndexTap(r),
                                                onSecondaryTapDown: (d) =>
                                                    onContextMenu(
                                                  d.globalPosition,
                                                  r,
                                                  selCol,
                                                  false,
                                                ),
                                              ),
                                              for (int col = 0;
                                                  col < headers.length;
                                                  col++)
                                                Builder(
                                                  builder: (_) {
                                                    final ref = _CellRef(
                                                      r,
                                                      col,
                                                    );
                                                    final invalid = isInvalid(
                                                      r,
                                                      col,
                                                    );
                                                    final isPhotos = col ==
                                                        headers.length - 1;
                                                    final photosCount =
                                                        cellPhotoCount(r, col);
                                                    final thumbB64 =
                                                        cellPhotoThumb(r, col);
                                                    final inlinePreview =
                                                        cellInlinePreviewAt(
                                                      r,
                                                      col,
                                                    );
                                                    final processing =
                                                        isAttachmentProcessing(
                                                      r,
                                                      col,
                                                    );
                                                    return _DataCell(
                                                      palette: palette,
                                                      metrics: metrics,
                                                      width: col ==
                                                              headers.length - 1
                                                          ? photosW
                                                          : colW,
                                                      text: cellTextAt(r, col),
                                                      hasGps: cellHasGps(
                                                        r,
                                                        col,
                                                      ),
                                                      hasAudio: cellHasAudios(
                                                        r,
                                                        col,
                                                      ),
                                                      photoThumbB64: thumbB64,
                                                      photosCount: photosCount,
                                                      inlinePreview: isPhotos
                                                          ? null
                                                          : inlinePreview,
                                                      wrapLines:
                                                          columnWrapLines(col),
                                                      textAlign:
                                                          columnTextAlign(col),
                                                      verticalAlign:
                                                          columnVerticalAlign(
                                                        col,
                                                      ),
                                                      attachmentProcessing:
                                                          processing,
                                                      zebra: r.isEven,
                                                      thumbB64: thumbB64,
                                                      decodeThumb: decodeThumb,
                                                      selected: r == selRow &&
                                                          col == selCol,
                                                      rowSelected: rowSelected,
                                                      isPhotos: isPhotos,
                                                      blinkRef: blinkRef,
                                                      cellRef: ref,
                                                      invalid: invalid,
                                                      searchHit: isSearchHit(
                                                        r,
                                                        col,
                                                      ),
                                                      isOverlayTarget:
                                                          overlayTargetCell ==
                                                              ref,
                                                      editorLink: editorLink,
                                                      onBuild: onCellBuild,
                                                      onTap: () =>
                                                          onEditRequested(
                                                        r,
                                                        col,
                                                        col ==
                                                                headers.length -
                                                                    1
                                                            ? photosW
                                                            : colW,
                                                      ),
                                                      onLongPress: () {
                                                        onSelect(r, col);
                                                        final box = ctx3
                                                            .findRenderObject();
                                                        if (box is RenderBox) {
                                                          final pos =
                                                              box.localToGlobal(
                                                            Offset.zero,
                                                          );
                                                          onContextMenu(
                                                            pos +
                                                                const Offset(
                                                                  120,
                                                                  12,
                                                                ),
                                                            r,
                                                            col,
                                                            false,
                                                          );
                                                        }
                                                      },
                                                      onSecondaryTapDown: (d) {
                                                        onSelect(r, col);
                                                        onContextMenu(
                                                          d.globalPosition,
                                                          r,
                                                          col,
                                                          false,
                                                        );
                                                      },
                                                      onDeleteRow: () =>
                                                          onDeleteRow(r),
                                                      onPickPhoto: () =>
                                                          onPickPhoto(r),
                                                      onAttachmentsTap: () =>
                                                          onOpenAttachments(
                                                        r,
                                                        col,
                                                      ),
                                                    );
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
          right: BorderSide(
            color: palette.gridBorder,
            width: math.max(palette.hairline, 0.55).toDouble(),
          ),
          bottom: BorderSide(
            color: palette.gridBorder,
            width: math.max(palette.hairline, 0.55).toDouble(),
          ),
        ),
      ),
      child: Text(
        '#',
        style: TextStyle(
          color: palette.headerText,
          fontWeight: FontWeight.w600,
          fontSize: metrics.indexFontSize,
          letterSpacing: 0.5,
        ),
      ),
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
    final radius = BorderRadius.zero;
    final borderColor = palette.gridBorder;
    final lineWidth = math.max(palette.hairline, 0.55).toDouble();

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
              right: BorderSide(color: borderColor, width: lineWidth),
              bottom: BorderSide(color: borderColor, width: lineWidth),
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
                t.isEmpty ? ' ' : t.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.headerText,
                  fontWeight: FontWeight.w600,
                  fontSize: metrics.headerFontSize,
                  height: 1.05,
                  letterSpacing: 0.7,
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
    required this.reviewState,
    required this.selected,
    required this.onTap,
    required this.onSecondaryTapDown,
  });

  final _SheetPalette palette;
  final _GridMetrics metrics;
  final double width;
  final int index;
  final String reviewState;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<TapDownDetails> onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    final neutralRing = palette.focusRing;
    final bg = selected ? palette.selectionFill : palette.indexBg;
    final radius = BorderRadius.zero;
    final lineWidth = math.max(palette.hairline, 0.55).toDouble();
    final normalizedState = _normalizeReviewState(reviewState);
    final stateLabel = _reviewStateShortLabel(normalizedState);
    final stateColors = _reviewStateColors(normalizedState, palette);

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
              right: BorderSide(color: palette.gridBorder, width: lineWidth),
              bottom: BorderSide(color: palette.gridBorder, width: lineWidth),
            ),
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
                        width: math.max(palette.hairline, 1.2).toDouble(),
                      ),
                    )
                  : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    index.toString(),
                    style: TextStyle(
                      color: selected ? palette.accent : palette.cellTextMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: metrics.indexFontSize,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: stateColors.$1,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: stateColors.$2,
                        width: math.max(palette.hairline, 0.75).toDouble(),
                      ),
                    ),
                    child: Text(
                      stateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: stateColors.$3,
                        fontWeight: FontWeight.w700,
                        fontSize: 8.8,
                        height: 1.0,
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
  }
}

(Color, Color, Color) _reviewStateColors(
  String reviewState,
  _SheetPalette palette,
) {
  switch (_normalizeReviewState(reviewState)) {
    case 'observada':
      return (
        palette.accent.withValues(alpha: palette.isLight ? 0.12 : 0.18),
        palette.accent.withValues(alpha: 0.26),
        palette.accent,
      );
    case 'corregida':
      return (
        palette.chipBg,
        palette.chipBorder,
        palette.chipText,
      );
    case 'aprobada':
      return (
        palette.accent.withValues(alpha: palette.isLight ? 0.10 : 0.16),
        palette.accent.withValues(alpha: 0.24),
        palette.accent,
      );
    case 'sin_revision':
    default:
      return (
        palette.hintBg,
        palette.border,
        palette.fgMuted,
      );
  }
}

String _reviewStateShortLabel(String reviewState) {
  switch (_normalizeReviewState(reviewState)) {
    case 'observada':
      return 'Obs.';
    case 'corregida':
      return 'Corr.';
    case 'aprobada':
      return 'Apr.';
    case 'sin_revision':
    default:
      return 'Sin rev.';
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
    required this.inlinePreview,
    required this.wrapLines,
    required this.textAlign,
    required this.verticalAlign,
    required this.attachmentProcessing,
    required this.zebra,
    required this.thumbB64,
    required this.decodeThumb,
    required this.selected,
    required this.rowSelected,
    required this.invalid,
    required this.searchHit,
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
    required this.onAttachmentsTap,
    required this.onBuild,
  });

  final _SheetPalette palette;
  final _GridMetrics metrics;
  final double width;
  final String text;
  final bool hasGps;
  final bool hasAudio;
  final String photoThumbB64;
  final int photosCount;
  final _CellInlinePreviewData? inlinePreview;
  final int wrapLines;
  final _GridTextAlignX textAlign;
  final _GridTextAlignY verticalAlign;
  final bool attachmentProcessing;
  final bool zebra;
  final String thumbB64;
  final Uint8List? Function(String raw) decodeThumb;
  final bool selected;
  final bool rowSelected;
  final bool invalid;
  final bool searchHit;
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
  final VoidCallback onAttachmentsTap;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    final isActive = blinkRef == cellRef;
    final focus = selected || isOverlayTarget;
    final baseBg = zebra ? palette.zebraB : palette.zebraA;
    final selectedBg = palette.selectionFill;
    final rowSelectedBg = palette.selectionFill.withValues(
      alpha: palette.isLight ? 0.5 : 0.66,
    );
    final searchBg = Color.lerp(
          baseBg,
          palette.focusRing.withValues(alpha: palette.isLight ? 0.16 : 0.22),
          0.6,
        ) ??
        baseBg;
    final invalidBg = Color.lerp(
          baseBg,
          const Color(0xFFFF3B30).withValues(
            alpha: palette.isLight ? 0.08 : 0.18,
          ),
          0.58,
        ) ??
        baseBg;
    final bg = isActive
        ? palette.blinkBg
        : (selected
            ? selectedBg
            : (rowSelected
                ? rowSelectedBg
                : (invalid ? invalidBg : (searchHit ? searchBg : baseBg))));

    final invalidBorder = const Color(0xFFFF3B30).withValues(
      alpha: palette.isLight ? 0.46 : 0.70,
    );
    final borderColor = focus
        ? palette.selectionBorder
        : (invalid
            ? invalidBorder
            : (searchHit
                ? palette.selectionBorder.withValues(
                    alpha: palette.isLight ? 0.52 : 0.7,
                  )
                : palette.gridBorder));
    final lineWidth = math.max(palette.hairline, 0.55).toDouble();

    final radius = BorderRadius.zero;

    final decoration = BoxDecoration(
      color: bg,
      borderRadius: radius,
      border: Border.all(color: borderColor, width: lineWidth),
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
              foregroundDecoration: focus
                  ? BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color:
                            invalid ? invalidBorder : palette.selectionBorder,
                        width: palette.isLight ? 1.25 : 1.4,
                      ),
                    )
                  : null,
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

  Widget _chip(Widget child, {VoidCallback? onTap}) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: palette.chipBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: palette.chipBorder,
          width: math.max(palette.hairline, 0.75).toDouble(),
        ),
      ),
      child: child,
    );
    if (onTap == null) return chip;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: chip,
    );
  }

  Widget _buildInlinePreviewChip(_CellInlinePreviewData preview) {
    final thumbBytes = preview.hasThumb ? decodeThumb(preview.thumbB64) : null;
    final leading = thumbBytes != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.memory(
              thumbBytes,
              width: 24,
              height: 24,
              fit: BoxFit.cover,
              cacheWidth: 48,
              cacheHeight: 48,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
            ),
          )
        : Icon(
            preview.icon,
            size: 17,
            color: palette.chipText,
          );

    return Tooltip(
      message: '${preview.title} - ${preview.subtitle}',
      child: InkWell(
        onTap: onAttachmentsTap,
        onLongPress: onAttachmentsTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 90, minWidth: 32),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: palette.chipBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: palette.chipBorder,
              width: math.max(palette.hairline, 1).toDouble(),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              if (preview.extraCount > 0) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '+${preview.extraCount}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: palette.chipText,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCellBody(BuildContext context) {
    if (attachmentProcessing) {
      return Row(
        children: [
          Expanded(
            child: _ProcessingSkeleton(
              palette: palette,
              height: 12,
            ),
          ),
          const SizedBox(width: 8),
          _chip(
            Text(
              'Procesando…',
              style: TextStyle(
                color: palette.chipText,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      );
    }

    final inline = inlinePreview;
    final requestedTextLines = wrapLines.clamp(1, 3);
    final availableTextHeight =
        (metrics.rowH - metrics.cellPadding.vertical).clamp(0.0, metrics.rowH);
    final linesByHeight =
        (availableTextHeight / (metrics.cellFontSize * 1.1)).floor();
    final maxTextLines = math.max(
      1,
      math.min(requestedTextLines, linesByHeight),
    );
    final textAlignFlutter = _gridTextAlignToFlutter(textAlign);
    final contentAlignment = _gridCellAlignment(
      horizontal: textAlign,
      vertical: verticalAlign,
    );
    final displayText = text.trim().isNotEmpty
        ? text
        : (!isPhotos && inline != null
            ? '${inline.title} · ${inline.subtitle}'
            : ' ');
    final content = isPhotos
        ? _PhotosCell(
            palette: palette,
            count: photosCount,
            thumbB64: thumbB64,
            decodeThumb: decodeThumb,
            onAdd: onPickPhoto,
            onDeleteRow: onDeleteRow,
          )
        : Row(
            children: [
              Expanded(
                child: Text(
                  displayText,
                  maxLines: maxTextLines,
                  textAlign: textAlignFlutter,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.cellText,
                    fontSize: metrics.cellFontSize,
                    height: 1.15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: selected ? -0.05 : 0,
                  ),
                ),
              ),
              if (inline != null) ...[
                const SizedBox(width: 6),
                _buildInlinePreviewChip(inline),
              ],
            ],
          );

    final badges = <Widget>[];
    if (photosCount > 0 && inline == null) {
      final bytes = decodeThumb(photoThumbB64);
      final iconWidget = bytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Image.memory(
                bytes,
                width: 12,
                height: 12,
                fit: BoxFit.cover,
                cacheWidth: 24,
                cacheHeight: 24,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
              ),
            )
          : Icon(Icons.photo_rounded, size: 12, color: palette.chipText);
      badges.add(
        _chip(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              const SizedBox(width: 3),
              Text(
                '$photosCount',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: palette.chipText,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          onTap: onAttachmentsTap,
        ),
      );
    }
    if (hasAudio) {
      badges.add(
        _chip(
          Icon(Icons.graphic_eq_rounded, size: 12, color: palette.chipText),
          onTap: onAttachmentsTap,
        ),
      );
    }
    if (hasGps) {
      badges.add(
        _chip(
          Icon(
            Icons.my_location_rounded,
            size: 11,
            color: palette.chipText,
          ),
          onTap: onAttachmentsTap,
        ),
      );
    }

    final decorated = badges.isEmpty
        ? content
        : Stack(
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

    if (isPhotos) return decorated;
    return Align(
      alignment: contentAlignment,
      child: SizedBox(width: double.infinity, child: decorated),
    );
  }
}

class _ProcessingSkeleton extends StatefulWidget {
  const _ProcessingSkeleton({
    required this.palette,
    required this.height,
  });

  final _SheetPalette palette;
  final double height;

  @override
  State<_ProcessingSkeleton> createState() => _ProcessingSkeletonState();
}

class _ProcessingSkeletonState extends State<_ProcessingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final alpha = 0.14 + (0.12 * t);
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: widget.palette.cellText.withValues(alpha: alpha),
          ),
        );
      },
    );
  }
}

class _PhotosCell extends StatelessWidget {
  const _PhotosCell({
    required this.palette,
    required this.count,
    required this.thumbB64,
    required this.decodeThumb,
    required this.onAdd,
    required this.onDeleteRow,
  });

  final _SheetPalette palette;
  final int count;
  final String thumbB64;
  final Uint8List? Function(String raw) decodeThumb;
  final VoidCallback onAdd;
  final VoidCallback onDeleteRow;

  @override
  Widget build(BuildContext context) {
    final thumbBytes = decodeThumb(thumbB64);
    final hasThumb = thumbBytes != null;
    return Row(
      children: [
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Icon(
              Icons.add_photo_alternate_outlined,
              size: 18,
              color: palette.fg,
            ),
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
              cacheWidth: 52,
              cacheHeight: 52,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
            ),
          ),
        if (hasThumb) const SizedBox(width: 6),
        Expanded(
          child: Text(
            count == 0 ? '0' : '$count',
            style: TextStyle(
              color: palette.fg,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.05,
              letterSpacing: 0.2,
            ),
          ),
        ),
        InkWell(
          onTap: onDeleteRow,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: palette.fgMuted,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================== UI: Status =================================
