import 'package:bitacora_web/screens/landing_screen.dart';
import 'package:bitacora_web/screens/premium_screen.dart';
import 'package:bitacora_web/services/sheet_store.dart';
import 'package:bitacora_web/start_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const mobileSize = Size(390, 844);

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

  void setMobileViewport(WidgetTester tester) {
    tester.view.physicalSize = mobileSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Landing screen supports text scales without overflow errors',
      (tester) async {
    setMobileViewport(tester);

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

  testWidgets('Landing shows sell CTAs on mobile width', (tester) async {
    setMobileViewport(tester);
    await pumpWithScale(
      tester,
      scale: 1.0,
      home: const LandingScreen(
        isLight: true,
        onToggleTheme: _noop,
      ),
    );
    expect(find.byKey(const Key('landing-cta-hero-primary')), findsOneWidget);
    expect(find.byKey(const Key('landing-cta-hero-whatsapp')), findsOneWidget);
  });

  testWidgets('Premium screen supports text scales without overflow errors',
      (tester) async {
    setMobileViewport(tester);

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

  testWidgets('Premium shows checkout CTA on mobile width', (tester) async {
    setMobileViewport(tester);
    await pumpWithScale(
      tester,
      scale: 1.0,
      home: const PremiumScreen(),
    );
    expect(find.byKey(const ValueKey<String>('premium-plan-Pro mensual')),
        findsOneWidget);
  });

  testWidgets('Start page supports text scales without overflow errors',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.onboarding_done.v1': true,
    });
    await SheetStore.init();
    setMobileViewport(tester);

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

  testWidgets('Start page keeps create CTA visible on mobile width',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.onboarding_done.v1': true,
    });
    await SheetStore.init();
    setMobileViewport(tester);
    await pumpWithScale(
      tester,
      scale: 1.0,
      home: const StartPage(
        isLight: true,
        onToggleTheme: _noop,
      ),
    );
    expect(find.byKey(const Key('start-create-sheet-fab')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
