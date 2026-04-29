import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile row controllers are materialized lazily', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(430, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rows = List<List<String>>.generate(
      140,
      (i) => <String>['row-$i', ''],
      growable: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(
          sheetId: 'mobile-lazy-controllers',
          initialHeaders: const <String>['Notas', 'Fotos'],
          initialRows: rows,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    final totalSlots = state.debugMobileRowCacheSlots as int;
    final materialized = state.debugMobileMaterializedRowControllers as int;

    expect(totalSlots, rows.length);
    expect(materialized, greaterThan(0));
    expect(materialized, lessThan(totalSlots));

    final before = state.debugMobileMaterializedRowControllers as int;
    state.debugMaterializeMobileRowController(rows.length - 1);
    await tester.pump();
    final after = state.debugMobileMaterializedRowControllers as int;
    expect(after, before + 1);
  });
}
