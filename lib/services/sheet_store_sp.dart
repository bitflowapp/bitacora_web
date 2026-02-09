import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/table_state.dart';

class SheetMeta {
  final String id;
  final DateTime updatedAt;
  final String title;
  final int rows;
  const SheetMeta(
      {required this.id,
      required this.updatedAt,
      required this.title,
      required this.rows});
}

class SheetStore {
  static const _indexKey = 'sheets:index:sp'; // {"ids":[...]}
  static Future<String?> loadRaw(String id) async {
    final p = await SharedPreferences.getInstance();
    return p.getString('sheet:$id');
  }

  static Future<void> saveState(String id, TableState state) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('sheet:$id', state.toJsonString());
    final ids = await _getIndex();
    if (!ids.contains(id)) {
      ids.insert(0, id);
      await _saveIndex(ids);
    }
  }

  static Future<void> rename(String id, String newTitle) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('sheet:$id:title', newTitle.trim());
  }

  static Future<String?> _readTitle(String id) async {
    final p = await SharedPreferences.getInstance();
    return p.getString('sheet:$id:title');
  }

  static Future<String> createNew() async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final s = TableState.empty();
    final p = await SharedPreferences.getInstance();
    await p.setString('sheet:$id', s.toJsonString());
    final ids = await _getIndex()
      ..insert(0, id);
    await _saveIndex(ids);
    return id;
  }

  static Future<String> ensureDefault() async {
    final ids = await _getIndex();
    if (ids.isEmpty) return createNew();
    return ids.first;
  }

  static Future<void> delete(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.remove('sheet:$id');
    await p.remove('sheet:$id:title');
    final ids = await _getIndex()
      ..remove(id);
    await _saveIndex(ids);
  }

  static Future<List<SheetMeta>> list() async {
    final ids = await _getIndex();
    final out = <SheetMeta>[];
    final p = await SharedPreferences.getInstance();
    for (final id in ids) {
      final raw = p.getString('sheet:$id');
      if (raw == null) continue;
      try {
        final ts = TableState.fromJsonString(raw);
        if (ts == null) continue;
        final custom = await _readTitle(id);
        final derived =
            ts.headers.firstWhere((h) => h.trim().isNotEmpty, orElse: () => '');
        final title = (custom != null && custom.trim().isNotEmpty)
            ? custom.trim()
            : derived;
        out.add(SheetMeta(
            id: id, updatedAt: ts.savedAt, title: title, rows: ts.rows.length));
      } catch (_) {
        out.add(SheetMeta(
            id: id,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            title: '',
            rows: 0));
      }
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  static Future<List<String>> _getIndex() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_indexKey);
    if (raw == null) return <String>[];
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (map['ids'] as List).cast<String>();
    } catch (_) {
      return <String>[];
    }
  }

  static Future<void> _saveIndex(List<String> ids) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_indexKey, jsonEncode({'ids': ids}));
  }
}
