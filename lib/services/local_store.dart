// lib/services/local_store.dart
// Persistencia liviana de la planilla actual (último estado abierto) usando
// SharedPreferences + utilidades de backup/restore en JSON.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/table_state.dart';
import 'save_file.dart';

class LocalStore {
  /// Clave nueva para guardar el último estado de la planilla (Bit Flow).
  static const String key = 'bitflow:current';

  /// Clave legacy usada en versiones anteriores (Gridnote).
  static const String _legacyKey = 'gridnote:current';

  /// Guarda el estado actual en SharedPreferences (JSON compacto).
  static Future<void> save(TableState s) async {
    final prefs = await SharedPreferences.getInstance();
    final json = s.toJsonString();
    await prefs.setString(key, json);
  }

  /// Carga el último estado guardado, o null si no hay nada válido.
  ///
  /// - Primero intenta con la clave nueva [key].
  /// - Si no hay nada, intenta migrar desde [_legacyKey] (Gridnote) y lo
  ///   guarda bajo la clave nueva para futuras lecturas.
  static Future<TableState?> load() async {
    final prefs = await SharedPreferences.getInstance();

    String? raw = prefs.getString(key);

    // Intento de migración transparente desde la clave legacy.
    if (raw == null || raw.isEmpty) {
      final legacyRaw = prefs.getString(_legacyKey);
      if (legacyRaw != null && legacyRaw.isNotEmpty) {
        final legacyState = TableState.fromJsonString(legacyRaw);
        if (legacyState != null) {
          // Migramos y limpiamos la clave vieja.
          await prefs.setString(key, legacyState.toJsonString());
          await prefs.remove(_legacyKey);
          return legacyState;
        } else {
          await prefs.remove(_legacyKey);
        }
      }
      return null;
    }

    final state = TableState.fromJsonString(raw);
    if (state == null) {
      // JSON corrupto o viejo: limpiamos la clave para evitar ruido futuro.
      await prefs.remove(key);
      return null;
    }
    return state;
  }

  /// Borra el último estado guardado (útil para "Reset" de la app).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove(_legacyKey);
  }

  /// Descarga un backup JSON con el contenido de la planilla.
  ///
  /// - Usa `trim()` y `pruneTrailingEmptyColumns()` para que el backup
  ///   quede prolijo y sin columnas basura al final.
  /// - Genera un nombre de archivo legible y único.
  static Future<void> downloadBackup(TableState s) async {
    final cleaned =
    s.trim(headersToo: true, cells: true).pruneTrailingEmptyColumns();

    final now = DateTime.now();
    String t(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${t(now.month)}${t(now.day)}_${t(now.hour)}${t(now.minute)}${t(now.second)}';

    // Nombre alineado a la marca Bit Flow / Bitácora Web.
    final name = 'bitflow_backup_$stamp.json';

    // Para backup es más amigable usar JSON identado.
    final bytes = utf8.encode(cleaned.toJsonString(pretty: true));
    await saveBytes(name, bytes);
  }

  /// Importa un backup JSON.
  ///
  /// - En Web: abre un selector de archivo y parsea el contenido.
  /// - En mobile/desktop: por ahora abre un mail con instrucciones.
  static Future<TableState?> importBackup() async {
    if (kIsWeb) {
      final raw = await pickTextFileWeb();
      if (raw == null || raw.isEmpty) return null;
      return TableState.fromJsonString(raw);
    } else {
      // Fallback simple para mobile/desktop hasta que haya un picker nativo.
      final uri = Uri(
        scheme: 'mailto',
        queryParameters: {
          'subject': 'Importar backup Bit Flow - Instrucciones',
          'body':
          'En esta versión, importar backup está disponible en Web.\n\n'
              'En móvil/desktop usá "Backup" para exportar el archivo JSON y reenviarlo a tu PC o navegador, '
              'donde podés abrir Bit Flow Web e importarlo desde ahí.',
        },
      );
      try {
        await launchUrl(uri);
      } catch (_) {
        // Si no hay cliente de correo, simplemente devolvemos null.
      }
      return null;
    }
  }
}
