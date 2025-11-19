// lib/services/export_xlsx_with_photos.dart
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

/// Genera un XLSX con datos + fotos embebidas.
/// - [columns]: encabezados de la tabla (sin la columna "#").
/// - [rows]: una lista de filas, cada fila es una lista de strings.
/// - [photosByRow]:
///     key = índice de fila (0-based, misma posición que en [rows])
///     value = lista de imágenes (Uint8List, JPG/PNG) para esa fila.
///
/// Devuelve los bytes del XLSX listo para guardar / enviar.
Future<Uint8List> buildXlsxWithPhotos({
  required List<String> columns,
  required List<List<String>> rows,
  Map<int, List<Uint8List>>? photosByRow,
}) async {
  final workbook = xlsio.Workbook();
  final sheet = workbook.worksheets[0];
  sheet.name = 'PLANILLA';

  const headerRow = 1;
  const firstDataRow = headerRow + 1;

  // Col 1 = "#", después van las columnas de la grilla.
  final baseColumnsCount = 1 + columns.length;

  // Máxima cantidad de fotos por fila (para saber cuántas columnas de foto crear)
  final maxPhotosPerRow = photosByRow == null || photosByRow.isEmpty
      ? 0
      : photosByRow.values.fold<int>(
    0,
        (prev, list) => math.max(prev, list.length),
  );

  final firstPhotoCol = baseColumnsCount + (maxPhotosPerRow > 0 ? 1 : 0);
  final lastCol =
  maxPhotosPerRow > 0 ? firstPhotoCol + maxPhotosPerRow - 1 : baseColumnsCount;

  // 1) Encabezados
  // Columna "#"
  sheet.getRangeByIndex(headerRow, 1).setText('#');

  // Resto de encabezados de la grilla
  for (var i = 0; i < columns.length; i++) {
    sheet.getRangeByIndex(headerRow, 2 + i).setText(columns[i]);
  }

  // Encabezados de fotos (Foto 1, Foto 2, ...)
  if (maxPhotosPerRow > 0) {
    for (var p = 0; p < maxPhotosPerRow; p++) {
      sheet
          .getRangeByIndex(headerRow, firstPhotoCol + p)
          .setText('Foto ${p + 1}');
    }
  }

  // Opcional: poner negrita a la fila de encabezados
  final headerRange =
  sheet.getRangeByIndex(headerRow, 1, headerRow, lastCol);
  final headerStyle = workbook.styles.add('HeaderStyle');
  headerStyle.bold = true;
  headerRange.cellStyle = headerStyle;

  // 2) Datos + fotos
  for (var r = 0; r < rows.length; r++) {
    final excelRow = firstDataRow + r;
    final rowValues = rows[r];

    // Columna "#"
    sheet.getRangeByIndex(excelRow, 1).setNumber((r + 1).toDouble());

    // Datos de la grilla
    for (var c = 0; c < rowValues.length; c++) {
      sheet.getRangeByIndex(excelRow, 2 + c).setText(rowValues[c]);
    }

    // Fotos para esta fila (si hay)
    if (maxPhotosPerRow > 0 && photosByRow != null) {
      final picsForRow = photosByRow[r];
      if (picsForRow != null && picsForRow.isNotEmpty) {
        // Ajustamos altura de la fila para que entren las miniaturas
        sheet.getRangeByIndex(excelRow, 1).rowHeight = 80;

        // Insertamos cada foto en su columna
        for (var p = 0; p < picsForRow.length && p < maxPhotosPerRow; p++) {
          final col = firstPhotoCol + p;
          final bytes = picsForRow[p];

          // Importante: JPG o PNG
          final picture = sheet.pictures.addStream(excelRow, col, bytes);
          picture.width = 100; // ancho aprox en px
          picture.height = 80; // alto aprox en px
        }
      }
    }
  }

  // 3) Autoajuste básico de columnas de texto
  for (var col = 1; col <= baseColumnsCount; col++) {
    sheet.autoFitColumn(col);
  }

  final bytes = workbook.saveAsStream();
  workbook.dispose();

  return Uint8List.fromList(bytes);
}
