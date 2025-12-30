import 'dart:typed_data';

/// Stub para plataformas no Web.
///
/// En este proyecto, la exportación XLSX "real" se hace sólo en Web
/// usando `export_xlsx_saver_web.dart`. En mobile/desktop este stub
/// permite que el import condicional compile sin acceder a `dart:html`.
Future<void> saveXlsxBytes(Uint8List bytes, String fileName) async {
  // No hace nada en plataformas no Web.
  // Si necesitás comportamiento en Android/iOS/desktop,
  // implementalo en otro servicio específico.
}