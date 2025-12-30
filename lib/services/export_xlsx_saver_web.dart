// lib/services/export_xlsx_saver_web.dart
// Web: descarga directa de XLSX usando bytes.
// Se usa mediante import condicional desde ExportXlsxService.

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:typed_data';
import 'dart:html' as html;

Future<void> saveXlsxBytes(Uint8List bytes, String fileName) async {
  // Asegura extensión .xlsx
  if (!fileName.toLowerCase().endsWith('.xlsx')) {
    fileName = '$fileName.xlsx';
  }

  final blob = html.Blob(
    [bytes],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);

  final a = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.append(a);
  a.click();
  a.remove();
  html.Url.revokeObjectUrl(url);
}
