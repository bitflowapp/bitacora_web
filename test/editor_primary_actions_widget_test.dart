import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/widgets/apple_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('primary + registro action inserts a real row (not no-op)',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'primary-actions-test',
          initialHeaders: <String>['Fecha', 'Estado', 'Progresiva', 'Photos'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    final initialRowCount = state.debugRowCount as int;

    final finder = find.byWidgetPredicate(
      (widget) => widget is AppleButton && widget.label == '+ Registro',
      description: 'AppleButton(+ Registro)',
    );
    expect(finder, findsOneWidget);
    final button = tester.widget<AppleButton>(finder);
    expect(button.onPressed, isNotNull);

    button.onPressed!.call();
    await tester.pumpAndSettle();

    expect(state.debugRowCount, initialRowCount + 1);
    expect(find.textContaining('Nuevo registro listo'), findsOneWidget);
  });
}
