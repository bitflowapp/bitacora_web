import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('find in sheet opens and selects a matching cell', (tester) async {
    tester.view.physicalSize = const Size(1700, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'find-in-sheet-smoke',
          initialHeaders: <String>['Actividad', 'Detalle', 'Fotos'],
          initialRows: <List<String>>[
            <String>['Inicio', '', ''],
            <String>['Objetivo encontrado', '', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;

    state.debugOpenInlineSearch();
    state.debugSearchInSheet('Objetivo');
    await tester.pumpAndSettle();

    expect(state.debugSelectedRow, 1);
    expect(state.debugSelectedCol, 0);
    expect(tester.takeException(), isNull);
  });
}
