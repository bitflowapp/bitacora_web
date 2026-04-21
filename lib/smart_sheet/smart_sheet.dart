// lib/smart_sheet/smart_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';

// Tema Gridnote
import 'package:bitacora_web/theme/gridnote_theme.dart';

// Importes por paquete porque este archivo vive en lib/smart_sheet/
import 'package:bitacora_web/widgets/smart_datasource.dart';
import 'package:bitacora_web/widgets/validators.dart';
import 'package:bitacora_web/widgets/suggestions.dart';
import 'package:bitacora_web/services/export_xlsx_service.dart';

const double _kSmartGridRadius = 14;
const double _kSmartGridHeaderHeight = 42;
const double _kSmartGridRowHeight = 54;
const double _kSmartGridLineWidth = 0.65;

/// Hoja de cálculo avanzada con estilo tipo Apple.
class SmartSheet extends StatefulWidget {
  final GridnoteThemeController theme;
  final List<String> initialHeaders;
  final List<List<dynamic>> initialRows;
  final String sheetName;

  const SmartSheet({
    Key? key,
    required this.theme,
    required this.initialHeaders,
    required this.initialRows,
    this.sheetName = 'Hoja inteligente',
  }) : super(key: key);

  @override
  State<SmartSheet> createState() => _SmartSheetState();
}

class _SmartSheetState extends State<SmartSheet> {
  late List<String> _headers;
  late List<List<dynamic>> _rows;
  late SmartDataSource _dataSource;
  late List<double?> _totals;

  final GlobalKey<SfDataGridState> _gridKey = GlobalKey<SfDataGridState>();
  int _selectedRow = -1;

  @override
  void initState() {
    super.initState();

    _headers = List<String>.from(widget.initialHeaders);

    _rows = widget.initialRows.map((r) {
      final copy = List<dynamic>.from(r);
      if (copy.length < _headers.length) {
        copy.addAll(List<dynamic>.filled(_headers.length - copy.length, ''));
      } else if (copy.length > _headers.length) {
        copy.removeRange(_headers.length, copy.length);
      }
      return copy;
    }).toList();

    if (_rows.isEmpty) {
      _rows = [List<dynamic>.filled(_headers.length, '')];
    }

    _dataSource = SmartDataSource(
      headers: _headers,
      rows: _rows,
      onChanged: _onCellChanged,
      onRowSelected: _onRowSelected,
    );

    _computeTotals();
  }

  void _onCellChanged(int rowIndex, int colIndex, String value) {
    setState(() {
      if (rowIndex >= 0 &&
          rowIndex < _rows.length &&
          colIndex >= 0 &&
          colIndex < _headers.length) {
        _rows[rowIndex][colIndex] = value;
      }
      _computeTotals();
    });
  }

  void _onRowSelected(int rowIndex) {
    setState(() => _selectedRow = rowIndex);
  }

  void _computeTotals() {
    _totals = List<double?>.filled(_headers.length, null);
    for (int c = 0; c < _headers.length; c++) {
      final numeric = Validators.isNumericColumn(_headers[c], c);
      if (!numeric) continue;

      double total = 0.0;
      bool hasData = false;

      for (final row in _rows) {
        if (c >= row.length) continue;
        final v = row[c];
        if (v == null) continue;

        final num? parsed = num.tryParse(v.toString().replaceAll(',', '.'));
        if (parsed != null) {
          total += parsed.toDouble();
          hasData = true;
        }
      }
      _totals[c] = hasData ? total : null;
    }
  }

  void _addRow() {
    setState(() {
      final suggestion = Suggestions.suggestRow(_rows, _headers);
      _rows.add(suggestion ?? List<dynamic>.filled(_headers.length, ''));
      _dataSource.updateRows(_rows);
    });
    _computeTotals();
  }

  void _duplicateRow() {
    if (_selectedRow < 0 || _selectedRow >= _rows.length) return;
    setState(() {
      final original = _rows[_selectedRow];
      _rows.insert(_selectedRow + 1, List<dynamic>.from(original));
      _dataSource.updateRows(_rows);
    });
    _computeTotals();
  }

  void _removeRow() {
    if (_selectedRow < 0 || _selectedRow >= _rows.length) return;
    setState(() {
      _rows.removeAt(_selectedRow);
      if (_rows.isEmpty) {
        _rows.add(List<dynamic>.filled(_headers.length, ''));
      }
      _dataSource.updateRows(_rows);
    });
    _computeTotals();
  }

  void _clearAll() {
    setState(() {
      _rows
        ..clear()
        ..addAll(
          List<List<dynamic>>.generate(
            3,
            (_) => List<dynamic>.filled(_headers.length, ''),
          ),
        );
      _dataSource.updateRows(_rows);
    });
    _computeTotals();
  }

  Future<void> _export() async {
    await ExportXlsxService.download(
      fileName: '${widget.sheetName}.xlsx',
      headers: _headers,
      rows:
          _rows.map((r) => r.map((e) => e?.toString() ?? '').toList()).toList(),
    );
  }

  Widget _buildTotalsRow(GridnoteTableStyle t) {
    final cells = <Widget>[];

    cells.add(
      Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        height: _kSmartGridHeaderHeight,
        decoration: BoxDecoration(
          color: t.headerBg,
          border: Border(
            right: BorderSide(color: t.gridLine, width: _kSmartGridLineWidth),
            top: BorderSide(color: t.gridLine, width: _kSmartGridLineWidth),
          ),
        ),
        child: Text(
          'Σ',
          style: t.headerTextStyle?.copyWith(color: t.headerText),
        ),
      ),
    );

    for (int c = 0; c < _headers.length; c++) {
      final val = _totals[c];
      final text = val == null ? '' : val.toStringAsFixed(2);
      cells.add(
        Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          height: _kSmartGridHeaderHeight,
          decoration: BoxDecoration(
            color: t.headerBg,
            border: Border(
              right: BorderSide(color: t.gridLine, width: _kSmartGridLineWidth),
              top: BorderSide(color: t.gridLine, width: _kSmartGridLineWidth),
            ),
          ),
          child: Text(
            text,
            style: t.cellTextStyle?.copyWith(
              color: t.headerText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return Row(children: cells);
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Agregar fila (Ctrl+N)',
            onPressed: _addRow,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Duplicar fila (Ctrl+J)',
            onPressed: _duplicateRow,
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: 'Borrar fila (Ctrl+D)',
            onPressed: _removeRow,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: 'Limpiar (Ctrl+L)',
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Exportar XLSX (Ctrl+E)',
            onPressed: _export,
            icon: const Icon(Icons.file_download),
          ),
        ],
      ),
    );
  }

  Map<LogicalKeySet, Intent> get _shortcuts => {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
            const _AddRowIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyJ):
            const _DuplicateRowIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyD):
            const _DeleteRowIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyL):
            const _ClearAllIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyE):
            const _ExportIntent(),
      };

  Map<Type, Action<Intent>> get _actions => {
        _AddRowIntent: CallbackAction<_AddRowIntent>(onInvoke: (_) {
          _addRow();
          return null;
        }),
        _DuplicateRowIntent: CallbackAction<_DuplicateRowIntent>(onInvoke: (_) {
          _duplicateRow();
          return null;
        }),
        _DeleteRowIntent: CallbackAction<_DeleteRowIntent>(onInvoke: (_) {
          _removeRow();
          return null;
        }),
        _ClearAllIntent: CallbackAction<_ClearAllIntent>(onInvoke: (_) {
          _clearAll();
          return null;
        }),
        _ExportIntent: CallbackAction<_ExportIntent>(onInvoke: (_) {
          unawaited(_export());
          return null;
        }),
      };

  @override
  Widget build(BuildContext context) {
    final tableStyle = GridnoteTableStyle.from(widget.theme.theme);
    _dataSource.updateStyle(tableStyle);

    final isLight = widget.theme.theme.material.brightness == Brightness.light;
    final accent = widget.theme.theme.accent;
    final selectionColor = accent.withValues(alpha: 0.08);
    final hoverColor = accent.withValues(alpha: 0.045);

    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: _actions,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildToolbar(),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tableStyle.cellBg,
                  borderRadius: BorderRadius.circular(_kSmartGridRadius),
                  border: Border.all(
                    color: tableStyle.gridLine,
                    width: _kSmartGridLineWidth,
                  ),
                  boxShadow: [
                    if (isLight)
                      const BoxShadow(
                        blurRadius: 24,
                        offset: Offset(0, 12),
                        color: Color(0x0A111827),
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_kSmartGridRadius),
                  child: Column(
                    children: [
                      Expanded(
                        child: SfDataGridTheme(
                          data: SfDataGridThemeData(
                            headerColor: tableStyle.headerBg,
                            headerHoverColor: tableStyle.headerBg,
                            gridLineColor: tableStyle.gridLine,
                            gridLineStrokeWidth: _kSmartGridLineWidth,
                            selectionColor: selectionColor,
                            rowHoverColor: hoverColor,
                            currentCellStyle: DataGridCurrentCellStyle(
                              borderColor: accent.withValues(alpha: 0.32),
                              borderWidth: 1.1,
                            ),
                            frozenPaneLineColor: tableStyle.gridLine,
                            frozenPaneLineWidth: _kSmartGridLineWidth,
                            frozenPaneElevation: 0,
                          ),
                          child: SfDataGrid(
                            key: _gridKey,
                            source: _dataSource,
                            columnWidthMode: ColumnWidthMode.none,
                            allowEditing: true,
                            navigationMode: GridNavigationMode.cell,
                            selectionMode: SelectionMode.single,
                            onSelectionChanged: (added, removed) {
                              if (added.isNotEmpty) {
                                _dataSource.selectRow(added.first);
                              }
                            },
                            headerRowHeight: _kSmartGridHeaderHeight,
                            rowHeight: _kSmartGridRowHeight,
                            frozenColumnsCount: 1,
                            gridLinesVisibility: GridLinesVisibility.both,
                            headerGridLinesVisibility:
                                GridLinesVisibility.horizontal,
                            columns: _buildColumns(tableStyle),
                          ),
                        ),
                      ),
                      _buildTotalsRow(tableStyle),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<GridColumn> _buildColumns(GridnoteTableStyle t) {
    final List<GridColumn> cols = [];

    // Columna índice
    cols.add(
      GridColumn(
        columnName: '#',
        width: 60,
        label: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: t.headerBg,
            border: Border(
              bottom: BorderSide(
                color: t.gridLine,
                width: _kSmartGridLineWidth,
              ),
            ),
          ),
          child: Text(
            '#',
            style: t.headerTextStyle,
          ),
        ),
      ),
    );

    // Columnas dinámicas
    for (int i = 0; i < _headers.length; i++) {
      final header = _headers[i].isEmpty ? 'Col ${i + 1}' : _headers[i];
      cols.add(
        GridColumn(
          columnName: 'c$i',
          width: 180,
          label: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: t.headerBg,
              border: Border(
                bottom: BorderSide(
                  color: t.gridLine,
                  width: _kSmartGridLineWidth,
                ),
              ),
            ),
            child: Text(
              header.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.headerTextStyle,
            ),
          ),
        ),
      );
    }
    return cols;
  }
}

// ---------- Intents ----------
class _AddRowIntent extends Intent {
  const _AddRowIntent();
}

class _DuplicateRowIntent extends Intent {
  const _DuplicateRowIntent();
}

class _DeleteRowIntent extends Intent {
  const _DeleteRowIntent();
}

class _ClearAllIntent extends Intent {
  const _ClearAllIntent();
}

class _ExportIntent extends Intent {
  const _ExportIntent();
}
