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
    required this.sheetName,
    required this.cellRef,
    required this.rowLabel,
    required this.type,
    required this.fileName,
    required this.description,
    required this.addedAt,
    required this.relativePath,
    this.rowNumber,
    this.latitude,
    this.longitude,
  });

  final String sheetName;
  final String cellRef;
  final String rowLabel;
  final String type;
  final String fileName;
  final String description;
  final DateTime? addedAt;
  final String relativePath;
  final int? rowNumber;
  final double? latitude;
  final double? longitude;

  String get cellOrRow {
    final cell = cellRef.trim();
    if (cell.isNotEmpty) return cell;
    return rowLabel.trim();
  }
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
  List<String>? columnTypes,
  String sheetName = 'PLANILLA',
  bool includeIndexColumn = true,
  bool includeCoverSheet = false,
  bool includeSummarySheet = false,
  DateTime? exportedAt,
  String? exportFileName,
  String? clientName,
  String? projectName,
  String? responsibleName,
  String? observations,
  String? qualityStatus,
  int? qualityCompletionPercent,
  int? qualityRowsReady,
  int? qualityRowsWithData,
  int? qualityInvalidCells,
  int? qualityPendingRequired,
  String brandName = 'BitFlow',
}) async {
  final workbook = xlsio.Workbook(1);
  try {
    final sheet = workbook.worksheets[0];
    sheet.name = _sanitizeWorksheetName(sheetName);
    sheet.tabColor = '#1F3A5F';

    const int headerRow = 1;
    const int firstDataRow = headerRow + 1;

    // Ancho real de texto: puede haber filas mas largas que headers.
    int textCols = columns.length;
    for (final r in rows) {
      if (r.length > textCols) textCols = r.length;
    }
    if (textCols < 0) textCols = 0;
    final normalizedColumnTypes = List<String>.generate(
      textCols,
      (index) {
        if (columnTypes == null || index >= columnTypes.length) return 'text';
        final value = columnTypes[index].trim().toLowerCase();
        return value.isEmpty ? 'text' : value;
      },
      growable: false,
    );

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

    // Estilos profesionales (nombre unico por seguridad).
    final styleSeed = DateTime.now().microsecondsSinceEpoch;
    final headerStyle = workbook.styles.add('HeaderStyle_$styleSeed');
    headerStyle.bold = true;
    headerStyle.fontColor = '#FFFFFFFF';
    headerStyle.backColor = '#FF1F3A5F';
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;

    final oddRowStyle = workbook.styles.add('BodyOddStyle_$styleSeed');
    oddRowStyle.backColor = '#FFFFFFFF';

    final evenRowStyle = workbook.styles.add('BodyEvenStyle_$styleSeed');
    evenRowStyle.backColor = '#FFF7FAFC';

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
        'Latitud GPS',
        'Longitud GPS',
        'Precisión GPS (m)',
        'Fecha GPS',
        'Origen GPS',
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
    sheet.autoFilters.filterRange = sheet.getRangeByIndex(
        headerRow, 1, math.max(headerRow, rows.length + 1), safeLastCol);
    sheet.getRangeByIndex(firstDataRow, 1).freezePanes();

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
      final rowStyle = r.isEven ? oddRowStyle : evenRowStyle;
      sheet.getRangeByIndex(excelRow, 1, excelRow, safeLastCol).cellStyle =
          rowStyle;

      // Columna "#"
      if (includeIndexColumn) {
        final indexCell = sheet.getRangeByIndex(excelRow, 1);
        indexCell.setNumber((r + 1).toDouble());
        indexCell.numberFormat = '0';
      }

      // Texto: escribe hasta textCols, padding con ''.
      for (int c = 0; c < textCols; c++) {
        final v = (c < rowValues.length) ? rowValues[c] : '';
        _setSheetValue(
          sheet,
          excelRow,
          textStartCol + c,
          v,
          columnType: normalizedColumnTypes[c],
        );
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

          final accuracyCell = sheet.getRangeByIndex(excelRow, gpsStartCol + 2);
          accuracyCell.setNumber(gps.accuracy ?? 0);
          accuracyCell.numberFormat = '0.00';

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

    for (int c = 0; c < textCols; c++) {
      final excelCol = textStartCol + c;
      final widthPx = _preferredColumnWidthPx(
        type: normalizedColumnTypes[c],
        maxLen: _maxTextLenForColumn(
          headers: columns,
          rows: rows,
          excelCol: excelCol,
          includeIndexColumn: includeIndexColumn,
        ),
      );
      sheet.setColumnWidthInPixels(excelCol, widthPx);
    }

    if (includeIndexColumn) {
      sheet.setColumnWidthInPixels(1, 56);
    }

    if (hasGps) {
      sheet.setColumnWidthInPixels(gpsStartCol, 118);
      sheet.setColumnWidthInPixels(gpsStartCol + 1, 118);
      sheet.setColumnWidthInPixels(gpsStartCol + 2, 112);
      sheet.setColumnWidthInPixels(gpsStartCol + 3, 142);
      sheet.setColumnWidthInPixels(gpsStartCol + 4, 132);
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

    xlsio.Worksheet? coverSheet;
    if (includeCoverSheet) {
      coverSheet = _buildCoverSheet(
        workbook,
        sheetName: sheetName,
        exportedAt: exportedAt ?? DateTime.now(),
        exportFileName: exportFileName,
        clientName: clientName,
        projectName: projectName,
        responsibleName: responsibleName,
        observations: observations,
        brandName: brandName,
      );
    }

    xlsio.Worksheet? summarySheet;
    if (includeSummarySheet) {
      summarySheet = _buildSummarySheet(
        workbook,
        rowsCount: rows.length,
        photosCount: _photosCount(
          photosByRow: photosByRow,
          attachments: attachments,
        ),
        gpsCount: _gpsCount(gpsByRow, attachments: attachments),
        videosCount: _videosCount(attachments),
        audiosCount: _audiosCount(attachments),
        evidenceCount: _evidenceCount(attachments),
        exportedAt: exportedAt ?? DateTime.now(),
        exportFileName: exportFileName,
        sheetName: sheetName,
        qualityStatus: qualityStatus,
        qualityCompletionPercent: qualityCompletionPercent,
        qualityRowsReady: qualityRowsReady,
        qualityRowsWithData: qualityRowsWithData,
        qualityInvalidCells: qualityInvalidCells,
        qualityPendingRequired: qualityPendingRequired,
        brandName: brandName,
      );
    }

    addBitflowMetaSheet(
      workbook,
      embeddedImageCount: embeddedCount,
      exportVersion: _kExportVersion,
      appVersion: _kAppVersion.isEmpty ? null : _kAppVersion,
      timestamp: DateTime.now(),
    );

    if (coverSheet != null) {
      workbook.worksheets.moveTo(coverSheet, 0);
    }
    if (summarySheet != null) {
      workbook.worksheets.moveTo(summarySheet, coverSheet != null ? 1 : 0);
    }

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
    final addedAtCell = photosSheet.getRangeByIndex(row, 4);
    addedAtCell.setDateTime(item.addedAt.toLocal());
    addedAtCell.numberFormat = 'yyyy-mm-dd hh:mm';
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
  sheet.tabColor = '#2D4C7A';

  const headers = [
    'Hoja',
    'Celda',
    'Fila',
    'Tipo',
    'Archivo',
    'Descripción',
    'Fecha',
    'Latitud',
    'Longitud',
    'Ruta relativa',
  ];

  for (int c = 0; c < headers.length; c++) {
    sheet.getRangeByIndex(1, c + 1).setText(headers[c]);
  }

  final styleSeed = DateTime.now().microsecondsSinceEpoch;
  final headerStyle = workbook.styles.add('EvidenceHeaderStyle_$styleSeed');
  headerStyle.bold = true;
  headerStyle.fontColor = '#FFFFFFFF';
  headerStyle.backColor = '#FF2D4C7A';
  headerStyle.hAlign = xlsio.HAlignType.center;
  headerStyle.vAlign = xlsio.VAlignType.center;
  final headerRange = sheet.getRangeByIndex(1, 1, 1, headers.length);
  headerRange.cellStyle = headerStyle;

  final oddRowStyle = workbook.styles.add('EvidenceOddStyle_$styleSeed');
  oddRowStyle.backColor = '#FFFFFFFF';
  final evenRowStyle = workbook.styles.add('EvidenceEvenStyle_$styleSeed');
  evenRowStyle.backColor = '#FFF7FAFC';

  for (int i = 0; i < attachments.length; i++) {
    final row = i + 2;
    final item = attachments[i];
    sheet.getRangeByIndex(row, 1, row, headers.length).cellStyle =
        i.isEven ? oddRowStyle : evenRowStyle;
    sheet.getRangeByIndex(row, 1).setText(item.sheetName);
    sheet.getRangeByIndex(row, 2).setText(item.cellRef);
    sheet
        .getRangeByIndex(row, 3)
        .setText(item.rowNumber?.toString() ?? item.rowLabel);
    sheet.getRangeByIndex(row, 4).setText(_displayAttachmentType(item.type));
    sheet.getRangeByIndex(row, 5).setText(item.fileName);
    sheet.getRangeByIndex(row, 6).setText(item.description);
    final dateCell = sheet.getRangeByIndex(row, 7);
    if (item.addedAt != null) {
      dateCell.setDateTime(item.addedAt!.toLocal());
      dateCell.numberFormat = 'yyyy-mm-dd hh:mm';
    } else {
      dateCell.setText('');
    }
    final latCell = sheet.getRangeByIndex(row, 8);
    if (item.latitude != null) {
      latCell.setNumber(item.latitude!);
      latCell.numberFormat = '0.000000';
    } else {
      latCell.setText('');
    }
    final lonCell = sheet.getRangeByIndex(row, 9);
    if (item.longitude != null) {
      lonCell.setNumber(item.longitude!);
      lonCell.numberFormat = '0.000000';
    } else {
      lonCell.setText('');
    }
    sheet.getRangeByIndex(row, 10).setText(item.relativePath);
  }

  final lastRow = attachments.length + 1;
  if (attachments.isNotEmpty) {
    final bodyRange = sheet.getRangeByIndex(1, 1, lastRow, headers.length);
    bodyRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
  }

  sheet.autoFilters.filterRange =
      sheet.getRangeByIndex(1, 1, math.max(1, lastRow), headers.length);
  sheet.getRangeByIndex(2, 1).freezePanes();

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
    return _countAttachmentsByType(attachments, 'gps');
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
    return _countAttachmentsByType(attachments, 'foto') +
        _countAttachmentsByType(attachments, 'photo');
  }
  if (photosByRow == null || photosByRow.isEmpty) return 0;
  return photosByRow.values.fold<int>(0, (prev, list) => prev + list.length);
}

void _setSheetValue(
  xlsio.Worksheet sheet,
  int r,
  int c,
  String v, {
  String columnType = 'text',
}) {
  final cell = sheet.getRangeByIndex(r, c);
  final trimmed = v.trim();
  if (FormulaEngine.isFormula(trimmed)) {
    cell.setFormula(trimmed);
    return;
  }
  final normalizedType = columnType.trim().toLowerCase();
  if (normalizedType == 'checkbox') {
    final boolValue = _parseBoolText(trimmed);
    if (boolValue != null) {
      cell.setText(boolValue ? 'Sí' : 'No');
      return;
    }
  }
  final numVal = double.tryParse(trimmed);
  if (numVal != null &&
      (normalizedType == 'number' ||
          RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(trimmed))) {
    cell.setNumber(numVal);
    cell.numberFormat = trimmed.contains('.') ? '#,##0.00' : '0';
    return;
  }
  final dt = _tryParseDateTime(trimmed);
  if (dt != null) {
    cell.setDateTime(dt);
    cell.numberFormat =
        normalizedType == 'date' ? 'yyyy-mm-dd' : 'yyyy-mm-dd hh:mm';
    return;
  }
  cell.setText(v);
}

bool? _parseBoolText(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  if (const {'si', 'sí', 'yes', 'true', 'ok', '1'}.contains(normalized)) {
    return true;
  }
  if (const {'no', 'false', '0', 'pendiente'}.contains(normalized)) {
    return false;
  }
  return null;
}

DateTime? _tryParseDateTime(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final parsed = DateTime.tryParse(trimmed);
  if (parsed != null) return parsed;
  final simpleDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
  if (simpleDate != null) {
    return DateTime(
      int.parse(simpleDate.group(1)!),
      int.parse(simpleDate.group(2)!),
      int.parse(simpleDate.group(3)!),
    );
  }
  return null;
}

xlsio.Worksheet _buildCoverSheet(
  xlsio.Workbook wb, {
  required String sheetName,
  required DateTime exportedAt,
  String? exportFileName,
  String? clientName,
  String? projectName,
  String? responsibleName,
  String? observations,
  String brandName = 'BitFlow',
}) {
  final cover = wb.worksheets.addWithName('Caratula');
  cover.showGridlines = false;
  cover.tabColor = '#15304D';

  final styleSeed = DateTime.now().microsecondsSinceEpoch;
  final brandStyle = wb.styles.add('CoverBrand_$styleSeed');
  brandStyle.backColor = '#FF15304D';
  brandStyle.fontColor = '#FFFFFFFF';
  brandStyle.bold = true;
  brandStyle.fontSize = 20;
  brandStyle.hAlign = xlsio.HAlignType.center;
  brandStyle.vAlign = xlsio.VAlignType.center;

  final titleStyle = wb.styles.add('CoverTitle_$styleSeed');
  titleStyle.fontColor = '#FF15304D';
  titleStyle.bold = true;
  titleStyle.fontSize = 18;
  titleStyle.vAlign = xlsio.VAlignType.center;

  final sectionStyle = wb.styles.add('CoverSection_$styleSeed');
  sectionStyle.backColor = '#FFEFF4F8';
  sectionStyle.fontColor = '#FF15304D';
  sectionStyle.bold = true;

  final labelStyle = wb.styles.add('CoverLabel_$styleSeed');
  labelStyle.fontColor = '#FF6B7785';
  labelStyle.bold = true;

  final valueStyle = wb.styles.add('CoverValue_$styleSeed');
  valueStyle.fontColor = '#FF1F2A36';
  valueStyle.wrapText = true;
  valueStyle.vAlign = xlsio.VAlignType.top;

  final notesStyle = wb.styles.add('CoverNotes_$styleSeed');
  notesStyle.fontColor = '#FF1F2A36';
  notesStyle.wrapText = true;
  notesStyle.vAlign = xlsio.VAlignType.top;

  final brandRange = cover.getRangeByIndex(1, 1, 2, 8);
  brandRange.merge();
  brandRange.setText('$brandName | Exportación profesional');
  brandRange.cellStyle = brandStyle;

  final titleRange = cover.getRangeByIndex(4, 1, 5, 8);
  titleRange.merge();
  titleRange.setText(
    sheetName.trim().isEmpty ? 'Planilla BitFlow' : sheetName.trim(),
  );
  titleRange.cellStyle = titleStyle;

  final subtitleRange = cover.getRangeByIndex(6, 1, 6, 8);
  subtitleRange.merge();
  subtitleRange.setText(
    'Exportado el ${_formatCellDateTime(exportedAt.toLocal())}'
    '${exportFileName != null && exportFileName.trim().isNotEmpty ? ' | $exportFileName' : ''}',
  );

  final infoHeader = cover.getRangeByIndex(8, 1, 8, 8);
  infoHeader.merge();
  infoHeader.setText('Datos de referencia');
  infoHeader.cellStyle = sectionStyle;

  final fields = <({String label, String value})>[
    (label: 'Cliente', value: _coverValue(clientName)),
    (label: 'Obra / proyecto', value: _coverValue(projectName)),
    (label: 'Responsable', value: _coverValue(responsibleName)),
    (label: 'Planilla', value: _coverValue(sheetName)),
    (label: 'Archivo', value: _coverValue(exportFileName)),
    (label: 'Fecha de exportación', value: _formatCellDateTime(exportedAt)),
  ];

  for (int i = 0; i < fields.length; i++) {
    final row = 10 + i;
    final labelRange = cover.getRangeByIndex(row, 1, row, 2);
    labelRange.merge();
    labelRange.setText(fields[i].label);
    labelRange.cellStyle = labelStyle;

    final valueRange = cover.getRangeByIndex(row, 3, row, 8);
    valueRange.merge();
    valueRange.setText(fields[i].value);
    valueRange.cellStyle = valueStyle;
  }

  final notesHeader = cover.getRangeByIndex(18, 1, 18, 8);
  notesHeader.merge();
  notesHeader.setText('Observaciones');
  notesHeader.cellStyle = sectionStyle;

  final notesRange = cover.getRangeByIndex(19, 1, 24, 8);
  notesRange.merge();
  notesRange.setText(_coverValue(observations));
  notesRange.cellStyle = notesStyle;

  for (int col = 1; col <= 8; col++) {
    cover.setColumnWidthInPixels(col, col <= 2 ? 150 : 132);
  }
  cover.setRowHeightInPixels(1, 24);
  cover.setRowHeightInPixels(2, 24);
  cover.setRowHeightInPixels(4, 24);
  cover.setRowHeightInPixels(5, 24);
  cover.setRowHeightInPixels(19, 26);
  cover.setRowHeightInPixels(20, 26);
  cover.setRowHeightInPixels(21, 26);
  cover.setRowHeightInPixels(22, 26);
  cover.setRowHeightInPixels(23, 26);
  cover.setRowHeightInPixels(24, 26);
  return cover;
}

xlsio.Worksheet _buildSummarySheet(
  xlsio.Workbook wb, {
  required int rowsCount,
  required int photosCount,
  required int gpsCount,
  required int videosCount,
  required int audiosCount,
  required int evidenceCount,
  required DateTime exportedAt,
  String? exportFileName,
  required String sheetName,
  String? qualityStatus,
  int? qualityCompletionPercent,
  int? qualityRowsReady,
  int? qualityRowsWithData,
  int? qualityInvalidCells,
  int? qualityPendingRequired,
  String brandName = 'BitFlow',
}) {
  final summary = wb.worksheets.addWithName('Resumen');
  summary.showGridlines = false;
  summary.tabColor = '#436A8B';

  final styleSeed = DateTime.now().microsecondsSinceEpoch;
  final titleStyle = wb.styles.add('SummaryTitle_$styleSeed');
  titleStyle.backColor = '#FF15304D';
  titleStyle.fontColor = '#FFFFFFFF';
  titleStyle.bold = true;
  titleStyle.fontSize = 16;
  titleStyle.hAlign = xlsio.HAlignType.center;
  titleStyle.vAlign = xlsio.VAlignType.center;

  final headerStyle = wb.styles.add('SummaryHeader_$styleSeed');
  headerStyle.backColor = '#FFEFF4F8';
  headerStyle.fontColor = '#FF15304D';
  headerStyle.bold = true;

  final labelStyle = wb.styles.add('SummaryLabel_$styleSeed');
  labelStyle.fontColor = '#FF6B7785';
  labelStyle.bold = true;

  final valueStyle = wb.styles.add('SummaryValue_$styleSeed');
  valueStyle.fontColor = '#FF1F2A36';

  final titleRange = summary.getRangeByIndex(1, 1, 2, 4);
  titleRange.merge();
  titleRange.setText('$brandName | Resumen de exportación');
  titleRange.cellStyle = titleStyle;

  final metaRows = <({String label, String value})>[
    (label: 'Planilla', value: _coverValue(sheetName)),
    (label: 'Archivo', value: _coverValue(exportFileName)),
    (label: 'Fecha de exportación', value: _formatCellDateTime(exportedAt)),
  ];

  for (int i = 0; i < metaRows.length; i++) {
    final row = 4 + i;
    summary.getRangeByIndex(row, 1).setText(metaRows[i].label);
    summary.getRangeByIndex(row, 1).cellStyle = labelStyle;
    final valueRange = summary.getRangeByIndex(row, 2, row, 4);
    valueRange.merge();
    valueRange.setText(metaRows[i].value);
    valueRange.cellStyle = valueStyle;
  }

  final section = summary.getRangeByIndex(9, 1, 9, 4);
  section.merge();
  section.setText('Indicadores');
  section.cellStyle = headerStyle;

  final metrics = <({String label, int value})>[
    (label: 'Total de registros', value: rowsCount),
    (label: 'Total de fotos', value: photosCount),
    (label: 'Total de ubicaciones', value: gpsCount),
    (label: 'Total de videos', value: videosCount),
    (label: 'Total de audios', value: audiosCount),
    (label: 'Total de evidencias', value: evidenceCount),
  ];

  for (int i = 0; i < metrics.length; i++) {
    final row = 11 + i;
    summary.getRangeByIndex(row, 1, row, 3).merge();
    summary.getRangeByIndex(row, 1).setText(metrics[i].label);
    summary.getRangeByIndex(row, 1).cellStyle = valueStyle;
    final valueCell = summary.getRangeByIndex(row, 4);
    valueCell.setNumber(metrics[i].value.toDouble());
    valueCell.numberFormat = '0';
    valueCell.cellStyle = valueStyle;
  }

  final qualitySection = summary.getRangeByIndex(18, 1, 18, 4);
  qualitySection.merge();
  qualitySection.setText('Calidad de datos');
  qualitySection.cellStyle = headerStyle;

  final safeQualityRowsWithData = qualityRowsWithData ?? 0;
  final qualityBase = math.max(safeQualityRowsWithData, rowsCount);
  final qualityRows = <({String label, String value})>[
    (label: 'Estado de carga', value: _coverValue(qualityStatus)),
    (
      label: 'Completitud de obligatorios',
      value: qualityCompletionPercent == null
          ? 'No informado'
          : '${qualityCompletionPercent.clamp(0, 100)}%',
    ),
    (
      label: 'Filas listas',
      value: qualityRowsReady == null
          ? 'No informado'
          : '${qualityRowsReady.clamp(0, qualityBase)}/$qualityBase',
    ),
    (
      label: 'Errores de validacion',
      value: (qualityInvalidCells ?? 0).toString(),
    ),
    (
      label: 'Obligatorios pendientes',
      value: (qualityPendingRequired ?? 0).toString(),
    ),
  ];

  for (int i = 0; i < qualityRows.length; i++) {
    final row = 20 + i;
    summary.getRangeByIndex(row, 1, row, 3).merge();
    summary.getRangeByIndex(row, 1).setText(qualityRows[i].label);
    summary.getRangeByIndex(row, 1).cellStyle = valueStyle;
    final valueRange = summary.getRangeByIndex(row, 4);
    valueRange.setText(qualityRows[i].value);
    valueRange.cellStyle = valueStyle;
  }

  for (int col = 1; col <= 4; col++) {
    summary.setColumnWidthInPixels(col, col == 4 ? 92 : 180);
  }
  summary.setRowHeightInPixels(1, 24);
  summary.setRowHeightInPixels(2, 24);
  summary.setRowHeightInPixels(18, 22);
  return summary;
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
  final clamped = len.clamp(0, 32);
  return (96 + (clamped * 5.5)).toInt();
}

int _preferredColumnWidthPx({
  required String type,
  required int maxLen,
}) {
  switch (type) {
    case 'date':
      return 136;
    case 'number':
      return 110;
    case 'status':
      return 118;
    case 'checkbox':
      return 84;
    default:
      return _widthPxForLen(maxLen);
  }
}

int _videosCount(List<AttachmentRow>? attachments) {
  return _countAttachmentsByType(attachments, 'video');
}

int _audiosCount(List<AttachmentRow>? attachments) {
  return _countAttachmentsByType(attachments, 'audio');
}

int _evidenceCount(List<AttachmentRow>? attachments) {
  if (attachments == null || attachments.isEmpty) return 0;
  return attachments.where((item) => item.type.trim().isNotEmpty).length;
}

int _countAttachmentsByType(List<AttachmentRow>? attachments, String type) {
  if (attachments == null || attachments.isEmpty) return 0;
  final normalized = type.trim().toLowerCase();
  return attachments.where((item) {
    return item.type.trim().toLowerCase() == normalized;
  }).length;
}

String _displayAttachmentType(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'foto':
    case 'photo':
      return 'Foto';
    case 'video':
      return 'Video';
    case 'audio':
      return 'Audio';
    case 'gps':
      return 'GPS';
    default:
      return raw.trim().isEmpty ? 'Archivo' : raw.trim();
  }
}

String _coverValue(String? raw) {
  final value = raw?.trim() ?? '';
  return value.isEmpty ? 'No informado' : value;
}

String _formatCellDateTime(DateTime value) {
  final local = value.toLocal();
  final yyyy = local.year.toString().padLeft(4, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd $hh:$min';
}
