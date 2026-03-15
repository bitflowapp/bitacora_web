// lib/services/export_xlsx_with_photos.dart
//
// XLSX con fotos embebidas (Syncfusion XlsIO) — robusto y sin referencias por nombre.
// - Escribe todo con getRangeByIndex.
// - Inserta fotos con pictures.addBase64(row, col, base64).
// - NO usa picture.left/top (no existen en Flutter XlsIO).
// - autoFitColumn con try/catch + fallback por ancho estimado para que nunca rompa el export.
// - Maneja filas con mas columnas que headers sin pisar columnas de fotos.
//
// Devuelve bytes del XLSX listo para guardar/enviar.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:bitacora_web/services/formula_engine.dart';

const String _kExportVersion = 'bitflow_xlsx_v2';
const String _kAppVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: '');

class GpsExport {
  const GpsExport({
    this.lat,
    this.lng,
    this.accuracy,
    this.ts,
    this.isLastKnown = false,
  });

  final double? lat;
  final double? lng;
  final double? accuracy;
  final DateTime? ts;
  final bool isLastKnown;

  bool get hasFix => lat != null && lng != null;
}

class PhotoMeta {
  const PhotoMeta({
    required this.rowIndex,
    required this.colIndex,
    required this.photoIndex,
    required this.addedAt,
    required this.sourceLabel,
    this.lat,
    this.lng,
    this.accuracy,
  });

  final int rowIndex;
  final int colIndex;
  final int photoIndex;
  final DateTime addedAt;
  final String sourceLabel;
  final double? lat;
  final double? lng;
  final double? accuracy;
}

class EmbeddedPhoto {
  const EmbeddedPhoto({
    required this.rowIndex,
    required this.colIndex,
    required this.bytes,
  });

  final int rowIndex;
  final int colIndex;
  final Uint8List bytes;
}

class AttachmentRow {
  const AttachmentRow({
    required this.cellRef,
    required this.type,
    required this.fileName,
    required this.notes,
    required this.relativePath,
  });

  final String cellRef;
  final String type;
  final String fileName;
  final String notes;
  final String relativePath;
}

class ExportReportMeta {
  const ExportReportMeta({
    required this.sheetName,
    required this.exportedAt,
    required this.rowsCount,
    required this.columnsCount,
    required this.nonEmptyCells,
    required this.photosCount,
    required this.videosCount,
    required this.audiosCount,
    required this.gpsCount,
  });

  final String sheetName;
  final DateTime exportedAt;
  final int rowsCount;
  final int columnsCount;
  final int nonEmptyCells;
  final int photosCount;
  final int videosCount;
  final int audiosCount;
  final int gpsCount;
}

/// Genera un XLSX con datos + fotos embebidas.
///
/// - [columns]: encabezados de la grilla (sin la columna "#").
/// - [rows]: filas (cada fila = lista de strings).
/// - [photosByRow]:
///     key = indice de fila 0-based (misma posicion que en [rows])
///     value = lista de imagenes (Uint8List JPG/PNG) para esa fila.
/// - [gpsByRow]: lista opcional de GPS por fila.
/// - [photoMeta]: lista opcional para armar hoja "Fotos" con previews embebidas.
///
/// Devuelve bytes del XLSX.
Future<Uint8List> buildXlsxWithPhotos({
  required List<String> columns,
  required List<List<String>> rows,
  Map<int, List<Uint8List>>? photosByRow,
  List<GpsExport?>? gpsByRow,
  List<PhotoMeta>? photoMeta,
  List<EmbeddedPhoto>? embeddedPhotos,
  List<AttachmentRow>? attachments,
  String sheetName = 'PLANILLA',
  bool includeIndexColumn = true,
  bool includeCoverSheet = false,
  bool includeSummarySheet = false,
  ExportReportMeta? reportMeta,
}) async {
  final workbook = xlsio.Workbook(1);
  try {
    final sheet = workbook.worksheets[0];
    sheet.name = _sanitizeWorksheetName(sheetName);

    const int headerRow = 1;
    const int firstDataRow = headerRow + 1;

    // Ancho real de texto: puede haber filas mas largas que headers.
    int textCols = columns.length;
    for (final r in rows) {
      if (r.length > textCols) textCols = r.length;
    }
    if (textCols < 0) textCols = 0;

    final bool hasGps = _hasGps(gpsByRow);
    final int gpsCols = hasGps ? 5 : 0;

    // Col 1 = "#" si se pide, luego textCols columnas de texto y gps.
    final int baseColumnsCount =
        (includeIndexColumn ? 1 : 0) + textCols + gpsCols;

    final bool useEmbedded =
        embeddedPhotos != null && embeddedPhotos.isNotEmpty;

    // Max fotos por fila (para crear columnas "Foto 1..N") cuando se usa modo legacy.
    final int maxPhotosPerRow = useEmbedded
        ? 0
        : (photosByRow == null || photosByRow.isEmpty)
            ? 0
            : photosByRow.values.fold<int>(
                0,
                (prev, list) => math.max(prev, list.length),
              );

    // Fotos empiezan despues del bloque de texto+gps (solo si hay fotos legacy).
    final int firstPhotoCol = baseColumnsCount + 1;
    final int lastCol = (maxPhotosPerRow > 0)
        ? (baseColumnsCount + maxPhotosPerRow)
        : baseColumnsCount;
    final int safeLastCol = math.max(1, lastCol);

    final int textStartCol = includeIndexColumn ? 2 : 1;
    final int gpsStartCol = textStartCol + textCols;

    // Estilo header (nombre unico por seguridad).
    final styleName = 'HeaderStyle_${DateTime.now().microsecondsSinceEpoch}';
    final headerStyle = workbook.styles.add(styleName);
    headerStyle.bold = true;
    headerStyle.backColor = '#FF1F2937';
    headerStyle.fontColor = '#FFFFFFFF';
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;

    final zebraStyleName =
        'BodyAltStyle_${DateTime.now().microsecondsSinceEpoch}';
    final zebraStyle = workbook.styles.add(zebraStyleName);
    zebraStyle.backColor = '#FFF8FAFC';

    // --------------------------
    // 1) Encabezados
    // --------------------------
    if (includeIndexColumn) {
      sheet.getRangeByIndex(headerRow, 1).setText('#');
    }

    // Headers de texto (si faltan, se completan con vacio).
    for (int i = 0; i < textCols; i++) {
      final title = (i < columns.length) ? columns[i] : '';
      sheet.getRangeByIndex(headerRow, textStartCol + i).setText(title);
    }

    if (hasGps) {
      const headers = [
        'GPS Lat',
        'GPS Lon',
        'GPS Acc (m)',
        'GPS Time',
        'GPS Source',
      ];
      for (int i = 0; i < headers.length; i++) {
        sheet.getRangeByIndex(headerRow, gpsStartCol + i).setText(headers[i]);
      }
    }

    // Headers de fotos (Foto 1..N)
    if (maxPhotosPerRow > 0) {
      for (int p = 0; p < maxPhotosPerRow; p++) {
        sheet
            .getRangeByIndex(headerRow, firstPhotoCol + p)
            .setText('Foto ${p + 1}');
      }
    }

    // Aplica estilo a toda la fila de encabezados.
    final headerRange =
        sheet.getRangeByIndex(headerRow, 1, headerRow, safeLastCol);
    headerRange.cellStyle = headerStyle;

    // --------------------------
    // 2) Datos + fotos
    // --------------------------
    const int photoThumbW = 100;
    const int photoThumbH = 80;
    const int photoColWidthPx = 112;
    const double photoRowHeightPx = 90.0;

    // Ajuste de columnas de fotos legacy si existen.
    if (maxPhotosPerRow > 0) {
      for (int p = 0; p < maxPhotosPerRow; p++) {
        sheet.setColumnWidthInPixels(firstPhotoCol + p, photoColWidthPx);
      }
    }

    final Map<int, List<EmbeddedPhoto>> embeddedByRow = {};
    final Set<int> embeddedCols = <int>{};
    if (useEmbedded) {
      for (final item in embeddedPhotos) {
        if (item.bytes.isEmpty) continue;
        if (item.rowIndex < 0 || item.colIndex < 0) continue;
        embeddedByRow
            .putIfAbsent(item.rowIndex, () => <EmbeddedPhoto>[])
            .add(item);
        embeddedCols.add(item.colIndex);
      }
    }

    int embeddedCount = 0;

    for (int r = 0; r < rows.length; r++) {
      final excelRow = firstDataRow + r;
      final rowValues = rows[r];

      // Columna "#"
      if (includeIndexColumn) {
        sheet.getRangeByIndex(excelRow, 1).setNumber((r + 1).toDouble());
      }

      // Texto: escribe hasta textCols, padding con ''.
      for (int c = 0; c < textCols; c++) {
        final v = (c < rowValues.length) ? rowValues[c] : '';
        _setSheetValue(sheet, excelRow, textStartCol + c, v);
      }

      if (r.isOdd) {
        final rowRange =
            sheet.getRangeByIndex(excelRow, 1, excelRow, safeLastCol);
        rowRange.cellStyle = zebraStyle;
      }

      // GPS
      if (hasGps) {
        final gps =
            (gpsByRow != null && r < gpsByRow.length) ? gpsByRow[r] : null;
        if (gps != null && gps.hasFix) {
          final latCell = sheet.getRangeByIndex(excelRow, gpsStartCol);
          latCell.setNumber(gps.lat ?? 0);
          latCell.numberFormat = '0.000000';
          final lngCell = sheet.getRangeByIndex(excelRow, gpsStartCol + 1);
          lngCell.setNumber(gps.lng ?? 0);
          lngCell.numberFormat = '0.000000';
          final accCell = sheet.getRangeByIndex(excelRow, gpsStartCol + 2);
          accCell.setNumber(gps.accuracy ?? 0);
          accCell.numberFormat = '0.0" m"';
          if (gps.ts != null) {
            final tsCell = sheet.getRangeByIndex(excelRow, gpsStartCol + 3);
            tsCell.setDateTime(gps.ts!);
            tsCell.numberFormat = 'yyyy-mm-dd hh:mm';
          }
          sheet
              .getRangeByIndex(excelRow, gpsStartCol + 4)
              .setText(gps.isLastKnown ? 'lastKnown' : 'current');
        }
      }

      // Fotos embebidas por celda (nuevo).
      if (useEmbedded) {
        final picsForRow = embeddedByRow[r];
        if (picsForRow != null && picsForRow.isNotEmpty) {
          sheet.setRowHeightInPixels(excelRow, photoRowHeightPx);
          for (final pic in picsForRow) {
            if (pic.colIndex < 0 || pic.colIndex >= textCols) continue;
            final col = textStartCol + pic.colIndex;
            try {
              final picture = sheet.pictures.addBase64(
                excelRow,
                col,
                base64Encode(pic.bytes),
              );
              picture.width = photoThumbW;
              picture.height = photoThumbH;
              embeddedCount++;
            } catch (_) {}
          }
        }
      }

      // Fotos legacy por fila.
      if (!useEmbedded &&
          maxPhotosPerRow > 0 &&
          photosByRow != null &&
          photosByRow.isNotEmpty) {
        final picsForRow = photosByRow[r];
        if (picsForRow != null && picsForRow.isNotEmpty) {
          // Altura de la fila solo si realmente tiene fotos.
          sheet.setRowHeightInPixels(excelRow, photoRowHeightPx);

          for (int p = 0; p < picsForRow.length && p < maxPhotosPerRow; p++) {
            final col = firstPhotoCol + p;
            final bytes = picsForRow[p];
            if (bytes.isEmpty) {
              sheet.getRangeByIndex(excelRow, col).setText('N/D');
              continue;
            }

            try {
              final picture = sheet.pictures.addBase64(
                excelRow,
                col,
                base64Encode(bytes),
              );
              picture.width = photoThumbW;
              picture.height = photoThumbH;
              embeddedCount++;
              // Nota: en Flutter XlsIO no existen picture.left/top.
            } catch (_) {
              // Si una imagen esta corrupta, no rompemos el XLSX.
              sheet.getRangeByIndex(excelRow, col).setText('N/D');
            }
          }
        }
      }
    }

    // --------------------------
    // 3) Bordes finos para toda el area usada
    // --------------------------
    final int lastRow = rows.length + 1; // incluye headers
    final tableRange = sheet.getRangeByIndex(1, 1, lastRow, safeLastCol);
    tableRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

    if (rows.isNotEmpty) {
      sheet.getRangeByIndex(2, 1).freezePanes();
      try {
        sheet.autoFilters.filterRange =
            sheet.getRangeByIndex(1, 1, lastRow, safeLastCol);
      } catch (_) {}
    }

    // --------------------------
    // 4) Anchos: autoFit con fallback seguro
    // --------------------------
    // Solo texto (incluye '#', GPS), fotos ya tienen ancho fijo.
    final int lastTextCol = math.max(1, baseColumnsCount);
    for (int col = 1; col <= lastTextCol; col++) {
      try {
        sheet.autoFitColumn(col);
      } catch (_) {
        // Fallback heuristico en px (evita romper la exportacion).
        final maxLen = _maxTextLenForColumn(
          headers: columns,
          rows: rows,
          excelCol: col,
          includeIndexColumn: includeIndexColumn,
        );
        final px = _widthPxForLen(maxLen);
        sheet.setColumnWidthInPixels(col, px);
      }
    }

    if (useEmbedded && embeddedCols.isNotEmpty) {
      for (final idx in embeddedCols) {
        if (idx < 0 || idx >= textCols) continue;
        final col = textStartCol + idx;
        sheet.setColumnWidthInPixels(col, photoColWidthPx);
      }
    }

    // --------------------------
    // 5) Hoja "Fotos" (opcional)
    // --------------------------
    if (photoMeta != null && photoMeta.isNotEmpty) {
      embeddedCount += _buildFotosSheet(
        workbook,
        photoMeta: photoMeta,
        photosByRow: photosByRow ?? const <int, List<Uint8List>>{},
      );
    }

    if (attachments != null && attachments.isNotEmpty) {
      _buildAttachmentsSheet(
        workbook,
        attachments: attachments,
      );
    }

    final computedMeta = reportMeta ??
        ExportReportMeta(
          sheetName: sheetName,
          exportedAt: DateTime.now(),
          rowsCount: rows.length,
          columnsCount: textCols,
          nonEmptyCells: _countNonEmptyCells(rows),
          photosCount: _photosCount(
            photosByRow: photosByRow,
            attachments: attachments,
          ),
          videosCount: _attachmentsCountByType(attachments, 'video'),
          audiosCount: _attachmentsCountByType(attachments, 'audio'),
          gpsCount: _gpsCount(gpsByRow, attachments: attachments),
        );

    if (includeCoverSheet) {
      _buildCoverSheet(workbook, reportMeta: computedMeta);
    }

    if (includeSummarySheet) {
      _buildSummarySheet(
        workbook,
        rowsCount: rows.length,
        photosCount: computedMeta.photosCount,
        gpsCount: computedMeta.gpsCount,
        reportMeta: computedMeta,
      );
    }

    addBitflowMetaSheet(
      workbook,
      embeddedImageCount: embeddedCount,
      exportVersion: _kExportVersion,
      appVersion: _kAppVersion.isEmpty ? null : _kAppVersion,
      timestamp: DateTime.now(),
    );

    final bytes = workbook.saveAsStream();
    return Uint8List.fromList(bytes);
  } finally {
    workbook.dispose();
  }
}

void addBitflowMetaSheet(
  xlsio.Workbook workbook, {
  required int embeddedImageCount,
  String? exportVersion,
  String? appVersion,
  DateTime? timestamp,
}) {
  final meta = workbook.worksheets.addWithName('_BITFLOW_META');
  meta.visibility = xlsio.WorksheetVisibility.hidden;
  meta.showGridlines = false;

  final ts = (timestamp ?? DateTime.now()).toIso8601String();
  final rows = <List<String>>[
    ['exportVersion', exportVersion ?? _kExportVersion],
    ['appVersion', appVersion ?? ''],
    ['timestamp', ts],
    ['embeddedImageCount', embeddedImageCount.toString()],
  ];

  for (int i = 0; i < rows.length; i++) {
    meta.getRangeByIndex(i + 1, 1).setText(rows[i][0]);
    meta.getRangeByIndex(i + 1, 2).setText(rows[i][1]);
  }

  try {
    meta.autoFitColumn(1);
    meta.autoFitColumn(2);
  } catch (_) {}
}

int _buildFotosSheet(
  xlsio.Workbook workbook, {
  required List<PhotoMeta> photoMeta,
  required Map<int, List<Uint8List>> photosByRow,
}) {
  final photosSheet = workbook.worksheets.addWithName('Fotos');
  photosSheet.showGridlines = false;

  final headers = [
    'Row',
    'Col',
    'File',
    'AddedAt',
    'Lat',
    'Lon',
    'Accuracy',
    'Source',
    'Foto',
  ];

  for (int c = 0; c < headers.length; c++) {
    photosSheet.getRangeByIndex(1, c + 1).setText(headers[c]);
  }

  final previewCol = headers.length;
  photosSheet.setColumnWidthInPixels(previewCol, 112);
  photosSheet.setRowHeightInPixels(1, 28);
  photosSheet.getRangeByIndex(2, 1).freezePanes();

  const hiddenHeaders = <String>{'File', 'Mime', 'Path'};
  for (int c = 0; c < headers.length; c++) {
    if (!hiddenHeaders.contains(headers[c])) continue;
    final existing = photosSheet.columns[c + 1];
    final col = existing ?? (xlsio.Column(photosSheet)..index = c + 1);
    col.isHidden = true;
    photosSheet.columns[c + 1] = col;
  }

  int embeddedCount = 0;

  for (int i = 0; i < photoMeta.length; i++) {
    final item = photoMeta[i];
    final row = i + 2;
    final bytes = (photosByRow[item.rowIndex] != null &&
            item.photoIndex < photosByRow[item.rowIndex]!.length)
        ? photosByRow[item.rowIndex]![item.photoIndex]
        : null;

    photosSheet.getRangeByIndex(row, 1).setNumber(item.rowIndex + 1);
    photosSheet.getRangeByIndex(row, 2).setNumber(item.colIndex + 1);
    photosSheet.getRangeByIndex(row, 3).setText('');
    photosSheet.getRangeByIndex(row, 4).setText(item.addedAt.toIso8601String());
    if (item.lat != null) {
      photosSheet.getRangeByIndex(row, 5).setNumber(item.lat ?? 0);
    }
    if (item.lng != null) {
      photosSheet.getRangeByIndex(row, 6).setNumber(item.lng ?? 0);
    }
    if (item.accuracy != null) {
      photosSheet.getRangeByIndex(row, 7).setNumber(item.accuracy ?? 0);
    }
    photosSheet.getRangeByIndex(row, 8).setText(item.sourceLabel);
    photosSheet.setRowHeightInPixels(row, 96);

    if (bytes != null && bytes.isNotEmpty) {
      try {
        final picture = photosSheet.pictures.addBase64(
          row,
          previewCol,
          base64Encode(bytes),
        );
        picture.width = 110;
        picture.height = 82;
        embeddedCount++;
      } catch (_) {
        photosSheet.getRangeByIndex(row, previewCol).setText('N/D');
      }
    } else {
      photosSheet.getRangeByIndex(row, previewCol).setText('N/D');
    }
  }

  final lastPhotoRow = photoMeta.length + 1;
  final lastPhotoCol = headers.length;
  final headerRange = photosSheet.getRangeByIndex(1, 1, 1, lastPhotoCol);
  headerRange.cellStyle.bold = true;
  headerRange.cellStyle.backColor = '#F4F0E6';
  headerRange.cellStyle.hAlign = xlsio.HAlignType.center;
  headerRange.cellStyle.vAlign = xlsio.VAlignType.center;
  headerRange.cellStyle.fontSize = 11;

  if (photoMeta.isNotEmpty) {
    final bodyRange =
        photosSheet.getRangeByIndex(1, 1, lastPhotoRow, lastPhotoCol);
    bodyRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
  }

  for (int c = 0; c < lastPhotoCol - 1; c++) {
    try {
      if (!hiddenHeaders.contains(headers[c])) {
        photosSheet.autoFitColumn(c + 1);
      }
    } catch (_) {}
  }

  return embeddedCount;
}

void _buildAttachmentsSheet(
  xlsio.Workbook workbook, {
  required List<AttachmentRow> attachments,
}) {
  final sheet = workbook.worksheets.addWithName('Evidencias');
  sheet.showGridlines = false;

  const headers = [
    'Celda',
    'Tipo',
    'Archivo',
    'Detalle',
    'Ruta en ZIP',
  ];

  for (int c = 0; c < headers.length; c++) {
    sheet.getRangeByIndex(1, c + 1).setText(headers[c]);
  }

  final headerRange = sheet.getRangeByIndex(1, 1, 1, headers.length);
  headerRange.cellStyle.bold = true;
  headerRange.cellStyle.backColor = '#FF1F2937';
  headerRange.cellStyle.fontColor = '#FFFFFFFF';
  headerRange.cellStyle.hAlign = xlsio.HAlignType.center;
  headerRange.cellStyle.vAlign = xlsio.VAlignType.center;
  headerRange.cellStyle.fontSize = 11;

  for (int i = 0; i < attachments.length; i++) {
    final row = i + 2;
    final item = attachments[i];
    sheet.getRangeByIndex(row, 1).setText(item.cellRef);
    sheet.getRangeByIndex(row, 2).setText(_evidenceTypeLabel(item.type));
    sheet.getRangeByIndex(row, 3).setText(item.fileName);
    sheet.getRangeByIndex(row, 4).setText(item.notes);
    sheet.getRangeByIndex(row, 5).setText(item.relativePath);
    if (i.isOdd) {
      final rowRange = sheet.getRangeByIndex(row, 1, row, headers.length);
      rowRange.cellStyle.backColor = '#FFF8FAFC';
    }
  }

  final lastRow = attachments.length + 1;
  if (attachments.isNotEmpty) {
    final bodyRange = sheet.getRangeByIndex(
      1,
      1,
      lastRow,
      headers.length,
    );
    bodyRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
  }

  sheet.getRangeByIndex(2, 1).freezePanes();
  try {
    sheet.autoFilters.filterRange =
        sheet.getRangeByIndex(1, 1, attachments.length + 1, headers.length);
  } catch (_) {}

  for (int c = 1; c <= headers.length; c++) {
    try {
      sheet.autoFitColumn(c);
    } catch (_) {}
  }
}

bool _hasGps(List<GpsExport?>? gpsByRow) {
  if (gpsByRow == null || gpsByRow.isEmpty) return false;
  for (final g in gpsByRow) {
    if (g != null && g.hasFix) return true;
  }
  return false;
}

int _gpsCount(List<GpsExport?>? gpsByRow, {List<AttachmentRow>? attachments}) {
  if (attachments != null && attachments.isNotEmpty) {
    return attachments.where((a) => a.type == 'gps').length;
  }
  if (gpsByRow == null || gpsByRow.isEmpty) return 0;
  int count = 0;
  for (final g in gpsByRow) {
    if (g != null && g.hasFix) count++;
  }
  return count;
}

int _photosCount({
  required Map<int, List<Uint8List>>? photosByRow,
  required List<AttachmentRow>? attachments,
}) {
  if (attachments != null && attachments.isNotEmpty) {
    return attachments.where((a) => a.type == 'photo').length;
  }
  if (photosByRow == null || photosByRow.isEmpty) return 0;
  return photosByRow.values.fold<int>(0, (prev, list) => prev + list.length);
}

void _setSheetValue(xlsio.Worksheet sheet, int r, int c, String v) {
  final trimmed = v.trim();
  if (FormulaEngine.isFormula(trimmed)) {
    sheet.getRangeByIndex(r, c).setFormula(trimmed);
    return;
  }
  final numVal = double.tryParse(trimmed);
  if (numVal != null && RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(trimmed)) {
    sheet.getRangeByIndex(r, c).setNumber(numVal);
    return;
  }
  final dt = DateTime.tryParse(trimmed);
  if (dt != null) {
    sheet.getRangeByIndex(r, c).setDateTime(dt);
    return;
  }
  sheet.getRangeByIndex(r, c).setText(v);
}

void _buildCoverSheet(
  xlsio.Workbook wb, {
  ExportReportMeta? reportMeta,
}) {
  final cover = wb.worksheets.addWithName('Caratula');
  cover.showGridlines = false;

  final title = cover.getRangeByIndex(1, 1, 1, 5);
  title.merge();
  title.setText('BITFLOW · REPORTE DE RELEVAMIENTO');
  title.cellStyle.bold = true;
  title.cellStyle.fontSize = 16;
  title.cellStyle.backColor = '#FF1F2937';
  title.cellStyle.fontColor = '#FFFFFFFF';

  final generatedAt = reportMeta?.exportedAt ?? DateTime.now();
  final labels = <List<String>>[
    ['Planilla', reportMeta?.sheetName ?? '-'],
    ['Fecha de exportacion', _formatExportStamp(generatedAt)],
    ['Registros', '${reportMeta?.rowsCount ?? 0}'],
    ['Columnas', '${reportMeta?.columnsCount ?? 0}'],
    ['Celdas con datos', '${reportMeta?.nonEmptyCells ?? 0}'],
    ['Fotos', '${reportMeta?.photosCount ?? 0}'],
    ['Videos', '${reportMeta?.videosCount ?? 0}'],
    ['Audios', '${reportMeta?.audiosCount ?? 0}'],
    ['Puntos GPS', '${reportMeta?.gpsCount ?? 0}'],
  ];
  for (int i = 0; i < labels.length; i++) {
    final row = i + 3;
    cover.getRangeByIndex(row, 1).setText(labels[i][0]);
    cover.getRangeByIndex(row, 2, row, 5).merge();
    cover.getRangeByIndex(row, 2).setText(labels[i][1]);
    if (i.isOdd) {
      cover.getRangeByIndex(row, 1, row, 5).cellStyle.backColor = '#FFF8FAFC';
    }
  }
  cover.getRangeByIndex(3, 1, labels.length + 2, 1).cellStyle.bold = true;
  try {
    cover.autoFitColumn(1);
    cover.setColumnWidthInPixels(2, 360);
  } catch (_) {}
}

void _buildSummarySheet(
  xlsio.Workbook wb, {
  required int rowsCount,
  required int photosCount,
  required int gpsCount,
  ExportReportMeta? reportMeta,
}) {
  final summary = wb.worksheets.addWithName('Resumen');
  summary.showGridlines = false;
  final data = [
    ['Filas', rowsCount],
    ['Columnas', reportMeta?.columnsCount ?? 0],
    ['Celdas con dato', reportMeta?.nonEmptyCells ?? 0],
    ['Fotos', photosCount],
    ['Videos', reportMeta?.videosCount ?? 0],
    ['Audios', reportMeta?.audiosCount ?? 0],
    ['Ubicaciones', gpsCount],
  ];

  final title = summary.getRangeByIndex(1, 1, 1, 2);
  title.merge();
  title.setText('Resumen ejecutivo');
  title.cellStyle.bold = true;
  title.cellStyle.fontSize = 13;
  title.cellStyle.backColor = '#FFE2E8F0';

  final header = summary.getRangeByIndex(2, 1, 2, 2);
  header.cellStyle.bold = true;
  header.cellStyle.backColor = '#FF1F2937';
  header.cellStyle.fontColor = '#FFFFFFFF';
  summary.getRangeByIndex(2, 1).setText('Indicador');
  summary.getRangeByIndex(2, 2).setText('Valor');

  for (int i = 0; i < data.length; i++) {
    final row = i + 3;
    summary.getRangeByIndex(row, 1).setText(data[i][0].toString());
    summary.getRangeByIndex(row, 2).setNumber(
          (data[i][1] is num) ? (data[i][1] as num).toDouble() : 0,
        );
    if (i.isOdd) {
      summary.getRangeByIndex(row, 1, row, 2).cellStyle.backColor = '#FFF8FAFC';
    }
  }

  summary.getRangeByIndex(2, 1, data.length + 2, 2).cellStyle.borders.all
      .lineStyle = xlsio.LineStyle.thin;
  summary.getRangeByIndex(3, 2, data.length + 2, 2).numberFormat = '#,##0';
  summary.getRangeByIndex(3, 1).freezePanes();

  try {
    summary.autoFitColumn(1);
    summary.autoFitColumn(2);
  } catch (_) {}
}

String _evidenceTypeLabel(String type) {
  switch (type.toLowerCase()) {
    case 'photo':
      return 'Foto';
    case 'video':
      return 'Video';
    case 'audio':
      return 'Audio';
    case 'gps':
      return 'GPS';
    default:
      return 'Archivo';
  }
}

String _formatExportStamp(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}

int _attachmentsCountByType(List<AttachmentRow>? attachments, String type) {
  if (attachments == null || attachments.isEmpty) return 0;
  return attachments.where((a) => a.type.toLowerCase() == type).length;
}

int _countNonEmptyCells(List<List<String>> rows) {
  var count = 0;
  for (final row in rows) {
    for (final cell in row) {
      if (cell.trim().isNotEmpty) count++;
    }
  }
  return count;
}

String _sanitizeWorksheetName(String name) {
  var n = name.trim();
  if (n.isEmpty) return 'PLANILLA';
  // Excel: max 31 y sin : \ / ? * [ ]
  n = n.replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ');
  n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (n.isEmpty) n = 'PLANILLA';
  if (n.length > 31) n = n.substring(0, 31).trim();
  return n.isEmpty ? 'PLANILLA' : n;
}

int _maxTextLenForColumn({
  required List<String> headers,
  required List<List<String>> rows,
  required int excelCol,
  required bool includeIndexColumn,
}) {
  // excelCol: 1 = "#" (si se incluye), 2 = headers[0], ...
  int maxLen = 0;

  if (includeIndexColumn && excelCol == 1) {
    maxLen = math.max(maxLen, 1); // "#"
    final n = rows.length.toString();
    maxLen = math.max(maxLen, n.length);
    return maxLen;
  }

  final idx = includeIndexColumn ? (excelCol - 2) : (excelCol - 1);
  if (idx >= 0 && idx < headers.length) {
    maxLen = math.max(maxLen, headers[idx].length);
  }

  for (final r in rows) {
    if (idx >= 0 && idx < r.length) {
      maxLen = math.max(maxLen, r[idx].length);
    }
  }
  return maxLen;
}

int _widthPxForLen(int len) {
  final clamped = len.clamp(0, 60);
  return (80 + (clamped * 7)).toInt();
}
