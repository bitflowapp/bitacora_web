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

/// Metadatos editoriales que alimentan la Caratula y el Resumen.
///
/// Todos los campos son opcionales; los que falten se muestran como
/// "No especificado" con un estilo discreto dentro del XLSX.
class ExportProjectMeta {
  const ExportProjectMeta({
    this.title,
    this.subtitle,
    this.exportedAt,
    this.obra,
    this.cliente,
    this.responsable,
    this.ubicacion,
    this.appVersion,
    this.sheetId,
    this.bundleNote,
  });

  final String? title;
  final String? subtitle;
  final DateTime? exportedAt;
  final String? obra;
  final String? cliente;
  final String? responsable;
  final String? ubicacion;
  final String? appVersion;
  final String? sheetId;

  /// Nota libre para mostrar en la caratula. Por ejemplo, cuando el XLSX
  /// viaja dentro de un paquete .zip, indica que las evidencias se abren
  /// desde la carpeta `attachments/`.
  final String? bundleNote;
}

enum _PlanColumnKind { text, date, number, status, evidence, observation }

class _ExportColumn {
  const _ExportColumn({
    required this.sourceIndex,
    required this.header,
    required this.kind,
    required this.dateNumberFormat,
  });

  final int sourceIndex;
  final String header;
  final _PlanColumnKind kind;
  final String? dateNumberFormat;
}

class _EvidenceCounts {
  const _EvidenceCounts({
    required this.photos,
    required this.videos,
    required this.audios,
    required this.files,
    required this.locations,
  });

  final int photos;
  final int videos;
  final int audios;
  final int files;
  final int locations;

  int get total => photos + videos + audios + files;
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
  ExportProjectMeta? projectMeta,
  bool inZip = false,
}) async {
  final workbook = xlsio.Workbook(1);
  try {
    final sheet = workbook.worksheets[0];
    sheet.name = _sanitizeWorksheetName(sheetName);

    const int headerRow = 1;
    const int firstDataRow = headerRow + 1;

    // Ancho real de texto: puede haber filas mas largas que headers.
    int sourceTextCols = columns.length;
    for (final r in rows) {
      if (r.length > sourceTextCols) sourceTextCols = r.length;
    }
    if (sourceTextCols < 0) sourceTextCols = 0;

    final bool hasGps = _hasGps(gpsByRow);
    final int gpsCols = hasGps ? 5 : 0;

    final bool useEmbedded =
        embeddedPhotos != null && embeddedPhotos.isNotEmpty;

    final embeddedSourceColsForFilter = <int>{};
    if (useEmbedded) {
      for (final item in embeddedPhotos) {
        if (item.bytes.isEmpty) continue;
        if (item.rowIndex < 0 || item.colIndex < 0) continue;
        embeddedSourceColsForFilter.add(item.colIndex);
      }
    }

    final exportColumns = _buildExportColumns(
      columns: columns,
      rows: rows,
      sourceTextCols: sourceTextCols,
      preservedSourceCols: embeddedSourceColsForFilter,
    );
    final int textCols = exportColumns.length;

    // Col 1 = "#" si se pide, luego textCols columnas de texto y gps.
    final int baseColumnsCount =
        (includeIndexColumn ? 1 : 0) + textCols + gpsCols;

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
    final sourceToExcelCol = <int, int>{};
    for (int i = 0; i < exportColumns.length; i++) {
      sourceToExcelCol[exportColumns[i].sourceIndex] = textStartCol + i;
    }
    final evidenceCounts = _countEvidence(
      photosByRow: photosByRow,
      embeddedPhotos: embeddedPhotos,
      attachments: attachments,
      gpsByRow: gpsByRow,
    );

    // Estilo header (nombre unico por seguridad).
    final styleName = 'HeaderStyle_${DateTime.now().microsecondsSinceEpoch}';
    final headerStyle = workbook.styles.add(styleName);
    headerStyle.bold = true;
    headerStyle.fontColor = '#1D1D1F';
    headerStyle.backColor = '#EAF3FF';
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;
    headerStyle.borders.top.lineStyle = xlsio.LineStyle.thin;
    headerStyle.borders.top.color = '#4A90D9';
    headerStyle.borders.left.lineStyle = xlsio.LineStyle.thin;
    headerStyle.borders.left.color = '#4A90D9';
    headerStyle.borders.right.lineStyle = xlsio.LineStyle.thin;
    headerStyle.borders.right.color = '#4A90D9';
    headerStyle.borders.bottom.lineStyle = xlsio.LineStyle.medium;
    headerStyle.borders.bottom.color = '#4A90D9';

    // --------------------------
    // 1) Encabezados
    // --------------------------
    if (includeIndexColumn) {
      sheet.getRangeByIndex(headerRow, 1).setText('#');
    }

    // Headers de texto (si faltan, se completan con vacio).
    for (int i = 0; i < textCols; i++) {
      final title = exportColumns[i].header;
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
        final column = exportColumns[c];
        final sourceIndex = column.sourceIndex;
        final v =
            (sourceIndex < rowValues.length) ? rowValues[sourceIndex] : '';
        _setPlanCellValue(sheet, excelRow, textStartCol + c, v, column);
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
            sheet
                .getRangeByIndex(excelRow, gpsStartCol + 3)
                .setDateTime(gps.ts!);
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
            final col = sourceToExcelCol[pic.colIndex];
            if (col == null) continue;
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
    // 3) Presentacion profesional de PLANILLA
    // --------------------------
    final int lastRow = rows.length + 1; // incluye headers
    _applyPlanSheetPresentation(
      sheet: sheet,
      exportColumns: exportColumns,
      rows: rows,
      headerRow: headerRow,
      firstDataRow: firstDataRow,
      safeLastCol: safeLastCol,
      lastRow: lastRow,
      includeIndexColumn: includeIndexColumn,
      textStartCol: textStartCol,
      hasGps: hasGps,
      gpsStartCol: gpsStartCol,
      baseColumnsCount: baseColumnsCount,
    );

    if (useEmbedded && embeddedCols.isNotEmpty) {
      for (final idx in embeddedCols) {
        final col = sourceToExcelCol[idx];
        if (col == null) continue;
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
        inZip: inZip,
      );
    }

    if (includeCoverSheet) {
      _buildCoverSheet(
        workbook,
        meta: projectMeta,
        sheetName: sheetName,
        rowsCount: rows.length,
        evidenceCount: evidenceCounts.total,
        inZip: inZip,
      );
    }

    if (includeSummarySheet) {
      _buildSummarySheet(
        workbook,
        rowsCount: rows.length,
        evidenceCount: evidenceCounts.total,
        photosCount: evidenceCounts.photos,
        videosCount: evidenceCounts.videos,
        audiosCount: evidenceCounts.audios,
        filesCount: evidenceCounts.files,
        gpsCount: evidenceCounts.locations,
        rows: rows,
        attachments: attachments,
        embeddedPhotos: embeddedPhotos,
        gpsByRow: gpsByRow,
        meta: projectMeta,
        inZip: inZip,
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
  bool inZip = false,
}) {
  final sheet = workbook.worksheets.addWithName('Adjuntos');
  sheet.showGridlines = false;

  // Banner con titulo + leyenda contextual.
  final title = sheet.getRangeByIndex(1, 1, 1, 7);
  title.merge();
  title.setText('Adjuntos del relevamiento');
  title.cellStyle.bold = true;
  title.cellStyle.fontSize = 14;
  title.cellStyle.fontColor = '#1F2937';
  title.cellStyle.backColor = '#EAF3FF';
  title.cellStyle.hAlign = xlsio.HAlignType.left;
  title.cellStyle.vAlign = xlsio.VAlignType.center;
  sheet.setRowHeightInPixels(1, 28);

  final hint = sheet.getRangeByIndex(2, 1, 2, 7);
  hint.merge();
  hint.setText(
    inZip
        ? 'Las evidencias viajan junto al XLSX dentro de este paquete .zip. Hace clic en "Abrir evidencia" para ver el archivo.'
        : 'Estas referencias indican evidencias que existen en la app. Para abrirlas, exporta como paquete .zip.',
  );
  hint.cellStyle.italic = true;
  hint.cellStyle.fontColor = inZip ? '#1E7E34' : '#8C5A00';
  hint.cellStyle.backColor = inZip ? '#F0F9F2' : '#FFF8E6';
  hint.cellStyle.hAlign = xlsio.HAlignType.left;
  hint.cellStyle.vAlign = xlsio.VAlignType.center;
  sheet.setRowHeightInPixels(2, 22);

  const headers = <String>[
    '#',
    'Tipo',
    'Archivo',
    'Celda',
    'Ruta relativa',
    'Accion',
    'Observacion',
  ];

  const int headerRow = 4;
  for (int c = 0; c < headers.length; c++) {
    sheet.getRangeByIndex(headerRow, c + 1).setText(headers[c]);
  }

  final headerRange = sheet.getRangeByIndex(headerRow, 1, headerRow, headers.length);
  headerRange.cellStyle.bold = true;
  headerRange.cellStyle.fontColor = '#1D1D1F';
  headerRange.cellStyle.backColor = '#EAF3FF';
  headerRange.cellStyle.hAlign = xlsio.HAlignType.center;
  headerRange.cellStyle.vAlign = xlsio.VAlignType.center;
  headerRange.cellStyle.fontSize = 11;
  headerRange.cellStyle.borders.bottom.lineStyle = xlsio.LineStyle.medium;
  headerRange.cellStyle.borders.bottom.color = '#4A90D9';
  sheet.setRowHeightInPixels(headerRow, 22);

  final int firstDataRow = headerRow + 1;

  for (int i = 0; i < attachments.length; i++) {
    final row = firstDataRow + i;
    final item = attachments[i];
    final type = item.type.trim();
    final hasPath = item.relativePath.trim().isNotEmpty;
    final isOpenable = inZip && hasPath && type != 'gps';

    sheet.getRangeByIndex(row, 1).setNumber((i + 1).toDouble());
    sheet
        .getRangeByIndex(row, 1)
        .cellStyle
        .hAlign = xlsio.HAlignType.center;

    sheet.getRangeByIndex(row, 2).setText(_attachmentTypeLabel(type));
    sheet.getRangeByIndex(row, 2).cellStyle.hAlign = xlsio.HAlignType.center;

    sheet
        .getRangeByIndex(row, 3)
        .setText(item.fileName.isEmpty ? '—' : item.fileName);
    sheet.getRangeByIndex(row, 4).setText(item.cellRef.isEmpty ? '—' : item.cellRef);
    sheet.getRangeByIndex(row, 4).cellStyle.hAlign = xlsio.HAlignType.center;

    final pathCell = sheet.getRangeByIndex(row, 5);
    if (hasPath) {
      pathCell.setText(item.relativePath);
      if (!inZip) {
        pathCell.cellStyle.fontColor = '#999999';
        pathCell.cellStyle.italic = true;
      }
    } else {
      pathCell.setText('—');
      pathCell.cellStyle.fontColor = '#999999';
      pathCell.cellStyle.italic = true;
      pathCell.cellStyle.hAlign = xlsio.HAlignType.center;
    }

    final actionCell = sheet.getRangeByIndex(row, 6);
    if (isOpenable) {
      try {
        final link = sheet.hyperlinks.add(
          actionCell,
          xlsio.HyperlinkType.file,
          item.relativePath,
        );
        link.textToDisplay = 'Abrir evidencia';
        link.screenTip = 'Abrir ${item.fileName}';
      } catch (_) {
        actionCell.setText('Abrir evidencia');
      }
      actionCell.cellStyle.fontColor = '#1565C0';
      actionCell.cellStyle.bold = true;
      actionCell.cellStyle.hAlign = xlsio.HAlignType.center;
    } else {
      actionCell.setText(type == 'gps'
          ? 'Sin archivo'
          : (inZip ? '—' : 'Solo en paquete .zip'));
      actionCell.cellStyle.italic = true;
      actionCell.cellStyle.fontColor = '#999999';
      actionCell.cellStyle.hAlign = xlsio.HAlignType.center;
    }

    final notesCell = sheet.getRangeByIndex(row, 7);
    final notes = item.notes.trim();
    if (notes.isEmpty) {
      notesCell.setText('—');
      notesCell.cellStyle.fontColor = '#999999';
      notesCell.cellStyle.italic = true;
      notesCell.cellStyle.hAlign = xlsio.HAlignType.center;
    } else {
      notesCell.setText(notes);
      notesCell.cellStyle.wrapText = true;
      notesCell.cellStyle.vAlign = xlsio.VAlignType.top;
    }

    if (i.isOdd) {
      sheet
          .getRangeByIndex(row, 1, row, headers.length)
          .cellStyle
          .backColor = '#F8FAFC';
    }
  }

  final lastDataRow = firstDataRow + attachments.length - 1;
  if (attachments.isNotEmpty) {
    final bodyRange = sheet.getRangeByIndex(
      headerRow,
      1,
      lastDataRow,
      headers.length,
    );
    bodyRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    bodyRange.cellStyle.borders.all.color = '#E0E0E0';
  }

  // Anchos pensados para legibilidad consistente.
  sheet.setColumnWidthInPixels(1, 48);
  sheet.setColumnWidthInPixels(2, 90);
  sheet.setColumnWidthInPixels(3, 240);
  sheet.setColumnWidthInPixels(4, 70);
  sheet.setColumnWidthInPixels(5, 280);
  sheet.setColumnWidthInPixels(6, 130);
  sheet.setColumnWidthInPixels(7, 320);

  try {
    sheet.getRangeByIndex(firstDataRow, 1).freezePanes();
  } catch (_) {}
}

String _attachmentTypeLabel(String type) {
  switch (type.trim().toLowerCase()) {
    case 'photo':
    case 'foto':
    case 'image':
    case 'imagen':
      return 'Foto';
    case 'video':
      return 'Video';
    case 'audio':
      return 'Audio';
    case 'gps':
    case 'ubicacion':
    case 'location':
      return 'GPS';
    case 'file':
    case 'archivo':
      return 'Archivo';
    default:
      return type.isEmpty ? '—' : type;
  }
}

List<_ExportColumn> _buildExportColumns({
  required List<String> columns,
  required List<List<String>> rows,
  required int sourceTextCols,
  required Set<int> preservedSourceCols,
}) {
  final exportColumns = <_ExportColumn>[];
  for (int sourceIndex = 0; sourceIndex < sourceTextCols; sourceIndex++) {
    final header = sourceIndex < columns.length ? columns[sourceIndex] : '';
    if (_isGenericEmptyColumn(
      header: header,
      rows: rows,
      sourceIndex: sourceIndex,
      preservedSourceCols: preservedSourceCols,
    )) {
      continue;
    }

    final kind = _inferColumnKind(
      header: header,
      rows: rows,
      sourceIndex: sourceIndex,
    );
    exportColumns.add(
      _ExportColumn(
        sourceIndex: sourceIndex,
        header: header,
        kind: kind,
        dateNumberFormat: kind == _PlanColumnKind.date
            ? _dateNumberFormatForColumn(
                header: header,
                rows: rows,
                sourceIndex: sourceIndex,
              )
            : null,
      ),
    );
  }
  return exportColumns;
}

bool _isGenericEmptyColumn({
  required String header,
  required List<List<String>> rows,
  required int sourceIndex,
  required Set<int> preservedSourceCols,
}) {
  if (preservedSourceCols.contains(sourceIndex)) return false;
  if (!RegExp(r'^Col \d+$', caseSensitive: false).hasMatch(header.trim())) {
    return false;
  }
  for (final row in rows) {
    if (sourceIndex < row.length && row[sourceIndex].trim().isNotEmpty) {
      return false;
    }
  }
  return true;
}

_PlanColumnKind _inferColumnKind({
  required String header,
  required List<List<String>> rows,
  required int sourceIndex,
}) {
  if (_isStatusHeader(header)) return _PlanColumnKind.status;
  if (_isEvidenceHeader(header)) return _PlanColumnKind.evidence;
  if (_isObservationHeader(header)) return _PlanColumnKind.observation;
  if (_isDateHeader(header) ||
      _allNonEmptyValuesMatch(rows, sourceIndex, _parseDateValue)) {
    return _PlanColumnKind.date;
  }
  if (_isIdentifierHeader(header)) return _PlanColumnKind.text;
  if (_isNumericHeader(header) ||
      _allNonEmptyNumericValues(rows, sourceIndex)) {
    return _PlanColumnKind.number;
  }
  return _PlanColumnKind.text;
}

void _setPlanCellValue(
  xlsio.Worksheet sheet,
  int row,
  int col,
  String value,
  _ExportColumn column,
) {
  final cell = sheet.getRangeByIndex(row, col);
  final trimmed = value.trim();
  if (FormulaEngine.isFormula(trimmed)) {
    cell.setFormula(trimmed);
    return;
  }

  if (column.kind == _PlanColumnKind.evidence &&
      _isEmptyEvidenceValue(trimmed)) {
    cell.setText('\u2014');
    _applyEmptyEvidenceStyle(cell);
    return;
  }

  if (column.kind == _PlanColumnKind.date) {
    final date = _parseDateValue(trimmed);
    if (date != null) {
      cell.setDateTime(date);
      cell.numberFormat = column.dateNumberFormat ?? 'dd/mm/yyyy';
      return;
    }
  }

  if (column.kind == _PlanColumnKind.number) {
    final number = _parseNumberStrict(trimmed);
    if (number != null) {
      cell.setNumber(number);
      cell.numberFormat = '0.00';
      cell.cellStyle.hAlign = xlsio.HAlignType.right;
      return;
    }
  }

  cell.setText(value);
}

void _applyPlanSheetPresentation({
  required xlsio.Worksheet sheet,
  required List<_ExportColumn> exportColumns,
  required List<List<String>> rows,
  required int headerRow,
  required int firstDataRow,
  required int safeLastCol,
  required int lastRow,
  required bool includeIndexColumn,
  required int textStartCol,
  required bool hasGps,
  required int gpsStartCol,
  required int baseColumnsCount,
}) {
  try {
    sheet.getRangeByIndex(firstDataRow, 1).freezePanes();
  } catch (_) {}

  try {
    sheet.autoFilters.filterRange =
        sheet.getRangeByIndex(headerRow, 1, lastRow, safeLastCol);
  } catch (_) {}

  final headerRange =
      sheet.getRangeByIndex(headerRow, 1, headerRow, safeLastCol);
  headerRange.cellStyle.borders.top.lineStyle = xlsio.LineStyle.thin;
  headerRange.cellStyle.borders.top.color = '#4A90D9';
  headerRange.cellStyle.borders.left.lineStyle = xlsio.LineStyle.thin;
  headerRange.cellStyle.borders.left.color = '#4A90D9';
  headerRange.cellStyle.borders.right.lineStyle = xlsio.LineStyle.thin;
  headerRange.cellStyle.borders.right.color = '#4A90D9';
  headerRange.cellStyle.borders.bottom.lineStyle = xlsio.LineStyle.medium;
  headerRange.cellStyle.borders.bottom.color = '#4A90D9';

  if (lastRow >= firstDataRow) {
    final dataRange = sheet.getRangeByIndex(
      firstDataRow,
      1,
      lastRow,
      safeLastCol,
    );
    dataRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
    dataRange.cellStyle.borders.all.color = '#E0E0E0';

    for (int excelRow = firstDataRow; excelRow <= lastRow; excelRow++) {
      if (excelRow.isEven) {
        sheet
            .getRangeByIndex(excelRow, 1, excelRow, safeLastCol)
            .cellStyle
            .backColor = '#F8FAFC';
      }
    }

    for (int i = 0; i < exportColumns.length; i++) {
      final column = exportColumns[i];
      final excelCol = textStartCol + i;
      for (int r = 0; r < rows.length; r++) {
        final cell = sheet.getRangeByIndex(firstDataRow + r, excelCol);
        final value = column.sourceIndex < rows[r].length
            ? rows[r][column.sourceIndex]
            : '';

        switch (column.kind) {
          case _PlanColumnKind.status:
            _applyStatusStyle(cell, value);
            break;
          case _PlanColumnKind.evidence:
            if (_isEmptyEvidenceValue(value)) {
              cell.setText('\u2014');
              _applyEmptyEvidenceStyle(cell);
            }
            break;
          case _PlanColumnKind.number:
            cell.numberFormat = '0.00';
            cell.cellStyle.hAlign = xlsio.HAlignType.right;
            break;
          case _PlanColumnKind.date:
            cell.numberFormat = column.dateNumberFormat ?? 'dd/mm/yyyy';
            break;
          case _PlanColumnKind.observation:
            cell.cellStyle.wrapText = true;
            cell.cellStyle.vAlign = xlsio.VAlignType.top;
            break;
          case _PlanColumnKind.text:
            break;
        }
      }
    }

    if (hasGps) {
      for (int r = 0; r < rows.length; r++) {
        final excelRow = firstDataRow + r;
        sheet.getRangeByIndex(excelRow, gpsStartCol).numberFormat = '0.000000';
        sheet.getRangeByIndex(excelRow, gpsStartCol + 1).numberFormat =
            '0.000000';
        sheet.getRangeByIndex(excelRow, gpsStartCol + 2).numberFormat = '0.00';
        sheet.getRangeByIndex(excelRow, gpsStartCol + 3).numberFormat =
            'dd/mm/yyyy hh:mm';
      }
    }
  }

  _applyPlanColumnWidths(
    sheet: sheet,
    exportColumns: exportColumns,
    rows: rows,
    includeIndexColumn: includeIndexColumn,
    textStartCol: textStartCol,
    hasGps: hasGps,
    gpsStartCol: gpsStartCol,
    baseColumnsCount: baseColumnsCount,
  );
}

void _applyPlanColumnWidths({
  required xlsio.Worksheet sheet,
  required List<_ExportColumn> exportColumns,
  required List<List<String>> rows,
  required bool includeIndexColumn,
  required int textStartCol,
  required bool hasGps,
  required int gpsStartCol,
  required int baseColumnsCount,
}) {
  if (includeIndexColumn) {
    _setColumnWidth(sheet, 1, math.max(10, rows.length.toString().length + 2));
  }

  for (int i = 0; i < exportColumns.length; i++) {
    final column = exportColumns[i];
    final excelCol = textStartCol + i;
    final maxLen = _maxVisibleLenForColumn(column, rows);
    final width = math.max(maxLen + 2, _minWidthForKind(column.kind));
    _setColumnWidth(sheet, excelCol, width.toDouble());
  }

  if (hasGps) {
    final gpsWidths = <double>[14, 14, 13, 18, 14];
    for (int i = 0; i < gpsWidths.length; i++) {
      _setColumnWidth(sheet, gpsStartCol + i, gpsWidths[i]);
    }
  }

  for (int col = 1; col <= math.max(1, baseColumnsCount); col++) {
    try {
      sheet.autoFitColumn(col);
      final current = sheet.getRangeByIndex(1, col).columnWidth;
      sheet.getRangeByIndex(1, col).columnWidth =
          current.clamp(10, 50).toDouble();
    } catch (_) {}
  }

  if (includeIndexColumn) {
    _setColumnWidth(sheet, 1, 10);
  }
  for (int i = 0; i < exportColumns.length; i++) {
    final column = exportColumns[i];
    final excelCol = textStartCol + i;
    final maxLen = _maxVisibleLenForColumn(column, rows);
    final width = math.max(maxLen + 2, _minWidthForKind(column.kind));
    final current = sheet.getRangeByIndex(1, excelCol).columnWidth;
    _setColumnWidth(sheet, excelCol, math.max(current, width.toDouble()));
  }
}

void _setColumnWidth(xlsio.Worksheet sheet, int col, double width) {
  sheet.getRangeByIndex(1, col).columnWidth = width.clamp(10, 50).toDouble();
}

int _maxVisibleLenForColumn(_ExportColumn column, List<List<String>> rows) {
  int maxLen = column.header.length;
  for (final row in rows) {
    final raw = column.sourceIndex < row.length ? row[column.sourceIndex] : '';
    final visible =
        column.kind == _PlanColumnKind.evidence && _isEmptyEvidenceValue(raw)
            ? '\u2014'
            : raw;
    maxLen = math.max(maxLen, visible.trim().length);
  }
  return maxLen;
}

double _minWidthForKind(_PlanColumnKind kind) {
  switch (kind) {
    case _PlanColumnKind.date:
      return 16;
    case _PlanColumnKind.number:
      return 13;
    case _PlanColumnKind.status:
      return 14;
    case _PlanColumnKind.evidence:
      return 16;
    case _PlanColumnKind.observation:
      return 36;
    case _PlanColumnKind.text:
      return 10;
  }
}

bool _hasGps(List<GpsExport?>? gpsByRow) {
  if (gpsByRow == null || gpsByRow.isEmpty) return false;
  for (final g in gpsByRow) {
    if (g != null && g.hasFix) return true;
  }
  return false;
}

int _directGpsCount(List<GpsExport?>? gpsByRow) {
  if (gpsByRow == null || gpsByRow.isEmpty) return 0;
  int count = 0;
  for (final g in gpsByRow) {
    if (g != null && g.hasFix) count++;
  }
  return count;
}

_EvidenceCounts _countEvidence({
  required Map<int, List<Uint8List>>? photosByRow,
  required List<EmbeddedPhoto>? embeddedPhotos,
  required List<AttachmentRow>? attachments,
  required List<GpsExport?>? gpsByRow,
}) {
  int attachmentPhotos = 0;
  int videos = 0;
  int audios = 0;
  int files = 0;
  int attachmentLocations = 0;

  if (attachments != null && attachments.isNotEmpty) {
    for (final item in attachments) {
      final type = _normalizeText(item.type);
      if (type.contains('gps') ||
          type.contains('ubicacion') ||
          type.contains('location')) {
        attachmentLocations++;
      } else if (type.contains('photo') ||
          type.contains('foto') ||
          type.contains('image') ||
          type.contains('imagen')) {
        attachmentPhotos++;
      } else if (type.contains('video')) {
        videos++;
      } else if (type.contains('audio')) {
        audios++;
      } else {
        files++;
      }
    }
  }

  final legacyPhotos = photosByRow == null || photosByRow.isEmpty
      ? 0
      : photosByRow.values.fold<int>(0, (prev, list) => prev + list.length);
  final embeddedPhotoCount = embeddedPhotos == null ? 0 : embeddedPhotos.length;

  return _EvidenceCounts(
    photos:
        math.max(attachmentPhotos, math.max(legacyPhotos, embeddedPhotoCount)),
    videos: videos,
    audios: audios,
    files: files,
    locations: attachmentLocations > 0
        ? attachmentLocations
        : _directGpsCount(gpsByRow),
  );
}

bool _isStatusHeader(String header) {
  return _normalizeText(header).contains('estado');
}

bool _isEvidenceHeader(String header) {
  final normalized = _normalizeText(header);
  final compact = normalized.replaceAll(RegExp(r'[\s/_-]+'), '');
  return normalized == 'foto' ||
      normalized == 'evidencia' ||
      normalized == 'fotos' ||
      normalized == 'adjuntos' ||
      compact == 'fotoevidencia' ||
      compact == 'fotoevidencias' ||
      normalized.contains('foto/evidencia') ||
      (normalized.contains('foto') && normalized.contains('evidencia'));
}

bool _isObservationHeader(String header) {
  final normalized = _normalizeText(header);
  return normalized.contains('observacion') ||
      normalized.contains('comentario') ||
      normalized.contains('nota');
}

bool _isDateHeader(String header) {
  final normalized = _normalizeText(header);
  return normalized.contains('fecha') ||
      normalized.contains('date') ||
      normalized.contains('hora') ||
      normalized.contains('time') ||
      normalized.contains('addedat');
}

bool _isNumericHeader(String header) {
  final normalized = _normalizeText(header);
  if (_isIdentifierHeader(header)) return false;
  return normalized.contains('potencial') ||
      normalized.contains('ir drop') ||
      normalized.contains('voltaje') ||
      normalized.contains('tension') ||
      normalized.contains('corriente') ||
      normalized.contains('resistencia') ||
      normalized.contains('ohm') ||
      RegExp(r'\bmv\b').hasMatch(normalized) ||
      RegExp(r'\((?:mv|v)\)').hasMatch(normalized);
}

bool _isIdentifierHeader(String header) {
  final normalized = _normalizeText(header);
  return RegExp(r'\bid\b').hasMatch(normalized) ||
      normalized.contains('codigo') ||
      normalized.contains('code') ||
      normalized.contains('progresiva') ||
      normalized.contains('referencia') ||
      normalized.contains('serie') ||
      normalized.contains('patente');
}

bool _allNonEmptyValuesMatch<T>(
  List<List<String>> rows,
  int sourceIndex,
  T? Function(String value) parser,
) {
  var hasValue = false;
  for (final row in rows) {
    if (sourceIndex >= row.length) continue;
    final value = row[sourceIndex].trim();
    if (value.isEmpty) continue;
    hasValue = true;
    if (parser(value) == null) return false;
  }
  return hasValue;
}

bool _allNonEmptyNumericValues(List<List<String>> rows, int sourceIndex) {
  var hasValue = false;
  for (final row in rows) {
    if (sourceIndex >= row.length) continue;
    final value = row[sourceIndex].trim();
    if (value.isEmpty) continue;
    hasValue = true;
    if (_looksLikeIdentifierValue(value) || _parseNumberStrict(value) == null) {
      return false;
    }
  }
  return hasValue;
}

bool _looksLikeIdentifierValue(String value) {
  final trimmed = value.trim();
  if (RegExp(r'^0\d+$').hasMatch(trimmed)) return true;
  if (RegExp(r'^\d{8,}$').hasMatch(trimmed)) return true;
  return false;
}

double? _parseNumberStrict(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (!RegExp(r'^-?(?:\d+|\d+[,.]\d+)$').hasMatch(trimmed)) return null;
  return double.tryParse(trimmed.replaceAll(',', '.'));
}

DateTime? _parseDateValue(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final iso = DateTime.tryParse(trimmed);
  if (iso != null) return iso;

  final match = RegExp(
    r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2})(?:[.,]\d+)?)?)?$',
  ).firstMatch(trimmed);
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
  final date = DateTime(year, month, day, hour, minute, second);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

String _dateNumberFormatForColumn({
  required String header,
  required List<List<String>> rows,
  required int sourceIndex,
}) {
  var hasTime = _normalizeText(header).contains('hora') ||
      _normalizeText(header).contains('time');
  for (final row in rows) {
    if (sourceIndex >= row.length) continue;
    final date = _parseDateValue(row[sourceIndex]);
    if (date == null) continue;
    if (_hasRealTime(date)) {
      hasTime = true;
      break;
    }
  }
  return hasTime ? 'dd/mm/yyyy hh:mm' : 'dd/mm/yyyy';
}

bool _hasRealTime(DateTime date) {
  return date.hour != 0 ||
      date.minute != 0 ||
      date.second != 0 ||
      date.millisecond != 0 ||
      date.microsecond != 0;
}

bool _isEmptyEvidenceValue(String value) {
  final normalized = _normalizeText(value);
  return normalized.isEmpty ||
      normalized == 'sin evidencia' ||
      normalized == 'sin evidencias' ||
      normalized == 'sin evidencia adjunta' ||
      normalized == 'sin evidencias adjuntas';
}

void _applyEmptyEvidenceStyle(xlsio.Range cell) {
  cell.cellStyle.fontColor = '#AAAAAA';
  cell.cellStyle.italic = true;
  cell.cellStyle.hAlign = xlsio.HAlignType.center;
  cell.cellStyle.vAlign = xlsio.VAlignType.center;
}

void _applyStatusStyle(xlsio.Range cell, String value) {
  final normalized = _normalizeText(value);
  if (normalized.isEmpty) return;

  if (_matchesAny(normalized, const [
    'critico',
    'error',
    'no conforme',
    'malo',
  ])) {
    _applySemanticStatusStyle(
      cell,
      backColor: '#FDECEA',
      fontColor: '#C62828',
    );
    return;
  }

  if (_matchesAny(normalized, const [
    'obs',
    'observado',
    'atencion',
    'pendiente',
    'revisar',
    'regular',
  ])) {
    _applySemanticStatusStyle(
      cell,
      backColor: '#FFF3E0',
      fontColor: '#E65100',
    );
    return;
  }

  if (_matchesAny(normalized, const [
    'ok',
    'conforme',
    'aprobado',
    'bueno',
  ])) {
    _applySemanticStatusStyle(
      cell,
      backColor: '#E6F4EA',
      fontColor: '#1E7E34',
    );
  }
}

bool _matchesAny(String normalized, List<String> tokens) {
  for (final token in tokens) {
    if (normalized == token || normalized.contains(token)) return true;
  }
  return false;
}

void _applySemanticStatusStyle(
  xlsio.Range cell, {
  required String backColor,
  required String fontColor,
}) {
  cell.cellStyle.backColor = backColor;
  cell.cellStyle.fontColor = fontColor;
  cell.cellStyle.bold = true;
  cell.cellStyle.hAlign = xlsio.HAlignType.center;
  cell.cellStyle.vAlign = xlsio.VAlignType.center;
}

String _normalizeText(String value) {
  var out = value.trim().toLowerCase();
  const replacements = {
    '\u00e1': 'a',
    '\u00e0': 'a',
    '\u00e4': 'a',
    '\u00e2': 'a',
    '\u00e9': 'e',
    '\u00e8': 'e',
    '\u00eb': 'e',
    '\u00ea': 'e',
    '\u00ed': 'i',
    '\u00ec': 'i',
    '\u00ef': 'i',
    '\u00ee': 'i',
    '\u00f3': 'o',
    '\u00f2': 'o',
    '\u00f6': 'o',
    '\u00f4': 'o',
    '\u00fa': 'u',
    '\u00f9': 'u',
    '\u00fc': 'u',
    '\u00fb': 'u',
    '\u00f1': 'n',
  };
  replacements.forEach((from, to) {
    out = out.replaceAll(from, to);
  });
  return out.replaceAll(RegExp(r'\s+'), ' ');
}

void _buildCoverSheet(
  xlsio.Workbook wb, {
  ExportProjectMeta? meta,
  required String sheetName,
  required int rowsCount,
  required int evidenceCount,
  required bool inZip,
}) {
  final cover = wb.worksheets.addWithName('Caratula');
  cover.showGridlines = false;

  // Banda de marca BitFlow
  final brand = cover.getRangeByIndex(1, 1, 1, 4);
  brand.merge();
  brand.setText('Bit Flow');
  brand.cellStyle.bold = true;
  brand.cellStyle.fontSize = 22;
  brand.cellStyle.fontColor = '#FFFFFF';
  brand.cellStyle.backColor = '#1F4E91';
  brand.cellStyle.hAlign = xlsio.HAlignType.left;
  brand.cellStyle.vAlign = xlsio.VAlignType.center;
  cover.setRowHeightInPixels(1, 38);

  final title = cover.getRangeByIndex(2, 1, 2, 4);
  title.merge();
  final titleText = (meta?.title?.trim().isNotEmpty ?? false)
      ? meta!.title!.trim()
      : (sheetName.trim().isEmpty ? 'Reporte de relevamiento' : sheetName.trim());
  title.setText(titleText);
  title.cellStyle.bold = true;
  title.cellStyle.fontSize = 16;
  title.cellStyle.fontColor = '#1D1D1F';
  title.cellStyle.hAlign = xlsio.HAlignType.left;
  title.cellStyle.vAlign = xlsio.VAlignType.center;
  cover.setRowHeightInPixels(2, 26);

  final subtitleText = meta?.subtitle?.trim();
  final subtitle = cover.getRangeByIndex(3, 1, 3, 4);
  subtitle.merge();
  subtitle.setText(subtitleText?.isNotEmpty == true
      ? subtitleText!
      : 'Reporte profesional generado por Bit Flow');
  subtitle.cellStyle.italic = true;
  subtitle.cellStyle.fontColor = '#5F6368';
  subtitle.cellStyle.hAlign = xlsio.HAlignType.left;
  subtitle.cellStyle.vAlign = xlsio.VAlignType.center;
  cover.setRowHeightInPixels(3, 20);

  int row = 5;

  row = _renderCoverSection(
    cover,
    startRow: row,
    title: 'Datos del proyecto',
    entries: <List<String?>>[
      ['Obra', meta?.obra],
      ['Cliente', meta?.cliente],
      ['Responsable', meta?.responsable],
      ['Ubicacion', meta?.ubicacion],
    ],
  );
  row += 1;

  final fechaTxt = _formatExportTimestamp(meta?.exportedAt ?? DateTime.now());
  row = _renderCoverSection(
    cover,
    startRow: row,
    title: 'Resumen del archivo',
    entries: <List<String?>>[
      ['Fecha de exportacion', fechaTxt],
      ['Cantidad de registros', rowsCount.toString()],
      ['Cantidad de evidencias', evidenceCount.toString()],
    ],
  );
  row += 1;

  row = _renderCoverSection(
    cover,
    startRow: row,
    title: 'Trazabilidad',
    entries: <List<String?>>[
      ['Version de Bit Flow', meta?.appVersion],
      ['ID de planilla', meta?.sheetId],
    ],
  );
  row += 1;

  final note = (meta?.bundleNote?.trim().isNotEmpty ?? false)
      ? meta!.bundleNote!.trim()
      : (inZip
          ? 'Las evidencias viajan dentro de este paquete .zip, en la carpeta attachments/.'
          : 'Las evidencias quedan registradas en la app. Para enviarlas, exporta como paquete .zip.');
  final noteRange = cover.getRangeByIndex(row, 1, row, 4);
  noteRange.merge();
  noteRange.setText(note);
  noteRange.cellStyle.italic = true;
  noteRange.cellStyle.fontColor = inZip ? '#1E7E34' : '#8C5A00';
  noteRange.cellStyle.backColor = inZip ? '#F0F9F2' : '#FFF8E6';
  noteRange.cellStyle.wrapText = true;
  noteRange.cellStyle.vAlign = xlsio.VAlignType.center;
  cover.setRowHeightInPixels(row, 36);

  cover.setColumnWidthInPixels(1, 220);
  cover.setColumnWidthInPixels(2, 320);
  cover.setColumnWidthInPixels(3, 24);
  cover.setColumnWidthInPixels(4, 280);
}

int _renderCoverSection(
  xlsio.Worksheet sheet, {
  required int startRow,
  required String title,
  required List<List<String?>> entries,
}) {
  final header = sheet.getRangeByIndex(startRow, 1, startRow, 4);
  header.merge();
  header.setText(title);
  header.cellStyle.bold = true;
  header.cellStyle.fontSize = 12;
  header.cellStyle.fontColor = '#1F4E91';
  header.cellStyle.borders.bottom.lineStyle = xlsio.LineStyle.medium;
  header.cellStyle.borders.bottom.color = '#1F4E91';
  header.cellStyle.vAlign = xlsio.VAlignType.center;
  sheet.setRowHeightInPixels(startRow, 22);

  var row = startRow + 1;
  for (final entry in entries) {
    final label = entry[0] ?? '';
    final rawValue = entry.length > 1 ? entry[1] : null;
    final value = (rawValue?.trim().isNotEmpty ?? false)
        ? rawValue!.trim()
        : 'No especificado';
    final isPlaceholder = !(rawValue?.trim().isNotEmpty ?? false);

    final labelCell = sheet.getRangeByIndex(row, 1);
    labelCell.setText(label);
    labelCell.cellStyle.bold = true;
    labelCell.cellStyle.fontColor = '#1D1D1F';
    labelCell.cellStyle.vAlign = xlsio.VAlignType.center;

    final valueCell = sheet.getRangeByIndex(row, 2);
    valueCell.setText(value);
    valueCell.cellStyle.vAlign = xlsio.VAlignType.center;
    if (isPlaceholder) {
      valueCell.cellStyle.italic = true;
      valueCell.cellStyle.fontColor = '#999999';
    } else {
      valueCell.cellStyle.fontColor = '#1D1D1F';
    }
    sheet.setRowHeightInPixels(row, 18);
    row++;
  }
  return row;
}

String _formatExportTimestamp(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

void _buildSummarySheet(
  xlsio.Workbook wb, {
  required int rowsCount,
  required int evidenceCount,
  required int photosCount,
  required int videosCount,
  required int audiosCount,
  required int filesCount,
  required int gpsCount,
  required List<List<String>> rows,
  List<AttachmentRow>? attachments,
  List<EmbeddedPhoto>? embeddedPhotos,
  List<GpsExport?>? gpsByRow,
  ExportProjectMeta? meta,
  bool inZip = false,
}) {
  final summary = wb.worksheets.addWithName('Resumen');
  summary.showGridlines = false;

  // Banda titular
  final title = summary.getRangeByIndex(1, 1, 1, 3);
  title.merge();
  title.setText('Resumen ejecutivo');
  title.cellStyle.bold = true;
  title.cellStyle.fontSize = 16;
  title.cellStyle.fontColor = '#FFFFFF';
  title.cellStyle.backColor = '#1F4E91';
  title.cellStyle.hAlign = xlsio.HAlignType.left;
  title.cellStyle.vAlign = xlsio.VAlignType.center;
  summary.setRowHeightInPixels(1, 30);

  final subtitle = summary.getRangeByIndex(2, 1, 2, 3);
  subtitle.merge();
  subtitle.setText(
    'Snapshot de cantidades, calidad de los registros y advertencias.',
  );
  subtitle.cellStyle.italic = true;
  subtitle.cellStyle.fontColor = '#5F6368';
  subtitle.cellStyle.vAlign = xlsio.VAlignType.center;
  summary.setRowHeightInPixels(2, 20);

  int row = 4;

  // ---------- Totales ----------
  row = _renderSummarySectionHeader(summary, row, 'Totales generales');
  row = _renderSummaryMetric(summary, row, 'Filas exportadas', rowsCount);
  row = _renderSummaryMetric(summary, row, 'Evidencias totales', evidenceCount);
  row = _renderSummaryMetric(summary, row, 'Fotos', photosCount);
  row = _renderSummaryMetric(summary, row, 'Videos', videosCount);
  row = _renderSummaryMetric(summary, row, 'Audios', audiosCount);
  row = _renderSummaryMetric(summary, row, 'Archivos', filesCount);
  row = _renderSummaryMetric(summary, row, 'Ubicaciones GPS', gpsCount);

  if (evidenceCount == 0 &&
      photosCount == 0 &&
      videosCount == 0 &&
      audiosCount == 0 &&
      filesCount == 0) {
    final cell = summary.getRangeByIndex(row, 1, row, 3);
    cell.merge();
    cell.setText('Sin evidencia adjunta en esta exportaci\u00f3n');
    cell.cellStyle.italic = true;
    cell.cellStyle.fontColor = '#8C5A00';
    cell.cellStyle.backColor = '#FFF8E6';
    cell.cellStyle.hAlign = xlsio.HAlignType.left;
    cell.cellStyle.vAlign = xlsio.VAlignType.center;
    summary.setRowHeightInPixels(row, 22);
    row++;
  }
  row += 1;

  // ---------- Calidad ----------
  final quality = _computeQuality(
    rows: rows,
    attachments: attachments,
    embeddedPhotos: embeddedPhotos,
    gpsByRow: gpsByRow,
  );
  row = _renderSummarySectionHeader(summary, row, 'Calidad del relevamiento');
  row = _renderSummaryMetric(
    summary,
    row,
    'Filas con evidencias',
    quality.rowsWithEvidence,
  );
  row = _renderSummaryMetric(
    summary,
    row,
    'Filas con GPS',
    quality.rowsWithGps,
  );
  row = _renderSummaryMetric(
    summary,
    row,
    'Filas vacias o incompletas',
    quality.rowsBlank,
  );
  row += 1;

  // ---------- Advertencias ----------
  final warnings = <String>[];
  if (meta?.cliente?.trim().isEmpty ?? true) {
    warnings.add('Falta indicar el cliente en la caratula.');
  }
  if (meta?.obra?.trim().isEmpty ?? true) {
    warnings.add('Falta indicar la obra en la caratula.');
  }
  if (meta?.responsable?.trim().isEmpty ?? true) {
    warnings.add('Falta indicar el responsable del relevamiento.');
  }
  if (rowsCount == 0) {
    warnings.add('La planilla no tiene filas exportadas.');
  }
  if (!inZip && evidenceCount > 0) {
    warnings.add(
      'Hay evidencias referenciadas pero el XLSX se export\u00f3 sin el paquete .zip. '
      'Volv\u00e9 a exportar como paquete para incluirlas.',
    );
  }

  row = _renderSummarySectionHeader(summary, row, 'Advertencias');
  if (warnings.isEmpty) {
    final cell = summary.getRangeByIndex(row, 1, row, 3);
    cell.merge();
    cell.setText('Sin advertencias. Relevamiento completo.');
    cell.cellStyle.italic = true;
    cell.cellStyle.fontColor = '#1E7E34';
    cell.cellStyle.backColor = '#F0F9F2';
    cell.cellStyle.hAlign = xlsio.HAlignType.left;
    cell.cellStyle.vAlign = xlsio.VAlignType.center;
    summary.setRowHeightInPixels(row, 22);
    row++;
  } else {
    for (final warning in warnings) {
      final cell = summary.getRangeByIndex(row, 1, row, 3);
      cell.merge();
      cell.setText('\u2022 $warning');
      cell.cellStyle.fontColor = '#8C5A00';
      cell.cellStyle.backColor = '#FFF8E6';
      cell.cellStyle.hAlign = xlsio.HAlignType.left;
      cell.cellStyle.vAlign = xlsio.VAlignType.center;
      cell.cellStyle.wrapText = true;
      summary.setRowHeightInPixels(row, 26);
      row++;
    }
  }

  summary.setColumnWidthInPixels(1, 280);
  summary.setColumnWidthInPixels(2, 90);
  summary.setColumnWidthInPixels(3, 320);
}

int _renderSummarySectionHeader(
  xlsio.Worksheet sheet,
  int row,
  String text,
) {
  final range = sheet.getRangeByIndex(row, 1, row, 3);
  range.merge();
  range.setText(text);
  range.cellStyle.bold = true;
  range.cellStyle.fontSize = 12;
  range.cellStyle.fontColor = '#1F4E91';
  range.cellStyle.borders.bottom.lineStyle = xlsio.LineStyle.medium;
  range.cellStyle.borders.bottom.color = '#1F4E91';
  range.cellStyle.vAlign = xlsio.VAlignType.center;
  sheet.setRowHeightInPixels(row, 22);
  return row + 1;
}

int _renderSummaryMetric(
  xlsio.Worksheet sheet,
  int row,
  String label,
  int value,
) {
  final labelCell = sheet.getRangeByIndex(row, 1);
  labelCell.setText(label);
  labelCell.cellStyle.bold = true;
  labelCell.cellStyle.vAlign = xlsio.VAlignType.center;

  final valueCell = sheet.getRangeByIndex(row, 2);
  valueCell.setNumber(value.toDouble());
  valueCell.cellStyle.hAlign = xlsio.HAlignType.right;
  valueCell.cellStyle.fontColor = value > 0 ? '#1D1D1F' : '#999999';
  valueCell.cellStyle.italic = value == 0;
  valueCell.numberFormat = '0';
  valueCell.cellStyle.vAlign = xlsio.VAlignType.center;

  sheet.setRowHeightInPixels(row, 18);
  return row + 1;
}

class _SummaryQuality {
  const _SummaryQuality({
    required this.rowsWithEvidence,
    required this.rowsWithGps,
    required this.rowsBlank,
  });

  final int rowsWithEvidence;
  final int rowsWithGps;
  final int rowsBlank;
}

_SummaryQuality _computeQuality({
  required List<List<String>> rows,
  List<AttachmentRow>? attachments,
  List<EmbeddedPhoto>? embeddedPhotos,
  List<GpsExport?>? gpsByRow,
}) {
  final evidenceRows = <int>{};
  final gpsRows = <int>{};

  if (attachments != null) {
    for (final item in attachments) {
      final r = _rowFromCellRef(item.cellRef);
      if (r == null) continue;
      final type = _normalizeText(item.type);
      if (type.contains('gps') ||
          type.contains('ubicacion') ||
          type.contains('location')) {
        gpsRows.add(r);
      } else {
        evidenceRows.add(r);
      }
    }
  }

  if (embeddedPhotos != null) {
    for (final p in embeddedPhotos) {
      if (p.rowIndex >= 0) evidenceRows.add(p.rowIndex);
    }
  }

  if (gpsByRow != null) {
    for (int i = 0; i < gpsByRow.length; i++) {
      final g = gpsByRow[i];
      if (g != null && g.hasFix) gpsRows.add(i);
    }
  }

  int blankRows = 0;
  for (final row in rows) {
    final hasContent = row.any((cell) => cell.trim().isNotEmpty);
    if (!hasContent) blankRows++;
  }

  return _SummaryQuality(
    rowsWithEvidence: evidenceRows.length,
    rowsWithGps: gpsRows.length,
    rowsBlank: blankRows,
  );
}

int? _rowFromCellRef(String ref) {
  final trimmed = ref.trim();
  if (trimmed.isEmpty) return null;
  final m = RegExp(r'^[A-Za-z]+(\d+)$').firstMatch(trimmed);
  if (m == null) return null;
  final raw = int.tryParse(m.group(1) ?? '');
  if (raw == null || raw <= 0) return null;
  return raw - 1;
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
