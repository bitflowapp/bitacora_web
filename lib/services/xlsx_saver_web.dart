import 'dart:typed_data';
import 'dart:html' as html;

/// Web: descarga directa de XLSX.
/// Devuelve el nombre lógico del archivo (para mostrar en la UI).
Future<String?> saveXlsx(String baseName, Uint8List bytes) async {
  final safe = _sanitize(baseName);
  final fileName = '$safe.xlsx';

  final blob = html.Blob(
    [bytes],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  // Algunos navegadores requieren que el <a> esté en el DOM para disparar la descarga.
  final body = html.document.body;
  if (body != null) {
    body.append(anchor);
    anchor.click();
    anchor.remove();
  } else {
    anchor.click();
  }

  html.Url.revokeObjectUrl(url);

  // En Web devolvemos sólo el nombre lógico.
  return fileName;
}

String _sanitize(String s) {
  // Quitamos extensión .xlsx si viene incluida.
  var t = s.trim().replaceAll(
        RegExp(r'\.xlsx$', caseSensitive: false),
        '',
      );

  // Reemplazamos caracteres conflictivos y espacios por guiones bajos.
  t = t.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  t = t.replaceAll(RegExp(r'\s+'), '_');

  // Nombre por defecto si queda vacío.
  if (t.isEmpty) {
    return 'gridnote_export';
  }

  // Limite de longitud razonable para el nombre.
  if (t.length > 80) {
    t = t.substring(0, 80);
  }

  return t;
}
