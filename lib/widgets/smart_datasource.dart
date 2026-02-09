// lib/widgets/smart_data_source.dart
import 'dart:async' show Timer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:bitacora_web/theme/gridnote_theme.dart';
import 'validators.dart';

typedef CellChanged = void Function(int rowIndex, int colIndex, String value);
typedef RowSelected = void Function(int rowIndex);

class SmartDataSource extends DataGridSource {
  SmartDataSource({
    required List<String> headers,
    required List<List<dynamic>> rows,
    required this.onChanged,
    required this.onRowSelected,
  })  : _headers = List<String>.from(headers),
        _rows = rows.map((r) => r.map((e) => e.toString()).toList()).toList() {
    _normalizeAll();
    _rebuildDgRows();
  }

  // ---- Modelo ----
  List<String> _headers;
  List<List<String>> _rows;

  List<String> get headers => List.unmodifiable(_headers);
  List<List<String>> get dataRows =>
      _rows.map((r) => List<String>.from(r)).toList(growable: false);

  final CellChanged onChanged;
  final RowSelected onRowSelected;

  // ---- Estilo opcional ----
  GridnoteTableStyle? _style;
  void updateStyle(GridnoteTableStyle s) {
    _style = s;
    notifyListeners();
  }

  // ---- Controladores por celda ----
  final Map<String, TextEditingController> _ctls = {};
  String _k(int r, int c) => '$r:$c';

  void disposeControllers() {
    for (final c in _ctls.values) c.dispose();
    _ctls.clear();
  }

  void _pruneOrReuseControllers() {
    final keep = <String>{};
    for (int r = 0; r < _rows.length; r++) {
      for (int c = 0; c < _headers.length; c++) {
        keep.add(_k(r, c));
      }
    }
    final remove = <String>[];
    _ctls.forEach((k, _) {
      if (!keep.contains(k)) remove.add(k);
    });
    for (final k in remove) {
      _ctls.remove(k)?.dispose();
    }
  }

  // ---- API externa para sincronizar ----
  void updateHeaders(List<String> headers) {
    _headers = List<String>.from(headers);
    _normalizeAll();
    _pruneOrReuseControllers();
    _rebuildDgRows();
    notifyListeners();
  }

  void updateRows(List<List<dynamic>> rows) {
    _rows = rows.map((r) => r.map((e) => e.toString()).toList()).toList();
    _normalizeAll();
    _pruneOrReuseControllers();
    _rebuildDgRows();
    notifyListeners();
  }

  void setCell(int r, int c, String v) {
    if (r < 0 || r >= _rows.length) return;
    if (c < 0 || c >= _headers.length) return;
    _rows[r][c] = v;
    onChanged(r, c, v);
    notifyListeners();
  }

  void addEmptyRow() {
    _rows.add(List<String>.filled(_headers.length, ''));
    _rebuildDgRows();
    notifyListeners();
  }

  void removeRowAt(int r) {
    if (_rows.isEmpty) return;
    final i = r.clamp(0, _rows.length - 1);
    _rows.removeAt(i);
    if (_rows.isEmpty) addEmptyRow();
    _rebuildDgRows();
    notifyListeners();
  }

  // ---- DataGridSource ----
  late List<DataGridRow> _dgRows;
  @override
  List<DataGridRow> get rows => _dgRows;

  void _rebuildDgRows() {
    _dgRows = List<DataGridRow>.generate(_rows.length, (r) {
      final cells = <DataGridCell>[
        DataGridCell<int>(columnName: '#', value: r + 1),
        for (int c = 0; c < _headers.length; c++)
          DataGridCell<String>(columnName: 'c$c', value: _rows[r][c]),
      ];
      return DataGridRow(cells: cells);
    });
  }

  int _rowIndex(DataGridRow row) {
    final cell = row.getCells().firstWhere(
          (e) => e.columnName == '#',
          orElse: () => const DataGridCell<int>(columnName: '#', value: 0),
        );
    return ((cell.value ?? 0) as int) - 1;
  }

  void selectRow(DataGridRow row) {
    final idx = _rowIndex(row);
    if (idx >= 0) onRowSelected(idx);
  }

  void _normalizeAll() {
    for (int r = 0; r < _rows.length; r++) {
      final row = _rows[r];
      if (row.length < _headers.length) {
        row.addAll(List<String>.filled(_headers.length - row.length, ''));
      } else if (row.length > _headers.length) {
        row.removeRange(_headers.length, row.length);
      }
    }
    if (_rows.isEmpty) {
      _rows.add(List<String>.filled(_headers.length, ''));
    }
  }

  // Debounce para onChanged intensivo
  final _debounce = _Debouncer(const Duration(milliseconds: 200));

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final r = _rowIndex(row);
    final t = _style;

    final zebra = (t?.zebra ?? true) && r.isEven;
    final bg =
        zebra ? (t?.zebraColor ?? const Color(0x0C000000)) : Colors.transparent;

    return DataGridRowAdapter(cells: <Widget>[
      _indexCell(r, bg),
      for (int c = 0; c < _headers.length; c++) _editCell(r, c, bg, t),
    ]);
  }

  Widget _indexCell(int r, Color bg) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: bg,
      child: Text(
        '${r + 1}',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
    );
  }

  Widget _editCell(int r, int c, Color bg, GridnoteTableStyle? t) {
    final key = _k(r, c);
    final txt = _rows[r][c];
    final ctl = _ctls.putIfAbsent(key, () => TextEditingController(text: txt));
    if (ctl.text != txt) ctl.text = txt;

    final isNum = Validators.isNumericColumn(_headers[c], c);
    final inputFmt = isNum
        ? <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))
          ]
        : const <TextInputFormatter>[];

    return Container(
      alignment: isNum ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: bg,
      child: TextField(
        controller: ctl,
        maxLines: 1,
        textAlign: isNum ? TextAlign.right : TextAlign.left,
        keyboardType: isNum
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        inputFormatters: inputFmt,
        decoration:
            const InputDecoration(isDense: true, border: InputBorder.none),
        style: const TextStyle(fontSize: 13.5),
        onChanged: (v) {
          _rows[r][c] = v;
          _debounce(() => onChanged(r, c, v));
          // Auto-nueva fila si se escribe en la última y hay algo
          final last = r == _rows.length - 1;
          if (last && _rows[r].any((e) => e.trim().isNotEmpty)) {
            addEmptyRow();
          }
        },
      ),
    );
  }
}

// ---- Util ----
class _Debouncer {
  _Debouncer(this.duration);
  final Duration duration;
  Timer? _t;
  void call(void Function() f) {
    _t?.cancel();
    _t = Timer(duration, f);
  }
}
