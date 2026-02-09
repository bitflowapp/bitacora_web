import 'package:bitacora_web/core/app_error.dart';
import 'package:bitacora_web/services/app_error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists ring buffer and keeps latest entries', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const storageKey = 'test.app_error_reporter.v1';
    final storage = const SharedPrefsAppErrorReporterStorage(
      storageKey: storageKey,
    );

    final reporter = AppErrorReporter(storage: storage, capacity: 3);
    await reporter.init();

    for (var i = 0; i < 5; i++) {
      reporter.record(
        AppError(
          flow: AppErrorFlow.save,
          kind: AppErrorKind.storage,
          userMessage: 'u$i',
          technicalMessage: 't$i',
        ),
        operation: 'op_$i',
      );
    }
    await reporter.flush();

    final restored = AppErrorReporter(storage: storage, capacity: 3);
    await restored.init();
    final messages =
        restored.recent(limit: 10).map((event) => event.userMessage).toList();

    expect(messages, <String>['u4', 'u3', 'u2']);
  });

  test('uses memory fallback when local storage is unavailable', () async {
    final reporter = AppErrorReporter(storage: _ThrowingStorage(), capacity: 2);
    await reporter.init();

    expect(reporter.isUsingMemoryFallback, isTrue);

    for (var i = 0; i < 3; i++) {
      reporter.record(
        AppError(
          flow: AppErrorFlow.load,
          kind: AppErrorKind.unavailable,
          userMessage: 'fallback_$i',
          technicalMessage: 'detail_$i',
        ),
        operation: 'fallback_op_$i',
      );
    }
    await reporter.flush();

    final messages =
        reporter.recent(limit: 10).map((event) => event.userMessage).toList();
    expect(messages, <String>['fallback_2', 'fallback_1']);
  });
}

class _ThrowingStorage implements AppErrorReporterStorage {
  @override
  Future<List<AppErrorEvent>> load() async {
    throw Exception('storage_unavailable');
  }

  @override
  Future<void> save(List<AppErrorEvent> events) async {
    throw Exception('storage_unavailable');
  }
}
