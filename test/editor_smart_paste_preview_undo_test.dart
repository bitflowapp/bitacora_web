import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<dynamic> pumpEditor(
    WidgetTester tester, {
    List<String>? headers,
    List<List<String>>? rows,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(
          sheetId: 'smart-paste-preview-test',
          initialHeaders: headers ?? const <String>['Col A', 'Col B', 'Fotos'],
          initialRows: rows ??
              const <List<String>>[
                <String>['legacy-a', 'legacy-b', ''],
                <String>['legacy-c', 'legacy-d', ''],
              ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state(find.byType(EditorScreen)) as dynamic;
  }

  testWidgets('smart paste detects table and opens preview sheet', (
    tester,
  ) async {
    final state = await pumpEditor(tester);

    state.debugStartSmartPastePreview('Nombre\tEstado\nAna\tOK');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('smart_paste_sheet')), findsOneWidget);
    expect(find.byKey(const Key('smart_paste_detect_label')), findsOneWidget);
    expect(
      find.textContaining('Bloque detectado: 2 filas x 2 columnas'),
      findsOneWidget,
    );
    expect(find.textContaining('Nombre | Estado'), findsOneWidget);
    expect(find.text('Insertar filas'), findsOneWidget);
    expect(find.text('Reemplazar desde celda activa'), findsOneWidget);
    expect(find.text('Usar primera fila como encabezados'), findsOneWidget);
  });

  testWidgets('smart paste apply shows undo and undo reverts changes', (
    tester,
  ) async {
    final state = await pumpEditor(tester);

    expect(state.debugCellText(0, 0), 'legacy-a');

    state.debugStartSmartPastePreview('A\tB\n1\t2');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('smart_paste_toggle_header')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('smart_paste_apply')));
    await tester.pumpAndSettle();

    expect(state.debugCellText(0, 0), 'A');
    expect(
      find.textContaining('Bloque detectado: 2 filas x 2 columnas'),
      findsOneWidget,
    );
    expect(find.text('Deshacer'), findsOneWidget);

    await tester.tap(find.text('Deshacer').first);
    await tester.pumpAndSettle();

    expect(state.debugCellText(0, 0), 'legacy-a');
  });

  testWidgets('smart paste can apply first row as headers from preview', (
    tester,
  ) async {
    final state = await pumpEditor(tester);

    state.debugStartSmartPastePreview('Nombre\tEstado\tObs\nAna\tOK\tListo');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('smart_paste_apply')));
    await tester.pumpAndSettle();

    expect(state.debugHeaderText(0), 'Nombre');
    expect(state.debugHeaderText(1), 'Estado');
    expect(state.debugHeaderText(2), 'Obs');
    expect(state.debugCellText(0, 0), 'Ana');
    expect(
        find.textContaining('primera fila como encabezados'), findsOneWidget);
  });
}
