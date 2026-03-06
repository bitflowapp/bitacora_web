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
      'headers': const ['A', 'B', 'Fotos'],
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
      'headers': const ['Actividad', 'Estado', 'Fotos'],
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
      'headers': const ['A', 'Fotos'],
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

  test('duplicate creates a copy preserving data and formulas', () {
    final sourceId = SheetStore.createFromModel(<String, dynamic>{
      'name': 'Budget Marzo',
      'savedAt': DateTime(2026, 3, 5, 9, 0).toIso8601String(),
      'headers': const <String>['Concepto', 'Monto', 'Total', 'Fotos'],
      'rows': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'r1',
          'cells': const <String>['Combustible', '1200', '=SUM(B1:B1)', ''],
        },
      ],
    });

    final copyId = SheetStore.duplicate(sourceId);

    expect(copyId, isNot(equals(sourceId)));

    final all = SheetStore.list();
    expect(all.length, 2);
    expect(all.any((meta) => meta.id == copyId), isTrue);
    expect(
      all.any(
        (meta) =>
            meta.id == copyId && meta.title.toLowerCase().contains('copia de'),
      ),
      isTrue,
    );

    final raw = SheetStore.loadRaw(copyId);
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!) as Map<String, dynamic>;
    final rows = decoded['rows'] as List<dynamic>;
    final firstRow = rows.first as Map<String, dynamic>;
    final cells = firstRow['cells'] as List<dynamic>;
    expect(cells[2], '=SUM(B1:B1)');
  });
}
