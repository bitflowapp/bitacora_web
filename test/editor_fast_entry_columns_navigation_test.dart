import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<dynamic> pumpMobileEditor(
    WidgetTester tester, {
    String sheetId = 'fast-entry-sheet',
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(
          sheetId: sheetId,
          initialHeaders: const <String>['A', 'B', 'C', 'Photos'],
          initialRows: const <List<String>>[
            <String>['a1', 'b1', 'c1', ''],
            <String>['a2', 'b2', 'c2', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state(find.byType(EditorScreen)) as dynamic;
  }

  Finder mobileEditorField() {
    return find.descendant(
      of: find.byKey(const ValueKey('mobileInlineEditorField')),
      matching: find.byType(TextField),
    );
  }

  testWidgets('adding five columns preserves existing data', (tester) async {
    final state = await pumpMobileEditor(tester, sheetId: 'add-columns');
    final initialHeaderCount = state.debugHeaderCount as int;

    state.debugAddColumns(5);
    await tester.pump();

    expect(state.debugHeaderCount, initialHeaderCount + 5);
    expect(state.debugCellText(0, 0), 'a1');
    expect(state.debugCellText(0, 1), 'b1');
    expect(state.debugHeaders.last, 'Photos');
    expect(state.debugHeaders, contains('Col $initialHeaderCount'));
  });

  testWidgets('confirming a cell can advance down', (tester) async {
    final state = await pumpMobileEditor(tester, sheetId: 'advance-down');
    state.debugSetConfirmAdvanceMode('down');
    state.debugOpenMobileEditorForCell(0, 0);
    await tester.pump();

    await tester.enterText(mobileEditorField(), 'editado');
    await tester.pump();
    state.debugCommitMobileEdit();
    await tester.pump();

    expect(state.debugCellText(0, 0), 'editado');
    expect(state.debugSelectedRow, 1);
    expect(state.debugSelectedCol, 0);
    expect(state.debugMobileEditorOpen, isTrue);
  });

  testWidgets('confirming a cell can advance right', (tester) async {
    final state = await pumpMobileEditor(tester, sheetId: 'advance-right');
    state.debugSetConfirmAdvanceMode('right');
    state.debugOpenMobileEditorForCell(0, 0);
    await tester.pump();

    await tester.enterText(mobileEditorField(), 'derecha');
    await tester.pump();
    state.debugCommitMobileEdit();
    await tester.pump();

    expect(state.debugCellText(0, 0), 'derecha');
    expect(state.debugSelectedRow, 0);
    expect(state.debugSelectedCol, 1);
    expect(state.debugMobileEditorOpen, isTrue);
  });

  testWidgets('confirming a cell can stay in place', (tester) async {
    final state = await pumpMobileEditor(tester, sheetId: 'advance-stay');
    state.debugSetConfirmAdvanceMode('stay');
    state.debugOpenMobileEditorForCell(0, 0);
    await tester.pump();

    await tester.enterText(mobileEditorField(), 'quieto');
    await tester.pump();
    state.debugCommitMobileEdit();
    await tester.pump();

    expect(state.debugCellText(0, 0), 'quieto');
    expect(state.debugSelectedRow, 0);
    expect(state.debugSelectedCol, 0);
    expect(state.debugMobileEditorOpen, isFalse);
  });

  testWidgets('confirming a header can advance to the next header', (
    tester,
  ) async {
    final state = await pumpMobileEditor(tester, sheetId: 'header-advance');
    state.debugSetConfirmAdvanceMode('right');
    state.debugOpenMobileEditorForHeader(0);
    await tester.pump();

    await tester.enterText(mobileEditorField(), 'Equipo');
    await tester.pump();
    state.debugCommitMobileEdit();
    await tester.pump();

    expect(state.debugHeaders[0], 'Equipo');
    expect(state.debugMobileEditorOpen, isTrue);
    expect(state.debugMobileEditingHeader, isTrue);
    expect(state.debugMobileCol, 1);
  });
}
