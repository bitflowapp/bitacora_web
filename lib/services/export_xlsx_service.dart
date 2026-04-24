// lib/services/export_xlsx_service.dart
//
// Exportador XLSX avanzado para Gridnote / Bitácora.
// - Hoja PLANILLA: datos principales.
// - Hoja FOTOS: metadatos de fotos por fila (opcional).
// - Hoja UBICACION: lat/long general + hyperlink a Google Maps.
// - Hoja INSTRUCCIONES: guía para quien recibe el archivo.
//
// Compatible con:
//  - Descarga local (móvil / desktop) mediante saver IO/Web.
//  - Envío por correo vía MailReportService (Cloud Functions + Resend).

import 'dart:typed_data';

import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import 'mail_report_service.dart';
import 'export_xlsx_with_photos.dart';

import 'save_xlsx.dart' as platform_saver;

class ExportXlsxService {
  const ExportXlsxService._();

  /// Compatibilidad con código legacy:
  /// permite llamadas tipo:
  ///   ExportXlsxService.saveXlsx('Planilla.xlsx', bytes);
  /// Internamente delega en el saver unificado por plataforma.
  static Future<void> saveXlsx(String fileName, List<int> bytes) async {
    final data = Uint8List.fromList(bytes);
    await platform_saver.saveXlsx(fileName, data);
  }

  /// Construye el XLSX en memoria (bytes).
  /// Útil si después querés usar esos bytes para enviar/compartir por otros canales.
  static Future<List<int>> buildXlsxBytes({
    required List<String> headers,
    required List<List<String>> rows,
    List<List<String>>? photoRows,
    Map<int, List<Uint8List>>? photosByRow,
    double? sheetLatitude,
    double? sheetLongitude,
    DateTime? sheetCreatedAt,
    String sheetName = 'PLANILLA',
  }) {
    return _buildXlsxBytes(
      sheetName: sheetName,
      headers: headers,
      rows: rows,
      photoRows: photoRows,
      photosByRow: photosByRow,
      sheetLatitude: sheetLatitude,
      sheetLongitude: sheetLongitude,
      sheetCreatedAt: sheetCreatedAt,
    );
  }

  /// Genera y guarda/descarga un XLSX local.
  static Future<void> download({
    String? fileName,
    String name = 'BitFlow',
    List<String> headers = const <String>[],
    List<List<String>> rows = const <List<String>>[],
    List<List<String>>? photoRows,
    Map<int, List<Uint8List>>? photosByRow,
    double? sheetLatitude,
    double? sheetLongitude,
    DateTime? sheetCreatedAt,
  }) async {
    final base = _resolveBaseName(fileName, name);

    final bytes = await buildXlsxBytes(
      sheetName: 'PLANILLA',
      headers: headers,
      rows: rows,
      photoRows: photoRows,
      photosByRow: photosByRow,
      sheetLatitude: sheetLatitude,
      sheetLongitude: sheetLongitude,
      sheetCreatedAt: sheetCreatedAt,
    );

    await saveXlsx('$base.xlsx', bytes);
  }

  /// Genera el XLSX en memoria y lo envía por mail usando [MailReportService].
  static Future<void> exportAndSendReport({
    required MailReportService mailService,
    required String to,
    String? subject,
    String? message,
    String? fileName,
    String name = 'BitFlow',
    List<String> headers = const <String>[],
    List<List<String>> rows = const <List<String>>[],
    List<List<String>>? photoRows,
    Map<int, List<Uint8List>>? photosByRow,
    double? sheetLatitude,
    double? sheetLongitude,
    DateTime? sheetCreatedAt,
  }) async {
    final base = _resolveBaseName(fileName, name);

    final bytes = await buildXlsxBytes(
      sheetName: 'PLANILLA',
      headers: headers,
      rows: rows,
      photoRows: photoRows,
      photosByRow: photosByRow,
      sheetLatitude: sheetLatitude,
      sheetLongitude: sheetLongitude,
      sheetCreatedAt: sheetCreatedAt,
    );

    await mailService.sendReport(
      to: to,
      subject: subject ?? 'Reporte tecnico Bit Flow',
      message: message ?? 'Adjunto XLSX generado desde Bit Flow.',
      fileName: '$base.xlsx',
      xlsxBytes: bytes,
    );
  }

  /// Normaliza el nombre base del archivo.
  static String _resolveBaseName(String? fileName, String name) {
    final candidate =
        (fileName != null && fileName.trim().isNotEmpty) ? fileName : name;

    // Quita extensión si ya viene con .xlsx
    var base = candidate.trim();
    if (base.toLowerCase().endsWith('.xlsx')) {
      base = base.substring(0, base.length - 5);
    }

    // Excel/OS: evitar separadores y caracteres raros en nombre de archivo.
    base = base
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return base.isEmpty ? 'BitFlow' : base;
  }

  /// Construye el XLSX en memoria.
  ///
  /// Caso 1: SIN fotos → workbook con 4 hojas (PLANILLA/FOTOS/UBICACION/INSTRUCCIONES).
  /// Caso 2: CON fotos → embeber en PLANILLA con [buildXlsxWithPhotos].
  static Future<List<int>> _buildXlsxBytes({
    required String sheetName,
    required List<String> headers,
    required List<List<String>> rows,
    List<List<String>>? photoRows,
    Map<int, List<Uint8List>>? photosByRow,
    double? sheetLatitude,
    double? sheetLongitude,
    DateTime? sheetCreatedAt,
  }) async {
    final safeSheetName = _sanitizeWorksheetName(sheetName);

    // Si hay fotos, embeber en la hoja principal.
    if (photosByRow != null && photosByRow.isNotEmpty) {
      final bytesWithPhotos = await buildXlsxWithPhotos(
        columns: headers,
        rows: rows,
        photosByRow: photosByRow,
        sheetName: safeSheetName,
        includeIndexColumn: false,
      );
      return bytesWithPhotos;
    }

    // Modo clásico (4 hojas).
    final workbook = xlsio.Workbook(4);
    try {
      final sheetPlanilla = workbook.worksheets[0]..name = safeSheetName;
      final sheetFotos = workbook.worksheets[1]..name = 'FOTOS';
      final sheetUbicacion = workbook.worksheets[2]..name = 'UBICACION';
      final sheetInstrucciones = workbook.worksheets[3]..name = 'INSTRUCCIONES';

      _buildPlanillaSheet(
        sheetPlanilla,
        headers: headers,
        rows: rows,
      );

      _buildFotosSheet(
        sheetFotos,
        photoRows: photoRows,
        photosByRow: photosByRow,
      );

      _buildUbicacionSheet(
        sheetUbicacion,
        latitude: sheetLatitude,
        longitude: sheetLongitude,
        createdAt: sheetCreatedAt,
      );

      _buildInstruccionesSheet(sheetInstrucciones);

      addBitflowMetaSheet(
        workbook,
        embeddedImageCount: 0,
        timestamp: DateTime.now(),
      );

      final bytes = workbook.saveAsStream();
      return bytes;
    } finally {
      workbook.dispose();
    }
  }

  static String _sanitizeWorksheetName(String name) {
    var n = name.trim();
    if (n.isEmpty) return 'PLANILLA';
    // Excel: max 31 y sin : \ / ? * [ ]
    n = n.replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ');
    n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (n.isEmpty) n = 'PLANILLA';
    if (n.length > 31) n = n.substring(0, 31).trim();
    return n.isEmpty ? 'PLANILLA' : n;
  }

  // ============================================================
  // Construcción de cada hoja (modo clásico sin fotos embebidas)
  // ============================================================

  static void _buildPlanillaSheet(
    xlsio.Worksheet sheet, {
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    int colCount = headers.length;
    for (final r in rows) {
      if (r.length > colCount) colCount = r.length;
    }
    if (colCount == 0) colCount = 1;

    final saneHeaders = _normalizeHeaders(headers, colCount);
    final saneRows = _normalizeRows(rows, colCount);

    final headerStyle = sheet.workbook.styles.add('HeaderStyle');
    headerStyle.bold = true;
    headerStyle.backColor = '#FF007AFF';
    headerStyle.fontColor = '#FFFFFFFF';
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;

    // Encabezados en fila 1.
    for (int c = 0; c < colCount; c++) {
      final cell = sheet.getRangeByIndex(1, c + 1);
      cell.setText(saneHeaders[c]);
      cell.cellStyle = headerStyle;
    }

    // Filas de datos desde la fila 2.
    for (int r = 0; r < saneRows.length; r++) {
      final row = saneRows[r];
      for (int c = 0; c < colCount; c++) {
        sheet.getRangeByIndex(r + 2, c + 1).setText(row[c]);
      }
    }

    // Bordes finos alrededor de la tabla.
    final lastRow = saneRows.length + 1;
    final tableRange = sheet.getRangeByIndex(1, 1, lastRow, colCount);
    tableRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

    // Auto-fit con fallback.
    for (int c = 1; c <= colCount; c++) {
      _safeAutoFitColumn(sheet, c, fallbackPx: 140);
    }
  }

  static void _buildFotosSheet(
    xlsio.Worksheet sheet, {
    required List<List<String>>? photoRows,
    required Map<int, List<Uint8List>>? photosByRow,
  }) {
    const fotoHeaders = <String>[
      'Fila',
      'Archivo',
      'Descripción',
      'Latitud',
      'Longitud',
      'Fecha/hora',
    ];

    final headerStyle = sheet.workbook.styles.add('FotosHeaderStyle');
    headerStyle.bold = true;
    headerStyle.backColor = '#FF007AFF';
    headerStyle.fontColor = '#FFFFFFFF';
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;

    // Encabezados en fila 1.
    for (int c = 0; c < fotoHeaders.length; c++) {
      final cell = sheet.getRangeByIndex(1, c + 1);
      cell.setText(fotoHeaders[c]);
      cell.cellStyle = headerStyle;
    }

    // Prioridad: photoRows explícito.
    if (photoRows != null && photoRows.isNotEmpty) {
      final saneRows = _normalizeRows(photoRows, fotoHeaders.length);

      for (int r = 0; r < saneRows.length; r++) {
        final row = saneRows[r];
        for (int c = 0; c < fotoHeaders.length; c++) {
          final value = (c == 1) ? '' : row[c];
          sheet.getRangeByIndex(r + 2, c + 1).setText(value);
        }
      }

      final lastRow = saneRows.length + 1;
      final tableRange = sheet.getRangeByIndex(
        1,
        1,
        lastRow,
        fotoHeaders.length,
      );
      tableRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    } else if (photosByRow != null && photosByRow.isNotEmpty) {
      // Fallback: resumen mínimo desde el mapa.
      final entries = photosByRow.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      int outRow = 2;
      for (final e in entries) {
        final rowIndex0 = e.key;
        final list = e.value;

        for (int i = 0; i < list.length; i++) {
          final filaHumana = (rowIndex0 + 1).toString();
          final archivo = 'N/D';
          final desc = 'Foto embebida en PLANILLA (Export)';

          sheet.getRangeByIndex(outRow, 1).setText(filaHumana);
          sheet.getRangeByIndex(outRow, 2).setText(archivo);
          sheet.getRangeByIndex(outRow, 3).setText(desc);
          sheet.getRangeByIndex(outRow, 4).setText('');
          sheet.getRangeByIndex(outRow, 5).setText('');
          sheet.getRangeByIndex(outRow, 6).setText('');
          outRow++;
        }
      }

      final lastRow = outRow - 1;
      if (lastRow >= 1) {
        final tableRange = sheet.getRangeByIndex(
          1,
          1,
          lastRow,
          fotoHeaders.length,
        );
        tableRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      }
    } else {
      sheet.getRangeByIndex(3, 1).setText(
            'No hay fotos asociadas en este reporte.',
          );
    }

    for (int c = 1; c <= fotoHeaders.length; c++) {
      _safeAutoFitColumn(sheet, c, fallbackPx: 180);
    }
  }

  static void _buildUbicacionSheet(
    xlsio.Worksheet sheet, {
    required double? latitude,
    required double? longitude,
    required DateTime? createdAt,
  }) {
    final title = sheet.getRangeByIndex(1, 1);
    title.setText('Ubicacion general de esta planilla');
    title.cellStyle.bold = true;
    title.cellStyle.fontSize = 14;

    sheet.getRangeByIndex(3, 1).setText('Latitud');
    sheet.getRangeByIndex(3, 2).setText('Longitud');

    if (latitude != null && longitude != null) {
      final latStr = latitude.toStringAsFixed(6);
      final lngStr = longitude.toStringAsFixed(6);

      sheet.getRangeByIndex(4, 1).setText(latStr);
      sheet.getRangeByIndex(4, 2).setText(lngStr);

      sheet.getRangeByIndex(6, 1).setText('Ver en Google Maps');

      final mapsUrl = 'https://www.google.com/maps?q=$latStr,$lngStr';

      // Hyperlink real (clickeable).
      final linkRange = sheet.getRangeByIndex(7, 1);
      final xlsio.Hyperlink link = sheet.hyperlinks.add(
        linkRange,
        xlsio.HyperlinkType.url,
        mapsUrl,
      );
      link.textToDisplay = 'Abrir en Google Maps';
      link.screenTip = 'Abrir ubicacion en Google Maps';

      linkRange.cellStyle.fontColor = '#FF0000FF';
      linkRange.cellStyle.bold = true;
    } else {
      sheet.getRangeByIndex(4, 1).setText(
            'Ubicacion no disponible en este reporte.',
          );
    }

    if (createdAt != null) {
      sheet.getRangeByIndex(9, 1).setText('Fecha/hora de generacion');
      final dateCell = sheet.getRangeByIndex(9, 2);
      dateCell.dateTime = createdAt;
      dateCell.numberFormat = 'dd/mm/yyyy hh:mm';
    }

    _safeAutoFitColumn(sheet, 1, fallbackPx: 320);
    _safeAutoFitColumn(sheet, 2, fallbackPx: 220);
  }

  static void _buildInstruccionesSheet(xlsio.Worksheet sheet) {
    final title = sheet.getRangeByIndex(1, 1);
    title.setText('Instrucciones para leer esta planilla');
    title.cellStyle.bold = true;
    title.cellStyle.fontSize = 14;

    final textCell = sheet.getRangeByIndex(3, 1);
    textCell.setText('''
1) Que es este archivo
   - Planilla generada automaticamente desde Bit Flow.
   - Contiene los datos exactamente como fueron cargados en campo.

2) Como ver los datos
   - Hoja PLANILLA   : datos principales (mediciones, observaciones, GPS).
   - Hoja FOTOS      : fotos asociadas a cada fila (nro. fila, archivo, descripcion).
   - Hoja UBICACION  : punto general de la planilla y link a Google Maps.
   - Hoja INSTRUCCIONES: esta ayuda.

3) Revision rapida
   - Verifique fecha y hora de los registros.
   - Use la columna Fila en FOTOS para cruzar cada foto con PLANILLA.
   - Use Latitud / Longitud para ubicar los puntos en un mapa.

4) Como reenviar esta planilla
   - Puede reenviar este mismo archivo .xlsx por:
       * Correo corporativo (Outlook, Gmail empresa, etc.).
       * WhatsApp / WhatsApp Business (adjuntar como Documento).
       * Teams, Slack u otra plataforma corporativa.
   - No es necesario modificar nada para que otros puedan verlo.

5) Recomendacion
   - Conserve este archivo como respaldo original del relevamiento.
   - Si hace cambios manuales, guardelo con otro nombre
     (por ejemplo: Planilla_ObraX_EDITADO.xlsx).
''');

    textCell.cellStyle.wrapText = true;

    sheet.setColumnWidthInPixels(1, 600);
    sheet.setRowHeightInPixels(3, 420.0);
  }

  // ============================================================
  // Helpers
  // ============================================================

  static void _safeAutoFitColumn(
    xlsio.Worksheet sheet,
    int col, {
    required int fallbackPx,
  }) {
    try {
      sheet.autoFitColumn(col);
    } catch (_) {
      sheet.setColumnWidthInPixels(col, fallbackPx);
    }
  }

  static List<String> _normalizeHeaders(List<String> headers, int colCount) {
    final result = List<String>.from(headers);
    while (result.length < colCount) {
      result.add('');
    }
    return result;
  }

  static List<List<String>> _normalizeRows(
      List<List<String>> rows, int colCount) {
    return rows.map((original) {
      final row = List<String>.from(original);
      while (row.length < colCount) {
        row.add('');
      }
      return row;
    }).toList();
  }
}

/// Función global legacy para compatibilidad con código antiguo.
Future<void> saveXlsx(String fileName, List<int> bytes) {
  return ExportXlsxService.saveXlsx(fileName, bytes);
}
