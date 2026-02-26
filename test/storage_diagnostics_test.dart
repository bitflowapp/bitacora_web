import 'package:bitacora_web/services/storage_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StorageDiagnostics classifyErrorForTest', () {
    test('classifies quota exceeded', () {
      final result = StorageDiagnostics.classifyErrorForTest(
        Exception('QuotaExceededError: indexeddb quota reached'),
      );

      expect(result.ok, isFalse);
      expect(result.code, 'quota_exceeded');
      expect(result.message.toLowerCase(), contains('espacio local'));
    });

    test('classifies session-only/private mode', () {
      final result = StorageDiagnostics.classifyErrorForTest(
        Exception('IndexedDB blocked in private / incognito mode'),
      );

      expect(result.ok, isFalse);
      expect(result.code, 'storage_session_only');
      expect(result.message.toLowerCase(), contains('incógnito'));
    });

    test('classification is case-insensitive', () {
      final result = StorageDiagnostics.classifyErrorForTest(
        Exception('QUOTAEXCEEDED while writing blob'),
      );

      expect(result.ok, isFalse);
      expect(result.code, 'quota_exceeded');
    });

    test('classifies storage blocked fallback', () {
      final result = StorageDiagnostics.classifyErrorForTest(
        StateError('browser denied local storage persistence'),
      );

      expect(result.ok, isFalse);
      expect(result.code, 'storage_blocked');
      expect(result.message.toLowerCase(), contains('guardado local'));
    });
  });
}
