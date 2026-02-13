import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/services/flowbot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FlowBot apply result explains no-op when there are no actions',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(1700, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-empty-apply-test',
          initialHeaders: <String>['Notas', 'Photos'],
          initialRows: <List<String>>[
            <String>['', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    final result =
        await state.debugApplyFlowBotActionsResult(const <FlowBotAction>[]);

    expect(result['ok'], false);
    expect((result['message'] as String), contains('no aplico cambios'));
    expect(result['applied'], 0);
  });

  testWidgets('FlowBot parse and apply pipeline updates active cell',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(1700, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-widget-test',
          initialHeaders: <String>['Notas', 'Photos'],
          initialRows: <List<String>>[
            <String>['', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    final parsed = await state.debugParseFlowBotCommand('poner OK en A1');
    expect(parsed.actions, isNotEmpty);

    final applied = await state.debugApplyFlowBotActions(parsed.actions);
    final result = await state.debugApplyFlowBotActionsResult(parsed.actions);
    await tester.pump();

    expect(applied, greaterThan(0));
    expect(result['ok'], true);
    expect(result['undoToken'], isNotNull);
    expect(state.debugCellText(0, 0), 'OK');
  });
}
