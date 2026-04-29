import 'package:bitacora_web/services/sheet_store.dart';
import 'package:bitacora_web/screens/landing_screen.dart';
import 'package:bitacora_web/start_page_v2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('StartPageV2 renders on Android phone constraints',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SheetStore.init();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StartPageV2(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bit Flow'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LandingScreen renders on Android phone constraints',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: LandingScreen(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Planillas de campo'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
