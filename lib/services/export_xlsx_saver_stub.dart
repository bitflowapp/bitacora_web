import 'dart:typed_data';

/// Stub para plataformas no web.
///
/// En desktop/mobile este saver no implementa descarga nativa.
/// Lanzamos error explícito para evitar falsos éxitos en la UI.
Future<void> saveXlsxBytes(Uint8List bytes, String fileName) async {
  throw UnsupportedError(
    'xlsx_save_unsupported_platform: only_web_saver_available',
  );
}
