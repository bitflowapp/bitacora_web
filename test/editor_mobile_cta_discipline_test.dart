import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<dynamic> pumpMobileEditor(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'mobile-cta-discipline-test',
          initialHeaders: <String>['Fecha', 'Estado', 'Fotos'],
          initialRows: <List<String>>[
            <String>['2026-03-18', 'Pendiente', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state(find.byType(EditorScreen)) as dynamic;
  }

  testWidgets(
      'mobile header menu keeps core sales CTAs first and hides secondary ones',
      (tester) async {
    await pumpMobileEditor(tester);

    await tester.tap(find.byTooltip('Opciones').hitTestable().first);
    await tester.pumpAndSettle();

    expect(find.text('Foto + registro'), findsOneWidget);
    expect(find.text('Editar fila'), findsOneWidget);
    expect(find.text('Exportar / compartir'), findsOneWidget);
    expect(find.text('Acciones por lote'), findsNothing);
    expect(find.text('Evidencia de la celda'), findsNothing);

    await tester.tap(find.text('Opciones avanzadas'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Acciones por lote'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Acciones por lote'), findsOneWidget);
    expect(find.text('Evidencia de la celda'), findsOneWidget);
  });

  testWidgets('mobile overflow uses honest media CTAs', (tester) async {
    final state = await pumpMobileEditor(tester);

    state.debugOpenMobileEditorForCell(0, 0);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mas acciones').hitTestable().first);
    await tester.pumpAndSettle();

    expect(find.text('Guardar y cerrar'), findsOneWidget);
    expect(find.text('Adjuntar foto en esta celda'), findsOneWidget);
    expect(find.text('Adjuntar video en esta celda'), findsOneWidget);
    expect(find.text('Adjuntar archivo en esta celda'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Adjuntar GPS en esta celda'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Adjuntar GPS en esta celda'), findsOneWidget);
    expect(find.text('Ajuste de GPS'), findsOneWidget);
    expect(find.text('Fotos de esta celda'), findsNothing);
    expect(find.text('GPS -> Pegar en esta celda'), findsNothing);
    expect(find.text('Modo GPS...'), findsNothing);
  });
}
