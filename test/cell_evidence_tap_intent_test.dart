import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<dynamic> pumpMobileEditor(WidgetTester tester, String sheetId) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: EditorScreen(sheetId: sheetId)));
    await tester.pump();
    return tester.state(find.byType(EditorScreen)) as dynamic;
  }

  testWidgets('tap on cell without evidence keeps direct edit behavior',
      (tester) async {
    final state = await pumpMobileEditor(tester, 'tap-intent-empty');

    state.debugHandleCellTapForIntent(0, 0);
    await tester.pumpAndSettle();

    expect(find.text('Esta celda tiene evidencia'), findsNothing);
    expect(state.debugMobileEditorOpen, isTrue);
  });

  testWidgets('tap on cell with evidence asks intent before editing',
      (tester) async {
    final state = await pumpMobileEditor(tester, 'tap-intent-evidence');
    state.debugApplyGpsFixToCell(0, 0, writeText: false);
    await tester.pump();

    state.debugHandleCellTapForIntent(0, 0);
    await tester.pumpAndSettle();

    expect(find.text('Esta celda tiene evidencia'), findsOneWidget);
    expect(find.text('1 evidencia adjunta: GPS.'), findsOneWidget);
    expect(find.text('Ver evidencia'), findsOneWidget);
    expect(find.text('Editar celda'), findsOneWidget);
    expect(find.text('Agregar evidencia'), findsOneWidget);
    expect(find.text('Agregar comentario'), findsNothing);
    expect(find.text('Agregar observación'), findsNothing);
    expect(state.debugMobileEditorOpen, isFalse);
  });

  testWidgets('Ver evidencia opens existing cell evidence manager',
      (tester) async {
    final state = await pumpMobileEditor(tester, 'tap-intent-view-evidence');
    state.debugApplyGpsFixToCell(0, 0, writeText: false);
    await tester.pump();

    state.debugHandleCellTapForIntent(0, 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver evidencia'));
    await tester.pumpAndSettle();

    expect(find.text('GPS adjuntado a esta celda'), findsOneWidget);
  });

  testWidgets('Editar celda from intent opens current editor without data loss',
      (tester) async {
    final state = await pumpMobileEditor(tester, 'tap-intent-edit');
    state.debugApplyGpsFixToCell(0, 0, writeText: false);
    await tester.pump();

    state.debugHandleCellTapForIntent(0, 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar celda'));
    await tester.pumpAndSettle();

    expect(find.text('Esta celda tiene evidencia'), findsNothing);
    expect(state.debugMobileEditorOpen, isTrue);
    expect(state.debugCellHasGps(0, 0), isTrue);
    expect(state.debugCellText(0, 0), isEmpty);
  });
}
