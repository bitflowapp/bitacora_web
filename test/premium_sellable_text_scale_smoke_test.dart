import 'package:bitacora_web/screens/landing_screen.dart';
import 'package:bitacora_web/screens/premium_screen.dart';
import 'package:bitacora_web/services/sheet_store.dart';
import 'package:bitacora_web/start_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpWithScale(
    WidgetTester tester, {
    required Widget home,
    required double scale,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          );
        },
        home: home,
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('Landing screen supports text scales without overflow errors',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final scale in <double>[1.0, 1.3, 1.6]) {
      await pumpWithScale(
        tester,
        scale: scale,
        home: const LandingScreen(
          isLight: true,
          onToggleTheme: _noop,
        ),
      );
      expect(find.byType(LandingScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Premium screen supports text scales without overflow errors',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final scale in <double>[1.0, 1.3, 1.6]) {
      await pumpWithScale(
        tester,
        scale: scale,
        home: const PremiumScreen(),
      );
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Start page supports text scales without overflow errors',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.onboarding_done.v1': true,
    });
    await SheetStore.init();
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final scale in <double>[1.0, 1.3, 1.6]) {
      await pumpWithScale(
        tester,
        scale: scale,
        home: const StartPage(
          isLight: true,
          onToggleTheme: _noop,
        ),
      );
      expect(find.byType(StartPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

void _noop() {}
