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

    // Indices de columnas con fotos embebidas: deben preservarse siempre
    // aunque sus celdas de texto esten vacias.
    final Set<int> photoColumnIndexes = <int>{};
    if (embeddedPhotos != null) {
      for (final p in embeddedPhotos) {
        if (p.bytes.isEmpty) continue;
        if (p.colIndex >= 0 && p.colIndex < textCols) {
          photoColumnIndexes.add(p.colIndex);
        }
      }
    }

    // Analisis de columnas para tipos, anchos y deteccion de columnas vacias.
    final allColumnInfos = _analyzeColumns(
      columns: columns,
      rows: rows,
      textCols: textCols,
      protectedIndexes: photoColumnIndexes,
    );
    final exportColumnInfos = _filterExportableColumns(allColumnInfos);
    final exportTextCols = exportColumnInfos.length;
    final keepIndexes = exportColumnInfos.map((c) => c.sourceIndex).toList();
    final embeddedRemap = <int, int>{
      for (int i = 0; i < keepIndexes.length; i++) keepIndexes[i]: i,
    };

    final bool hasGps = _hasGps(gpsByRow);
    final int gpsCols = hasGps ? 5 : 0;

    // Col 1 = "#" si se pide, luego exportTextCols columnas de texto y gps.
    final int baseColumnsCount =
        (includeIndexColumn ? 1 : 0) + exportTextCols + gpsCols;

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
    final int gpsStartCol = textStartCol + exportTextCols;

    // --------------------------
    // 1) Encabezados
    // --------------------------
    if (includeIndexColumn) {
      sheet.getRangeByIndex(headerRow, 1).setText('#');
    }

    // Headers de texto (solo columnas exportables).
    for (int i = 0; i < exportTextCols; i++) {
      sheet
          .getRangeByIndex(headerRow, textStartCol + i)
          .setText(exportColumnInfos[i].header);
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

    // Aplica estilo profesional a toda la fila de encabezados.
    final headerRange =
        sheet.getRangeByIndex(headerRow, 1, headerRow, safeLastCol);
    _applyHeaderStyle(headerRange);
    sheet.setRowHeightInPixels(headerRow, 24);

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
      final isZebra = (r % 2) == 1;

      // Columna "#"
      if (includeIndexColumn) {
        final idxCell = sheet.getRangeByIndex(excelRow, 1);
        idxCell.setNumber((r + 1).toDouble());
        idxCell.cellStyle.hAlign = xlsio.HAlignType.right;
        if (isZebra) _applyZebra(idxCell);
      }

      // Texto: solo columnas exportables.
      for (int i = 0; i < exportTextCols; i++) {
        final info = exportColumnInfos[i];
        final src = info.sourceIndex;
        final v = (src < rowValues.length) ? rowValues[src] : '';
        final col = textStartCol + i;
        final cell = sheet.getRangeByIndex(excelRow, col);

        if (info.type == _XlsxColType.evidence && _looksLikeNoEvidence(v)) {
          _applyEvidencePlaceholder(cell);
        } else if (info.type == _XlsxColType.status) {
          cell.setText(v);
          final bucket = _statusBucket(v);
          if (bucket.isNotEmpty) {
            _applyStatusStyle(cell, bucket);
          } else if (isZebra) {
            _applyZebra(cell);
          }
        } else {
          _writeTypedCell(sheet, excelRow, col, v, info);
          if (info.type == _XlsxColType.observations) {
            cell.cellStyle.wrapText = true;
            cell.cellStyle.vAlign = xlsio.VAlignType.top;
          }
          if (isZebra) _applyZebra(cell);
        }
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
          accCell.numberFormat = '0.0';
          if (gps.ts != null) {
            final tsCell = sheet.getRangeByIndex(excelRow, gpsStartCol + 3);
            tsCell.setDateTime(gps.ts!);
            tsCell.numberFormat = 'dd/mm/yyyy hh:mm';
          }
          sheet
              .getRangeByIndex(excelRow, gpsStartCol + 4)
              .setText(gps.isLastKnown ? 'lastKnown' : 'current');
        }
        if (isZebra) {
          for (int g = 0; g < 5; g++) {
            _applyZebra(sheet.getRangeByIndex(excelRow, gpsStartCol + g));
          }
        }
      }

      // Fotos embebidas por celda (nuevo).
      if (useEmbedded) {
        final picsForRow = embeddedByRow[r];
        if (picsForRow != null && picsForRow.isNotEmpty) {
          sheet.setRowHeightInPixels(excelRow, photoRowHeightPx);
          for (final pic in picsForRow) {
            final mapped = embeddedRemap[pic.colIndex];
            if (mapped == null) continue;
            final col = textStartCol + mapped;
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
    // 3) Bordes diferenciados (body) y freeze + autofilter
    // --------------------------
    final int lastRow = rows.length + 1; // incluye headers
    if (rows.isNotEmpty) {
      final bodyRange =
          sheet.getRangeByIndex(firstDataRow, 1, lastRow, safeLastCol);
      _applyDataBorders(bodyRange);
    }

    // Freeze panes en la fila debajo del header.
    if (rows.isNotEmpty) {
      sheet.getRangeByIndex(firstDataRow, 1).freezePanes();
    }

    // Autofiltro sobre el rango de la tabla.
    final filterRange = sheet.getRangeByIndex(1, 1, lastRow, safeLastCol);
    _applyAutoFilter(sheet, filterRange);

    // --------------------------
    // 4) Anchos calculados por tipo (clamp 10..50)
    // --------------------------
    if (includeIndexColumn) {
      final idxLen = math.max(1, rows.length.toString().length);
      sheet.getRangeByIndex(1, 1).columnWidth =
          _xlsxColumnWidthClamp(_XlsxColType.number, idxLen).toDouble();
    }
    for (int i = 0; i < exportTextCols; i++) {
      final info = exportColumnInfos[i];
      final col = textStartCol + i;
      final width = _xlsxColumnWidthClamp(info.type, info.maxContentLen);
      sheet.getRangeByIndex(1, col).columnWidth = width.toDouble();
    }
    if (hasGps) {
      const gpsWidths = [14.0, 14.0, 12.0, 18.0, 14.0];
      for (int g = 0; g < gpsWidths.length; g++) {
        sheet.getRangeByIndex(1, gpsStartCol + g).columnWidth = gpsWidths[g];
      }
    }

    if (useEmbedded && embeddedCols.isNotEmpty) {
      for (final idx in embeddedCols) {
        final mapped = embeddedRemap[idx];
        if (mapped == null) continue;
        final col = textStartCol + mapped;
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

    if (includeCoverSheet) {
      _buildCoverSheet(workbook);
    }

    if (includeSummarySheet) {
      _buildSummarySheet(
        workbook,
        rowsCount: rows.length,
        photosCount: _photosCount(
          photosByRow: photosByRow,
          attachments: attachments,
        ),
        videosCount: _attachmentsCountByType(attachments, 'video'),
        audiosCount: _attachmentsCountByType(attachments, 'audio'),
        filesCount: _attachmentsCountByType(attachments, 'file'),
        gpsCount: _gpsCount(gpsByRow, attachments: attachments),
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
  final sheet = workbook.worksheets.addWithName('Adjuntos');
  sheet.showGridlines = false;

  const headers = [
    'Referencia de celda',
    'Tipo',
    'Nombre de archivo',
    'Notas',
    'Ruta',
  ];

  for (int c = 0; c < headers.length; c++) {
    sheet.getRangeByIndex(1, c + 1).setText(headers[c]);
  }

  final headerRange = sheet.getRangeByIndex(1, 1, 1, headers.length);
  headerRange.cellStyle.bold = true;
  headerRange.cellStyle.backColor = '#F4F0E6';
  headerRange.cellStyle.hAlign = xlsio.HAlignType.center;
  headerRange.cellStyle.vAlign = xlsio.VAlignType.center;
  headerRange.cellStyle.fontSize = 11;

  for (int i = 0; i < attachments.length; i++) {
    final row = i + 2;
    final item = attachments[i];
    sheet.getRangeByIndex(row, 1).setText(item.cellRef);
    sheet.getRangeByIndex(row, 2).setText(item.type);
    sheet.getRangeByIndex(row, 3).setText(item.fileName);
    sheet.getRangeByIndex(row, 4).setText(item.notes);
    sheet.getRangeByIndex(row, 5).setText(item.relativePath);
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

int _attachmentsCountByType(List<AttachmentRow>? attachments, String type) {
  if (attachments == null || attachments.isEmpty) return 0;
  return attachments.where((a) => a.type == type).length;
}

void _buildCoverSheet(xlsio.Workbook wb) {
  final cover = wb.worksheets.addWithName('Caratula');
  cover.showGridlines = false;

  final title = cover.getRangeByIndex(1, 1, 1, 3);
  title.merge();
  title.setText('Bitácora PRO');
  title.cellStyle.bold = true;
  title.cellStyle.fontSize = 18;
  title.cellStyle.fontColor = _kColorHeaderFg;
  title.cellStyle.hAlign = xlsio.HAlignType.left;
  title.cellStyle.vAlign = xlsio.VAlignType.center;
  cover.setRowHeightInPixels(1, 32);

  final subtitle = cover.getRangeByIndex(2, 1, 2, 3);
  subtitle.merge();
  subtitle.setText('Reporte profesional de campo');
  subtitle.cellStyle.italic = true;
  subtitle.cellStyle.fontColor = _kColorPlaceholderFg;
  subtitle.cellStyle.fontSize = 11;

  final labels = <String>['Obra', 'Cliente', 'Responsable', 'Fecha'];
  const startRow = 4;
  for (int i = 0; i < labels.length; i++) {
    final r = startRow + i;
    final labelCell = cover.getRangeByIndex(r, 1);
    labelCell.setText(labels[i]);
    labelCell.cellStyle.bold = true;
    labelCell.cellStyle.fontColor = _kColorHeaderFg;
    labelCell.cellStyle.vAlign = xlsio.VAlignType.center;

    final valueCell = cover.getRangeByIndex(r, 2);
    valueCell.setText('No especificado');
    _applyPlaceholderStyle(valueCell);
    valueCell.cellStyle.vAlign = xlsio.VAlignType.center;
    cover.setRowHeightInPixels(r, 22);
  }

  cover.getRangeByIndex(1, 1).columnWidth = 22;
  cover.getRangeByIndex(1, 2).columnWidth = 38;
  cover.getRangeByIndex(1, 3).columnWidth = 18;
}

void _buildSummarySheet(
  xlsio.Workbook wb, {
  required int rowsCount,
  required int photosCount,
  required int videosCount,
  required int audiosCount,
  required int filesCount,
  required int gpsCount,
}) {
  final summary = wb.worksheets.addWithName('Resumen');
  summary.showGridlines = false;

  final title = summary.getRangeByIndex(1, 1, 1, 2);
  title.merge();
  title.setText('Resumen del reporte');
  title.cellStyle.bold = true;
  title.cellStyle.fontSize = 14;
  title.cellStyle.fontColor = _kColorHeaderFg;
  summary.setRowHeightInPixels(1, 26);

  final evidencesTotal =
      photosCount + videosCount + audiosCount + filesCount;

  final entries = <List<dynamic>>[
    ['Filas', rowsCount],
    ['Evidencias totales', evidencesTotal],
    ['Fotos', photosCount],
    ['Videos', videosCount],
    ['Audios', audiosCount],
    ['Archivos', filesCount],
    ['Ubicaciones', gpsCount],
  ];

  const startRow = 3;
  for (int i = 0; i < entries.length; i++) {
    final r = startRow + i;
    final labelCell = summary.getRangeByIndex(r, 1);
    labelCell.setText(entries[i][0].toString());
    labelCell.cellStyle.bold = true;
    labelCell.cellStyle.fontColor = _kColorHeaderFg;

    final value = entries[i][1];
    final valueCell = summary.getRangeByIndex(r, 2);
    valueCell.setNumber((value is num) ? value.toDouble() : 0);
    valueCell.numberFormat = '0';
    valueCell.cellStyle.hAlign = xlsio.HAlignType.right;
  }

  if (evidencesTotal == 0) {
    final noteRow = startRow + entries.length + 1;
    final note = summary.getRangeByIndex(noteRow, 1, noteRow, 2);
    note.merge();
    note.setText('No se registraron evidencias adjuntas en esta exportación.');
    note.cellStyle.italic = true;
    note.cellStyle.fontColor = _kColorPlaceholderFg;
    note.cellStyle.wrapText = true;
    summary.setRowHeightInPixels(noteRow, 22);
  }

  summary.getRangeByIndex(1, 1).columnWidth = 24;
  summary.getRangeByIndex(1, 2).columnWidth = 16;
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

// ============================================================
// Helpers de presentacion comercial (XLSX profesional)
// ============================================================

enum _XlsxColType { text, date, number, status, evidence, observations }

class _XlsxColumnInfo {
  _XlsxColumnInfo({
    required this.sourceIndex,
    required this.header,
    required this.type,
    required this.maxContentLen,
    required this.dateHasTime,
    required this.numberHasDecimals,
  });

  final int sourceIndex;
  final String header;
  _XlsxColType type;
  int maxContentLen;
  bool dateHasTime;
  bool numberHasDecimals;
}

const String _kColorHeaderBg = '#FFEAF3FF';
const String _kColorHeaderFg = '#FF1D1D1F';
const String _kColorHeaderBorder = '#FF4A90D9';
const String _kColorBodyBorder = '#FFE0E0E0';
const String _kColorZebra = '#FFF8FAFC';
const String _kColorEvidencePlaceholder = '#FFAAAAAA';
const String _kColorOkBg = '#FFE6F4EA';
const String _kColorOkFg = '#FF1E7E34';
const String _kColorWarnBg = '#FFFFF3E0';
const String _kColorWarnFg = '#FFE65100';
const String _kColorCritBg = '#FFFDECEA';
const String _kColorCritFg = '#FFC62828';
const String _kColorPlaceholderFg = '#FF999999';

final RegExp _kGenericHeaderRegExp =
    RegExp(r'^col\s*\d+$', caseSensitive: false);

String _stripDiacriticsLower(String s) {
  const map = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
    'å': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };
  final lower = s.toLowerCase();
  final buf = StringBuffer();
  for (int i = 0; i < lower.length; i++) {
    final ch = lower[i];
    buf.write(map[ch] ?? ch);
  }
  return buf.toString();
}

bool _isGenericHeader(String header) {
  final t = header.trim();
  if (t.isEmpty) return true;
  return _kGenericHeaderRegExp.hasMatch(t);
}

bool _looksLikeNoEvidence(String value) {
  final v = _stripDiacriticsLower(value.trim());
  if (v.isEmpty) return false;
  return v == 'sin evidencia' ||
      v == 'sin evidencias' ||
      v == 'no evidencia' ||
      v == 'sin foto' ||
      v == 'sin fotos' ||
      v == 'no foto' ||
      v == 'n/d' ||
      v == 's/d' ||
      v == 'na' ||
      v == 'n/a';
}

bool _looksLikePlaceholder(String value) {
  final v = _stripDiacriticsLower(value.trim());
  if (v.isEmpty) return true;
  return v == 'no especificado' ||
      v == 'no especificada' ||
      v == 'sin especificar' ||
      v == 'no definido' ||
      v == 'no definida' ||
      v == 'pendiente';
}

DateTime? _parseDateLoose(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final iso = DateTime.tryParse(t);
  if (iso != null) return iso;
  final m = RegExp(
    r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
  ).firstMatch(t);
  if (m == null) return null;
  final day = int.tryParse(m.group(1) ?? '');
  final month = int.tryParse(m.group(2) ?? '');
  var year = int.tryParse(m.group(3) ?? '');
  if (day == null || month == null || year == null) return null;
  if (year < 100) year += 2000;
  final hour = int.tryParse(m.group(4) ?? '0') ?? 0;
  final minute = int.tryParse(m.group(5) ?? '0') ?? 0;
  final second = int.tryParse(m.group(6) ?? '0') ?? 0;
  try {
    return DateTime(year, month, day, hour, minute, second);
  } catch (_) {
    return null;
  }
}

double? _parseNumberLoose(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  if (!RegExp(r'^-?\d+(?:[.,]\d+)?$').hasMatch(t)) return null;
  return double.tryParse(t.replaceAll(',', '.'));
}

bool _isPureInteger(String raw) {
  final t = raw.trim();
  return RegExp(r'^-?\d+$').hasMatch(t);
}

_XlsxColType _classifyByName(String header) {
  final h = _stripDiacriticsLower(header.trim());
  if (h.isEmpty) return _XlsxColType.text;
  if (h == 'estado' ||
      h == 'status' ||
      h.contains('condicion') ||
      h.contains('resultado')) {
    return _XlsxColType.status;
  }
  if (h.contains('observ') || h.contains('comentario') || h.contains('nota')) {
    return _XlsxColType.observations;
  }
  if (h.contains('evidenc') ||
      h.contains('foto') ||
      h.contains('imagen') ||
      h.contains('adjunto')) {
    return _XlsxColType.evidence;
  }
  if (h == 'fecha' ||
      h.contains('fecha') ||
      h.contains('hora') ||
      h.contains('timestamp')) {
    return _XlsxColType.date;
  }
  if (h.contains('codigo') ||
      h.contains('progresiva') ||
      h.contains('id ') ||
      h == 'id' ||
      h == 'n°' ||
      h == 'nro' ||
      h == 'numero') {
    return _XlsxColType.text; // tratar como texto para no deformar
  }
  if (h.contains('voltaj') ||
      h.contains('tension') ||
      h.contains('corriente') ||
      h.contains('ampere') ||
      h.contains('resist') ||
      h.contains('ohm') ||
      h.contains('porcent') ||
      h.contains('%') ||
      h.contains('medic') ||
      h.contains('valor') ||
      h.contains('cantidad') ||
      h.contains('total') ||
      h.contains('peso') ||
      h.contains('temperatura')) {
    return _XlsxColType.number;
  }
  return _XlsxColType.text;
}

int _xlsxColumnWidthClamp(_XlsxColType type, int contentLen) {
  int min;
  int max;
  switch (type) {
    case _XlsxColType.observations:
      min = 28;
      max = 50;
      break;
    case _XlsxColType.evidence:
      min = 16;
      max = 40;
      break;
    case _XlsxColType.date:
      min = 14;
      max = 22;
      break;
    case _XlsxColType.status:
      min = 14;
      max = 18;
      break;
    case _XlsxColType.number:
      min = 12;
      max = 22;
      break;
    case _XlsxColType.text:
      min = 10;
      max = 50;
      break;
  }
  // +2 de padding para que no se corte el contenido.
  final desired = contentLen + 2;
  if (desired < min) return min;
  if (desired > max) return max;
  return desired;
}

String _statusBucket(String value) {
  final v = _stripDiacriticsLower(value.trim());
  if (v.isEmpty) return '';
  const ok = {'ok', 'conforme', 'aprobado', 'bueno', 'apto'};
  const warn = {
    'obs',
    'observado',
    'atencion',
    'revisar',
    'pendiente',
    'regular',
    'a revisar',
  };
  const crit = {
    'critico',
    'error',
    'no conforme',
    'malo',
    'rechazado',
    'no apto',
    'falla',
  };
  if (ok.contains(v)) return 'ok';
  if (warn.contains(v)) return 'warn';
  if (crit.contains(v)) return 'crit';
  return '';
}

void _applyStatusStyle(xlsio.Range cell, String bucket) {
  final style = cell.cellStyle;
  switch (bucket) {
    case 'ok':
      style.backColor = _kColorOkBg;
      style.fontColor = _kColorOkFg;
      break;
    case 'warn':
      style.backColor = _kColorWarnBg;
      style.fontColor = _kColorWarnFg;
      break;
    case 'crit':
      style.backColor = _kColorCritBg;
      style.fontColor = _kColorCritFg;
      break;
    default:
      return;
  }
  style.bold = true;
  style.hAlign = xlsio.HAlignType.center;
  style.vAlign = xlsio.VAlignType.center;
}

void _applyEvidencePlaceholder(xlsio.Range cell) {
  cell.setText('—');
  final style = cell.cellStyle;
  style.fontColor = _kColorEvidencePlaceholder;
  style.hAlign = xlsio.HAlignType.center;
  style.vAlign = xlsio.VAlignType.center;
  try {
    style.italic = true;
  } catch (_) {}
}

void _applyZebra(xlsio.Range cell) {
  cell.cellStyle.backColor = _kColorZebra;
}

void _applyDataBorders(xlsio.Range range) {
  final borders = range.cellStyle.borders;
  borders.all.lineStyle = xlsio.LineStyle.thin;
  borders.all.color = _kColorBodyBorder;
}

void _applyHeaderStyle(xlsio.Range range) {
  final style = range.cellStyle;
  style.bold = true;
  style.backColor = _kColorHeaderBg;
  style.fontColor = _kColorHeaderFg;
  style.hAlign = xlsio.HAlignType.center;
  style.vAlign = xlsio.VAlignType.center;
  style.fontSize = 11;
  final borders = style.borders;
  borders.all.lineStyle = xlsio.LineStyle.thin;
  borders.all.color = _kColorHeaderBorder;
  borders.bottom.lineStyle = xlsio.LineStyle.medium;
  borders.bottom.color = _kColorHeaderBorder;
}

void _applyAutoFilter(xlsio.Worksheet sheet, xlsio.Range range) {
  try {
    sheet.autoFilters.filterRange = range;
  } catch (_) {}
}

void _applyPlaceholderStyle(xlsio.Range cell) {
  final style = cell.cellStyle;
  style.fontColor = _kColorPlaceholderFg;
  try {
    style.italic = true;
  } catch (_) {}
}

List<_XlsxColumnInfo> _analyzeColumns({
  required List<String> columns,
  required List<List<String>> rows,
  required int textCols,
  Set<int> protectedIndexes = const <int>{},
}) {
  final infos = <_XlsxColumnInfo>[];
  for (int c = 0; c < textCols; c++) {
    final header = (c < columns.length) ? columns[c] : '';
    final nameType = _classifyByName(header);
    int maxLen = header.length;
    bool hasAnyValue = false;
    bool allParsedAsDate = true;
    bool sawAnyDate = false;
    bool dateHasTime = false;
    bool allParsedAsNumber = true;
    bool sawAnyNumber = false;
    bool numberHasDecimals = false;

    for (final r in rows) {
      final v = (c < r.length) ? r[c] : '';
      if (v.isNotEmpty) hasAnyValue = true;
      if (v.length > maxLen) maxLen = v.length;
      final tv = v.trim();
      if (tv.isEmpty) continue;
      final dt = _parseDateLoose(tv);
      if (dt != null) {
        sawAnyDate = true;
        if (dt.hour != 0 || dt.minute != 0 || dt.second != 0) {
          dateHasTime = true;
        }
      } else {
        allParsedAsDate = false;
      }
      final num = _parseNumberLoose(tv);
      if (num != null) {
        sawAnyNumber = true;
        if (!_isPureInteger(tv)) {
          numberHasDecimals = true;
        }
      } else {
        allParsedAsNumber = false;
      }
    }

    var type = nameType;
    if (type == _XlsxColType.text) {
      if (sawAnyDate && allParsedAsDate) {
        type = _XlsxColType.date;
      } else if (sawAnyNumber && allParsedAsNumber) {
        type = _XlsxColType.number;
      }
    } else if (type == _XlsxColType.date) {
      if (!sawAnyDate) type = _XlsxColType.text;
    } else if (type == _XlsxColType.number) {
      if (!sawAnyNumber || !allParsedAsNumber) type = _XlsxColType.text;
    }

    infos.add(_XlsxColumnInfo(
      sourceIndex: c,
      header: header,
      type: type,
      maxContentLen: maxLen,
      dateHasTime: dateHasTime,
      numberHasDecimals: numberHasDecimals,
    ));
    // Marcar si la columna no tiene datos para decision posterior.
    // Las columnas protegidas (con fotos embebidas) nunca se descartan.
    if (!hasAnyValue &&
        _isGenericHeader(header) &&
        !protectedIndexes.contains(c)) {
      // Lo marcamos rellenando type especial via maxContentLen=-1.
      infos.last.maxContentLen = -1;
    }
  }
  return infos;
}

List<_XlsxColumnInfo> _filterExportableColumns(List<_XlsxColumnInfo> all) {
  return all.where((c) => c.maxContentLen >= 0).toList(growable: false);
}

void _writeTypedCell(
  xlsio.Worksheet sheet,
  int row,
  int col,
  String raw,
  _XlsxColumnInfo info,
) {
  final cell = sheet.getRangeByIndex(row, col);
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    cell.setText('');
    return;
  }
  if (FormulaEngine.isFormula(trimmed)) {
    cell.setFormula(trimmed);
    return;
  }
  switch (info.type) {
    case _XlsxColType.date:
      final dt = _parseDateLoose(trimmed);
      if (dt != null) {
        cell.setDateTime(dt);
        cell.numberFormat =
            info.dateHasTime ? 'dd/mm/yyyy hh:mm' : 'dd/mm/yyyy';
        return;
      }
      cell.setText(raw);
      return;
    case _XlsxColType.number:
      final n = _parseNumberLoose(trimmed);
      if (n != null) {
        cell.setNumber(n);
        cell.numberFormat = info.numberHasDecimals ? '0.00' : '0';
        cell.cellStyle.hAlign = xlsio.HAlignType.right;
        return;
      }
      cell.setText(raw);
      return;
    case _XlsxColType.status:
    case _XlsxColType.evidence:
    case _XlsxColType.observations:
    case _XlsxColType.text:
      cell.setText(raw);
      return;
  }
}

