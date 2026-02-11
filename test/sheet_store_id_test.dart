import 'dart:convert';

import 'package:bitacora_web/services/sheet_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SheetStore.init();
  });

  test('createNew generates unique ids during burst creation', () {
    final ids = List<String>.generate(120, (_) => SheetStore.createNew());
    final unique = ids.toSet();

    expect(unique.length, ids.length);

    final listedIds = SheetStore.list().map((s) => s.id).toSet();
    expect(listedIds.length, ids.length);
    expect(listedIds.containsAll(ids), isTrue);
  });

  test('createFromModel generates unique ids and keeps all sheets', () {
    final model = <String, dynamic>{
      'name': '',
      'savedAt': DateTime(2026, 2, 7).toIso8601String(),
      'headers': const ['A', 'B', 'Photos'],
      'colIds': const ['c_a', 'c_b', 'col_photos'],
      'rows': const <Map<String, dynamic>>[],
    };

    final ids = List<String>.generate(
      120,
      (_) => SheetStore.createFromModel(model),
    );
    final unique = ids.toSet();

    expect(unique.length, ids.length);

    final listedIds = SheetStore.list().map((s) => s.id).toSet();
    expect(listedIds.length, ids.length);
    expect(listedIds.containsAll(ids), isTrue);
  });

  test('normalizeModel preserves column configuration keys', () {
    final normalized = SheetStore.normalizeModel(<String, dynamic>{
      'name': 'Demo',
      'savedAt': DateTime(2026, 2, 11).toIso8601String(),
      'headers': const ['Actividad', 'Estado', 'Photos'],
      'colIds': const ['c_activity', 'c_status', 'col_photos'],
      'rows': const <Map<String, dynamic>>[],
      'columnPrefs': const <String, dynamic>{
        'c_activity': <String, dynamic>{'type': 'text', 'required': true},
        'c_status': <String, dynamic>{
          'type': 'status',
          'enumValues': <String>['OK', 'Obs']
        },
      },
      'columnOrder': const <String>['c_status', 'c_activity'],
      'frozenColId': 'c_status',
    });

    expect(normalized['columnPrefs'], isA<Map>());
    expect(normalized['columnOrder'], isA<List>());
    expect(normalized['frozenColId'], 'c_status');
  });

  test('list ignores backup metadata keys under bitflow:sheet prefix',
      () async {
    final now = DateTime(2026, 2, 11, 12, 0).toIso8601String();
    final model = jsonEncode(<String, dynamic>{
      'name': 'Demo',
      'savedAt': now,
      'headers': const ['A', 'Photos'],
      'colIds': const ['c_a', 'col_photos'],
      'rows': const <Map<String, dynamic>>[],
    });

    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow:sheet:demo_1': model,
      'bitflow:sheet:demo_1:backup': model,
      'bitflow:sheet:demo_1:bk:list': const <String>[
        'bitflow:sheet:demo_1:bk:1739275200000',
      ],
      'bitflow:sheet:demo_1:bk:1739275200000': model,
    });
    await SheetStore.init();

    final listedIds =
        SheetStore.list().map((s) => s.id).toList(growable: false);
    expect(listedIds, ['demo_1']);
  });
}
