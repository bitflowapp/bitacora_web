import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('smart paste detects table + header hint', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'smart-paste-detect',
          initialHeaders: <String>['Notas', 'Estado', 'Photos'],
          initialRows: <List<String>>[
            <String>['', '', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    final info = state.debugSmartPasteDetection('Nombre\tEstado\nAna\tOK')
        as Map<String, Object>;

    expect(info['rows'], 2);
    expect(info['cols'], 2);
    expect(info['isTable'], isTrue);
    expect(info['headerHint'], isTrue);
  });

  testWidgets('smart paste can insert rows and map first row as headers',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'smart-paste-insert',
          initialHeaders: <String>['Notas', 'Estado', 'Photos'],
          initialRows: <List<String>>[
            <String>['legacy-1', 'old', ''],
            <String>['legacy-2', 'old', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    final changed = await state.debugApplySmartPaste(
      'Nombre\tEstado\nAna\tOK\nLuis\tObs',
      insertRows: true,
      useHeaderRow: true,
    );
    await tester.pumpAndSettle();

    expect(changed, greaterThan(0));
    expect(state.debugHeaderText(0), 'Nombre');
    expect(state.debugHeaderText(1), 'Estado');
    expect(state.debugCellText(0, 0), 'Ana');
    expect(state.debugCellText(1, 1), 'Obs');
    expect(state.debugCellText(2, 0), 'legacy-1');
  });
}
