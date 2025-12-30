// lib/services/attachments_export_helper.dart
// Carga fotos (image/*) desde AttachmentsServiceWeb, agrupadas por fila,
// limitado a maxPerRow para exportar a Excel.

import 'dart:typed_data';
import '../services/attachments_service_web.dart';

class AttachmentsExportHelper {
  AttachmentsExportHelper._();

  static Future<Map<int, List<Uint8List>>> loadPhotosByRow({
    required String sheetId,
    required int rowCount,
    int maxPerRow = 3,
  }) async {
    final Map<int, List<Uint8List>> out = {};
    for (var r = 0; r < rowCount; r++) {
      final items = await AttachmentsServiceWeb.I.listFor(sheetId: sheetId, row: r);
      if (items.isEmpty) continue;

      final photos = <Uint8List>[];
      for (final it in items) {
        if (it.mime.startsWith('image/')) {
          photos.add(it.bytes);
          if (photos.length >= maxPerRow) break;
        }
      }
      if (photos.isNotEmpty) {
        out[r] = photos;
      }
    }
    return out;
  }
}
