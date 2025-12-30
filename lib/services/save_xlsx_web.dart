// lib/services/save_xlsx_web.dart
import 'dart:typed_data';
import 'dart:html' as html;

/// Web: descarga directa de XLSX.
/// Devuelve siempre null porque en Web no hay ruta local.
Future<String?> saveXlsx(String baseName, Uint8List bytes) async {
  final safeBase = _sanitizeBase(baseName);
  final fileName =
  safeBase.toLowerCase().endsWith('.xlsx') ? safeBase : '$safeBase.xlsx';

  final blob = html.Blob(
    [bytes],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );

  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);

  // Compatibilidad: en Web no devolvemos ruta.
  return null;
}

String _sanitizeBase(String s) {
  var t = s.trim();
  if (t.isEmpty) t = 'bitflow_export';

  if (t.toLowerCase().endsWith('.xlsx')) {
    t = t.substring(0, t.length - 5);
  }

  // Limpiamos caracteres problemáticos para nombre de archivo.
  t = t.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  return t;
}
