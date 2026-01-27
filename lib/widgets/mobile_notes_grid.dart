part of '../screens/editor_screen.dart';

const double _kMobileCardMinW = 110.0;
const double _kMobileCardMaxW = 140.0;
const double _kMobileCardH = 52.0;
const double _kMobileCardGap = 0.0;
const double _kMobileRowPadH = 0.0;
const double _kMobileRowPadV = 0.0;
const double _kMobileRowSpacing = 0.0;
const double _kMobileRowH = _kMobileCardH + (_kMobileRowPadV * 2);
const double _kMobileHeaderRowH = _kMobileRowH;

double _mobileCardWidthForScreen(double screenW) {
  final raw = screenW * 0.34;
  final clamped = raw.clamp(_kMobileCardMinW, _kMobileCardMaxW);
  return clamped.toDouble();
}

int _alphaFor(double opacity) => (opacity * 255).round();

class _MobileNotesGrid extends StatelessWidget {
  const _MobileNotesGrid({
    required this.palette,
    required this.headers,
    required this.rowModels,
    required this.cellTextAt,
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
  });

  final _SheetPalette palette;
  final List<String> headers;
  final List<_RowModel> rowModels;
  final String Function(int r, int c) cellTextAt;

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

  @override
  Widget build(BuildContext context) {
    assert(rowScrollControllers.length >= rowModels.length);
    assert(rowKeys.length >= rowModels.length);

    return ListView.separated(
      controller: verticalController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
      itemCount: rowModels.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: _kMobileRowSpacing),
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
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    final cardW = _mobileCardWidthForScreen(MediaQuery.of(context).size.width);
    return SizedBox(
      height: _kMobileHeaderRowH,
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          onHorizontalScroll(headerScrollController.offset, true, -1);
          return false;
        },
        child: ListView.separated(
          controller: headerScrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
              horizontal: _kMobileRowPadH, vertical: _kMobileRowPadV),
          itemCount: headers.length,
          separatorBuilder: (_, __) => const SizedBox(width: _kMobileCardGap),
          itemBuilder: (ctx, col) {
            final label = _labelHeader(headers, col);
            final isActive = activeIsHeader && activeCol == col;
            return _buildCard(
              context: ctx,
              width: cardW,
              isHeader: true,
              isActive: isActive,
              isSelected: false,
              onTap: () => onHeaderTap(ctx, col),
              onLongPress: (pos) =>
                  onContextMenu(pos, -1, col, true),
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
    final cardW = _mobileCardWidthForScreen(MediaQuery.of(context).size.width);
    return SizedBox(
      height: _kMobileRowH,
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          onHorizontalScroll(rowScrollControllers[row].offset, false, row);
          return false;
        },
        child: ListView.separated(
          controller: rowScrollControllers[row],
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
              horizontal: _kMobileRowPadH, vertical: _kMobileRowPadV),
          itemCount: headers.length,
          separatorBuilder: (_, __) => const SizedBox(width: _kMobileCardGap),
          itemBuilder: (ctx, col) {
            final isPhotos = col == headers.length - 1;
            final isActive =
                !activeIsHeader && activeRow == row && activeCol == col;
            final isSelected = row == selectedRow && col == selectedCol;

            if (isPhotos) {
              final photos = rowModels[row].photos;
              final thumb = photos.isNotEmpty ? photos.last.thumbB64 : '';
              return _buildCard(
                context: ctx,
                width: cardW,
                isHeader: false,
                isActive: false,
                isSelected: isSelected,
                onTap: () => onCellTap(ctx, row, col),
                onLongPress: (pos) =>
                    onContextMenu(pos, row, col, false),
                child: _PhotosCell(
                  palette: palette,
                  count: photos.length,
                  thumbB64: thumb,
                  onAdd: () => onPickPhoto(row),
                  onDeleteRow: () => onDeleteRow(row),
                ),
              );
            }

            final text = cellTextAt(row, col);
            return _buildCard(
              context: ctx,
              width: cardW,
              isHeader: false,
              isActive: isActive,
              isSelected: isSelected,
              onTap: () => onCellTap(ctx, row, col),
              onLongPress: (pos) => onContextMenu(pos, row, col, false),
              child: isActive
                  ? ValueListenableBuilder<TextEditingValue>(
                      valueListenable: activeController,
                      builder: (ctx, value, __) {
                        return _buildCardText(value.text, isHeader: false);
                      },
                    )
                  : _buildCardText(text, isHeader: false),
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
    required VoidCallback onTap,
    required ValueChanged<Offset> onLongPress,
    required Widget child,
  }) {
    final headerBg = palette.isLight
        ? const Color(0xFFF4F0E6)
        : palette.headerBg;
    final cellBg = palette.isLight
        ? const Color(0xFFFFFFFF)
        : palette.cellBg;
    final activeBg = palette.isLight
        ? const Color(0xFFFDF4E2)
        : palette.cellBg;
    final bg = isActive ? activeBg : (isHeader ? headerBg : cellBg);

    final borderColor = isActive
        ? palette.accent.withAlpha(_alphaFor(0.7))
        : (palette.isLight
            ? const Color(0xFFE0E0E0)
            : palette.borderStrong);

    Offset? lastTapPos;

    return SizedBox(
      width: width,
      height: _kMobileCardH,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onTapDown: (d) => lastTapPos = d.globalPosition,
          onLongPress: () {
            final pos = lastTapPos ?? _fallbackTapPos(context);
            onLongPress(pos);
          },
          borderRadius: BorderRadius.circular(1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(1),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildCardText(String text, {required bool isHeader}) {
    final t = text.trim();
    final display = t.isEmpty ? ' ' : t;
    return Text(
      display,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: palette.fg,
        fontWeight: isHeader ? FontWeight.w800 : FontWeight.w600,
        fontSize: isHeader ? 13.0 : 13.0,
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
