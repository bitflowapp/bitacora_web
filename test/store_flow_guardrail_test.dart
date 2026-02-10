import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/screens/diagnostics_screen.dart';
import 'package:bitacora_web/services/sheet_store.dart';
import 'package:bitacora_web/start_page.dart';
import 'package:bitacora_web/ui/app_strings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Store guardrail flow: onboarding -> create -> save -> diagnostics',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SheetStore.init();
    tester.view.physicalSize = const Size(1700, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StartPage(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('Primeros pasos'), findsOneWidget);

    await tester.tap(find.text('Siguiente').first);
    await _pumpFrames(tester);
    await tester.tap(find.text('Crear hoja').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planilla vacia').first);
    await tester.pumpAndSettle();

    expect(find.byType(EditorScreen), findsOneWidget);

    final saveByText = find.text(AppStrings.editorSave);
    if (saveByText.evaluate().isNotEmpty) {
      await tester.tap(saveByText.first);
    } else {
      await tester.tap(find.byTooltip(AppStrings.editorSave).first);
    }
    await _pumpFrames(tester);
    expect(tester.takeException(), isNull);

    Navigator.of(tester.element(find.byType(EditorScreen))).pop();
    await _pumpFrames(tester);
    expect(find.byType(StartPage), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis).first);
    await _pumpFrames(tester);
    await tester.tap(find.textContaining('Diagn').first);
    await _pumpFrames(tester);

    expect(find.byType(DiagnosticsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 140));
  }
}

void _noop() {}
