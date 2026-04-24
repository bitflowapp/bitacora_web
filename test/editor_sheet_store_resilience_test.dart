import 'dart:convert';

import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/services/sheet_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Test-only access to the platform interface lets us simulate storage failure.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('editor can load SheetStore model when SharedPreferences fails',
      (tester) async {
    const sheetId = 'sheet-store-without-prefs';
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = _ThrowingPrefsStore();

    await SheetStore.init();
    SheetStore.saveModel(sheetId, _richModel(sheetId));
    await SheetStore.flushPendingWrites();

    await _pumpEditor(tester, sheetId);

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    expect(state.debugCellText(0, 0), 'Bomba P-101');
    expect(state.debugCellMetaAt(0, 0)?.hasGps, isTrue);
  });

  testWidgets('editor loads full SheetStore model with cell metadata',
      (tester) async {
    const sheetId = 'sheet-store-full-model';
    await SheetStore.init();
    SheetStore.saveModel(sheetId, _richModel(sheetId));
    await SheetStore.flushPendingWrites();

    await _pumpEditor(tester, sheetId);

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    expect(state.debugCellText(0, 0), 'Bomba P-101');
    expect(state.debugCellMetaAt(0, 0)?.hasGps, isTrue);

    await state.debugSaveNow();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('bitflow:sheet:$sheetId');
    expect(raw, isNotNull);

    final saved = jsonDecode(raw!) as Map<String, dynamic>;
    expect(saved['cellMeta'], isA<Map>());
    expect(saved['columnPrefs'], isA<Map>());
    expect(
      ((saved['columnPrefs'] as Map)['col_equipo'] as Map)['enumValues'],
      contains('Obs'),
    );
  });
}

Future<void> _pumpEditor(WidgetTester tester, String sheetId) async {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: EditorScreen(sheetId: sheetId),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Map<String, dynamic> _richModel(String sheetId) {
  return <String, dynamic>{
    'name': 'Relevamiento con metadata',
    'savedAt': DateTime(2026, 4, 24, 10).toIso8601String(),
    'headers': <String>['Equipo', 'Photos'],
    'colIds': <String>['col_equipo', 'col_photos'],
    'columnPrefs': <String, dynamic>{
      'col_equipo': <String, dynamic>{
        'type': 'status',
        'enumValues': <String>['OK', 'Obs', 'Urgente'],
      },
    },
    'rows': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'row_1',
        'cells': <String>['Bomba P-101', ''],
      },
    ],
    'cellMeta': <String, dynamic>{
      '$sheetId|row_1|col_equipo': <String, dynamic>{
        'gps': <String, dynamic>{
          'lat': -38.9516,
          'lng': -68.0591,
          'acc': 4.5,
          'ts': DateTime(2026, 4, 24, 10, 15).toIso8601String(),
          'source': 'test',
          'provider': 'gps',
        },
      },
    },
  };
}

class _ThrowingPrefsStore extends SharedPreferencesStorePlatform {
  Never _fail() => throw StateError('shared_preferences_unavailable');

  @override
  Future<bool> clear() async => _fail();

  @override
  Future<Map<String, Object>> getAll() async => _fail();

  @override
  Future<bool> remove(String key) async => _fail();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      _fail();
}
