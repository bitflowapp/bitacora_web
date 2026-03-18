import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpEditor(
    WidgetTester tester, {
    required Size size,
    required String sheetId,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(
          sheetId: sheetId,
          initialHeaders: const <String>['Fecha', 'Estado', 'Fotos'],
          initialRows: const <List<String>>[
            <String>['', '', ''],
            <String>['', '', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('field mode reduces FAB actions to core set', (tester) async {
    await pumpEditor(
      tester,
      size: const Size(390, 2000),
      sheetId: 'field-mode-widget-test',
    );
    final state = tester.state(find.byType(EditorScreen)) as dynamic;

    await state.debugSetFieldMode(true);
    await tester.pumpAndSettle();
    expect(state.debugFieldModeEnabled, isTrue);

    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('mobile-fab-main')),
    );
    fab.onPressed?.call();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mobile-fab-action-quick-capture')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-fab-action-new-record')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-fab-action-flowbot')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-fab-action-export')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-fab-action-smart-paste')),
      findsNothing,
    );
  });
}
