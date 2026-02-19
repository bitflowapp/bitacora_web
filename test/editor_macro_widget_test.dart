import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('save and run macro offline applies grid changes',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1700, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'macro-offline-widget-test',
          initialHeaders: <String>['Fecha', 'Estado', 'Fotos'],
          initialRows: <List<String>>[
            <String>['', '', ''],
            <String>['', '', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    state.debugSetLastFlowBotValidCommand('poner OK en A1');

    await state.debugSaveFlowBotMacro('Macro test');
    expect(state.debugFlowBotMacroCount, 1);

    await state.debugRunFlowBotMacro('Macro test');
    await tester.pumpAndSettle();

    expect(state.debugCellText(0, 0), 'OK');
    expect(find.textContaining('Aplicado:'), findsOneWidget);
  });
}
