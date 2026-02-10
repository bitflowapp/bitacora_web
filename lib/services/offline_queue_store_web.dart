// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: uri_does_not_exist
import 'dart:indexed_db' as idb;

class OfflineQueueStore {
  static const String _dbName = 'bitflow_offline_queue_v1';
  static const String _storeName = 'sheet_queues';

  const OfflineQueueStore();

  static idb.Database? _db;
  static final Map<String, String> _memoryFallback = <String, String>{};

  bool get isPersistent => true;

  Future<String?> read(String sheetId) async {
    final key = _safeId(sheetId);
    final db = await _ensureDb();
    if (db == null) return _memoryFallback[key];
    try {
      final tx = db.transaction(_storeName, 'readonly');
      final store = tx.objectStore(_storeName);
      final record = await store.getObject(key) as Map?;
      await tx.completed;
      final payload = (record?['payload'] ?? '').toString().trim();
      if (payload.isEmpty) return null;
      return payload;
    } catch (_) {
      return _memoryFallback[key];
    }
  }

  Future<void> write({
    required String sheetId,
    required String payload,
  }) async {
    final key = _safeId(sheetId);
    final trimmed = payload.trim();
    if (trimmed.isEmpty) {
      await delete(sheetId);
      return;
    }
    final db = await _ensureDb();
    if (db == null) {
      _memoryFallback[key] = trimmed;
      return;
    }
    try {
      final tx = db.transaction(_storeName, 'readwrite');
      final store = tx.objectStore(_storeName);
      await store.put(<String, dynamic>{
        'payload': trimmed,
        'updatedAt': DateTime.now().toIso8601String(),
      }, key);
      await tx.completed;
      _memoryFallback.remove(key);
    } catch (_) {
      _memoryFallback[key] = trimmed;
    }
  }

  Future<void> delete(String sheetId) async {
    final key = _safeId(sheetId);
    _memoryFallback.remove(key);
    final db = await _ensureDb();
    if (db == null) return;
    try {
      final tx = db.transaction(_storeName, 'readwrite');
      final store = tx.objectStore(_storeName);
      await store.delete(key);
      await tx.completed;
    } catch (_) {}
  }

  Future<idb.Database?> _ensureDb() async {
    final existing = _db;
    if (existing != null) return existing;
    final indexedDb = html.window.indexedDB;
    if (indexedDb == null) return null;
    try {
      _db = await indexedDb.open(
        _dbName,
        version: 1,
        onUpgradeNeeded: (event) {
          final db = (event.target as idb.Request).result as idb.Database;
          if (!db.objectStoreNames!.contains(_storeName)) {
            db.createObjectStore(_storeName);
          }
        },
      );
    } catch (_) {
      _db = null;
    }
    return _db;
  }

  String _safeId(String raw) {
    final trimmed = raw.trim().isEmpty ? 'sheet' : raw.trim();
    return trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }
}
