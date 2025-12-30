import 'dart:typed_data';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'xlsx_saver_io.dart' if (dart.library.html) 'xlsx_saver_web.dart' as saver;

/// Resultado de guardado XLSX.
class ExportResult {
  final String fileName;
  final String? savedPathOrUri;
  final int bytesCount;

  const ExportResult({
    required this.fileName,
    required this.savedPathOrUri,
    required this.bytesCount,
  });
}

/// Exportador central de XLSX para Gridnote / Bitácora.
///
/// - Soporta números, fechas, bool y texto.
/// - Auto-ajusta columnas y filas.
/// - Aplica estilos mínimos compatibles con el diseño de la app.
/// - Usa saver específico por plataforma (IO / Web) vía import condicional.
final class XlsxExporter {
  /// Exporta a XLSX real. Auto-fit columnas y filas. Estilos mínimos.
  static Future<ExportResult> export({
    required List<String> headers,
    required List<List<dynamic>> rows,
    String sheetName = 'Mediciones',
    String baseFileName = 'bitflow_export',
    bool autoFit = true,
  }) async {
    final book = xlsio.Workbook(1);
    try {
      final ws = book.worksheets[0];
      ws.name = _safeSheetName(sheetName);

      // ---------- Encabezados ----------
      for (int c = 0; c < headers.length; c++) {
        ws.getRangeByIndex(1, c + 1).setText(headers[c]);
      }

      if (headers.isNotEmpty) {
        final head = ws.getRangeByIndex(1, 1, 1, headers.length);
        final hs = head.cellStyle;
        hs.bold = true;
        hs.hAlign = xlsio.HAlignType.center;
        hs.vAlign = xlsio.VAlignType.center;
        hs.backColor = '#F2F2F7'; // gris muy claro tipo header iOS
        hs.fontSize = 11;
        hs.borders.all.lineStyle = xlsio.LineStyle.thin;
      }

      // ---------- Datos ----------
      for (int r = 0; r < rows.length; r++) {
        final row = rows[r];
        for (int c = 0; c < headers.length; c++) {
          final cell = ws.getRangeByIndex(r + 2, c + 1);
          final v = c < row.length ? row[c] : null;

          if (v == null) {
            cell.setText('');
          } else if (v is num) {
            cell.setNumber(v.toDouble());
          } else if (v is DateTime) {
            cell.dateTime = v;
            cell.numberFormat = 'dd/mm/yyyy';
          } else if (v is bool) {
            cell.setText(v ? 'Sí' : 'No');
          } else {
            cell.setText(v.toString());
          }

          // Bordes de datos finos, discretos
          cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.hair;
        }
      }

      // ---------- Formatos automáticos por nombre de columna ----------
      for (int c = 0; c < headers.length; c++) {
        final name = headers[c].toLowerCase();
        final dataRange = ws.getRangeByIndex(
          2,
          c + 1,
          rows.isEmpty ? 2 : rows.length + 1,
          c + 1,
        );

        if (name.contains('ohm') ||
            name.contains('resist') ||
            name.contains('valor')) {
          dataRange.numberFormat = '#,##0.00';
        }
        if (name.contains('latitud') ||
            name.contains('longitud') ||
            name.contains('longitude')) {
          dataRange.numberFormat = '0.000000';
        }
      }

      // ---------- AutoFit ----------
      if (autoFit) {
        final range = ws.getRangeByIndex(
          1,
          1,
          rows.isEmpty ? 1 : rows.length + 1,
          headers.isEmpty ? 1 : headers.length,
        );
        range.autoFitColumns();
        range.autoFitRows();

        // ancho mínimo cómodo
        for (var c = 1; c <= (headers.isEmpty ? 1 : headers.length); c++) {
          final col = ws.getRangeByIndex(1, c);
          if (col.columnWidth < 12) {
            col.columnWidth = 12;
          }
        }
      }

      // ---------- Generar bytes y guardar ----------
      final bytesList = book.saveAsStream();
      final Uint8List bytes = Uint8List.fromList(bytesList);

      final stamped = '${_sanitize(baseFileName)}_${_ts()}';
      final saved = await saver.saveXlsx(stamped, bytes);

      return ExportResult(
        fileName: '$stamped.xlsx',
        savedPathOrUri: saved,
        bytesCount: bytes.length,
      );
    } finally {
      book.dispose();
    }
  }

  static String _safeSheetName(String s) {
    var t = s.trim();
    if (t.isEmpty) t = 'Sheet1';
    // Quitar caracteres inválidos para nombres de hoja.
    t = t.replaceAll(RegExp(r'[\\/\?\*\[\]:]'), ' ');
    return t.length > 31 ? t.substring(0, 31) : t;
  }

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  static String _ts() {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }
}
