import 'package:hive_flutter/hive_flutter.dart';

class StorageCheckResult {
  const StorageCheckResult({
    required this.ok,
    required this.message,
  });

  final bool ok;
  final String message;
}

class StorageDiagnostics {
  static const String _boxName = 'diagnostics_probe_v1';

  static Future<StorageCheckResult> check() async {
    try {
      await Hive.initFlutter();
      final box = Hive.isBoxOpen(_boxName)
          ? Hive.box<dynamic>(_boxName)
          : await Hive.openBox<dynamic>(_boxName);

      const key = 'probe';
      await box.put(key, 'ok');
      final ok = box.get(key) == 'ok';
      await box.delete(key);
      await box.close();

      return StorageCheckResult(
        ok: ok,
        message: ok ? 'OK' : 'No se pudo escribir en storage.',
      );
    } catch (e) {
      return StorageCheckResult(
        ok: false,
        message: e.toString(),
      );
    }
  }
}
