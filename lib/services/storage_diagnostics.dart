import 'package:hive_flutter/hive_flutter.dart';

class StorageCheckResult {
  const StorageCheckResult({
    required this.ok,
    required this.message,
    this.code = 'ok',
  });

  final bool ok;
  final String message;
  final String code;
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
        code: ok ? 'ok' : 'storage_probe_failed',
        message: ok
            ? 'OK'
            : 'No pudimos confirmar guardado local persistente. Exportá ZIP para evitar pérdida de datos.',
      );
    } catch (e) {
      final classified = _classifyStorageError(e);
      return StorageCheckResult(
        ok: false,
        code: classified.code,
        message: classified.message,
      );
    }
  }

  static StorageCheckResult classifyErrorForTest(Object error) {
    final classified = _classifyStorageError(error);
    return StorageCheckResult(
      ok: false,
      code: classified.code,
      message: classified.message,
    );
  }

  static ({String code, String message}) _classifyStorageError(Object error) {
    final lower = error.toString().toLowerCase();
    if (lower.contains('quota') || lower.contains('quotaexceeded')) {
      return (
        code: 'quota_exceeded',
        message:
            'Espacio local del navegador agotado. Exportá ZIP y liberá almacenamiento del sitio antes de seguir.',
      );
    }
    if (lower.contains('indexeddb') ||
        lower.contains('private') ||
        lower.contains('incognito') ||
        lower.contains('blocked')) {
      return (
        code: 'storage_session_only',
        message:
            'El navegador está en modo temporal/incógnito y puede no guardar adjuntos de forma permanente. Exportá ZIP antes de cerrar.',
      );
    }
    return (
      code: 'storage_blocked',
      message:
          'El navegador bloqueó el guardado local persistente. Probá habilitar almacenamiento del sitio o exportar ZIP.',
    );
  }
}
