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

    expect(find.text('1 cambio listo'), findsOneWidget);
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

    expect(find.text('Acciones rapidas'), findsOneWidget);
    expect(find.text('Favoritos'), findsOneWidget);
    expect(find.text('Sugeridas'), findsOneWidget);
    expect(find.text('Recientes'), findsOneWidget);
    expect(find.text('Ejemplos reales'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('flowbot-quick-primary-duplicate-row')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('1 cambio listo'), findsOneWidget);

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

    expect(find.text('1 cambio listo'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('flowbot-apply')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(state.debugCellText(0, 1), 'OK');
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

    expect(find.text('1 cambio listo'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('flowbot-apply')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(state.debugRowCount, 2);
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

    expect(find.text('Sin acciones detectadas'), findsWidgets);
    expect(find.byKey(const ValueKey('flowbot-apply')), findsOneWidget);
    expect(find.byKey(const ValueKey('flowbot-warning')), findsOneWidget);
    expect(find.textContaining('Prueba con:'), findsWidgets);
    applyButton = tester.widget<AppleButton>(
      find.byKey(const ValueKey('flowbot-apply')),
    );
    expect(applyButton.onPressed, isNull);
    expect(state.debugCellText(0, 0), '');
    expect(tester.takeException(), isNull);
  });
}
