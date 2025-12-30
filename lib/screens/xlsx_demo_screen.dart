// lib/screens/xlsx_demo_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';

import '../services/xlsx_exporter.dart';
import '../services/mail_share.dart';

class XlsxDemoScreen extends StatefulWidget {
  const XlsxDemoScreen({super.key});

  @override
  State<XlsxDemoScreen> createState() => _XlsxDemoScreenState();
}

class _XlsxDemoScreenState extends State<XlsxDemoScreen> {
  // Datos demo
  late final _rows = <_DemoRow>[
    _DemoRow(date: DateTime.now(), progresiva: '0+000', ohm3e: 12.4, ohm4e: 11.8, obs: ''),
    _DemoRow(date: DateTime.now(), progresiva: '0+025', ohm3e: 13.1, ohm4e: 12.6, obs: ''),
    _DemoRow(date: DateTime.now(), progresiva: '0+050', ohm3e: 14.7, ohm4e: 13.9, obs: ''),
    _DemoRow(date: DateTime.now(), progresiva: '0+075', ohm3e: 11.9, ohm4e: 11.2, obs: ''),
    _DemoRow(
      date: DateTime.now(),
      progresiva: '0+100',
      ohm3e: 15.0,
      ohm4e: 14.3,
      obs: 'Zona húmeda',
    ),
  ];

  late final _DemoDataSource _source = _DemoDataSource(_rows);

  String? _lastPathOrUri; // ruta en IO/desktop, nombre lógico en Web, o null
  bool _busy = false;

  // ---------- Exportar a XLSX ----------
  Future<void> _exportXlsx() async {
    if (_busy) return;
    setState(() => _busy = true);

    final headers = <String>[
      'Fecha',
      'Progresiva',
      '3 electrodos',
      '4 electrodos',
      'Observaciones',
    ];

    final rows = _rows
        .map((r) => <Object?>[
      _fmtDate(r.date),
      r.progresiva,
      r.ohm3e,
      r.ohm4e,
      r.obs,
    ])
        .toList();

    final res = await XlsxExporter.export(
      headers: headers,
      rows: rows,
      sheetName: 'Mediciones',
      baseFileName: 'Gridnote_Mediciones',
    );

    if (!mounted) return;

    setState(() {
      _lastPathOrUri = res.savedPathOrUri ?? res.fileName;
      _busy = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('XLSX guardado: ${res.fileName}')),
    );
  }

  // ---------- Enviar / compartir ----------
  Future<void> _sendEmail() async {
    if (_busy) return;
    setState(() => _busy = true);

    // Si aún no exportamos, exportamos primero
    if (_lastPathOrUri == null) {
      await _exportXlsx();
      if (!mounted) return;
    }

    final subject =
        'Mediciones Gridnote - ${DateTime.now().toIso8601String().substring(0, 10)}';
    const body = 'Adjunto XLSX generado desde Gridnote.';

    await MailShare.sendFile(
      filePath: _lastPathOrUri ?? 'gridnote.xlsx', // en Web se usa como nombre lógico
      subject: subject,
      body: body,
    );

    if (!mounted) return;
    setState(() => _busy = false);
  }

  String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo XLSX + Email'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _exportXlsx,
            tooltip: 'Exportar XLSX',
            icon: const Icon(Icons.save_alt),
          ),
          IconButton(
            onPressed: _busy ? null : _sendEmail,
            tooltip: 'Enviar/Compartir',
            icon: const Icon(Icons.send),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: SfDataGridTheme(
            data: const SfDataGridThemeData(
              headerColor: Color(0xFF1A1A1A),
            ),
            child: SfDataGrid(
              source: _source,
              headerGridLinesVisibility: GridLinesVisibility.both,
              gridLinesVisibility: GridLinesVisibility.both,
              columnWidthMode: ColumnWidthMode.fill,
              rowHeight: 44,
              headerRowHeight: 46,
              // OJO: lista SIN const porque GridColumn NO es const
              columns: [
                GridColumn(
                  columnName: 'Fecha',
                  label: const _HeaderLabel('Fecha'),
                ),
                GridColumn(
                  columnName: 'Progresiva',
                  label: const _HeaderLabel('Progresiva'),
                ),
                GridColumn(
                  columnName: '3 electrodos',
                  label: const _HeaderLabel('3 electrodos'),
                ),
                GridColumn(
                  columnName: '4 electrodos',
                  label: const _HeaderLabel('4 electrodos'),
                ),
                GridColumn(
                  columnName: 'Observaciones',
                  label: const _HeaderLabel('Observaciones'),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _busy
          ? FloatingActionButton(
        onPressed: null,
        child: const CircularProgressIndicator(),
      )
          : null,
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  final String text;
  const _HeaderLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _DemoRow {
  final DateTime date;
  final String progresiva;
  final double ohm3e;
  final double ohm4e;
  final String obs;

  _DemoRow({
    required this.date,
    required this.progresiva,
    required this.ohm3e,
    required this.ohm4e,
    required this.obs,
  });
}

class _DemoDataSource extends DataGridSource {
  _DemoDataSource(List<_DemoRow> rows)
      : _rows = rows
      .map(
        (r) => DataGridRow(
      cells: [
        DataGridCell<String>(columnName: 'Fecha', value: _fmtDate(r.date)),
        DataGridCell<String>(columnName: 'Progresiva', value: r.progresiva),
        DataGridCell<double>(columnName: '3 electrodos', value: r.ohm3e),
        DataGridCell<double>(columnName: '4 electrodos', value: r.ohm4e),
        DataGridCell<String>(columnName: 'Observaciones', value: r.obs),
      ],
    ),
  )
      .toList();

  final List<DataGridRow> _rows;

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final idx = _rows.indexOf(row);
    final bg = idx.isEven ? const Color(0xFF111315) : const Color(0xFF0E1012);
    return DataGridRowAdapter(
      color: bg,
      cells: row.getCells().map((cell) {
        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${cell.value}',
            style: const TextStyle(color: Colors.white),
          ),
        );
      }).toList(),
    );
  }

  static String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }
}
