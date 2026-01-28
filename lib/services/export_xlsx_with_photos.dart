// lib/services/export_xlsx_with_photos.dart
//
// XLSX con fotos embebidas (Syncfusion XlsIO) — robusto y sin referencias por nombre.
// - Escribe todo con getRangeByIndex.
// - Inserta fotos con pictures.addStream(row, col, bytes).
// - NO usa picture.left/top (no existen en Flutter XlsIO).
// - autoFitColumn con try/catch + fallback por ancho estimado para que nunca rompa el export.
// - Maneja filas con más columnas que headers sin pisar columnas de fotos.
//
// Devuelve bytes del XLSX listo para guardar/enviar.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

/// Genera un XLSX con datos + fotos embebidas.
///
/// - [columns]: encabezados de la grilla (sin la columna "#").
/// - [rows]: filas (cada fila = lista de strings).
/// - [photosByRow]:
///     key = índice de fila 0-based (misma posición que en [rows])
///     value = lista de imágenes (Uint8List JPG/PNG) para esa fila.
///
/// Devuelve bytes del XLSX.
Future<Uint8List> buildXlsxWithPhotos({
  required List<String> columns,
  required List<List<String>> rows,
  Map<int, List<Uint8List>>? photosByRow,
}) async {
  final workbook = xlsio.Workbook(1);
  try {
    final sheet = workbook.worksheets[0];
    sheet.name = 'PLANILLA';

    const int headerRow = 1;
    const int firstDataRow = headerRow + 1;

    // Ancho real de texto: puede haber filas más largas que headers.
    int textCols = columns.length;
    for (final r in rows) {
      if (r.length > textCols) textCols = r.length;
    }
    if (textCols < 0) textCols = 0;

    // Col 1 = "#", luego textCols columnas de texto.
    final int baseColumnsCount = 1 + textCols;

    // Máxima cantidad de fotos por fila (para crear columnas "Foto 1..N").
    final int maxPhotosPerRow = (photosByRow == null || photosByRow.isEmpty)
        ? 0
        : photosByRow.values.fold<int>(
      0,
          (prev, list) => math.max(prev, list.length),
    );

    // Fotos empiezan inmediatamente después del bloque de texto.
    // (solo si hay fotos)
    final int firstPhotoCol = baseColumnsCount + 1;
    final int lastCol = (maxPhotosPerRow > 0)
        ? (baseColumnsCount + maxPhotosPerRow)
        : baseColumnsCount;

    // Estilo header (nombre único por seguridad).
    final styleName = 'HeaderStyle_${DateTime.now().microsecondsSinceEpoch}';
    final headerStyle = workbook.styles.add(styleName);
    headerStyle.bold = true;
    headerStyle.backColor = '#FFEFEFEF';
    headerStyle.hAlign = xlsio.HAlignType.center;
    headerStyle.vAlign = xlsio.VAlignType.center;

    // --------------------------
    // 1) Encabezados
    // --------------------------
    sheet.getRangeByIndex(headerRow, 1).setText('#');

    // Headers de texto (si faltan, se completan con vacío).
    for (int i = 0; i < textCols; i++) {
      final title = (i < columns.length) ? columns[i] : '';
      sheet.getRangeByIndex(headerRow, 2 + i).setText(title);
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
    sheet.getRangeByIndex(headerRow, 1, headerRow, lastCol);
    headerRange.cellStyle = headerStyle;

    // --------------------------
    // 2) Datos + fotos
    // --------------------------
    const int photoThumbW = 100;
    const int photoThumbH = 80;
    const int photoColWidthPx = 112;
    const double photoRowHeightPx = 90.0;

    // Ajuste de columnas de fotos si existen.
    if (maxPhotosPerRow > 0) {
      for (int p = 0; p < maxPhotosPerRow; p++) {
        sheet.setColumnWidthInPixels(firstPhotoCol + p, photoColWidthPx);
      }
    }

    for (int r = 0; r < rows.length; r++) {
      final excelRow = firstDataRow + r;
      final rowValues = rows[r];

      // Columna "#"
      sheet.getRangeByIndex(excelRow, 1).setNumber((r + 1).toDouble());

      // Texto: escribe hasta textCols, padding con ''.
      for (int c = 0; c < textCols; c++) {
        final v = (c < rowValues.length) ? rowValues[c] : '';
        sheet.getRangeByIndex(excelRow, 2 + c).setText(v);
      }

      // Fotos de esta fila
      if (maxPhotosPerRow > 0 &&
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
              // Nota: en Flutter XlsIO no existen picture.left/top.
            } catch (_) {
              // Si una imagen está corrupta, no rompemos el XLSX.
              sheet.getRangeByIndex(excelRow, col).setText('N/D');
            }
          }
        }
      }
    }

    // --------------------------
    // 3) Bordes finos para toda el área usada
    // --------------------------
    final int lastRow = rows.length + 1; // incluye headers
    final tableRange = sheet.getRangeByIndex(1, 1, lastRow, lastCol);
    tableRange.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;

    // --------------------------
    // 4) Anchos: autoFit con fallback seguro
    // --------------------------
    // Solo texto (incluye '#'), fotos ya tienen ancho fijo.
    final int lastTextCol = baseColumnsCount;
    for (int col = 1; col <= lastTextCol; col++) {
      try {
        sheet.autoFitColumn(col);
      } catch (_) {
        // Fallback heurístico en px (evita romper la exportación).
        final maxLen = _maxTextLenForColumn(
          headers: columns,
          rows: rows,
          excelCol: col,
        );
        final px = _widthPxForLen(maxLen);
        sheet.setColumnWidthInPixels(col, px);
      }
    }

    final bytes = workbook.saveAsStream();
    return Uint8List.fromList(bytes);
  } finally {
    workbook.dispose();
  }
}

int _maxTextLenForColumn({
  required List<String> headers,
  required List<List<String>> rows,
  required int excelCol,
}) {
  // excelCol: 1 = "#", 2 = headers[0], ...
  int maxLen = 0;

  if (excelCol == 1) {
    maxLen = math.max(maxLen, 1); // "#"
    final n = rows.length.toString();
    maxLen = math.max(maxLen, n.length);
    return maxLen;
  }

  final idx = excelCol - 2; // col 2 -> index 0
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
