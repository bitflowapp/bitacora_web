import 'dart:typed_data';

import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../../services/save_xlsx.dart';
import '../spreadsheet_models.dart';

class SpreadsheetXlsxExporter {
  const SpreadsheetXlsxExporter();

  Future<SpreadsheetExportArtifact> export({
    required SpreadsheetTemplate template,
    required List<Map<String, String>> rows,
    String fileBaseName = 'agente_planillas',
  }) async {
    final workbook = xlsio.Workbook();
    try {
      final sheet = workbook.worksheets[0];
      sheet.name = _safeSheetName(template.name);
      _safeHideGridlines(sheet);

      final styles = _buildStyles(workbook);

      // Encabezados
      for (var col = 0; col < template.fields.length; col++) {
        final field = template.fields[col];
        final cell = sheet.getRangeByIndex(1, col + 1);
        cell.setText(field.label);
        cell.cellStyle = styles.header;
      }

      // Datos
      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        final excelRow = rowIndex + 2;
        final zebra = rowIndex.isEven ? _Zebra.even : _Zebra.odd;

        for (var col = 0; col < template.fields.length; col++) {
          final field = template.fields[col];
          final raw = (row[field.key] ?? '').trim();
          final cell = sheet.getRangeByIndex(excelRow, col + 1);

          _writeTypedCell(
            cell: cell,
            raw: raw,
            type: field.type,
            styles: styles,
            zebra: zebra,
          );
        }
      }

      // Congelar encabezado
      _safeFreezeHeader(sheet);

      // Ajustes finales de columnas
      for (var col = 0; col < template.fields.length; col++) {
        final excelCol = col + 1;
        _safeAutoFit(sheet, excelCol);
        _applyMinWidth(
          sheet,
          excelCol,
          _suggestedMinWidth(template.fields[col].type),
        );
      }

      final bytes = Uint8List.fromList(workbook.saveAsStream());

      final safeBaseName = _safeFileBaseName(fileBaseName);
      final fileName = '$safeBaseName.xlsx';
      final saved = await saveXlsx(fileName, bytes);

      return SpreadsheetExportArtifact(
        fileName: fileName,
        location: saved ?? fileName,
        bytes: bytes.length,
      );
    } finally {
      workbook.dispose();
    }
  }

  void _writeTypedCell({
    required xlsio.Range cell,
    required String raw,
    required SpreadsheetFieldType type,
    required _SpreadsheetStyles styles,
    required _Zebra zebra,
  }) {
    switch (type) {
      case SpreadsheetFieldType.date:
        final date = parseLooseDate(raw);
        if (date != null) {
          cell.setDateTime(date);
          cell.cellStyle =
          zebra == _Zebra.even ? styles.dateEven : styles.dateOdd;
        } else {
          cell.setText(raw);
          cell.cellStyle =
          zebra == _Zebra.even ? styles.textEven : styles.textOdd;
        }
        break;

      case SpreadsheetFieldType.number:
        final number = parseLooseNumber(raw);
        if (number != null) {
          cell.setNumber(number);
          cell.cellStyle =
          zebra == _Zebra.even ? styles.numberEven : styles.numberOdd;
        } else {
          cell.setText(raw);
          cell.cellStyle =
          zebra == _Zebra.even ? styles.textEven : styles.textOdd;
        }
        break;

      case SpreadsheetFieldType.currency:
        final currency = parseLooseNumber(raw);
        if (currency != null) {
          cell.setNumber(currency);
          cell.cellStyle =
          zebra == _Zebra.even ? styles.currencyEven : styles.currencyOdd;
        } else {
          cell.setText(raw);
          cell.cellStyle =
          zebra == _Zebra.even ? styles.textEven : styles.textOdd;
        }
        break;

      case SpreadsheetFieldType.integer:
        final integer = parseLooseNumber(raw);
        if (integer != null && (integer % 1).abs() < 0.0001) {
          cell.setNumber(integer.truncateToDouble());
          cell.cellStyle =
          zebra == _Zebra.even ? styles.integerEven : styles.integerOdd;
        } else {
          cell.setText(raw);
          cell.cellStyle =
          zebra == _Zebra.even ? styles.textEven : styles.textOdd;
        }
        break;

      case SpreadsheetFieldType.text:
        cell.setText(raw);
        cell.cellStyle =
        zebra == _Zebra.even ? styles.textEven : styles.textOdd;
        break;
    }
  }

  _SpreadsheetStyles _buildStyles(xlsio.Workbook workbook) {
    final header = workbook.styles.add('sa_header');
    header.bold = true;
    header.fontSize = 11;
    header.backColor = '#E8EEF7';
    header.fontColor = '#253244';
    header.hAlign = xlsio.HAlignType.center;
    header.vAlign = xlsio.VAlignType.center;
    header.borders.all.lineStyle = xlsio.LineStyle.thin;

    final textEven = workbook.styles.add('sa_text_even');
    _configureBaseDataStyle(
      textEven,
      backColor: '#FFFFFF',
      hAlign: xlsio.HAlignType.left,
    );

    final textOdd = workbook.styles.add('sa_text_odd');
    _configureBaseDataStyle(
      textOdd,
      backColor: '#F7F9FC',
      hAlign: xlsio.HAlignType.left,
    );

    final dateEven = workbook.styles.add('sa_date_even');
    _configureBaseDataStyle(
      dateEven,
      backColor: '#FFFFFF',
      hAlign: xlsio.HAlignType.center,
      numberFormat: 'dd/mm/yyyy',
    );

    final dateOdd = workbook.styles.add('sa_date_odd');
    _configureBaseDataStyle(
      dateOdd,
      backColor: '#F7F9FC',
      hAlign: xlsio.HAlignType.center,
      numberFormat: 'dd/mm/yyyy',
    );

    final numberEven = workbook.styles.add('sa_num_even');
    _configureBaseDataStyle(
      numberEven,
      backColor: '#FFFFFF',
      hAlign: xlsio.HAlignType.right,
      numberFormat: '#,##0.00',
    );

    final numberOdd = workbook.styles.add('sa_num_odd');
    _configureBaseDataStyle(
      numberOdd,
      backColor: '#F7F9FC',
      hAlign: xlsio.HAlignType.right,
      numberFormat: '#,##0.00',
    );

    final integerEven = workbook.styles.add('sa_int_even');
    _configureBaseDataStyle(
      integerEven,
      backColor: '#FFFFFF',
      hAlign: xlsio.HAlignType.right,
      numberFormat: '0',
    );

    final integerOdd = workbook.styles.add('sa_int_odd');
    _configureBaseDataStyle(
      integerOdd,
      backColor: '#F7F9FC',
      hAlign: xlsio.HAlignType.right,
      numberFormat: '0',
    );

    final currencyEven = workbook.styles.add('sa_curr_even');
    _configureBaseDataStyle(
      currencyEven,
      backColor: '#FFFFFF',
      hAlign: xlsio.HAlignType.right,
      numberFormat: r'[$$-C0A] #,##0.00',
    );

    final currencyOdd = workbook.styles.add('sa_curr_odd');
    _configureBaseDataStyle(
      currencyOdd,
      backColor: '#F7F9FC',
      hAlign: xlsio.HAlignType.right,
      numberFormat: r'[$$-C0A] #,##0.00',
    );

    return _SpreadsheetStyles(
      header: header,
      textEven: textEven,
      textOdd: textOdd,
      dateEven: dateEven,
      dateOdd: dateOdd,
      numberEven: numberEven,
      numberOdd: numberOdd,
      integerEven: integerEven,
      integerOdd: integerOdd,
      currencyEven: currencyEven,
      currencyOdd: currencyOdd,
    );
  }

  void _configureBaseDataStyle(
      xlsio.Style style, {
        required String backColor,
        required xlsio.HAlignType hAlign,
        String? numberFormat,
      }) {
    style.backColor = backColor;
    style.fontSize = 10.5;
    style.fontColor = '#1F2937';
    style.hAlign = hAlign;
    style.vAlign = xlsio.VAlignType.center;
    style.borders.all.lineStyle = xlsio.LineStyle.hair;
    if (numberFormat != null) {
      style.numberFormat = numberFormat;
    }
  }

  void _safeHideGridlines(xlsio.Worksheet sheet) {
    try {
      sheet.showGridlines = false;
    } catch (_) {}
  }

  void _safeFreezeHeader(xlsio.Worksheet sheet) {
    try {
      sheet.getRangeByIndex(2, 1).freezePanes();
    } catch (_) {}
  }

  void _safeAutoFit(xlsio.Worksheet sheet, int column) {
    try {
      sheet.autoFitColumn(column);
    } catch (_) {}
  }

  void _applyMinWidth(xlsio.Worksheet sheet, int column, double minWidth) {
    final range = sheet.getRangeByIndex(1, column);
    if (range.columnWidth < minWidth) {
      range.columnWidth = minWidth;
    }
  }

  double _suggestedMinWidth(SpreadsheetFieldType type) {
    switch (type) {
      case SpreadsheetFieldType.date:
        return 13;
      case SpreadsheetFieldType.number:
      case SpreadsheetFieldType.integer:
        return 12;
      case SpreadsheetFieldType.currency:
        return 14;
      case SpreadsheetFieldType.text:
        return 18;
    }
  }

  String _safeFileBaseName(String raw) {
    final base = raw.trim().isEmpty ? 'agente_planillas' : raw.trim();
    final cleaned = base
        .replaceAll(RegExp(r'\.xlsx$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');

    return cleaned.isEmpty ? 'agente_planillas' : cleaned;
  }

  String _safeSheetName(String raw) {
    var name = raw
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\[\]]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    if (name.isEmpty) name = 'PLANILLA';
    if (name.length > 31) {
      name = name.substring(0, 31).trimRight();
    }

    return name.isEmpty ? 'PLANILLA' : name;
  }
}

enum _Zebra { even, odd }

class _SpreadsheetStyles {
  const _SpreadsheetStyles({
    required this.header,
    required this.textEven,
    required this.textOdd,
    required this.dateEven,
    required this.dateOdd,
    required this.numberEven,
    required this.numberOdd,
    required this.integerEven,
    required this.integerOdd,
    required this.currencyEven,
    required this.currencyOdd,
  });

  final xlsio.Style header;
  final xlsio.Style textEven;
  final xlsio.Style textOdd;
  final xlsio.Style dateEven;
  final xlsio.Style dateOdd;
  final xlsio.Style numberEven;
  final xlsio.Style numberOdd;
  final xlsio.Style integerEven;
  final xlsio.Style integerOdd;
  final xlsio.Style currencyEven;
  final xlsio.Style currencyOdd;
}