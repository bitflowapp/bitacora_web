import 'dart:typed_data';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:file_saver/file_saver.dart';

/// Exportación XLSX real, simple y confiable.
/// - Tipado básico (DateTime, num, String)
/// - AutoFit de columnas
/// - Sanitiza sheetName para Excel (≤31 chars, sin []:*?/\)
/// - Soporta `fileName:` y `name:` (sin extensión)
class ExportXlsxService {
  static Future<void> download({
    String? fileName, // compat. retro
    String name = 'Gridnote',
    List<String> headers = const [],
    List<List<Object?>> rows = const [],
    String sheetName = 'Hoja1',
  }) async {
    final book = xlsio.Workbook();
    try {
      final sheet = book.worksheets[0];
      sheet.name = _safeSheetName(sheetName);

      // Encabezados
      if (headers.isNotEmpty) {
        for (var c = 0; c < headers.length; c++) {
          final cell = sheet.getRangeByIndex(1, c + 1);
          cell.setText(headers[c]);
          cell.cellStyle.bold = true;
        }
      }

      // Filas con tipado
      final startRow = headers.isNotEmpty ? 2 : 1;
      var maxCols = headers.isNotEmpty ? headers.length : 0;

      for (var r = 0; r < rows.length; r++) {
        final row = rows[r];
        if (row.length > maxCols) maxCols = row.length;

        for (var c = 0; c < row.length; c++) {
          final v = row[c];
          final cell = sheet.getRangeByIndex(startRow + r, c + 1);

          if (v == null) {
            cell.setText('');
          } else if (v is num) {
            cell.setNumber(v.toDouble());
          } else if (v is DateTime) {
            cell.setDateTime(v);
            cell.numberFormat = 'dd/mm/yyyy';
          } else {
            cell.setText(v.toString());
          }
        }
      }

      // AutoFit seguro
      final cols = (maxCols == 0 ? 1 : maxCols);
      for (var c = 1; c <= cols; c++) {
        try {
          sheet.autoFitColumn(c);
        } catch (_) {
          // algunos formatos vacíos pueden lanzar; se ignora
        }
      }

      // Guardar
      final bytes = Uint8List.fromList(book.saveAsStream());

      // Nombre final con extensión .xlsx asegurada
      final suggested = (fileName?.trim().isNotEmpty ?? false)
          ? fileName!.trim()
          : name.trim();
      final base = suggested.toLowerCase().endsWith('.xlsx')
          ? suggested.substring(0, suggested.length - 5)
          : suggested;

      await FileSaver.instance.saveFile(
        name: base,
        bytes: bytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    } finally {
      book.dispose();
    }
  }

  /// Excel: máximo 31 caracteres y no permite []:*?/\
  static String _safeSheetName(String input) {
    const invalid = r'[\[\]\:\*\?\\\/]';
    final sanitized = input.replaceAll(RegExp(invalid), '_');
    return sanitized.length <= 31 ? sanitized : sanitized.substring(0, 31);
  }
}
