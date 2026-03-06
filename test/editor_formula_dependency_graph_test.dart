import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/services/formula_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('formula dependency chain recalculates after source edit',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1700, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'formula-graph-test',
          initialHeaders: <String>['A', 'B', 'C', 'Fotos'],
          initialRows: <List<String>>[
            <String>['1', '=SUM(A1:A2)', '=B1*2', ''],
            <String>['2', '', '', ''],
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    final dynamic state = tester.state(find.byType(EditorScreen));
    expect(state.debugDisplayedCellText(0, 1), '3');
    expect(state.debugDisplayedCellText(0, 2), '6');

    state.debugSetCellValue(0, 0, '10');
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.debugDisplayedCellText(0, 1), '12');
    expect(state.debugDisplayedCellText(0, 2), '24');
  });

  testWidgets('formula dependency graph reports circular references',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1700, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'formula-cycle-test',
          initialHeaders: <String>['A', 'B', 'Fotos'],
          initialRows: <List<String>>[
            <String>['=B1', '=A1', ''],
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    final dynamic state = tester.state(find.byType(EditorScreen));
    expect(state.debugDisplayedCellText(0, 0), FormulaErrors.cycle);
    expect(state.debugDisplayedCellText(0, 1), FormulaErrors.cycle);
  });
}
