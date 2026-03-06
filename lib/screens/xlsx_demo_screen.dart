// lib/screens/xlsx_demo_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../services/mail_share.dart';
import '../services/xlsx_exporter.dart';

class XlsxDemoScreen extends StatefulWidget {
  const XlsxDemoScreen({super.key});

  @override
  State<XlsxDemoScreen> createState() => _XlsxDemoScreenState();
}

class _XlsxDemoScreenState extends State<XlsxDemoScreen> {
  late final List<_DemoRow> _rows = <_DemoRow>[
    _DemoRow(
      date: DateTime.now(),
      progresiva: '0+000',
      ohm3e: 12.4,
      ohm4e: 11.8,
      obs: '',
    ),
    _DemoRow(
      date: DateTime.now(),
      progresiva: '0+025',
      ohm3e: 13.1,
      ohm4e: 12.6,
      obs: '',
    ),
    _DemoRow(
      date: DateTime.now(),
      progresiva: '0+050',
      ohm3e: 14.7,
      ohm4e: 13.9,
      obs: '',
    ),
    _DemoRow(
      date: DateTime.now(),
      progresiva: '0+075',
      ohm3e: 11.9,
      ohm4e: 11.2,
      obs: '',
    ),
    _DemoRow(
      date: DateTime.now(),
      progresiva: '0+100',
      ohm3e: 15.0,
      ohm4e: 14.3,
      obs: 'Zona húmeda',
    ),
  ];

  late final _DemoDataSource _source = _DemoDataSource(_rows);

  String? _lastPathOrUri;
  String? _lastFileName;
  bool _busy = false;

  List<String> get _headers => const <String>[
        'Fecha',
        'Progresiva',
        '3 electrodos',
        '4 electrodos',
        'Observaciones',
      ];

  List<List<Object?>> get _exportRows => _rows
      .map(
        (r) => <Object?>[
          _fmtDate(r.date),
          r.progresiva,
          r.ohm3e,
          r.ohm4e,
          r.obs,
        ],
      )
      .toList(growable: false);

  void _snack(String message) {
    if (!mounted) return;
    final text = message.trim();
    if (text.isEmpty) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text)),
      );
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _performExport() async {
    final res = await XlsxExporter.export(
      headers: _headers,
      rows: _exportRows,
      sheetName: 'Mediciones',
      baseFileName: 'BitFlow_Mediciones',
    );

    if (!mounted) return;

    setState(() {
      _lastPathOrUri = res.savedPathOrUri ?? res.fileName;
      _lastFileName = res.fileName;
    });

    _snack('XLSX guardado: ${res.fileName}');
  }

  Future<void> _ensureExported() async {
    if ((_lastPathOrUri ?? '').trim().isNotEmpty) return;
    await _performExport();
  }

  Future<void> _exportXlsx() async {
    await _runBusy(() async {
      try {
        await _performExport();
      } catch (_) {
        _snack('No se pudo exportar el XLSX.');
      }
    });
  }

  Future<void> _sendEmail() async {
    await _runBusy(() async {
      try {
        await _ensureExported();

        final filePath = (_lastPathOrUri ?? '').trim();
        if (filePath.isEmpty) {
          _snack('No se pudo preparar el archivo para compartir.');
          return;
        }

        final subject =
            'Mediciones BitFlow - ${DateTime.now().toIso8601String().substring(0, 10)}';
        const body = 'Adjunto XLSX generado desde BitFlow.';

        await MailShare.sendFile(
          filePath: filePath,
          subject: subject,
          body: body,
        );

        final name = (_lastFileName ?? 'bitflow_mediciones.xlsx').trim();
        _snack('Archivo enviado/compartido: $name');
      } catch (_) {
        _snack('No se pudo enviar o compartir el archivo.');
      }
    });
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
          if (_busy)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.08),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
        ],
      ),
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
            .asMap()
            .entries
            .map(
              (entry) => _IndexedGridRow(
                index: entry.key,
                row: DataGridRow(
                  cells: [
                    DataGridCell<String>(
                      columnName: 'Fecha',
                      value: _fmtDate(entry.value.date),
                    ),
                    DataGridCell<String>(
                      columnName: 'Progresiva',
                      value: entry.value.progresiva,
                    ),
                    DataGridCell<double>(
                      columnName: '3 electrodos',
                      value: entry.value.ohm3e,
                    ),
                    DataGridCell<double>(
                      columnName: '4 electrodos',
                      value: entry.value.ohm4e,
                    ),
                    DataGridCell<String>(
                      columnName: 'Observaciones',
                      value: entry.value.obs,
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false);

  final List<_IndexedGridRow> _rows;

  @override
  List<DataGridRow> get rows =>
      _rows.map((item) => item.row).toList(growable: false);

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final item = _rows.firstWhere((element) => identical(element.row, row));
    final bg =
        item.index.isEven ? const Color(0xFF111315) : const Color(0xFF0E1012);

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
      }).toList(growable: false),
    );
  }

  static String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }
}

class _IndexedGridRow {
  const _IndexedGridRow({
    required this.index,
    required this.row,
  });

  final int index;
  final DataGridRow row;
}
