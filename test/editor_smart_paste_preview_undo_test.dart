import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpEditor(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'smart-paste-preview-test',
          initialHeaders: <String>['Col A', 'Col B', 'Photos'],
          initialRows: <List<String>>[
            <String>['legacy-a', 'legacy-b', ''],
            <String>['legacy-c', 'legacy-d', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('smart paste detects table and opens preview sheet', (
    tester,
  ) async {
    await pumpEditor(tester);
    final state = tester.state(find.byType(EditorScreen)) as dynamic;

    state.debugStartSmartPastePreview('Nombre\tEstado\nAna\tOK');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('smart_paste_sheet')), findsOneWidget);
    expect(find.byKey(const Key('smart_paste_detect_label')), findsOneWidget);
    expect(find.textContaining('Detecte 2x2'), findsOneWidget);
    expect(find.textContaining('Nombre | Estado'), findsOneWidget);
    expect(find.text('Insertar filas'), findsOneWidget);
    expect(find.text('Reemplazar desde celda activa'), findsOneWidget);
  });

  testWidgets('smart paste apply shows undo and undo reverts changes', (
    tester,
  ) async {
    await pumpEditor(tester);
    final state = tester.state(find.byType(EditorScreen)) as dynamic;

    expect(state.debugCellText(0, 0), 'legacy-a');

    state.debugStartSmartPastePreview('A\tB\n1\t2');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('smart_paste_toggle_header')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('smart_paste_apply')));
    await tester.pumpAndSettle();

    expect(state.debugCellText(0, 0), 'A');
    expect(find.textContaining('Pegado OK'), findsOneWidget);
    expect(find.text('Deshacer'), findsOneWidget);

    await tester.tap(find.text('Deshacer').first);
    await tester.pumpAndSettle();

    expect(state.debugCellText(0, 0), 'legacy-a');
  });
}
