// lib/services/export_xlsx_service.dart
//
// Exportador XLSX avanzado para Gridnote / Bitácora.
// - Hoja PLANILLA: datos principales.
// - Hoja FOTOS: metadatos de fotos por fila (opcional).
// - Hoja UBICACION: lat/long general + link de texto a Google Maps.
// - Hoja INSTRUCCIONES: guía para quien recibe el archivo.
//
// Compatible con:
//  - Descarga local (móvil / desktop) mediante saver stub/web (saveXlsxBytes).
//  - Envío por correo vía MailReportService (Cloud Functions + Resend).

import 'dart:typed_data';

import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import 'mail_report_service.dart';
import 'export_xlsx_with_photos.dart';

// Saver genérico: stub por defecto / web override, con alias.
import 'export_xlsx_saver_stub.dart'
if (dart.library.html) 'export_xlsx_saver_web.dart' as xlsx_saver;

class ExportXlsxService {
  const ExportXlsxService._();

  /// Compatibilidad con código legacy:
  /// permite llamadas tipo:
  ///   ExportXlsxService.saveXlsx('Planilla.xlsx', bytes);
  ///
  /// Internamente delega en el saver unificado (saveXlsxBytes).
  static Future<void> saveXlsx(String fileName, List<int> bytes) async {
    final data = Uint8List.fromList(bytes);
    await xlsx_saver.saveXlsxBytes(data, fileName);
  }

  /// Genera y guarda/descarga un XLSX local.
  ///
  /// [fileName] tiene prioridad; si es nulo o vacío se usa [name].
  ///
  /// [headers]  → encabezados de la grilla.
  /// [rows]     → filas de la grilla (cada fila = lista de celdas).
  ///
  /// [photoRows] → filas para la hoja FOTOS. Ejemplo:
  ///   [
  ///     ["Fila", "Archivo", "Descripción", "Latitud", "Longitud", "Fecha/hora"],
  ///     ...
  ///   ]
  ///
  /// [photosByRow] → mapa de fotos por fila (para embeber en PLANILLA):
  ///   key = índice de fila (0-based respecto a [rows])
  ///   value = lista de bytes de imagen (JPG/PNG) de esa fila.
  ///
  /// [sheetLatitude] / [sheetLongitude] → ubicación general de la planilla.
  ///
  /// [sheetCreatedAt] → fecha/hora de generación del XLSX.
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

    final bytes = await _buildXlsxBytes(
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
  ///
  /// No descarga nada localmente; solo arma el archivo y lo envía.
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

    final bytes = await _buildXlsxBytes(
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
      subject: subject ?? 'Reporte Gridnote',
      message: message ?? 'Adjunto XLSX generado desde Gridnote.',
      fileName: '$base.xlsx',
      xlsxBytes: bytes,
    );
  }

  /// Normaliza el nombre base del archivo.
  static String _resolveBaseName(String? fileName, String name) {
    final candidate =
    (fileName != null && fileName.trim().isNotEmpty) ? fileName : name;
    final trimmed = candidate.trim();
    return trimmed.isEmpty ? 'BitFlow' : trimmed;
  }

  /// Construye el XLSX en memoria.
  ///
  /// Caso 1: SIN fotos → usa workbook con 4 hojas (PLANILLA/FOTOS/UBICACION/INSTRUCCIONES).
  /// Caso 2: CON fotos → delega en [buildXlsxWithPhotos] y devuelve un XLSX
  ///         con las fotos embebidas en la hoja PLANILLA.
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
    // Si hay fotos, delegamos directamente a buildXlsxWithPhotos.
    if (photosByRow != null && photosByRow.isNotEmpty) {
      final bytesWithPhotos = await buildXlsxWithPhotos(
        columns: headers,
        rows: rows,
        photosByRow: photosByRow,
      );
      return bytesWithPhotos;
    }

    // Sin fotos: 4 hojas clásicas.
    final workbook = xlsio.Workbook(4);

    final sheetPlanilla = workbook.worksheets[0]..name = sheetName;
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
    );

    _buildUbicacionSheet(
      sheetUbicacion,
      latitude: sheetLatitude,
      longitude: sheetLongitude,
      createdAt: sheetCreatedAt,
    );

    _buildInstruccionesSheet(sheetInstrucciones);

    final bytes = workbook.saveAsStream();
    workbook.dispose();
    return bytes;
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
      if (r.length > colCount) {
        colCount = r.length;
      }
    }
    if (colCount == 0) {
      colCount = 1;
    }

    final saneHeaders = _normalizeHeaders(headers, colCount);
    final saneRows = _normalizeRows(rows, colCount);

    final headerStyle = sheet.workbook.styles.add('HeaderStyle');
    headerStyle.bold = true;
    headerStyle.backColor = '#FFEFEFEF';
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

    // Auto-fit de columnas.
    for (int c = 1; c <= colCount; c++) {
      sheet.autoFitColumn(c);
    }
  }

  static void _buildFotosSheet(
      xlsio.Worksheet sheet, {
        required List<List<String>>? photoRows,
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
    headerStyle.backColor = '#FFEFEFEF';
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;

    // Encabezados en fila 1.
    for (int c = 0; c < fotoHeaders.length; c++) {
      final cell = sheet.getRangeByIndex(1, c + 1);
      cell.setText(fotoHeaders[c]);
      cell.cellStyle = headerStyle;
    }

    if (photoRows != null && photoRows.isNotEmpty) {
      final saneRows = _normalizeRows(photoRows, fotoHeaders.length);

      for (int r = 0; r < saneRows.length; r++) {
        final row = saneRows[r];
        for (int c = 0; c < fotoHeaders.length; c++) {
          sheet.getRangeByIndex(r + 2, c + 1).setText(row[c]);
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
    } else {
      sheet.getRangeByIndex(3, 1).setText(
        'No hay fotos asociadas en este reporte.',
      );
    }

    for (int c = 1; c <= fotoHeaders.length; c++) {
      sheet.autoFitColumn(c);
    }
  }

  static void _buildUbicacionSheet(
      xlsio.Worksheet sheet, {
        required double? latitude,
        required double? longitude,
        required DateTime? createdAt,
      }) {
    final title = sheet.getRangeByIndex(1, 1);
    title.setText('Ubicación general de esta planilla');
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

      // Link como texto (copiar/pegar) sin usar hyperlinks.add.
      final linkCell = sheet.getRangeByIndex(7, 1);
      linkCell.setText(mapsUrl);
      linkCell.cellStyle.fontColor = '#FF0000FF';
      linkCell.cellStyle.bold = true;
    } else {
      sheet
          .getRangeByIndex(4, 1)
          .setText('Ubicación no disponible en este reporte.');
    }

    if (createdAt != null) {
      sheet.getRangeByIndex(9, 1).setText('Fecha/hora de generación');
      final dateCell = sheet.getRangeByIndex(9, 2);
      dateCell.dateTime = createdAt;
      dateCell.numberFormat = 'dd/mm/yyyy hh:mm';
    }

    sheet.autoFitColumn(1);
    sheet.autoFitColumn(2);
  }

  static void _buildInstruccionesSheet(xlsio.Worksheet sheet) {
    final title = sheet.getRangeByIndex(1, 1);
    title.setText('Instrucciones para leer esta planilla');
    title.cellStyle.bold = true;
    title.cellStyle.fontSize = 14;

    final textCell = sheet.getRangeByIndex(3, 1);
    textCell.setText('''
1) Qué es este archivo
   - Planilla generada automáticamente desde la app Gridnote / Bitácora.
   - Contiene los datos exactamente como fueron cargados en campo.

2) Cómo ver los datos
   - Hoja PLANILLA   : datos principales (mediciones, observaciones, GPS).
   - Hoja FOTOS      : fotos asociadas a cada fila (n° fila, archivo, descripción).
   - Hoja UBICACION  : punto general de la planilla y link de texto a Google Maps.
   - Hoja INSTRUCCIONES: esta ayuda.

3) Revisión rápida
   - Verifique fecha y hora de los registros.
   - Use la columna Fila en FOTOS para cruzar cada foto con PLANILLA.
   - Use Latitud / Longitud para ubicar los puntos en un mapa.

4) Cómo reenviar esta planilla
   - Puede reenviar este mismo archivo .xlsx por:
       * Correo corporativo (Outlook, Gmail empresa, etc.).
       * WhatsApp / WhatsApp Business (adjuntar como Documento).
       * Teams, Slack u otra plataforma corporativa.
   - No es necesario modificar nada para que otros puedan verlo.

5) Recomendación
   - Conserve este archivo como respaldo original del relevamiento.
   - Si hace cambios manuales, guárdelo con otro nombre
     (por ejemplo: Planilla_ObraX_EDITADO.xlsx).
''');

    textCell.cellStyle.wrapText = true;

    // Ancho cómodo para leer texto de instrucciones.
    sheet.setColumnWidthInPixels(1, 600);
    sheet.setRowHeightInPixels(3, 420.0);
  }

  // ============================================================
  // Helpers de normalización
  // ============================================================

  static List<String> _normalizeHeaders(
      List<String> headers,
      int colCount,
      ) {
    final result = List<String>.from(headers);
    while (result.length < colCount) {
      result.add('');
    }
    return result;
  }

  static List<List<String>> _normalizeRows(
      List<List<String>> rows,
      int colCount,
      ) {
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
/// Permite seguir llamando `saveXlsx('archivo.xlsx', bytes);` directamente.
Future<void> saveXlsx(String fileName, List<int> bytes) {
  return ExportXlsxService.saveXlsx(fileName, bytes);
}
