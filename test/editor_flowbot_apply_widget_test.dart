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
          initialHeaders: <String>['Notas', 'Fotos'],
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
          initialHeaders: <String>['Notas', 'Fotos'],
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

  testWidgets('FlowBot real commands mutate grid (new row, today, clear)',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(1700, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-real-commands',
          initialHeaders: <String>[
            'Fecha',
            'Estado',
            'Progresiva',
            'Observaciones',
            'Fotos',
          ],
          initialRows: <List<String>>[
            <String>['', '', '', '', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    final beforeRows = state.debugRowCount as int;

    final newRowParsed = await state.debugParseFlowBotCommand(
      'fila nueva: estado=OK, progresiva=1200, observaciones=revisar',
    );
    expect(newRowParsed.actions, isNotEmpty);
    final newRowApplied = await state.debugApplyFlowBotActions(
      newRowParsed.actions,
    );
    await tester.pump();
    expect(newRowApplied, greaterThan(0));
    expect(state.debugRowCount, beforeRows + 1);
    expect(state.debugCellText(beforeRows, 1), 'OK');
    expect(state.debugCellText(beforeRows, 2), '1200');
    expect(state.debugCellText(beforeRows, 3), 'revisar');

    final dateParsed =
        await state.debugParseFlowBotCommand('fecha hoy columna completa');
    final dateApplied =
        await state.debugApplyFlowBotActions(dateParsed.actions);
    await tester.pump();
    expect(dateApplied, greaterThan(0));
    expect(state.debugCellText(0, 0), isNotEmpty);
    expect(state.debugCellText(beforeRows, 0), isNotEmpty);

    final clearParsed = await state.debugParseFlowBotCommand('limpiar fila');
    final clearApplied =
        await state.debugApplyFlowBotActions(clearParsed.actions);
    await tester.pump();
    expect(clearApplied, greaterThan(0));
    expect(state.debugCellText(beforeRows, 1), '');
  });

  testWidgets('FlowBot primary CTA parses and applies current command from UI',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-apply-ui-test',
          initialHeaders: <String>['Notas', 'Fotos'],
          initialRows: <List<String>>[
            <String>['', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    await state.debugSetFieldMode(true);
    await tester.pumpAndSettle();

    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('mobile-fab-main')),
    );
    fab.onPressed?.call();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mobile-fab-action-flowbot')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('flowbot-command-input')),
      'poner OK en A1',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('flowbot-apply')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('flowbot-apply')), findsNothing);
    expect(state.debugCellText(0, 0), 'OK');
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlowBot apply CTA explains invalid command instead of silent no-op',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-invalid-ui-test',
          initialHeaders: <String>['Notas', 'Fotos'],
          initialRows: <List<String>>[
            <String>['', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    await state.debugSetFieldMode(true);
    await tester.pumpAndSettle();

    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('mobile-fab-main')),
    );
    fab.onPressed?.call();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mobile-fab-action-flowbot')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('flowbot-command-input')),
      'comando inventado sin accion',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('flowbot-apply')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('flowbot-apply')), findsOneWidget);
    expect(find.byKey(const ValueKey('flowbot-warning')), findsOneWidget);
    expect(find.textContaining('No se detectaron acciones'), findsWidgets);
    expect(state.debugCellText(0, 0), '');
    expect(tester.takeException(), isNull);
  });
}
