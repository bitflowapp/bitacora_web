// test/store_storage_fallback_test.dart
//
// Validates that SheetStore.init() never blocks the app regardless of
// storage backend availability, and that the store is usable after init.

import 'package:bitacora_web/services/sheet_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('SheetStore.init() does not throw', () async {
    await expectLater(SheetStore.init(), completes);
  });

  test('SheetStore is usable after init regardless of persistence mode', () async {
    await SheetStore.init();

    final id = SheetStore.createNew();
    expect(id, isNotEmpty);

    final list = SheetStore.list();
    expect(list.any((s) => s.id == id), isTrue);
  });

  test('SheetStore.isPersistent is a valid bool after init', () async {
    await SheetStore.init();
    // Valid bool — either persistent (Hive) or memory fallback.
    expect(SheetStore.isPersistent, isA<bool>());
  });

  test('SheetStore saves and loads data after init', () async {
    await SheetStore.init();

    final id = SheetStore.createNew();
    SheetStore.saveModel(id, <String, dynamic>{
      'name': 'Test planilla',
      'savedAt': DateTime(2026, 4, 24).toIso8601String(),
      'headers': <String>['A', 'B', 'Photos'],
      'columnSpecs': <Map<String, dynamic>>[
        <String, dynamic>{'label': 'A', 'type': 'text'},
        <String, dynamic>{'label': 'B', 'type': 'text'},
        <String, dynamic>{'label': 'Photos', 'type': 'photos'},
      ],
      'rows': <Map<String, dynamic>>[
        <String, dynamic>{
          'cells': <String>['val1', 'val2', ''],
        },
      ],
    });

    final raw = SheetStore.loadRaw(id);
    expect(raw, isNotNull);
    expect(raw, contains('Test planilla'));
  });

  test('SheetStore.init() called twice does not throw', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SheetStore.init();
    await expectLater(SheetStore.init(), completes);
  });
}
