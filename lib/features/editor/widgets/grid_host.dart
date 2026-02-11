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
        rowH: 53,
        headerH: 49,
        cellPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        headerPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        cellFontSize: 14.0,
        headerFontSize: 13.2,
        indexFontSize: 12.5,
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
        rowH: 61,
        headerH: 56,
        cellPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        headerPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        cellFontSize: 15.5,
        headerFontSize: 14.5,
        indexFontSize: 13.7,
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
            final safeH = (c.hasBoundedHeight && c.maxHeight.isFinite)
                ? c.maxHeight
                : viewSize.height;
            final shellRadius = BorderRadius.circular(22);
            final shellShadow = palette.cellText.withValues(
              alpha: palette.isLight ? 0.05 : 0.2,
            );

            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.gridBg,
                  borderRadius: shellRadius,
                  border: Border.all(
                    color: palette.gridBorder,
                    width: math.max(palette.hairline, 1).toDouble(),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: shellShadow,
                      blurRadius: 24,
                      offset: const Offset(0, 10),
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
                                        final rowSelected = selectedRows
                                            .contains(r);
                                        return SizedBox(
                                          height: metrics.rowH,
                                          child: Row(
                                            children: [
                                              _RowIndexCell(
                                                palette: palette,
                                                metrics: metrics,
                                                width: indexW,
                                                index: r + 1,
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
                                              for (
                                                int col = 0;
                                                col < headers.length;
                                                col++
                                              )
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
                                                    final isPhotos =
                                                        col ==
                                                        headers.length - 1;
                                                    final photosCount =
                                                        cellPhotoCount(r, col);
                                                    final thumbB64 =
                                                        cellPhotoThumb(r, col);
                                                    return _DataCell(
                                                      palette: palette,
                                                      metrics: metrics,
                                                      width:
                                                          col ==
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
                                                      zebra: r.isEven,
                                                      thumbB64: thumbB64,
                                                      selected:
                                                          r == selRow &&
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
                                                      onTap: () => onEditRequested(
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
                                                          final pos = box
                                                              .localToGlobal(
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
            width: math.max(palette.hairline, 1).toDouble(),
          ),
          bottom: BorderSide(
            color: palette.gridBorder,
            width: math.max(palette.hairline, 1).toDouble(),
          ),
        ),
      ),
      child: Text(
        '#',
        style: TextStyle(
          color: palette.headerText,
          fontWeight: FontWeight.w900,
          fontSize: metrics.indexFontSize,
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
    final t = text.trim().isEmpty
        ? (isPhotos ? kPhotosHeader : '')
        : text.trim();
    final radius = BorderRadius.zero;
    final borderColor = palette.gridBorder;
    final lineWidth = math.max(palette.hairline, 0.85).toDouble();

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
                t.isEmpty ? ' ' : t,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.headerText,
                  fontWeight: FontWeight.w700,
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
    final neutralRing = palette.focusRing.withValues(
      alpha: palette.isLight ? 0.65 : 0.78,
    );
    final bg = selected ? palette.selectionFill : palette.indexBg;
    final radius = BorderRadius.zero;
    final lineWidth = math.max(palette.hairline, 0.85).toDouble();

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
              child: Text(
                index.toString(),
                style: TextStyle(
                  color: selected ? palette.cellText : palette.cellTextMuted,
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
  final bool zebra;
  final String thumbB64;
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
    final searchBg =
        Color.lerp(
          baseBg,
          palette.focusRing.withValues(alpha: palette.isLight ? 0.16 : 0.22),
          0.6,
        ) ??
        baseBg;
    final invalidBg =
        Color.lerp(
          baseBg,
          palette.cellText.withValues(alpha: palette.isLight ? 0.08 : 0.16),
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

    final invalidBorder = palette.cellText.withValues(
      alpha: palette.isLight ? 0.35 : 0.56,
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
    final lineWidth = math.max(palette.hairline, 0.85).toDouble();

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
                        color: invalid
                            ? invalidBorder
                            : palette.selectionBorder,
                        width: 1.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: palette.chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: palette.chipBorder,
          width: math.max(palette.hairline, 1).toDouble(),
        ),
      ),
      child: child,
    );
    if (onTap == null) return chip;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: chip,
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
                color: palette.cellText,
                fontSize: metrics.cellFontSize,
                height: 1.1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: selected ? -0.12 : -0.04,
              ),
            ),
          );

    final badges = <Widget>[];
    if (photosCount > 0) {
      final bytes = _tryDecodeB64(photoThumbB64);
      final iconWidget = bytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Image.memory(
                bytes,
                width: 12,
                height: 12,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
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
                'F$photosCount',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: palette.chipText,
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.graphic_eq_rounded, size: 12, color: palette.chipText),
              const SizedBox(width: 3),
              Text(
                'A',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: palette.chipText,
                ),
              ),
            ],
          ),
          onTap: onAttachmentsTap,
        ),
      );
    }
    if (hasGps) {
      badges.add(
        _chip(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.my_location_rounded,
                size: 11,
                color: palette.chipText,
              ),
              const SizedBox(width: 3),
              Text(
                'GPS',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: palette.chipText,
                ),
              ),
            ],
          ),
          onTap: onAttachmentsTap,
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
              filterQuality: FilterQuality.low,
            ),
          ),
        if (hasThumb) const SizedBox(width: 6),
        Expanded(
          child: Text(
            count == 0 ? '0' : '$count',
            style: TextStyle(
              color: palette.fg,
              fontWeight: FontWeight.w900,
              height: 1.05,
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
