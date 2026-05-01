import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'empty_state.dart';

class AppTableColumn<T> {
  const AppTableColumn({
    required this.label,
    required this.cellBuilder,
    this.minWidth = 160,
    this.alignment = Alignment.centerLeft,
    this.headerAlignment = Alignment.centerLeft,
    this.flex = 1,
  });

  final String label;
  final Widget Function(BuildContext context, T row) cellBuilder;
  final double minWidth;
  final Alignment alignment;
  final Alignment headerAlignment;
  final int flex;

  factory AppTableColumn.text({
    required String label,
    required String Function(T row) value,
    double minWidth = 160,
    Alignment alignment = Alignment.centerLeft,
    Alignment headerAlignment = Alignment.centerLeft,
    int flex = 1,
    int maxLines = 2,
  }) {
    return AppTableColumn<T>(
      label: label,
      minWidth: minWidth,
      alignment: alignment,
      headerAlignment: headerAlignment,
      flex: flex,
      cellBuilder: (context, row) => Text(
        value(row),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class AppTable<T> extends StatelessWidget {
  const AppTable({
    super.key,
    required this.columns,
    required this.rows,
    this.caption,
    this.emptyTitle = 'Sin datos',
    this.emptyMessage = 'Todav\u00eda no hay elementos para mostrar.',
    this.emptyActionLabel,
    this.onEmptyAction,
    this.maxHeight,
  });

  final List<AppTableColumn<T>> columns;
  final List<T> rows;
  final String? caption;
  final String emptyTitle;
  final String emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final validColumns = columns.where((column) => column.flex > 0).toList();

    if (validColumns.isEmpty) {
      return EmptyState(
        title: 'Tabla no disponible',
        message: 'No se definieron columnas para renderizar.',
        icon: Icons.table_chart_outlined,
      );
    }

    if (rows.isEmpty) {
      return EmptyState(
        title: emptyTitle,
        message: emptyMessage,
        icon: Icons.table_rows_outlined,
        actionLabel: emptyActionLabel,
        onAction: onEmptyAction,
      );
    }

    final totalMinWidth = validColumns.fold<double>(
      0,
      (sum, column) => sum + column.minWidth,
    );
    final headerTextStyle = t.text.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: t.colors.textSecondary,
      letterSpacing: 0.1,
    );
    final cellTextStyle = t.text.bodyMedium?.copyWith(
      color: t.colors.textPrimary,
      height: 1.3,
    );

    Widget buildHeader() {
      return Row(
        children: [
          for (final column in validColumns)
            SizedBox(
              width: column.minWidth,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Align(
                  alignment: column.headerAlignment,
                  child: Text(column.label, style: headerTextStyle),
                ),
              ),
            ),
        ],
      );
    }

    Widget buildRow(T row, int index) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: index.isEven ? t.colors.surface : t.colors.surfaceMuted,
          border: Border(
            top: BorderSide(color: t.colors.border),
          ),
        ),
        child: DefaultTextStyle(
          style: cellTextStyle ?? const TextStyle(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final column in validColumns)
                SizedBox(
                  width: column.minWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    child: Align(
                      alignment: column.alignment,
                      child: column.cellBuilder(context, row),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    Widget table = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: totalMinWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: t.colors.surfaceElevated,
                border: Border(
                  bottom: BorderSide(color: t.colors.border),
                ),
              ),
              child: buildHeader(),
            ),
            for (int i = 0; i < rows.length; i++) buildRow(rows[i], i),
          ],
        ),
      ),
    );

    if (maxHeight != null) {
      table = SizedBox(
        height: maxHeight,
        child: SingleChildScrollView(
          child: table,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((caption ?? '').trim().isNotEmpty) ...[
          Text(
            caption!.trim(),
            style: t.text.bodySmall?.copyWith(
              color: t.colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: t.colors.surface,
            borderRadius: BorderRadius.circular(t.radii.md),
            border: Border.all(color: t.colors.border),
          ),
          child: table,
        ),
      ],
    );
  }
}
