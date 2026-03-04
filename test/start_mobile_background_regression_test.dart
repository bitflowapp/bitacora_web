import 'package:bitacora_web/services/sheet_store.dart';
import 'package:bitacora_web/services/web_capabilities.dart';
import 'package:bitacora_web/start_page.dart';
import 'package:bitacora_web/widgets/animated_video_background.dart';
import 'package:bitacora_web/widgets/app_background_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    WebCapabilities.debugMobileWebUiOverride = null;
  });

  tearDown(() {
    WebCapabilities.debugMobileWebUiOverride = null;
  });

  testWidgets('mobile web mode disables decorative background layers',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.onboarding_done.v1': true,
      'bitflow.demo_mode_enabled.v1': true,
    });
    await SheetStore.init();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    WebCapabilities.debugMobileWebUiOverride = true;
    expect(WebCapabilities.isMobileWebUi(shortestSide: 390), isTrue);

    await tester.pumpWidget(
      const MaterialApp(
        home: AppBackgroundShell(
          disableDecorativeBackground: true,
          backgroundColor: Color(0xFFF5EFE4),
          debugLayerName: 'test-shell',
          child: StartPage(
            isLight: true,
            onToggleTheme: _noop,
          ),
        ),
      ),
    );

    await _pumpFrames(tester);

    expect(find.byType(AnimatedVideoBackground), findsNothing);
    expect(find.byKey(const ValueKey('start-hero-backdrop-art')), findsNothing);

    final baseFill = tester
        .widget<ColoredBox>(find.byKey(const ValueKey('start-base-fill')));
    expect(baseFill.color.alpha, equals(0xFF));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void _noop() {}
