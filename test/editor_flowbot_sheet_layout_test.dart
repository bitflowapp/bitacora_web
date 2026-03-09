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

    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('mobile-fab-main')),
    );
    fab.onPressed?.call();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mobile-fab-action-flowbot')));
    await tester.pumpAndSettle();

    expect(find.text('FlowBot'), findsOneWidget);
    expect(find.text('Analizar'), findsOneWidget);
    expect(find.widgetWithText(AppleButton, 'Aplicar'), findsOneWidget);

    final applyRect =
        tester.getRect(find.widgetWithText(AppleButton, 'Aplicar'));
    expect(applyRect.bottom, lessThanOrEqualTo(680));
    expect(tester.takeException(), isNull);
  });
}
