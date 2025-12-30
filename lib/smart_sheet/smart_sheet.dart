// lib/smart_sheet/smart_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

// Tema Gridnote
import 'package:bitacora_web/theme/gridnote_theme.dart';

// Importes por paquete porque este archivo vive en lib/smart_sheet/
import 'package:bitacora_web/widgets/smart_datasource.dart';
import 'package:bitacora_web/widgets/validators.dart';
import 'package:bitacora_web/widgets/suggestions.dart';
import 'package:bitacora_web/services/export_xlsx_service.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 8),
        height: 40,
        decoration: BoxDecoration(
          color: t.headerBg,
          border: Border(
            right: BorderSide(color: t.gridLine),
            top: BorderSide(color: t.gridLine),
          ),
        ),
        child: const Text('Σ', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );

    for (int c = 0; c < _headers.length; c++) {
      final val = _totals[c];
      final text = val == null ? '' : val.toStringAsFixed(2);
      cells.add(
        Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 40,
          decoration: BoxDecoration(
            color: t.headerBg,
            border: Border(
              right: BorderSide(color: t.gridLine),
              top: BorderSide(color: t.gridLine),
            ),
          ),
          child:
              Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: tableStyle.gridLine.withOpacity(0.8)),
                  boxShadow: [
                    if (isLight)
                      const BoxShadow(
                        blurRadius: 20,
                        offset: Offset(0, 10),
                        color: Color(0x15000000),
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    children: [
                      Expanded(
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
                          headerRowHeight: 42,
                          rowHeight: 38,
                          frozenColumnsCount: 1,
                          gridLinesVisibility: GridLinesVisibility.both,
                          headerGridLinesVisibility: GridLinesVisibility.both,
                          columns: _buildColumns(tableStyle),
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
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: t.headerBg,
          child: Text(
            '#',
            style: TextStyle(color: t.headerText, fontWeight: FontWeight.w700),
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: t.headerBg,
            child: Text(
              header,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(color: t.headerText, fontWeight: FontWeight.w700),
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
