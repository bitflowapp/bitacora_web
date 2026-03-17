import 'dart:typed_data';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'xlsx_saver_io.dart' if (dart.library.html) 'xlsx_saver_web.dart'
as saver;

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

/// Fila rica para exportación corporativa con multimedia.
class EnterpriseMediaRow {
  final String id;
  final DateTime? date;
  final String location;
  final double? latitude;
  final double? longitude;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final Uint8List? videoThumbnailBytes;
  final String? videoUrl;
  final double? resistanceOhm;
  final String observations;

  const EnterpriseMediaRow({
    required this.id,
    required this.date,
    required this.location,
    required this.latitude,
    required this.longitude,
    this.photoBytes,
    this.photoUrl,
    this.videoThumbnailBytes,
    this.videoUrl,
    this.resistanceOhm,
    this.observations = '',
  });

  String? get mapsUrl {
    final lat = latitude;
    final lon = longitude;
    if (lat == null || lon == null) return null;
    final q = Uri.encodeComponent('${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}');
    return 'https://www.google.com/maps/search/?api=1&query=$q';
  }
}

/// Exportador central de XLSX para Gridnote / Bit Flow.
final class XlsxExporter {
  /// Exportador básico genérico.
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

      for (int c = 0; c < headers.length; c++) {
        ws.getRangeByIndex(1, c + 1).setText(headers[c]);
      }

      if (headers.isNotEmpty) {
        final head = ws.getRangeByIndex(1, 1, 1, headers.length);
        final hs = head.cellStyle;
        hs.bold = true;
        hs.hAlign = xlsio.HAlignType.center;
        hs.vAlign = xlsio.VAlignType.center;
        hs.backColor = '#F2F2F7';
        hs.fontSize = 11;
        hs.borders.all.lineStyle = xlsio.LineStyle.thin;
      }

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

          cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.hair;
        }
      }

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

      if (autoFit) {
        final range = ws.getRangeByIndex(
          1,
          1,
          rows.isEmpty ? 1 : rows.length + 1,
          headers.isEmpty ? 1 : headers.length,
        );
        range.autoFitColumns();
        range.autoFitRows();

        for (int c = 1; c <= (headers.isEmpty ? 1 : headers.length); c++) {
          final col = ws.getRangeByIndex(1, c);
          if (col.columnWidth < 12) {
            col.columnWidth = 12;
          }
        }
      }

      final bytesList = book.saveAsStream();
      final bytes = Uint8List.fromList(bytesList);

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

  /// Exportación corporativa con estética tipo la imagen:
  /// - título grande
  /// - bloques de metadata
  /// - tabla técnica
  /// - foto embebida
  /// - miniatura de video con link
  /// - GPS enlazado a Maps
  static Future<ExportResult> exportEnterpriseMediaReport({
    required List<EnterpriseMediaRow> rows,
    String title = 'Mediciones de Neuquén Capital',
    String company = 'Luna Ing / Bit Flow',
    String project = 'Relevamiento técnico',
    String operatorName = 'Operador',
    String sheetName = 'Mediciones',
    String baseFileName = 'bitflow_enterprise_report',
    Uint8List? logoBytes,
  }) async {
    final book = xlsio.Workbook(1);

    try {
      final ws = book.worksheets[0];
      ws.name = _safeSheetName(sheetName);
      ws.showGridlines = false;
      ws.tabColor = '#2F6D5C';

      ws.pageSetup.orientation = xlsio.ExcelPageOrientation.landscape;
      ws.pageSetup.isFitToPage = true;
      ws.pageSetup.fitToPagesWide = 1;
      ws.pageSetup.leftMargin = 0.25;
      ws.pageSetup.rightMargin = 0.25;
      ws.pageSetup.topMargin = 0.35;
      ws.pageSetup.bottomMargin = 0.35;
      ws.pageSetup.showGridlines = false;

      _setColumnsForEnterpriseLayout(ws);

      // Fondo general sutil.
      final fullBg = ws.getRangeByName('A1:I200');
      fullBg.cellStyle.backColor = '#F7F8FA';

      // Banda superior verde.
      final titleRange = ws.getRangeByName('A1:I2');
      titleRange.merge();
      titleRange.setText(title);
      final titleStyle = titleRange.cellStyle;
      titleStyle.backColor = '#2F6D5C';
      titleStyle.fontColor = '#FFFFFF';
      titleStyle.bold = true;
      titleStyle.fontSize = 20;
      titleStyle.hAlign = xlsio.HAlignType.center;
      titleStyle.vAlign = xlsio.VAlignType.center;

      // Subtítulo.
      final subtitleRange = ws.getRangeByName('A3:I3');
      subtitleRange.merge();
      subtitleRange.setText(
        'Reporte técnico exportado desde Bit Flow · Foto · Video · GPS · Observaciones',
      );
      final subtitleStyle = subtitleRange.cellStyle;
      subtitleStyle.backColor = '#EAF1EE';
      subtitleStyle.fontColor = '#38594E';
      subtitleStyle.fontSize = 10;
      subtitleStyle.hAlign = xlsio.HAlignType.center;
      subtitleStyle.vAlign = xlsio.VAlignType.center;
      subtitleStyle.borders.bottom.lineStyle = xlsio.LineStyle.thin;
      subtitleStyle.borders.bottom.color = '#C8D4CE';

      if (logoBytes != null && logoBytes.isNotEmpty) {
        final picture = ws.pictures.addStream(1, 1, logoBytes);
        picture.width = 36;
        picture.height = 36;
      }

      // Cards corporativas.
      _buildInfoCard(
        ws: ws,
        range: 'A4:C5',
        label: 'Proyecto',
        value: project,
      );
      _buildInfoCard(
        ws: ws,
        range: 'D4:F5',
        label: 'Empresa',
        value: company,
      );
      _buildInfoCard(
        ws: ws,
        range: 'G4:I5',
        label: 'Generado',
        value:
        '${_formatDate(DateTime.now())} · ${operatorName.trim().isEmpty ? 'Operador' : operatorName}',
      );

      // Línea separadora.
      final separator = ws.getRangeByName('A6:I6');
      separator.cellStyle.backColor = '#F7F8FA';

      // Encabezados tabla.
      const headerRow = 8;
      const startDataRow = 9;

      final headers = <String>[
        'ID',
        'Fecha',
        'Ubicación',
        'Latitud',
        'Longitud',
        'Foto',
        'Video',
        'Resistencia (Ohm)',
        'Observaciones',
      ];

      for (int i = 0; i < headers.length; i++) {
        ws.getRangeByIndex(headerRow, i + 1).setText(headers[i]);
      }

      final head = ws.getRangeByIndex(headerRow, 1, headerRow, headers.length);
      final hs = head.cellStyle;
      hs.backColor = '#E9EDF2';
      hs.fontColor = '#3C4858';
      hs.bold = true;
      hs.fontSize = 11;
      hs.hAlign = xlsio.HAlignType.center;
      hs.vAlign = xlsio.VAlignType.center;
      hs.borders.all.lineStyle = xlsio.LineStyle.thin;
      hs.borders.all.color = '#BFC8D2';

      ws.setRowHeightInPixels(headerRow, 34);
      ws.getRangeByName('A9').freezePanes();

      for (int i = 0; i < rows.length; i++) {
        final excelRow = startDataRow + i;
        final item = rows[i];
        final bool isEven = i.isEven;

        ws.setRowHeightInPixels(excelRow, 70);

        final rowRange = ws.getRangeByIndex(excelRow, 1, excelRow, headers.length);
        final rowStyle = rowRange.cellStyle;
        rowStyle.backColor = isEven ? '#FFFFFF' : '#F5F7FA';
        rowStyle.borders.all.lineStyle = xlsio.LineStyle.hair;
        rowStyle.borders.all.color = '#D7DEE6';
        rowStyle.vAlign = xlsio.VAlignType.center;

        // ID
        final idCell = ws.getRangeByIndex(excelRow, 1);
        idCell.setText(item.id);
        idCell.cellStyle.hAlign = xlsio.HAlignType.center;
        idCell.cellStyle.bold = true;
        idCell.cellStyle.fontColor = '#3D4752';

        // Fecha
        final dateCell = ws.getRangeByIndex(excelRow, 2);
        if (item.date != null) {
          dateCell.dateTime = item.date;
          dateCell.numberFormat = 'dd/mm/yyyy';
        } else {
          dateCell.setText('');
        }
        dateCell.cellStyle.hAlign = xlsio.HAlignType.center;

        // Ubicación
        final locCell = ws.getRangeByIndex(excelRow, 3);
        locCell.setText(item.location);
        locCell.cellStyle.wrapText = true;
        locCell.cellStyle.vAlign = xlsio.VAlignType.center;
        locCell.cellStyle.hAlign = xlsio.HAlignType.left;

        final mapUrl = item.mapsUrl;
        if (mapUrl != null) {
          final link = ws.hyperlinks.add(locCell, xlsio.HyperlinkType.url, mapUrl);
          link.screenTip = 'Abrir ubicación en Google Maps';
          link.textToDisplay = item.location;
        }

        // Latitud
        final latCell = ws.getRangeByIndex(excelRow, 4);
        if (item.latitude != null) {
          latCell.setNumber(item.latitude!);
          latCell.numberFormat = '0.000000';
        } else {
          latCell.setText('');
        }
        latCell.cellStyle.hAlign = xlsio.HAlignType.center;

        // Longitud
        final lonCell = ws.getRangeByIndex(excelRow, 5);
        if (item.longitude != null) {
          lonCell.setNumber(item.longitude!);
          lonCell.numberFormat = '0.000000';
        } else {
          lonCell.setText('');
        }
        lonCell.cellStyle.hAlign = xlsio.HAlignType.center;

        // Foto
        _insertMediaCell(
          ws: ws,
          row: excelRow,
          column: 6,
          bytes: item.photoBytes,
          url: item.photoUrl,
          fallbackText: item.photoUrl != null ? 'Abrir foto' : 'Sin foto',
        );

        // Video (miniatura + link)
        _insertMediaCell(
          ws: ws,
          row: excelRow,
          column: 7,
          bytes: item.videoThumbnailBytes,
          url: item.videoUrl,
          fallbackText: item.videoUrl != null ? 'Abrir video' : 'Sin video',
          overlayPlayHint: item.videoThumbnailBytes != null,
        );

        // Resistencia
        final ohmCell = ws.getRangeByIndex(excelRow, 8);
        if (item.resistanceOhm != null) {
          ohmCell.setNumber(item.resistanceOhm!);
          ohmCell.numberFormat = '#,##0.00';
        } else {
          ohmCell.setText('');
        }
        ohmCell.cellStyle.hAlign = xlsio.HAlignType.center;
        ohmCell.cellStyle.bold = true;
        ohmCell.cellStyle.fontSize = 12;
        ohmCell.cellStyle.fontColor = '#20252B';

        // Observaciones
        final obsCell = ws.getRangeByIndex(excelRow, 9);
        obsCell.setText(item.observations);
        obsCell.cellStyle.wrapText = true;
        obsCell.cellStyle.hAlign = xlsio.HAlignType.left;
        obsCell.cellStyle.vAlign = xlsio.VAlignType.center;
      }

      final bottomRow = startDataRow + rows.length + 1;

      // Nota de trazabilidad.
      final noteRange = ws.getRangeByIndex(bottomRow, 1, bottomRow, 9);
      noteRange.merge();
      noteRange.setText(
        'Este reporte incluye trazabilidad geográfica y evidencia multimedia. '
            'Las columnas Foto y Video contienen miniaturas o enlaces clickeables según disponibilidad.',
      );
      final noteStyle = noteRange.cellStyle;
      noteStyle.backColor = '#EEF3F6';
      noteStyle.fontColor = '#5A6776';
      noteStyle.fontSize = 9;
      noteStyle.wrapText = true;
      noteStyle.borders.top.lineStyle = xlsio.LineStyle.thin;
      noteStyle.borders.top.color = '#C9D3DC';
      noteStyle.hAlign = xlsio.HAlignType.left;
      noteStyle.vAlign = xlsio.VAlignType.center;
      ws.setRowHeightInPixels(bottomRow, 32);

      final printAreaEndRow = bottomRow;
      ws.pageSetup.printArea = 'A1:I$printAreaEndRow';
      ws.pageSetup.printTitleRows = r'$8:$8';

      final bytesList = book.saveAsStream();
      final bytes = Uint8List.fromList(bytesList);

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

  static void _setColumnsForEnterpriseLayout(xlsio.Worksheet ws) {
    ws.setColumnWidthInPixels(1, 55);   // ID
    ws.setColumnWidthInPixels(2, 95);   // Fecha
    ws.setColumnWidthInPixels(3, 180);  // Ubicación
    ws.setColumnWidthInPixels(4, 110);  // Latitud
    ws.setColumnWidthInPixels(5, 110);  // Longitud
    ws.setColumnWidthInPixels(6, 120);  // Foto
    ws.setColumnWidthInPixels(7, 120);  // Video
    ws.setColumnWidthInPixels(8, 120);  // Resistencia
    ws.setColumnWidthInPixels(9, 220);  // Observaciones
  }

  static void _buildInfoCard({
    required xlsio.Worksheet ws,
    required String range,
    required String label,
    required String value,
  }) {
    final card = ws.getRangeByName(range);
    card.merge();

    final style = card.cellStyle;
    style.backColor = '#FFFFFF';
    style.borders.all.lineStyle = xlsio.LineStyle.thin;
    style.borders.all.color = '#D7DEE6';
    style.wrapText = true;
    style.hAlign = xlsio.HAlignType.left;
    style.vAlign = xlsio.VAlignType.center;
    style.fontSize = 11;
    style.fontColor = '#26323E';

    card.setText('$label\n$value');
  }

  static void _insertMediaCell({
    required xlsio.Worksheet ws,
    required int row,
    required int column,
    required Uint8List? bytes,
    required String? url,
    required String fallbackText,
    bool overlayPlayHint = false,
  }) {
    final cell = ws.getRangeByIndex(row, column);
    cell.cellStyle.hAlign = xlsio.HAlignType.center;
    cell.cellStyle.vAlign = xlsio.VAlignType.center;
    cell.cellStyle.backColor = '#F2F4F7';

    if (bytes != null && bytes.isNotEmpty) {
      final picture = ws.pictures.addStream(row, column, bytes);
      picture.width = 102;
      picture.height = 56;

      if (url != null && url.trim().isNotEmpty) {
        final link = ws.hyperlinks.addImage(
          picture,
          xlsio.HyperlinkType.url,
          url.trim(),
        );
        link.screenTip = overlayPlayHint ? 'Abrir video' : 'Abrir imagen';
      }

      if (overlayPlayHint) {
        final hint = ws.getRangeByIndex(row, column);
        hint.setText('▶');
        hint.cellStyle.fontSize = 16;
        hint.cellStyle.bold = true;
        hint.cellStyle.fontColor = '#FFFFFF';
        hint.cellStyle.hAlign = xlsio.HAlignType.center;
        hint.cellStyle.vAlign = xlsio.VAlignType.center;
      }

      return;
    }

    if (url != null && url.trim().isNotEmpty) {
      final link = ws.hyperlinks.add(
        cell,
        xlsio.HyperlinkType.url,
        url.trim(),
      );
      link.textToDisplay = fallbackText;
      link.screenTip = fallbackText;
      return;
    }

    cell.setText(fallbackText);
    cell.cellStyle.fontColor = '#7A8694';
    cell.cellStyle.fontSize = 9;
  }

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  static String _safeSheetName(String s) {
    var t = s.trim();
    if (t.isEmpty) t = 'Sheet1';
    t = t.replaceAll(RegExp(r'[\\/\?\*\[\]:]'), ' ');
    return t.length > 31 ? t.substring(0, 31) : t;
  }

  static String _sanitize(String s) {
    final value = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return value.isEmpty ? 'bitflow_export' : value;
  }

  static String _ts() {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }
}