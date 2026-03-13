import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<dynamic> pumpEditor(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'add-content-insert-test',
          initialHeaders: <String>['A', 'B', 'Fotos'],
          initialRows: <List<String>>[
            <String>['r1a', 'r1b', ''],
            <String>['r2a', 'r2b', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state(find.byType(EditorScreen)) as dynamic;
  }

  testWidgets('insert row preserves existing rows order', (tester) async {
    final state = await pumpEditor(tester);

    expect(state.debugRowCount, 2);
    expect(state.debugCellText(1, 0), 'r2a');

    state.debugInsertRowAt(1);
    await tester.pumpAndSettle();

    expect(state.debugRowCount, 3);
    expect(state.debugCellText(2, 0), 'r2a');
    expect(state.debugCellText(2, 1), 'r2b');
  });

  testWidgets('insert column keeps existing data and last header invariant',
      (tester) async {
    final state = await pumpEditor(tester);

    final beforeColumns = state.debugColumnCount as int;
    final lastHeaderBefore = state.debugHeaderText(beforeColumns - 1) as String;
    expect(beforeColumns, greaterThanOrEqualTo(3));
    expect(state.debugCellText(0, 1), 'r1b');

    state.debugInsertColumnAt(1);
    await tester.pumpAndSettle();

    final afterColumns = state.debugColumnCount as int;
    expect(afterColumns, beforeColumns + 1);
    expect(state.debugCellText(0, 2), 'r1b');
    expect(state.debugCellText(1, 2), 'r2b');
    expect(state.debugHeaderText(afterColumns - 1), lastHeaderBefore);
  });

  testWidgets('insert actions do not break mobile layout', (tester) async {
    final state = await pumpEditor(tester);

    state.debugInsertRowAt(0);
    state.debugInsertColumnAt(1);
    await tester.pumpAndSettle();

    expect(find.byType(EditorScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
