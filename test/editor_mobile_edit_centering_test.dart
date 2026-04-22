import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile edit keeps grid visible and scrolls toward active cell',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rows = List<List<String>>.generate(
      40,
      (i) => <String>['fila $i', 'estado', '$i', ''],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(
          sheetId: 'mobile-edit-centering-test',
          initialHeaders: const <String>[
            'Col A',
            'Col B',
            'Col C',
            'Photos',
          ],
          initialRows: rows,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    final beforeEnsureCalls = state.debugMobileEnsureVisibleCalls as int;

    state.debugOpenMobileEditorForCell(26, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(state.debugMobileEditorOpen, isTrue);
    expect(
        find.byKey(const ValueKey('mobileInlineEditorField')), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-grid-root')), findsOneWidget);

    final panelSize = tester
        .getSize(find.byKey(const ValueKey('mobile-inline-editor-panel')));
    final screenH =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(panelSize.height, lessThan(screenH * 0.6));
    expect(state.debugMobileEnsureVisibleCalls, greaterThan(beforeEnsureCalls));
  });

  testWidgets('mobile edit syncs draft live and cancel discards it',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'mobile-live-draft-test',
          initialHeaders: <String>['Prog.', 'Obs.', 'Photos'],
          initialRows: <List<String>>[
            <String>['0+000', 'lectura inicial', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    state.debugOpenMobileEditorForCell(0, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    final field = find.descendant(
      of: find.byKey(const ValueKey('mobileInlineEditorField')),
      matching: find.byType(TextField),
    );
    expect(field, findsOneWidget);

    await tester.enterText(field, 'terreno húmedo, lectura estable');
    await tester.pump(const Duration(milliseconds: 120));

    expect(state.debugHasCellDraft(0, 1), isTrue);
    expect(
      state.debugEffectiveCellText(0, 1),
      'terreno húmedo, lectura estable',
    );
    expect(state.debugCellText(0, 1), 'lectura inicial');

    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();

    expect(state.debugMobileEditorOpen, isFalse);
    expect(state.debugHasCellDraft(0, 1), isFalse);
    expect(state.debugCellText(0, 1), 'lectura inicial');
  });
}
