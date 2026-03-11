import 'package:bitacora_web/start_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.onboarding_done.v1': true,
      'bitflow.demo_mode_enabled.v1': true,
    });
  });

  testWidgets('menu de tres puntos muestra X y cierra al tocarla',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const StartPage(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-more-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('start-more-close-x')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('start-more-close-x')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('start-more-close-x')), findsNothing);
  });

  testWidgets('menu de tres puntos usa contenido scrolleable en viewport chico',
      (tester) async {
    tester.view.physicalSize = const Size(320, 520);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const StartPage(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start-more-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('start-more-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
