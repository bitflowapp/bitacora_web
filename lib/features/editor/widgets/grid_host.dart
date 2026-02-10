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
                              return RepaintBoundary(
                                child: SizedBox(
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
                                        onSecondaryTapDown: (d) =>
                                            onContextMenu(d.globalPosition, r,
                                                selCol, false),
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
                                                  final pos = box.localToGlobal(
                                                      Offset.zero);
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
                                                onContextMenu(d.globalPosition,
                                                    r, col, false);
                                              },
                                              onDeleteRow: () => onDeleteRow(r),
                                              onPickPhoto: () => onPickPhoto(r),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
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
        palette.hintBg.withOpacity(palette.isLight ? 0.75 : 0.28);
    final bg = isActive ? palette.blinkBg : (selected ? selectedBg : baseBg);

    final borderColor = invalid
        ? Colors.red.withOpacity(palette.isLight ? 0.85 : 0.75)
        : focus
            ? palette.borderStrong.withOpacity(palette.isLight ? 0.70 : 0.75)
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
        color: palette.hintBg.withOpacity(palette.isLight ? 0.75 : 0.30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: palette.borderStrong.withOpacity(0.35),
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
    if (!isPhotos && photosCount > 0) {
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
          : Icon(
              Icons.photo_rounded,
              size: 12,
              color: palette.fgMuted,
            );
      badges.add(
        _badge(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              const SizedBox(width: 3),
              Text(
                '$photosCount',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: palette.fgMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (hasAudio) {
      badges.add(
        _badge(
          Icon(
            Icons.graphic_eq_rounded,
            size: 12,
            color: palette.fgMuted,
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
            color: palette.fgMuted,
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
