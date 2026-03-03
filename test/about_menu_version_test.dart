import 'package:bitacora_web/screens/about_screen.dart';
import 'package:bitacora_web/start_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('open About from menu and render version row', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.onboarding_done.v1': true,
    });
    tester.view.physicalSize = const Size(1700, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: StartPage(isLight: true, onToggleTheme: _noop)),
    );
    await _pumpFrames(tester);

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis).first);
    await _pumpFrames(tester);
    await tester.tap(find.textContaining('Acerca').first);
    await _pumpFrames(tester);

    expect(find.text(AboutScreen.routeTitle), findsOneWidget);
    expect(find.text('Versión'), findsOneWidget);
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void _noop() {}
