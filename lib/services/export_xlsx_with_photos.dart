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

import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

const String _kExportVersion = 'bitflow_xlsx_v2';
const String _kAppVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: '');
const String _kInk = '#1D1D1F';
const String _kMutedInk = '#6E6E73';
const String _kSoftBlue = '#EAF3FF';
const String _kSoftBlue2 = '#F5FAFF';
const String _kLine = '#D7E3F0';
const String _kLinkBlue = '#0563C1';

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
    this.cellValue = '',
    this.linkTarget,
    this.previewBytes,
    this.lat,
    this.lng,
    this.accuracy,
    this.addedAt,
    this.transcript = '',
  });

  final String cellRef;
  final String type;
  final String fileName;
  final String notes;
  final String relativePath;
  final String cellValue;
  final String? linkTarget;
  final Uint8List? previewBytes;
  final double? lat;
  final double? lng;
  final double? accuracy;
  final DateTime? addedAt;
  final String transcript;

  bool get hasPreview => previewBytes != null && previewBytes!.isNotEmpty;

  String get effectiveLinkTarget {
    final explicit = linkTarget?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    return relativePath.trim();
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
  String sheetName = 'PLANILLA',
  bool includeIndexColumn = true,
  bool includeCoverSheet = false,
  bool includeSummarySheet = false,
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
    headerStyle.backColor = _kSoftBlue;
    headerStyle.fontColor = _kInk;
    headerStyle.fontSize = 11;
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;
    headerStyle.wrapText = true;

    // --------------------------
    // 1) Encabezados
    // --------------------------
    if (includeIndexColumn) {
      sheet.getRangeByIndex(headerRow, 1).setText('#');
    }

    // Headers de texto (si faltan, se completan con vacio).
    for (int i = 0; i < textCols; i++) {
      final title = (i < columns.length) ? columns[i] : '';
      if (title.trim().isNotEmpty) {
        sheet
            .getRangeByIndex(headerRow, textStartCol + i)
            .setText(_polishVisibleText(title));
      }
    }

    if (hasGps) {
      const headers = [
        'GPS Lat',
        'GPS Lon',
        'GPS Acc (m)',
        'GPS Time',
        'GPS Tipo',
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
    sheet.showGridlines = false;
    sheet.setRowHeightInPixels(headerRow, 32);
    try {
      sheet.getRangeByIndex(firstDataRow, 1).freezePanes();
    } catch (_) {}

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
        var v = (c < rowValues.length) ? rowValues[c] : '';
        if (_isEvidenceSummaryColumn(c, columns)) {
          v = _evidenceSummaryForTypes(
            _evidenceTypesForRow(r, attachments),
          );
        }
        _setSheetValue(sheet, excelRow, textStartCol + c, v);
      }

      // GPS
      if (hasGps) {
        final gps =
            (gpsByRow != null && r < gpsByRow.length) ? gpsByRow[r] : null;
        if (gps != null && gps.hasFix) {
          sheet.getRangeByIndex(excelRow, gpsStartCol).setNumber(gps.lat ?? 0);
          sheet
              .getRangeByIndex(excelRow, gpsStartCol + 1)
              .setNumber(gps.lng ?? 0);
          sheet
              .getRangeByIndex(excelRow, gpsStartCol + 2)
              .setNumber(gps.accuracy ?? 0);
          if (gps.ts != null) {
            final cell = sheet.getRangeByIndex(excelRow, gpsStartCol + 3);
            cell.setDateTime(gps.ts!);
            _styleDateCell(cell);
          }
          sheet
              .getRangeByIndex(excelRow, gpsStartCol + 4)
              .setText(gps.isLastKnown ? 'Última ubicación' : 'GPS');
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
              final imageBytes = _prepareImageForOffice(pic.bytes);
              final picture = sheet.pictures.addBase64(
                excelRow,
                col,
                base64Encode(imageBytes),
              );
              picture.width = photoThumbW;
              picture.height = photoThumbH;
              embeddedCount++;
            } catch (_) {
              sheet
                  .getRangeByIndex(excelRow, col)
                  .setText('Imagen no disponible');
            }
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
              final imageBytes = _prepareImageForOffice(bytes);
              final picture = sheet.pictures.addBase64(
                excelRow,
                col,
                base64Encode(imageBytes),
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
    tableRange.cellStyle.borders.all.color = _kLine;
    tableRange.cellStyle.vAlign = xlsio.VAlignType.center;
    tableRange.cellStyle.wrapText = true;
    if (rows.isNotEmpty) {
      final bodyRange =
          sheet.getRangeByIndex(firstDataRow, 1, lastRow, safeLastCol);
      bodyRange.cellStyle.fontColor = _kInk;
      bodyRange.cellStyle.fontSize = 10;
      bodyRange.cellStyle.vAlign = xlsio.VAlignType.center;
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
      embeddedCount += _buildAttachmentsSheet(
        workbook,
        attachments: attachments,
      );
    }

    if (includeCoverSheet) {
      _buildCoverSheet(workbook, sheetName: sheetName);
    }

    if (includeSummarySheet) {
      _buildSummarySheet(
        workbook,
        sheetName: sheetName,
        rowsCount: rows.length,
        photosCount: _photosCount(
          photosByRow: photosByRow,
          attachments: attachments,
        ),
        videosCount: _videosCount(attachments),
        audiosCount: _audiosCount(attachments),
        filesCount: _filesCount(attachments),
        gpsCount: _gpsCount(gpsByRow, attachments: attachments),
        exportedAt: DateTime.now(),
      );
    }

    _reorderSheets(
      workbook,
      includeCoverSheet: includeCoverSheet,
      includeSummarySheet: includeSummarySheet,
    );

    addBitflowMetaSheet(
      workbook,
      embeddedImageCount: embeddedCount,
      exportVersion: _kExportVersion,
      appVersion: _cleanAppVersionForMeta(_kAppVersion),
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
    if ((appVersion ?? '').trim().isNotEmpty)
      ['appVersion', appVersion!.trim()],
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
    'Fila',
    'Columna',
    'Fecha',
    'Latitud',
    'Longitud',
    'Precisión',
    'Origen',
    'Foto',
  ];

  for (int c = 0; c < headers.length; c++) {
    photosSheet.getRangeByIndex(1, c + 1).setText(headers[c]);
  }

  final previewCol = headers.length;
  photosSheet.setColumnWidthInPixels(previewCol, 112);
  photosSheet.setRowHeightInPixels(1, 28);
  photosSheet.getRangeByIndex(2, 1).freezePanes();

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
    final addedAt = photosSheet.getRangeByIndex(row, 3);
    addedAt.setDateTime(item.addedAt);
    _styleDateCell(addedAt);
    if (item.lat != null) {
      photosSheet.getRangeByIndex(row, 4).setNumber(item.lat ?? 0);
    }
    if (item.lng != null) {
      photosSheet.getRangeByIndex(row, 5).setNumber(item.lng ?? 0);
    }
    if (item.accuracy != null) {
      photosSheet.getRangeByIndex(row, 6).setNumber(item.accuracy ?? 0);
    }
    final sourceLabel = _friendlyPhotoSourceLabel(item.sourceLabel);
    if (sourceLabel.isNotEmpty) {
      photosSheet.getRangeByIndex(row, 7).setText(sourceLabel);
    }
    photosSheet.setRowHeightInPixels(row, 96);

    if (bytes != null && bytes.isNotEmpty) {
      try {
        final imageBytes = _prepareImageForOffice(
          bytes,
          maxWidth: 900,
          maxHeight: 700,
          quality: 78,
        );
        final picture = photosSheet.pictures.addBase64(
          row,
          previewCol,
          base64Encode(imageBytes),
        );
        picture.width = 110;
        picture.height = 82;
        embeddedCount++;
      } catch (_) {
        photosSheet
            .getRangeByIndex(row, previewCol)
            .setText('Foto adjunta disponible desde la app/export.');
      }
    } else {
      photosSheet
          .getRangeByIndex(row, previewCol)
          .setText('Foto adjunta disponible desde la app/export.');
    }
  }

  final lastPhotoRow = photoMeta.length + 1;
  final lastPhotoCol = headers.length;
  final headerRange = photosSheet.getRangeByIndex(1, 1, 1, lastPhotoCol);
  headerRange.cellStyle.bold = true;
  headerRange.cellStyle.backColor = _kSoftBlue;
  headerRange.cellStyle.fontColor = _kInk;
  headerRange.cellStyle.hAlign = xlsio.HAlignType.center;
  headerRange.cellStyle.vAlign = xlsio.VAlignType.center;
  headerRange.cellStyle.fontSize = 11;
  headerRange.cellStyle.wrapText = true;

  if (photoMeta.isNotEmpty) {
    final bodyRange =
        photosSheet.getRangeByIndex(1, 1, lastPhotoRow, lastPhotoCol);
    bodyRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    bodyRange.cellStyle.borders.all.color = _kLine;
    bodyRange.cellStyle.vAlign = xlsio.VAlignType.center;
    bodyRange.cellStyle.wrapText = true;
  }

  for (int c = 0; c < lastPhotoCol - 1; c++) {
    try {
      photosSheet.autoFitColumn(c + 1);
    } catch (_) {}
  }

  return embeddedCount;
}

int _buildAttachmentsSheet(
  xlsio.Workbook workbook, {
  required List<AttachmentRow> attachments,
}) {
  final sheet = workbook.worksheets.addWithName('Evidencias');
  sheet.showGridlines = false;

  const headers = [
    'Celda',
    'Valor',
    'Tipo',
    'Nombre',
    'Descripción',
    'Transcripción',
    'Fecha',
    'Coordenadas',
    'Precisión',
    'Abrir',
    'Vista',
  ];

  for (int c = 0; c < headers.length; c++) {
    sheet.getRangeByIndex(1, c + 1).setText(headers[c]);
  }

  final headerRange = sheet.getRangeByIndex(1, 1, 1, headers.length);
  headerRange.cellStyle.bold = true;
  headerRange.cellStyle.backColor = _kSoftBlue;
  headerRange.cellStyle.fontColor = _kInk;
  headerRange.cellStyle.hAlign = xlsio.HAlignType.center;
  headerRange.cellStyle.vAlign = xlsio.VAlignType.center;
  headerRange.cellStyle.fontSize = 11;
  headerRange.cellStyle.wrapText = true;

  final sequenceByCellType = <String, int>{};
  var embeddedCount = 0;

  for (int i = 0; i < attachments.length; i++) {
    final row = i + 2;
    final item = attachments[i];
    final target = item.effectiveLinkTarget;
    final sequenceKey = '${item.cellRef}:${item.type}';
    final sequence = (sequenceByCellType[sequenceKey] ?? 0) + 1;
    sequenceByCellType[sequenceKey] = sequence;

    sheet.getRangeByIndex(row, 1).setText(item.cellRef);
    sheet
        .getRangeByIndex(row, 2)
        .setText(_clipCellText(_polishVisibleText(item.cellValue)));
    sheet.getRangeByIndex(row, 3).setText(_attachmentTypeLabel(item.type));
    sheet
        .getRangeByIndex(row, 4)
        .setText(_friendlyEvidenceName(item, sequence));
    sheet.getRangeByIndex(row, 5).setText(_polishVisibleText(item.notes));
    sheet
        .getRangeByIndex(row, 6)
        .setText(_transcriptTextForEvidence(item.transcript));
    if (item.addedAt != null) {
      final dateCell = sheet.getRangeByIndex(row, 7);
      dateCell.setDateTime(item.addedAt!);
      _styleDateCell(dateCell);
    }
    if (item.lat != null && item.lng != null) {
      sheet.getRangeByIndex(row, 8).setText(
            '${item.lat!.toStringAsFixed(6)}, ${item.lng!.toStringAsFixed(6)}',
          );
    }
    if (item.accuracy != null) {
      sheet
          .getRangeByIndex(row, 9)
          .setText('${item.accuracy!.toStringAsFixed(0)} m');
    }
    final openCell = sheet.getRangeByIndex(row, 10);
    if (target.isNotEmpty && _isSafeExportLink(target)) {
      _addFileHyperlink(
        sheet,
        openCell,
        target,
        displayText: _attachmentOpenLabel(item.type),
      );
    } else if (target.isNotEmpty) {
      // Link no portable (ruta local del dispositivo) — no se expone al cliente.
      openCell.setText('Disponible desde la app');
      openCell.cellStyle.fontColor = _kMutedInk;
    }

    final previewCell = sheet.getRangeByIndex(row, 11);
    if (item.hasPreview) {
      sheet.setRowHeightInPixels(row, 92);
      try {
        final imageBytes = _prepareImageForOffice(
          item.previewBytes!,
          maxWidth: 760,
          maxHeight: 560,
          quality: 76,
        );
        final picture = sheet.pictures.addBase64(
          row,
          11,
          base64Encode(imageBytes),
        );
        picture.width = 104;
        picture.height = 78;
        embeddedCount++;
      } catch (_) {
        previewCell.setText('Foto adjunta disponible desde la app/export.');
      }
    } else if (item.type == 'photo') {
      previewCell.setText('Foto adjunta disponible desde la app/export.');
    } else if (item.type == 'video') {
      previewCell.setText('Video adjunto');
    } else if (item.type == 'audio') {
      previewCell.setText(item.transcript.trim().isEmpty
          ? 'Audio adjunto'
          : 'Audio transcripto');
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
    bodyRange.cellStyle.borders.all.color = _kLine;
    bodyRange.cellStyle.vAlign = xlsio.VAlignType.center;
    bodyRange.cellStyle.wrapText = true;
  }

  for (int c = 1; c <= headers.length; c++) {
    try {
      sheet.autoFitColumn(c);
    } catch (_) {}
  }
  sheet.setColumnWidthInPixels(11, 120);
  return embeddedCount;
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

int _videosCount(List<AttachmentRow>? attachments) {
  if (attachments == null || attachments.isEmpty) return 0;
  return attachments.where((a) => a.type == 'video').length;
}

int _audiosCount(List<AttachmentRow>? attachments) {
  if (attachments == null || attachments.isEmpty) return 0;
  return attachments.where((a) => a.type == 'audio').length;
}

int _filesCount(List<AttachmentRow>? attachments) {
  if (attachments == null || attachments.isEmpty) return 0;
  return attachments.where((a) => a.type == 'file').length;
}

bool _isEvidenceSummaryColumn(int index, List<String> columns) {
  if (index < 0 || index >= columns.length) return false;
  final normalized =
      columns[index].toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized.contains('evidencia') ||
      normalized == 'foto' ||
      normalized == 'fotos' ||
      normalized == 'foto adjunta';
}

List<String> _evidenceTypesForRow(
  int rowIndex,
  List<AttachmentRow>? attachments,
) {
  if (attachments == null || attachments.isEmpty) return const <String>[];
  final types = <String>[];
  for (final item in attachments) {
    if (_rowIndexFromCellRef(item.cellRef) == rowIndex) {
      types.add(item.type);
    }
  }
  return types;
}

int? _rowIndexFromCellRef(String value) {
  final match = RegExp(r'^[A-Za-z]+(\d+)$').firstMatch(value.trim());
  if (match == null) return null;
  final oneBased = int.tryParse(match.group(1) ?? '');
  if (oneBased == null || oneBased < 1) return null;
  return oneBased - 1;
}

String _evidenceSummaryForTypes(List<String> rawTypes) {
  final types = rawTypes
      .map((type) => type.trim().toLowerCase())
      .where((type) => type.isNotEmpty)
      .toList(growable: false);
  if (types.isEmpty) return 'Sin evidencia';
  if (types.length > 1) return '${types.length} evidencias';
  switch (types.single) {
    case 'photo':
      return 'Foto adjunta';
    case 'video':
      return 'Video adjunto';
    case 'gps':
      return 'Ubicación GPS';
    case 'audio':
      return 'Audio adjunto';
    case 'file':
      return 'Archivo adjunto';
    default:
      return '1 evidencia';
  }
}

void _setSheetValue(xlsio.Worksheet sheet, int r, int c, String v) {
  final trimmed = v.trim();
  final numVal = double.tryParse(trimmed);
  if (numVal != null && RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(trimmed)) {
    final cell = sheet.getRangeByIndex(r, c);
    cell.setNumber(numVal);
    cell.cellStyle.hAlign = xlsio.HAlignType.right;
    return;
  }
  final dt = _tryParseExportDate(trimmed);
  if (dt != null) {
    final cell = sheet.getRangeByIndex(r, c);
    cell.setDateTime(dt);
    _styleDateCell(cell);
    return;
  }
  final cell = sheet.getRangeByIndex(r, c);
  cell.setText(_polishVisibleText(v));
  cell.cellStyle.hAlign = xlsio.HAlignType.left;
}

void _buildCoverSheet(xlsio.Workbook wb, {required String sheetName}) {
  final cover = wb.worksheets.addWithName('Caratula');
  cover.showGridlines = false;
  cover.setColumnWidthInPixels(1, 190);
  cover.setColumnWidthInPixels(2, 320);
  cover.setColumnWidthInPixels(4, 230);

  final title = cover.getRangeByIndex(1, 1);
  title.setText('Bit Flow');
  title.cellStyle.bold = true;
  title.cellStyle.fontSize = 24;
  title.cellStyle.fontColor = _kInk;

  final subtitle = cover.getRangeByIndex(2, 1);
  subtitle.setText('Reporte técnico de campo');
  subtitle.cellStyle.fontSize = 12;
  subtitle.cellStyle.fontColor = _kMutedInk;

  final labels = [
    'Obra',
    'Cliente',
    'Responsable',
    'Fecha de emisión',
  ];
  for (int i = 0; i < labels.length; i++) {
    final row = i + 5;
    final label = cover.getRangeByIndex(row, 1);
    label.setText(labels[i]);
    label.cellStyle.bold = true;
    label.cellStyle.fontColor = _kInk;
    label.cellStyle.backColor = _kSoftBlue2;
    if (i == 0) {
      cover.getRangeByIndex(row, 2).setText(_fallbackSheetName(sheetName));
    } else if (i == 3) {
      // Fecha de emisión = fecha real de generación del reporte
      final dateCell = cover.getRangeByIndex(row, 2);
      dateCell.setDateTime(DateTime.now());
      _styleDateCell(dateCell);
    } else {
      cover.getRangeByIndex(row, 2).setText('No especificado');
    }
  }
  final range = cover.getRangeByIndex(5, 1, 8, 2);
  range.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
  range.cellStyle.borders.all.color = _kLine;
  range.cellStyle.vAlign = xlsio.VAlignType.center;
  try {
    cover.autoFitColumn(1);
    cover.autoFitColumn(2);
  } catch (_) {}
}

void _buildSummarySheet(
  xlsio.Workbook wb, {
  required String sheetName,
  required int rowsCount,
  required int photosCount,
  required int videosCount,
  required int audiosCount,
  required int filesCount,
  required int gpsCount,
  required DateTime exportedAt,
}) {
  final summary = wb.worksheets.addWithName('Resumen');
  summary.showGridlines = false;
  final totalEvidence =
      photosCount + videosCount + audiosCount + filesCount + gpsCount;
  final data = [
    [
      'Planilla',
      sheetName.trim().isEmpty ? 'Bit Flow' : _polishVisibleText(sheetName),
    ],
    ['Exportado', exportedAt],
    ['Filas', rowsCount],
    ['Evidencias', totalEvidence],
    ['Fotos', photosCount],
    ['Videos', videosCount],
    ['Audios', audiosCount],
    ['Archivos', filesCount],
    ['Ubicaciones', gpsCount],
  ];
  final title = summary.getRangeByIndex(1, 1);
  title.setText('Resumen de exportación');
  title.cellStyle.bold = true;
  title.cellStyle.fontSize = 16;
  title.cellStyle.fontColor = _kInk;
  for (int i = 0; i < data.length; i++) {
    final row = i + 3;
    final label = summary.getRangeByIndex(row, 1);
    label.setText(data[i][0].toString());
    label.cellStyle.bold = true;
    label.cellStyle.backColor = _kSoftBlue2;
    final value = summary.getRangeByIndex(row, 2);
    final rawValue = data[i][1];
    if (rawValue is DateTime) {
      value.setDateTime(rawValue);
      _styleDateCell(value);
    } else if (rawValue is num) {
      value.setNumber(rawValue.toDouble());
      value.cellStyle.hAlign = xlsio.HAlignType.right;
    } else {
      value.setText(_polishVisibleText(rawValue.toString()));
    }
  }
  final range = summary.getRangeByIndex(3, 1, data.length + 2, 2);
  range.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
  range.cellStyle.borders.all.color = _kLine;
  try {
    summary.autoFitColumn(1);
    summary.autoFitColumn(2);
  } catch (_) {}
}

Uint8List _prepareImageForOffice(
  Uint8List bytes, {
  int maxWidth = 1280,
  int maxHeight = 960,
  int quality = 78,
}) {
  if (bytes.isEmpty) return bytes;
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final oriented = img.bakeOrientation(decoded);
    final scale = math.min(
      maxWidth / oriented.width,
      maxHeight / oriented.height,
    );
    final normalized = scale < 1
        ? img.copyResize(
            oriented,
            width: math.max(1, (oriented.width * scale).round()),
            height: math.max(1, (oriented.height * scale).round()),
            interpolation: img.Interpolation.average,
          )
        : oriented;
    final encoded = img.encodeJpg(normalized, quality: quality);
    if (encoded.isEmpty) return bytes;
    return Uint8List.fromList(encoded);
  } catch (_) {
    return bytes;
  }
}

DateTime? _tryParseExportDate(String value) {
  if (value.isEmpty) return null;
  final iso = DateTime.tryParse(value);
  if (iso != null) return iso;

  final match = RegExp(
    r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
  ).firstMatch(value);
  if (match == null) return null;

  final day = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  var year = int.tryParse(match.group(3) ?? '');
  final hour = int.tryParse(match.group(4) ?? '0') ?? 0;
  final minute = int.tryParse(match.group(5) ?? '0') ?? 0;
  final second = int.tryParse(match.group(6) ?? '0') ?? 0;
  if (day == null || month == null || year == null) return null;
  if (year < 100) year += 2000;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final parsed = DateTime(year, month, day, hour, minute, second);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

void _styleDateCell(xlsio.Range cell) {
  cell.numberFormat = 'dd/mm/yyyy hh:mm';
  cell.cellStyle.hAlign = xlsio.HAlignType.center;
}

String _attachmentTypeLabel(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'photo':
      return 'Foto adjunta';
    case 'video':
      return 'Video adjunto';
    case 'audio':
      return 'Audio adjunto';
    case 'gps':
      return 'Ubicación GPS';
    case 'file':
      return 'Archivo adjunto';
    default:
      return raw.trim().isEmpty ? 'Adjunto' : raw.trim();
  }
}

String _friendlyPhotoSourceLabel(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'camera':
    case 'camara':
    case 'cámara':
      return 'Cámara';
    case 'gallery':
    case 'galeria':
    case 'galería':
      return 'Galería';
    case 'current':
    case 'stream':
      return 'Captura desde la app';
    default:
      return _polishVisibleText(raw.trim());
  }
}

String _friendlyEvidenceName(AttachmentRow item, int sequence) {
  final cell = item.cellRef.trim();
  final suffix = cell.isEmpty ? '' : ' · $cell';
  switch (item.type.trim().toLowerCase()) {
    case 'photo':
      return 'Foto $sequence$suffix';
    case 'video':
      return 'Video $sequence$suffix';
    case 'audio':
      return 'Audio $sequence$suffix';
    case 'gps':
      return sequence > 1 ? 'GPS $sequence$suffix' : 'GPS$suffix';
    case 'file':
      return 'Archivo $sequence$suffix';
    default:
      return 'Evidencia $sequence$suffix';
  }
}

String _clipCellText(String value) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= 120) return normalized;
  return '${normalized.substring(0, 119)}...';
}

String _transcriptTextForEvidence(String value) {
  final normalized = _polishVisibleText(
    value.replaceAll(RegExp(r'\s+'), ' ').trim(),
  );
  return normalized.isEmpty ? 'Sin transcripción' : normalized;
}

String _fallbackSheetName(String sheetName) {
  final clean =
      _polishVisibleText(sheetName.replaceAll(RegExp(r'\s+'), ' ').trim());
  return clean.isEmpty ? 'No especificado' : clean;
}

String? _cleanAppVersionForMeta(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return null;
  final lower = clean.toLowerCase();
  if (lower == 'dev' || lower == 'unknown' || lower == 'null') return null;
  if (RegExp(r'^\d{1,2}$').hasMatch(clean)) return null;
  return clean;
}

String _polishVisibleText(String value) {
  if (value.isEmpty) return value;
  var polished = value;
  const replacements = <String, String>{
    'Reporte tecnico': 'Reporte técnico',
    'reporte tecnico': 'reporte técnico',
    'Resumen de exportacion': 'Resumen de exportación',
    'resumen de exportacion': 'resumen de exportación',
    'Descripcion': 'Descripción',
    'descripcion': 'descripción',
    'Transcripcion': 'Transcripción',
    'transcripcion': 'transcripción',
    'Precision': 'Precisión',
    'precision': 'precisión',
    'Ubicacion': 'Ubicación',
    'ubicacion': 'ubicación',
    'Ultima ubicacion': 'Última ubicación',
    'ultima ubicacion': 'última ubicación',
    'Sin dano visible': 'Sin daño visible',
    'sin dano visible': 'sin daño visible',
    'Medicion': 'Medición',
    'medicion': 'medición',
    'Proteccion catodica': 'Protección catódica',
    'proteccion catodica': 'protección catódica',
    'Fecha de emision': 'Fecha de emisión',
    'fecha de emision': 'fecha de emisión',
  };
  for (final entry in replacements.entries) {
    polished = polished.replaceAll(entry.key, entry.value);
  }
  return polished;
}

String _attachmentOpenLabel(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'video':
      return 'Abrir video';
    case 'audio':
      return 'Abrir audio';
    case 'photo':
      return 'Abrir foto';
    case 'gps':
      return 'Abrir en mapa';
    default:
      return 'Abrir archivo';
  }
}

void _addFileHyperlink(
  xlsio.Worksheet sheet,
  xlsio.Range range,
  String target, {
  required String displayText,
}) {
  final cleaned = target.trim();
  if (cleaned.isEmpty) return;
  try {
    final lower = cleaned.toLowerCase();
    final type = lower.startsWith('http://') ||
            lower.startsWith('https://') ||
            lower.startsWith('mailto:')
        ? xlsio.HyperlinkType.url
        : xlsio.HyperlinkType.file;
    final link = sheet.hyperlinks.add(
      range,
      type,
      cleaned,
      displayText,
      displayText,
    );
    link.textToDisplay = displayText;
    range.cellStyle.fontColor = _kLinkBlue;
    range.cellStyle.bold = true;
  } catch (_) {
    range.setText(displayText);
    range.cellStyle.fontColor = _kLinkBlue;
  }
}

/// Devuelve true si el link es portable y seguro para incluir en el XLSX.
/// Suprime rutas locales del dispositivo que no existen en la máquina del cliente.
bool _isSafeExportLink(String target) {
  final t = target.trim().toLowerCase();
  if (t.isEmpty) {
    return false;
  }
  if (t.startsWith('file://')) {
    return false;
  }
  if (t.startsWith('c:/') || t.startsWith('c:\\')) {
    return false;
  }
  if (t.startsWith('/users/') ||
      t.startsWith('/var/') ||
      t.startsWith('/tmp/') ||
      t.startsWith('/data/')) {
    return false;
  }
  if (t.contains('/cache/') || t.contains('\\cache\\')) {
    return false;
  }
  return true;
}

/// Reordena las hojas del workbook al orden esperado:
/// Carátula → Resumen → Planilla → Evidencias → _BITFLOW_META.
void _reorderSheets(
  xlsio.Workbook workbook, {
  required bool includeCoverSheet,
  required bool includeSummarySheet,
}) {
  try {
    int nextIndex = 0;
    if (includeCoverSheet) {
      final cover = _findWorksheet(workbook, 'Caratula');
      if (cover != null && workbook.worksheets.count > 1) {
        workbook.worksheets.moveTo(cover, nextIndex);
        nextIndex++;
      }
    }
    if (includeSummarySheet) {
      final summary = _findWorksheet(workbook, 'Resumen');
      if (summary != null && workbook.worksheets.count > 1) {
        workbook.worksheets.moveTo(summary, nextIndex);
      }
    }
  } catch (_) {
    // Reorden es best-effort; nunca bloquea el export.
  }
}

xlsio.Worksheet? _findWorksheet(xlsio.Workbook wb, String name) {
  for (var i = 0; i < wb.worksheets.count; i++) {
    if (wb.worksheets[i].name == name) return wb.worksheets[i];
  }
  return null;
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
