import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/widgets/apple_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FlowBot sheet keeps analyze and apply visible on compact mobile',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-compact-sheet-test',
          initialHeaders: <String>['Fecha', 'Estado', 'Fotos'],
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
    expect(tester.takeException(), isNull);

    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('mobile-fab-main')),
    );
    fab.onPressed?.call();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mobile-fab-action-flowbot')));
    await tester.pumpAndSettle();

    expect(find.text('FlowBot'), findsOneWidget);
    expect(find.text('Dictar'), findsOneWidget);
    expect(find.text('Analizar'), findsOneWidget);
    expect(find.widgetWithText(AppleButton, 'Aplicar cambios'), findsOneWidget);

    final applyRect = tester.getRect(
      find.widgetWithText(AppleButton, 'Aplicar cambios'),
    );
    expect(applyRect.bottom, lessThanOrEqualTo(680));
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlowBot history chips stay inside compact mobile viewport',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.editor.flowbot.history.v1':
          '["fila nueva: estado=OK, observaciones=este comando de prueba es deliberadamente largo para validar el chip en mobile"]',
    });
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-history-chip-test',
          initialHeaders: <String>['Fecha', 'Estado', 'Fotos'],
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
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('mobile-fab-action-flowbot')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('Recientes'), findsOneWidget);

    final chip = find.byKey(const ValueKey('flowbot-history-chip-0'));
    expect(chip, findsOneWidget);

    final chipRect = tester.getRect(chip);
    expect(chipRect.right, lessThanOrEqualTo(320));
    expect(chipRect.left, greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlowBot inline bar stays hidden on ultra compact viewport',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'flowbot-inline-ultra-compact',
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

    expect(find.byKey(const ValueKey('flowbot-inline-bar')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
