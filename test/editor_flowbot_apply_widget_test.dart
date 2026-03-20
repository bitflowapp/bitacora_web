import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/services/flowbot.dart';
import 'package:bitacora_web/services/flowbot_quick_store.dart';
import 'package:bitacora_web/widgets/apple_ui.dart';
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
    expect((result['message'] as String), contains('no dejo cambios listos'));
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
    expect(result['message'], contains('Listo en A1'));
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

  testWidgets('FlowBot analyze then apply updates B2 from UI', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-apply-ui-test',
          initialHeaders: <String>['Campo 1', 'Estado', 'Fotos'],
          initialRows: <List<String>>[
            <String>['', '', ''],
            <String>['', '', ''],
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
      'poner OK en B2',
    );
    await tester.pump();

    AppleButton applyButton = tester.widget<AppleButton>(
      find.byKey(const ValueKey('flowbot-apply')),
    );
    expect(applyButton.onPressed, isNull);

    await tester.ensureVisible(find.byKey(const ValueKey('flowbot-analyze')));
    await tester.tap(find.byKey(const ValueKey('flowbot-analyze')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('cambio listo en'), findsOneWidget);
    applyButton = tester.widget<AppleButton>(
      find.byKey(const ValueKey('flowbot-apply')),
    );
    expect(applyButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('flowbot-apply')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('flowbot-apply')), findsNothing);
    expect(state.debugCellText(1, 1), 'OK');
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlowBot suggested quick actions preview and apply fast',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-quick-actions-ui-test',
          initialName: 'Relevamiento demo',
          initialHeaders: <String>[
            'Campo 1',
            'Estado',
            'Observaciones',
            'Fotos'
          ],
          initialRows: <List<String>>[
            <String>['A', '', '', ''],
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

    expect(find.textContaining('Acciones para'), findsOneWidget);
    expect(find.text('Favoritos'), findsOneWidget);
    expect(find.text('Sugeridas'), findsOneWidget);
    expect(find.text('Recientes'), findsOneWidget);
    expect(find.text('Ejemplos reales'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('flowbot-quick-primary-duplicate-row')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('cambio listo en'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('flowbot-apply')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(state.debugRowCount, 2);
    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-favorites-other-sheet',
          initialHeaders: <String>['Campo 1', 'Estado', 'Fotos'],
          initialRows: <List<String>>[
            <String>['', '', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final otherState = tester.state(find.byType(EditorScreen)) as dynamic;
    await otherState.debugSetFieldMode(true);
    await tester.pumpAndSettle();
    final otherFab = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('mobile-fab-main')),
    );
    otherFab.onPressed?.call();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mobile-fab-action-flowbot')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('flowbot-favorite-chip-0')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlowBot quick action with prompt previews and applies value',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-quick-prompt-ui-test',
          initialHeaders: <String>['Campo 1', 'Estado', 'Fotos'],
          initialRows: <List<String>>[
            <String>['', '', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    await state.debugSetFieldMode(true);
    state.debugSelectCell(0, 1);
    await tester.pumpAndSettle();

    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('mobile-fab-main')),
    );
    fab.onPressed?.call();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mobile-fab-action-flowbot')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('flowbot-quick-primary-set-active-cell')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('flowbot-quick-input-set-active-cell')),
      'OK',
    );
    await tester.tap(find.text('Previsualizar'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('cambio listo en'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('flowbot-apply')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(state.debugCellText(0, 1), 'OK');
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlowBot inline bar executes a simple action from the editor',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-inline-simple',
          initialTemplateKind: 'campo',
          initialHeaders: <String>['Campo 1', 'Estado', 'Fotos'],
          initialRows: <List<String>>[
            <String>['', '', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    await state.debugSetFieldMode(true);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('flowbot-inline-bar')), findsOneWidget);
    expect(find.textContaining('FlowBot para'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('flowbot-inline-action-0')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(state.debugRowCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlowBot inline bar opens a minimal prompt for value actions',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-inline-prompt',
          initialTemplateKind: 'inventario',
          initialHeaders: <String>['Campo 1', 'Estado', 'Fotos'],
          initialRows: <List<String>>[
            <String>['', '', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    await state.debugSetFieldMode(true);
    state.debugSelectCell(0, 1);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('flowbot-inline-action-0')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('flowbot-inline-input-set-active-cell')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('flowbot-inline-input-set-active-cell')),
      'OK',
    );
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(state.debugCellText(0, 1), 'OK');
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlowBot inline bar changes with selection and template',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<dynamic> pumpSheet({
      required String sheetId,
      required String templateKind,
      required List<List<String>> rows,
    }) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: EditorScreen(
            sheetId: sheetId,
            initialTemplateKind: templateKind,
            initialHeaders: const <String>['Campo 1', 'Estado', 'Fotos'],
            initialRows: rows,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(EditorScreen)) as dynamic;
      await state.debugSetFieldMode(true);
      await tester.pumpAndSettle();
      return state;
    }

    final campoState = await pumpSheet(
      sheetId: 'flowbot-inline-campo',
      templateKind: 'campo',
      rows: const <List<String>>[
        <String>['A', '', ''],
        <String>['', '', ''],
      ],
    );
    campoState.debugSelectCell(0, 1);
    await tester.pumpAndSettle();
    expect(
      List<String>.from(campoState.debugFlowBotInlineActionIds()),
      isNot(contains('copy-previous-row')),
    );

    campoState.debugSelectCell(1, 1);
    await tester.pumpAndSettle();
    expect(
      List<String>.from(campoState.debugFlowBotInlineActionIds()),
      contains('copy-previous-row'),
    );

    final inventarioState = await pumpSheet(
      sheetId: 'flowbot-inline-inventario',
      templateKind: 'inventario',
      rows: const <List<String>>[
        <String>['A', '', ''],
      ],
    );
    expect(
      List<String>.from(inventarioState.debugFlowBotInlineActionIds()),
      isNot(contains('copy-previous-row')),
    );
    expect(
      List<String>.from(inventarioState.debugFlowBotInlineActionIds()),
      contains('set-active-cell'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlowBot applies fill blanks and copy previous row commands',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(1700, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-fill-copy-test',
          initialHeaders: <String>[
            'Campo 1',
            'Estado',
            'Observaciones',
            'Fotos'
          ],
          initialRows: <List<String>>[
            <String>['A', 'OK', '', ''],
            <String>['B', '', '', ''],
            <String>['C', '', '', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    state.debugSelectCell(2, 1);

    final fillParsed = await state.debugParseFlowBotCommand(
      'completar vacios en columna Estado con Pendiente',
    );
    expect(fillParsed.actions, isNotEmpty);
    final fillApplied =
        await state.debugApplyFlowBotActions(fillParsed.actions);
    await tester.pump();
    expect(fillApplied, 2);
    expect(state.debugCellText(0, 1), 'OK');
    expect(state.debugCellText(1, 1), 'Pendiente');
    expect(state.debugCellText(2, 1), 'Pendiente');

    state.debugSelectCell(1, 0);
    final copyParsed = await state.debugParseFlowBotCommand(
      'copiar valor de la fila anterior en A2',
    );
    expect(copyParsed.actions, hasLength(1));
    final copyApplied =
        await state.debugApplyFlowBotActions(copyParsed.actions);
    await tester.pump();
    expect(copyApplied, 1);
    expect(state.debugCellText(1, 0), 'A');
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlowBot stores recents per sheet and restores them on reopen',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpSheet(String sheetId) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: EditorScreen(
            sheetId: sheetId,
            initialHeaders: const <String>['Campo 1', 'Estado', 'Fotos'],
            initialRows: const <List<String>>[
              <String>['', '', ''],
              <String>['', '', ''],
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
    }

    await pumpSheet('flowbot-recents-a');
    await tester.enterText(
      find.byKey(const ValueKey('flowbot-command-input')),
      'poner OK en B2',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('flowbot-analyze')));
    await tester.tap(find.byKey(const ValueKey('flowbot-analyze')));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('flowbot-apply')));
    await tester.pump();
    await tester.pumpAndSettle();

    await pumpSheet('flowbot-recents-a');
    expect(find.text('Recientes'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('flowbot-history-chip-0')), findsOneWidget);
    expect(find.text('poner OK en B2'), findsWidgets);

    await pumpSheet('flowbot-recents-b');
    expect(find.text('poner OK en B2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlowBot prefers template context for recents across sheets',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpSheet(String sheetId) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: EditorScreen(
            sheetId: sheetId,
            initialTemplateKind: 'campo',
            initialHeaders: const <String>['Campo 1', 'Estado', 'Fotos'],
            initialRows: const <List<String>>[
              <String>['', '', ''],
              <String>['', '', ''],
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
    }

    await pumpSheet('flowbot-template-a');
    await tester.enterText(
      find.byKey(const ValueKey('flowbot-command-input')),
      'poner OK en B2',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('flowbot-analyze')));
    await tester.tap(find.byKey(const ValueKey('flowbot-analyze')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('flowbot-apply')));
    await tester.pumpAndSettle();

    await pumpSheet('flowbot-template-b');
    expect(find.text('Recientes'), findsOneWidget);
    expect(find.text('poner OK en B2'), findsWidgets);
    expect(
      find.byKey(const ValueKey('flowbot-history-chip-0')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlowBot shows template suggested favorites by rubro',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpSheet({
      required String sheetId,
      required String templateKind,
    }) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: EditorScreen(
            sheetId: sheetId,
            initialTemplateKind: templateKind,
            initialHeaders: const <String>['Campo 1', 'Estado', 'Fotos'],
            initialRows: const <List<String>>[
              <String>['', '', ''],
              <String>['', '', ''],
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
    }

    await pumpSheet(sheetId: 'flowbot-template-campo', templateKind: 'campo');
    expect(find.text('Favoritos recomendados'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('flowbot-template-favorite-chip-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('flowbot-template-favorite-chip-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('flowbot-template-favorite-chip-2')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('flowbot-template-favorite-chip-0')),
        matching: find.textContaining('Duplicar fila'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('flowbot-template-favorite-chip-1')),
        matching: find.text('Completar vacios'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('flowbot-template-favorite-chip-2')),
        matching: find.textContaining('Copiar fila anterior'),
      ),
      findsOneWidget,
    );

    await pumpSheet(
      sheetId: 'flowbot-template-inventario',
      templateKind: 'inventario',
    );
    expect(
      find.byKey(const ValueKey('flowbot-template-favorite-chip-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('flowbot-template-favorite-chip-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('flowbot-template-favorite-chip-2')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('flowbot-template-favorite-chip-0')),
        matching: find.textContaining('Poner valor en'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Copiar fila anterior'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('flowbot-template-favorite-chip-2')),
        matching: find.text('Agregar columna'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlowBot favorites persist across reopen and execute fast',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<dynamic> pumpSheet() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        const MaterialApp(
          home: EditorScreen(
            sheetId: 'flowbot-favorites-sheet',
            initialHeaders: <String>['Campo 1', 'Estado', 'Fotos'],
            initialRows: <List<String>>[
              <String>['', '', ''],
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
      return state;
    }

    await pumpSheet();
    await tester.ensureVisible(
      find.byKey(
        const ValueKey('flowbot-suggested-favorite-toggle-duplicate-row'),
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey('flowbot-suggested-favorite-toggle-duplicate-row'),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('flowbot-close')));
    await tester.pumpAndSettle();

    final state = await pumpSheet();
    expect(find.text('Favoritos'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('flowbot-favorite-chip-0')), findsOneWidget);

    await tester
        .ensureVisible(find.byKey(const ValueKey('flowbot-favorite-chip-0')));
    await tester.tap(find.byKey(const ValueKey('flowbot-favorite-chip-0')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('cambio listo en'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('flowbot-apply')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(state.debugRowCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'FlowBot hides duplicate template suggestion when user already favorited it',
      (tester) async {
    final favoritesRaw = FlowBotQuickStore.encodeFavoritesByContext(
      <String, List<FlowBotFavoriteShortcut>>{
        'template:campo': <FlowBotFavoriteShortcut>[
          const FlowBotFavoriteShortcut(
            kind: 'quick_action',
            label: 'Duplicar fila actual',
            quickActionId: 'duplicate-row',
          ),
        ],
      },
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.editor.flowbot.favorites_by_context.v1': favoritesRaw,
    });

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-template-user-favorite',
          initialTemplateKind: 'campo',
          initialHeaders: <String>['Campo 1', 'Estado', 'Fotos'],
          initialRows: <List<String>>[
            <String>['', '', ''],
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

    expect(find.text('Favoritos'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('flowbot-favorite-chip-0')), findsOneWidget);
    expect(find.text('Favoritos recomendados'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('flowbot-template-favorite-chip-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('flowbot-template-favorite-chip-2')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlowBot favorites stay isolated between different templates',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpSheet({
      required String sheetId,
      required String templateKind,
    }) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: EditorScreen(
            sheetId: sheetId,
            initialTemplateKind: templateKind,
            initialHeaders: const <String>['Campo 1', 'Estado', 'Fotos'],
            initialRows: const <List<String>>[
              <String>['', '', ''],
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
    }

    await pumpSheet(sheetId: 'flowbot-fav-campo-a', templateKind: 'campo');
    await tester.ensureVisible(
      find.byKey(const ValueKey('flowbot-template-favorite-toggle-0')),
    );
    await tester
        .tap(find.byKey(const ValueKey('flowbot-template-favorite-toggle-0')));
    await tester.pumpAndSettle();

    await pumpSheet(sheetId: 'flowbot-fav-campo-b', templateKind: 'campo');
    expect(
        find.byKey(const ValueKey('flowbot-favorite-chip-0')), findsOneWidget);

    await pumpSheet(
      sheetId: 'flowbot-fav-inventario-a',
      templateKind: 'inventario',
    );
    expect(find.byKey(const ValueKey('flowbot-favorite-chip-0')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'FlowBot migrates sheet-scoped persisted data into template context safely',
      (tester) async {
    final oldRecents = FlowBotQuickStore.encodeRecentByContext(
      <String, List<String>>{
        'sheet:flowbot-migrate-sheet': <String>['poner OK en B2'],
      },
    );
    final oldFavorites = FlowBotQuickStore.encodeFavoritesByContext(
      <String, List<FlowBotFavoriteShortcut>>{
        'sheet:flowbot-migrate-sheet': <FlowBotFavoriteShortcut>[
          const FlowBotFavoriteShortcut(
            kind: 'quick_action',
            label: 'Duplicar fila actual',
            quickActionId: 'duplicate-row',
          ),
        ],
      },
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.editor.flowbot.recent_by_context.v2': oldRecents,
      'bitflow.editor.flowbot.favorites_by_context.v1': oldFavorites,
    });

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-migrate-sheet',
          initialTemplateKind: 'campo',
          initialHeaders: <String>['Campo 1', 'Estado', 'Fotos'],
          initialRows: <List<String>>[
            <String>['', '', ''],
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

    expect(find.text('poner OK en B2'), findsWidgets);
    expect(
        find.byKey(const ValueKey('flowbot-favorite-chip-0')), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final migratedRecentsRaw =
        prefs.getString('bitflow.editor.flowbot.recent_by_context.v2') ?? '';
    final migratedFavoritesRaw =
        prefs.getString('bitflow.editor.flowbot.favorites_by_context.v1') ?? '';
    final migratedRecents = FlowBotQuickStore.decodeRecentByContext(
      migratedRecentsRaw,
    );
    final migratedFavorites = FlowBotQuickStore.decodeFavoritesByContext(
      migratedFavoritesRaw,
    );

    expect(
      migratedRecents['template:campo'],
      contains('poner OK en B2'),
    );
    expect(
      migratedFavorites['template:campo']?.single.quickActionId,
      'duplicate-row',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlowBot invalid favorite warns clearly and keeps apply disabled',
      (tester) async {
    final favoritesRaw = FlowBotQuickStore.encodeFavoritesByContext(
      <String, List<FlowBotFavoriteShortcut>>{
        'sheet:flowbot-invalid-favorite-sheet': <FlowBotFavoriteShortcut>[
          const FlowBotFavoriteShortcut(
            kind: 'quick_action',
            label: 'Copiar fila anterior',
            quickActionId: 'copy-previous-row',
          ),
        ],
      },
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.editor.flowbot.favorites_by_context.v1': favoritesRaw,
    });

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-invalid-favorite-sheet',
          initialHeaders: <String>['Campo 1', 'Estado', 'Fotos'],
          initialRows: <List<String>>[
            <String>['A', '', ''],
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

    expect(
        find.byKey(const ValueKey('flowbot-favorite-chip-0')), findsOneWidget);
    await tester
        .ensureVisible(find.byKey(const ValueKey('flowbot-favorite-chip-0')));
    await tester.tap(find.byKey(const ValueKey('flowbot-favorite-chip-0')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('flowbot-warning')), findsOneWidget);
    expect(find.textContaining('no aplica'), findsWidgets);
    final applyButton = tester.widget<AppleButton>(
      find.byKey(const ValueKey('flowbot-apply')),
    );
    expect(applyButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'FlowBot invalid template suggestion warns clearly and keeps apply disabled',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-invalid-template-suggestion',
          initialTemplateKind: 'campo',
          initialHeaders: <String>['Campo 1', 'Estado', 'Fotos'],
          initialRows: <List<String>>[
            <String>['A', '', ''],
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

    await tester.ensureVisible(
      find.byKey(const ValueKey('flowbot-template-favorite-chip-1')),
    );
    await tester
        .tap(find.byKey(const ValueKey('flowbot-template-favorite-chip-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('flowbot-warning')), findsOneWidget);
    expect(find.textContaining('no aplica'), findsWidgets);
    final applyButton = tester.widget<AppleButton>(
      find.byKey(const ValueKey('flowbot-apply')),
    );
    expect(applyButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlowBot apply CTA stays disabled when analyze finds no actions',
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

    AppleButton applyButton = tester.widget<AppleButton>(
      find.byKey(const ValueKey('flowbot-apply')),
    );
    expect(applyButton.onPressed, isNull);

    await tester.ensureVisible(find.byKey(const ValueKey('flowbot-analyze')));
    await tester.tap(find.byKey(const ValueKey('flowbot-analyze')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('flowbot-apply')), findsOneWidget);
    expect(find.byKey(const ValueKey('flowbot-warning')), findsOneWidget);
    expect(find.textContaining('Prueba con:'), findsWidgets);
    applyButton = tester.widget<AppleButton>(
      find.byKey(const ValueKey('flowbot-apply')),
    );
    expect(applyButton.onPressed, isNull);
    expect(applyButton.variant, AppleButtonVariant.ghost);
    expect(find.textContaining('No hay cambios listos para'), findsOneWidget);
    expect(find.textContaining('Elegi una accion rapida para'), findsOneWidget);
    expect(state.debugCellText(0, 0), '');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'FlowBot irrelevant input shows useful help and hides model tools',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.editor.flowbot.recent_by_context.v2':
          '{"sheet:flowbot-irrelevant-help":["hola hola"]}',
    });

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-irrelevant-help',
          initialHeaders: <String>['Campo 1', 'Estado', 'Fotos'],
          initialRows: <List<String>>[
            <String>['', '', ''],
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

    expect(find.byKey(const ValueKey('flowbot-history-chip-0')), findsNothing);
    expect(find.text('Usar Local LLM'), findsNothing);
    expect(find.textContaining('Descargar modelo'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('flowbot-command-input')),
      'hola hola',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('flowbot-analyze')));
    await tester.tap(find.byKey(const ValueKey('flowbot-analyze')));
    await tester.pump();
    await tester.pumpAndSettle();

    final applyButton = tester.widget<AppleButton>(
      find.byKey(const ValueKey('flowbot-apply')),
    );
    expect(applyButton.onPressed, isNull);
    expect(applyButton.variant, AppleButtonVariant.ghost);
    expect(find.textContaining('No hay cambios listos para'), findsOneWidget);
    expect(find.byKey(const ValueKey('flowbot-empty-help')), findsOneWidget);
    expect(find.textContaining('Elegi una accion rapida para'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('flowbot-empty-help-chip-0')),
      findsOneWidget,
    );
    expect(
      find.textContaining('No parece una accion de planilla'),
      findsWidgets,
    );
    expect(state.debugCellText(0, 0), '');
    expect(tester.takeException(), isNull);
  });
}
