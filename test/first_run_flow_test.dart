import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/screens/sheets_screen.dart';
import 'package:bitacora_web/services/sheet_store.dart';
import 'package:bitacora_web/start_page.dart';
import 'package:bitacora_web/ui/app_strings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first run shows onboarding and respects no-show toggle',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SheetStore.init();

    await tester.pumpWidget(
      const MaterialApp(
        home: StartPage(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Primeros pasos'), findsOneWidget);

    final switchFinder = find.byType(Switch).evaluate().isNotEmpty
        ? find.byType(Switch).first
        : find.byType(CupertinoSwitch).first;
    await tester.tap(switchFinder);
    await tester.pump(const Duration(milliseconds: 180));

    await tester.tap(find.text('Ahora no').first);
    await _pumpUntilDialogGone(tester);

    expect(find.text('Primeros pasos'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 80));

    await tester.pumpWidget(
      const MaterialApp(
        home: StartPage(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Primeros pasos'), findsNothing);
  });

  testWidgets('template creation creates and opens a new sheet entry',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SheetStore.init();
    tester.view.physicalSize = const Size(1700, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final before = SheetStore.list().length;

    await tester.pumpWidget(
      const MaterialApp(
        home: SheetsScreen(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text(AppStrings.templates).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plantilla base'));
    await tester.pumpAndSettle();

    expect(find.byType(EditorScreen), findsOneWidget);
    expect(SheetStore.list().length, before + 1);
  });
}

void _noop() {}

Future<void> _pumpUntilDialogGone(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 120));
    if (find.text('Primeros pasos').evaluate().isEmpty) return;
  }
}
