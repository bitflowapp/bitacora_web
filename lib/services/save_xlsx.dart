// Guarda un .xlsx de forma real con auto-descarga en Web
// y archivo en móvil/escritorio.
// Devuelve la ruta cuando la plataforma la expone, o null en Web.

import 'dart:typed_data';

import 'xlsx_saver_io.dart'
if (dart.library.html) 'xlsx_saver_web.dart' as platform_saver;

Future<String?> saveXlsx(String baseName, Uint8List bytes) {
  return platform_saver.saveXlsx(baseName, bytes);
}
