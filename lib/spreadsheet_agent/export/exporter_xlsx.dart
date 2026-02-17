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

      final headerStyle = workbook.styles.add('sa_header');
      headerStyle.bold = true;
      headerStyle.backColor = '#E9EFF8';
      headerStyle.hAlign = xlsio.HAlignType.center;
      headerStyle.vAlign = xlsio.VAlignType.center;
      headerStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

      final textStyle = workbook.styles.add('sa_text');
      textStyle.borders.all.lineStyle = xlsio.LineStyle.hair;

      final dateStyle = workbook.styles.add('sa_date');
      dateStyle.borders.all.lineStyle = xlsio.LineStyle.hair;
      dateStyle.numberFormat = 'dd/mm/yyyy';

      final numberStyle = workbook.styles.add('sa_num');
      numberStyle.borders.all.lineStyle = xlsio.LineStyle.hair;
      numberStyle.numberFormat = '#,##0.00';

      final integerStyle = workbook.styles.add('sa_int');
      integerStyle.borders.all.lineStyle = xlsio.LineStyle.hair;
      integerStyle.numberFormat = '0';

      final currencyStyle = workbook.styles.add('sa_curr');
      currencyStyle.borders.all.lineStyle = xlsio.LineStyle.hair;
      currencyStyle.numberFormat = r'[$$-C0A] #,##0.00';

      for (var col = 0; col < template.fields.length; col++) {
        final field = template.fields[col];
        final cell = sheet.getRangeByIndex(1, col + 1);
        cell.setText(field.label);
        cell.cellStyle = headerStyle;
      }

      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        for (var col = 0; col < template.fields.length; col++) {
          final field = template.fields[col];
          final raw = (row[field.key] ?? '').trim();
          final cell = sheet.getRangeByIndex(rowIndex + 2, col + 1);

          switch (field.type) {
            case SpreadsheetFieldType.date:
              final date = parseLooseDate(raw);
              if (date != null) {
                cell.setDateTime(date);
                cell.cellStyle = dateStyle;
              } else {
                cell.setText(raw);
                cell.cellStyle = textStyle;
              }
              break;
            case SpreadsheetFieldType.number:
              final number = parseLooseNumber(raw);
              if (number != null) {
                cell.setNumber(number);
                cell.cellStyle = numberStyle;
              } else {
                cell.setText(raw);
                cell.cellStyle = textStyle;
              }
              break;
            case SpreadsheetFieldType.currency:
              final currency = parseLooseNumber(raw);
              if (currency != null) {
                cell.setNumber(currency);
                cell.cellStyle = currencyStyle;
              } else {
                cell.setText(raw);
                cell.cellStyle = textStyle;
              }
              break;
            case SpreadsheetFieldType.integer:
              final integer = parseLooseNumber(raw);
              if (integer != null && (integer % 1).abs() < 0.0001) {
                cell.setNumber(integer.truncateToDouble());
                cell.cellStyle = integerStyle;
              } else {
                cell.setText(raw);
                cell.cellStyle = textStyle;
              }
              break;
            case SpreadsheetFieldType.text:
              cell.setText(raw);
              cell.cellStyle = textStyle;
              break;
          }
        }
      }

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

  void _safeAutoFit(xlsio.Worksheet sheet, int column) {
    try {
      sheet.autoFitColumn(column);
    } catch (_) {}
  }

  void _applyMinWidth(xlsio.Worksheet sheet, int column, double minWidth) {
    final current = sheet.getRangeByIndex(1, column).columnWidth;
    if (current < minWidth) {
      sheet.getRangeByIndex(1, column).columnWidth = minWidth;
    }
  }

  double _suggestedMinWidth(SpreadsheetFieldType type) {
    switch (type) {
      case SpreadsheetFieldType.date:
        return 13;
      case SpreadsheetFieldType.number:
      case SpreadsheetFieldType.currency:
      case SpreadsheetFieldType.integer:
        return 12;
      case SpreadsheetFieldType.text:
        return 16;
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
    if (name.length > 31) name = name.substring(0, 31).trimRight();
    return name.isEmpty ? 'PLANILLA' : name;
  }
}
