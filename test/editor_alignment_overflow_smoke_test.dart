import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('grid text stays overflow-safe and supports column presentation',
      (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const longText =
        'Texto muy largo para verificar wrap y overflow en celda sin romper layout.';

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'align-overflow-smoke',
          initialHeaders: <String>['Notas', 'Fotos'],
          initialRows: <List<String>>[
            <String>[longText, ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    state.debugSetColumnPresentation(
      0,
      wrapLines: 3,
      textAlign: 'center',
      verticalAlign: 'top',
    );
    await tester.pumpAndSettle();

    final textFinder = find.byWidgetPredicate((widget) {
      return widget is Text && widget.data == longText;
    });
    expect(textFinder, findsWidgets);

    final textWidget = tester.widget<Text>(textFinder.first);
    expect(textWidget.maxLines, inInclusiveRange(1, 3));
    expect(textWidget.overflow, TextOverflow.ellipsis);
    expect(textWidget.textAlign, TextAlign.center);

    await tester.tap(textFinder.first);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
  });
}
