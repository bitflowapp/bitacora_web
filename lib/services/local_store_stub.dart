import "dart:convert";
import "package:shared_preferences/shared_preferences.dart";
import "../models/table_state.dart";

class LocalStore {
  static const _key = "bitacora_state_v1";

  static Future<void> save(TableState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  static Future<TableState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return TableState.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> downloadBackup(TableState state,
      {String filename = "bitacora_backup.json"}) async {}
  static Future<TableState?> importBackup() async => null;
}
