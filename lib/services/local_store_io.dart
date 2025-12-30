import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/table_state.dart';

const _kStorageKey = 'bitacora_state_v1';

class LocalStore {
  static Future<void> save(TableState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStorageKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  // Nota: lectura síncrona no disponible en IO.
  static TableState? load() {
    return null;
  }

  static void clear() {
    SharedPreferences.getInstance().then((p) {
      p.remove(_kStorageKey);
    });
  }

  static void downloadBackup(TableState state,
      {String filename = 'bitacora_backup.json'}) {}
  static Future<TableState?> importBackup() async {
    return null;
  }
}
