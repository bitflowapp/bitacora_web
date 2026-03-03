import 'package:bitacora_web/services/sheet_store.dart';
import 'package:bitacora_web/start_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('quick switcher opens with ctrl/cmd+k and closes with esc',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.onboarding_done.v1': true,
    });
    await SheetStore.init();
    final sheetId = SheetStore.createNew();
    SheetStore.rename(sheetId, 'Quick Switcher Sheet');

    await tester.pumpWidget(
      const MaterialApp(
        home: StartPage(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );
    await _pumpFrames(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('command_palette_dialog')), findsOneWidget);
    expect(find.text('Quick Switcher'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('command_palette_dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void _noop() {}
