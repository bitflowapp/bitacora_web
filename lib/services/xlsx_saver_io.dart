// lib/services/xlsx_saver_io.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const int _maxXlsxBaseNameLength = 120;

/// IO (Android, iOS, desktop): guarda el XLSX en disco y devuelve la ruta.
///
/// Android / iOS:
///   - Usa getApplicationDocumentsDirectory() (carpeta de documentos de la app).
///
/// Windows / Linux / macOS:
///   - Intenta usar la carpeta de Descargas del usuario.
///   - Si no está disponible, cae a getApplicationDocumentsDirectory().
Future<String?> saveXlsx(String baseName, Uint8List bytes) async {
  final safe = _sanitize(baseName);
  final fileName = '$safe.xlsx';

  final dir = await _resolveBaseDir();

  // Aseguramos que el directorio exista.
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final file = File(p.join(dir.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<Directory> _resolveBaseDir() async {
  if (Platform.isAndroid || Platform.isIOS) {
    // Documentos de la app (accesible para compartir / adjuntar).
    return getApplicationDocumentsDirectory();
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Preferimos Descargas para que el usuario lo encuentre fácil.
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return downloads;
    }
    return getApplicationDocumentsDirectory();
  }

  // Fallback genérico.
  return getApplicationDocumentsDirectory();
}

String _sanitize(String s) {
  // Quitá una extensión .xlsx final si viene incluida.
  var t = s.trim().replaceAll(RegExp(r'\.xlsx$', caseSensitive: false), '');

  // Reemplazamos caracteres problemáticos en Windows/macOS/Linux.
  // Ej: \ / : * ? " < > |  ->  _
  t = t.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  // Evitamos nombre vacío.
  if (t.isEmpty) return 'gridnote_export';

  if (t.length > _maxXlsxBaseNameLength) {
    t = t
        .substring(0, _maxXlsxBaseNameLength)
        .replaceFirst(RegExp(r'[_\s.-]+$'), '');
  }

  return t;
}
