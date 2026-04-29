import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<dynamic> pumpFieldEditor(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(430, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'field-workflow-test',
          initialHeaders: <String>[
            'Estado',
            'Prioridad',
            'Observaciones',
            'Fotos',
          ],
          initialRows: <List<String>>[
            <String>['Pendiente', '', '', ''],
            <String>['Pendiente', '', '', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state(find.byType(EditorScreen)) as dynamic;
  }

  Finder quickBarText(String text) {
    return find.descendant(
      of: find.byKey(const ValueKey('selection-quick-actions-open')),
      matching: find.text(text),
    );
  }

  testWidgets('field quick bar exposes core mobile actions', (tester) async {
    await pumpFieldEditor(tester);

    expect(find.byKey(const ValueKey('selection-quick-actions-open')),
        findsOneWidget);
    expect(quickBarText('Foto'), findsOneWidget);
    expect(quickBarText('GPS'), findsOneWidget);
    expect(quickBarText('Estado'), findsOneWidget);
    expect(quickBarText('Prioridad'), findsOneWidget);
    expect(quickBarText('Observación'), findsOneWidget);
    expect(quickBarText('Exportar'), findsOneWidget);
  });

  testWidgets('field quick status and priority update selected row',
      (tester) async {
    final state = await pumpFieldEditor(tester);

    await tester.tap(quickBarText('Estado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crítico'));
    await tester.pumpAndSettle();

    expect(state.debugCellText(0, 0), 'Crítico');

    await tester.tap(quickBarText('Prioridad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alta'));
    await tester.pumpAndSettle();

    expect(state.debugCellText(0, 1), 'Alta');
  });

  testWidgets('field export copy is human and evidence-focused',
      (tester) async {
    await pumpFieldEditor(tester);

    await tester.tap(quickBarText('Exportar'));
    await tester.pumpAndSettle();

    expect(find.text('Reporte PDF'), findsOneWidget);
    expect(find.text('Reporte para compartir'), findsOneWidget);
    expect(find.text('Planilla Excel'), findsOneWidget);
    expect(find.text('Planilla editable'), findsOneWidget);
    expect(find.text('Paquete con evidencias'), findsOneWidget);
    expect(find.textContaining('Datos + fotos/evidencias'), findsOneWidget);
    expect(find.textContaining('metadata'), findsNothing);
    expect(find.textContaining('backup ZIP'), findsNothing);
  });
}
