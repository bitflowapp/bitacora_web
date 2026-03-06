import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('grid renders computed formula values', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1700, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'formula-grid-test',
          initialHeaders: <String>['A', 'B', 'Fotos'],
          initialRows: <List<String>>[
            <String>['123', '=SUM(A1:A1)', ''],
            <String>['456', '=SUM(A1:A2)', ''],
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(EditorScreen), findsOneWidget);
    expect(find.text('579'), findsWidgets);
    expect(find.text('=SUM(A1:A2)'), findsNothing);
  });
}
