part of '../features/editor/editor_screen.dart';

const double _kMobileCardMinW = 120.0;
const double _kMobileCardMaxW = 170.0;

double _mobileCardH(_GridDensity density) {
  switch (density) {
    case _GridDensity.compact:
      return 34.0;
    case _GridDensity.roomy:
      return 45.0;
    case _GridDensity.normal:
    default:
      return 38.0;
  }
}

double _mobileRowPadH(_GridDensity density) {
  switch (density) {
    case _GridDensity.compact:
      return 11.0;
    case _GridDensity.roomy:
      return 14.0;
    case _GridDensity.normal:
    default:
      return 13.0;
  }
}

double _mobileRowPadV(_GridDensity density) {
  switch (density) {
    case _GridDensity.compact:
      return 6.0;
    case _GridDensity.roomy:
      return 7.0;
    case _GridDensity.normal:
    default:
      return 7.0;
  }
}

double _mobileRowSpacing(_GridDensity density) {
  switch (density) {
    case _GridDensity.compact:
      return 7.0;
    case _GridDensity.roomy:
      return 10.0;
    case _GridDensity.normal:
    default:
      return 9.0;
  }
}

double _mobileCardGap(_GridDensity density) {
  switch (density) {
    case _GridDensity.compact:
      return 7.0;
    case _GridDensity.roomy:
      return 10.0;
    case _GridDensity.normal:
    default:
      return 9.0;
  }
}

double _mobileCardPadH(_GridDensity density) {
  switch (density) {
    case _GridDensity.compact:
      return 9.0;
    case _GridDensity.roomy:
      return 12.0;
    case _GridDensity.normal:
    default:
      return 11.0;
  }
}

double _mobileCardPadV(_GridDensity density) {
  switch (density) {
    case _GridDensity.compact:
      return 6.0;
    case _GridDensity.roomy:
      return 7.0;
    case _GridDensity.normal:
    default:
      return 7.0;
  }
}

double _mobileRowH(_GridDensity density) =>
    _mobileCardH(density) + (_mobileRowPadV(density) * 2);

double _mobileHeaderRowH(_GridDensity density) => _mobileRowH(density);

double _mobileListPadTop(_GridDensity density) {
  switch (density) {
    case _GridDensity.compact:
      return 6.0;
    case _GridDensity.roomy:
      return 8.0;
    case _GridDensity.normal:
    default:
      return 7.0;
  }
}

double _mobileListPadBottom(_GridDensity density) {
  switch (density) {
    case _GridDensity.compact:
      return 9.0;
    case _GridDensity.roomy:
      return 14.0;
    case _GridDensity.normal:
    default:
      return 12.0;
  }
}

double _mobileTextSize(_GridDensity density, {required bool isHeader}) {
  switch (density) {
    case _GridDensity.compact:
      return isHeader ? 12.0 : 12.0;
    case _GridDensity.roomy:
      return isHeader ? 14.0 : 14.0;
    case _GridDensity.normal:
    default:
      return isHeader ? 13.0 : 13.0;
  }
}

double _mobileCardWidthForScreen(double screenW) {
  final raw = screenW * 0.34;
  final clamped = raw.clamp(_kMobileCardMinW, _kMobileCardMaxW);
  return clamped.toDouble();
}

class _MobileNotesGrid extends StatelessWidget {
  const _MobileNotesGrid({
    required this.palette,
    required this.density,
    required this.headers,
    required this.rowModels,
    required this.cellTextAt,
    required this.cellHasGps,
    required this.cellHasAudios,
    required this.cellPhotoThumb,
    required this.cellPhotoCount,
    required this.cellInlinePreviewAt,
    required this.decodeThumb,
    required this.verticalController,
    required this.headerScrollController,
    required this.rowScrollControllers,
    required this.headerKey,
    required this.rowKeys,
    required this.selectedRow,
    required this.selectedCol,
    required this.activeRow,
    required this.activeCol,
    required this.activeIsHeader,
    required this.activeController,
    required this.onCellTap,
    required this.onHeaderTap,
    required this.onHorizontalScroll,
    required this.onContextMenu,
    required this.onPickPhoto,
    required this.onDeleteRow,
    required this.onOpenAttachments,
    required this.onRowBuild,
    required this.onCellBuild,
  });

  final _SheetPalette palette;
  final _GridDensity density;
  final List<String> headers;
  final List<_RowModel> rowModels;
  final String Function(int r, int c) cellTextAt;
  final bool Function(int r, int c) cellHasGps;
  final bool Function(int r, int c) cellHasAudios;
  final String Function(int r, int c) cellPhotoThumb;
  final int Function(int r, int c) cellPhotoCount;
  final _CellInlinePreviewData? Function(int r, int c) cellInlinePreviewAt;
  final Uint8List? Function(String raw) decodeThumb;

  final ScrollController verticalController;
  final ScrollController headerScrollController;
  final List<ScrollController> rowScrollControllers;
  final GlobalKey headerKey;
  final List<GlobalKey> rowKeys;

  final int selectedRow;
  final int selectedCol;
  final int activeRow;
  final int activeCol;
  final bool activeIsHeader;
  final TextEditingController activeController;

  final void Function(BuildContext context, int r, int c) onCellTap;
  final void Function(BuildContext context, int c) onHeaderTap;
  final void Function(double offset, bool isHeader, int row) onHorizontalScroll;
  final _ContextMenu onContextMenu;
  final ValueChanged<int> onPickPhoto;
  final ValueChanged<int> onDeleteRow;
  final void Function(int r, int c) onOpenAttachments;
  final ValueChanged<String> onRowBuild;
  final VoidCallback onCellBuild;

  @override
  Widget build(BuildContext context) {
    assert(rowScrollControllers.length >= rowModels.length);
    assert(rowKeys.length >= rowModels.length);
    final shellRadius = BorderRadius.circular(22);
    final shellShadow = palette.cellText.withValues(
      alpha: palette.isLight ? 0.06 : 0.24,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
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
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: shellRadius,
          child: ListView.separated(
            controller: verticalController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              0,
              _mobileListPadTop(density),
              0,
              _mobileListPadBottom(density),
            ),
            itemCount: rowModels.length + 1,
            separatorBuilder: (_, __) =>
                SizedBox(height: _mobileRowSpacing(density)),
            itemBuilder: (ctx, index) {
              if (index == 0) {
                return KeyedSubtree(
                  key: headerKey,
                  child: _buildHeaderRow(ctx),
                );
              }
              final row = index - 1;
              return KeyedSubtree(
                key: rowKeys[row],
                child: _buildDataRow(ctx, row),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    final cardW = _mobileCardWidthForScreen(MediaQuery.of(context).size.width);
    return SizedBox(
      height: _mobileHeaderRowH(density),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          onHorizontalScroll(headerScrollController.offset, true, -1);
          return false;
        },
        child: ListView.separated(
          controller: headerScrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: _mobileRowPadH(density),
            vertical: _mobileRowPadV(density),
          ),
          itemCount: headers.length,
          separatorBuilder: (_, __) => SizedBox(width: _mobileCardGap(density)),
          itemBuilder: (ctx, col) {
            final label = _labelHeader(headers, col);
            final isActive = activeIsHeader && activeCol == col;
            return _buildCard(
              context: ctx,
              width: cardW,
              isHeader: true,
              isActive: isActive,
              isSelected: false,
              hasGps: false,
              hasAudio: false,
              hasPhoto: false,
              zebra: false,
              photoThumbB64: '',
              inlinePreview: null,
              onTap: () => onHeaderTap(ctx, col),
              onLongPress: (pos) => onContextMenu(pos, -1, col, true),
              onAttachmentsTap: null,
              child: isActive
                  ? ValueListenableBuilder<TextEditingValue>(
                      valueListenable: activeController,
                      builder: (ctx, value, __) {
                        return _buildCardText(value.text, isHeader: true);
                      },
                    )
                  : _buildCardText(label, isHeader: true),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, int row) {
    onRowBuild(rowModels[row].id);
    final cardW = _mobileCardWidthForScreen(MediaQuery.of(context).size.width);
    return SizedBox(
      height: _mobileRowH(density),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          onHorizontalScroll(rowScrollControllers[row].offset, false, row);
          return false;
        },
        child: ListView.separated(
          controller: rowScrollControllers[row],
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: _mobileRowPadH(density),
            vertical: _mobileRowPadV(density),
          ),
          itemCount: headers.length,
          separatorBuilder: (_, __) => SizedBox(width: _mobileCardGap(density)),
          itemBuilder: (ctx, col) {
            onCellBuild();
            final isPhotos = col == headers.length - 1;
            final isActive =
                !activeIsHeader && activeRow == row && activeCol == col;
            final isSelected = row == selectedRow && col == selectedCol;

            if (isPhotos) {
              final thumb = cellPhotoThumb(row, col);
              final count = cellPhotoCount(row, col);
              final hasAudio = cellHasAudios(row, col);
              final hasGps = cellHasGps(row, col);
              return _buildCard(
                context: ctx,
                width: cardW,
                isHeader: false,
                isActive: false,
                isSelected: isSelected,
                hasGps: hasGps,
                hasAudio: hasAudio,
                hasPhoto: count > 0,
                zebra: row.isEven,
                photoThumbB64: thumb,
                inlinePreview: null,
                onTap: () => onCellTap(ctx, row, col),
                onLongPress: (pos) => onContextMenu(pos, row, col, false),
                onAttachmentsTap: () => onOpenAttachments(row, col),
                child: _PhotosCell(
                  palette: palette,
                  count: count,
                  thumbB64: thumb,
                  decodeThumb: decodeThumb,
                  onAdd: () => onPickPhoto(row),
                  onDeleteRow: () => onDeleteRow(row),
                ),
              );
            }

            final text = cellTextAt(row, col);
            final hasGps = cellHasGps(row, col);
            final hasAudio = cellHasAudios(row, col);
            final thumbB64 = cellPhotoThumb(row, col);
            final hasPhoto = cellPhotoCount(row, col) > 0;
            final inlinePreview = cellInlinePreviewAt(row, col);
            final displayText = text.trim().isNotEmpty
                ? text
                : (inlinePreview == null
                    ? text
                    : '${inlinePreview.title} · ${inlinePreview.subtitle}');
            return _buildCard(
              context: ctx,
              width: cardW,
              isHeader: false,
              isActive: isActive,
              isSelected: isSelected,
              hasGps: hasGps,
              hasAudio: hasAudio,
              hasPhoto: inlinePreview == null && hasPhoto,
              zebra: row.isEven,
              photoThumbB64: inlinePreview == null ? thumbB64 : '',
              inlinePreview: inlinePreview,
              onTap: () => onCellTap(ctx, row, col),
              onLongPress: (pos) => onContextMenu(pos, row, col, false),
              onAttachmentsTap: () => onOpenAttachments(row, col),
              child: isActive
                  ? ValueListenableBuilder<TextEditingValue>(
                      valueListenable: activeController,
                      builder: (ctx, value, __) {
                        return _buildCardText(value.text, isHeader: false);
                      },
                    )
                  : _buildCardTextWithPreview(
                      displayText,
                      isHeader: false,
                      preview: inlinePreview,
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required double width,
    required bool isHeader,
    required bool isActive,
    required bool isSelected,
    required bool hasGps,
    required bool hasAudio,
    required bool hasPhoto,
    required bool zebra,
    required String photoThumbB64,
    required _CellInlinePreviewData? inlinePreview,
    required VoidCallback onTap,
    required ValueChanged<Offset> onLongPress,
    required VoidCallback? onAttachmentsTap,
    required Widget child,
  }) {
    final headerBg = palette.headerBg;
    final baseBg =
        isHeader ? headerBg : (zebra ? palette.zebraB : palette.zebraA);
    final activeBg = palette.selectionFill;
    final selectedBg = palette.selectionFill;
    final bg = isActive ? activeBg : (isSelected ? selectedBg : baseBg);

    final borderColor =
        (isActive || isSelected) ? palette.selectionBorder : palette.gridBorder;
    final lineWidth = math.max(palette.hairline, 1).toDouble();

    final radius = 6.0;

    Offset? lastTapPos;

    Widget badge(Widget inner, {VoidCallback? onTap}) {
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
        child: inner,
      );
      if (onTap == null) return chip;
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: chip,
      );
    }

    final badges = <Widget>[];
    if (inlinePreview == null &&
        (photoThumbB64.trim().isNotEmpty || hasPhoto)) {
      final bytes = decodeThumb(photoThumbB64);
      if (bytes != null) {
        badges.add(
          badge(
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Image.memory(
                bytes,
                width: 12,
                height: 12,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
              ),
            ),
            onTap: onAttachmentsTap,
          ),
        );
      } else if (hasPhoto) {
        badges.add(
          badge(
            Icon(Icons.photo_rounded, size: 12, color: palette.chipText),
            onTap: onAttachmentsTap,
          ),
        );
      }
    }
    if (hasAudio) {
      badges.add(
        badge(
          Icon(Icons.graphic_eq_rounded, size: 12, color: palette.chipText),
          onTap: onAttachmentsTap,
        ),
      );
    }
    if (hasGps) {
      badges.add(
        badge(
          Icon(Icons.my_location_rounded, size: 12, color: palette.chipText),
          onTap: onAttachmentsTap,
        ),
      );
    }

    final decoratedChild = badges.isEmpty
        ? child
        : Stack(
            children: [
              child,
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

    return SizedBox(
      width: width,
      height: _mobileCardH(density),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onTapDown: (d) => lastTapPos = d.globalPosition,
          onLongPress: () {
            final pos = lastTapPos ?? _fallbackTapPos(context);
            onLongPress(pos);
          },
          borderRadius: BorderRadius.circular(radius),
          hoverColor: palette.hoverBg,
          splashColor: palette.pressedBg,
          child: Ink(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor, width: lineWidth),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _mobileCardPadH(density),
                vertical: _mobileCardPadV(density),
              ),
              child: Container(
                foregroundDecoration: (isActive || isSelected)
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(color: palette.focusRing, width: 2),
                      )
                    : null,
                child: decoratedChild,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardTextWithPreview(
    String text, {
    required bool isHeader,
    _CellInlinePreviewData? preview,
  }) {
    if (isHeader || preview == null) {
      return _buildCardText(text, isHeader: isHeader);
    }
    final thumbBytes = preview.hasThumb ? decodeThumb(preview.thumbB64) : null;
    final leading = thumbBytes != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(
              thumbBytes,
              width: 18,
              height: 18,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
            ),
          )
        : Icon(preview.icon, size: 15, color: palette.cellTextMuted);
    return Row(
      children: [
        Expanded(
          child: _buildCardText(
            text,
            isHeader: isHeader,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          constraints: const BoxConstraints(maxWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: palette.chipBg,
            borderRadius: BorderRadius.circular(8),
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
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    '+${preview.extraCount}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.chipText,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardText(
    String text, {
    required bool isHeader,
    int maxLines = 2,
  }) {
    final t = text.trim();
    final display = t.isEmpty ? ' ' : t;
    return Text(
      display,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: isHeader ? palette.headerText : palette.cellText,
        fontWeight: isHeader ? FontWeight.w700 : FontWeight.w600,
        fontSize: _mobileTextSize(density, isHeader: isHeader),
        height: 1.05,
        letterSpacing: 0.0,
      ),
    );
  }

  String _labelHeader(List<String> headers, int c) {
    final t = headers[c].trim();
    if (t.isNotEmpty) return t;
    if (c == headers.length - 1) return kPhotosHeader;
    return 'Col ${c + 1}';
  }

  Offset _fallbackTapPos(BuildContext context) {
    final box = context.findRenderObject();
    if (box is RenderBox) {
      return box.localToGlobal(Offset.zero);
    }
    return Offset.zero;
  }
}
