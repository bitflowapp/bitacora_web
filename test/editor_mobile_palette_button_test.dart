import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpMobileEditor(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'mobile-palette-button-test',
          initialHeaders: <String>['Col A', 'Col B', 'Photos'],
          initialRows: <List<String>>[
            <String>['a', 'b', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mobile bolt button opens command palette', (tester) async {
    await pumpMobileEditor(tester);

    await tester.tap(find.byKey(const ValueKey('mobile-palette-bolt')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('command_palette_dialog')), findsOneWidget);
  });
}
