import 'dart:convert';
import 'package:bitacora_web/web/html_compat.dart' as html;import '../models/table_state.dart';

class LocalStore {
  /// Clave nueva para Bit Flow.
  static const String _key = 'bitflow_state_v1';

  /// Clave legacy usada en versiones anteriores (Bitácora Web vieja).
  static const String _legacyKey = 'bitacora_state_v1';

  /// Guarda el estado actual en localStorage (JSON compacto).
  static Future<void> save(TableState state) async {
    try {
      final json = jsonEncode(state.toJson());
      html.window.localStorage[_key] = json;
    } catch (_) {
      // Si algo falla (JSON gigante, etc.), no tiramos la app.
    }
  }

  /// Carga el último estado guardado, o null si no hay nada válido.
  ///
  /// - Primero intenta con la clave nueva [_key].
  /// - Si no hay nada, intenta migrar desde [_legacyKey] y lo re-guarda
  ///   bajo la clave nueva.
  static Future<TableState?> load() async {
    String? raw = html.window.localStorage[_key];

    // Intento de migración transparente desde la key vieja.
    if (raw == null) {
      final legacyRaw = html.window.localStorage[_legacyKey];
      if (legacyRaw != null) {
        final legacyState = _decodeState(legacyRaw);
        if (legacyState != null) {
          // Migramos y guardamos bajo la clave nueva.
          await save(legacyState);
          html.window.localStorage.remove(_legacyKey);
          return legacyState;
        } else {
          // JSON viejo/corrupto: limpiamos la legacy.
          html.window.localStorage.remove(_legacyKey);
        }
      }
      return null;
    }

    final state = _decodeState(raw);
    if (state == null) {
      // JSON corrupto: limpiamos para no seguir arrastrando basura.
      html.window.localStorage.remove(_key);
      return null;
    }
    return state;
  }

  /// Intenta decodificar un [TableState] desde un string JSON.
  static TableState? _decodeState(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return TableState.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Borra cualquier estado persistido (nuevo + legacy).
  static Future<void> clear() async {
    html.window.localStorage.remove(_key);
    html.window.localStorage.remove(_legacyKey);
  }

  /// Descarga un backup JSON con el contenido de la planilla.
  ///
  /// - Aplica `trim()` y `pruneTrailingEmptyColumns()` para limpiar.
  /// - Genera un nombre con timestamp si no se pasa [filename].
  static Future<void> downloadBackup(
    TableState state, {
    String? filename,
  }) async {
    // Limpieza para que el backup no tenga columnas basura al final.
    final cleaned =
        state.trim(headersToo: true, cells: true).pruneTrailingEmptyColumns();

    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';

    final baseName = (filename?.trim().isNotEmpty == true
            ? filename!.trim()
            : 'bitflow_backup_$stamp.json')
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');

    final data = utf8.encode(jsonEncode(cleaned.toJson()));
    final blob = html.Blob(<Object>[data], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final a = html.AnchorElement(href: url)
      ..download = baseName
      ..style.display = 'none';

    html.document.body?.append(a);
    a.click();
    a.remove();
    html.Url.revokeObjectUrl(url);
  }

  /// Importa un backup JSON desde un archivo elegido por el usuario.
  ///
  /// Devuelve un [TableState] válido o null si algo sale mal.
  static Future<TableState?> importBackup() async {
    final input = html.FileUploadInputElement()
      ..accept = '.json,application/json';

    input.click();

    try {
      await input.onChange.first;
      final file = input.files?.first;
      if (file == null) return null;

      final reader = html.FileReader()..readAsText(file);
      await reader.onLoad.first;

      final result = reader.result;
      if (result is! String) return null;

      final map = jsonDecode(result) as Map<String, dynamic>;
      return TableState.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}
