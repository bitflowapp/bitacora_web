import 'package:bitacora_web/services/app_decor_policy.dart';
import 'package:bitacora_web/services/sheet_store.dart';
import 'package:bitacora_web/start_page.dart';
import 'package:bitacora_web/widgets/animated_video_background.dart';
import 'package:bitacora_web/widgets/app_background_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppDecorPolicy.debugDecorativeBackgroundOverride = null;
  });

  tearDown(() {
    AppDecorPolicy.debugDecorativeBackgroundOverride = null;
  });

  testWidgets('web decor policy disables decorative background layers',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.onboarding_done.v1': true,
      'bitflow.demo_mode_enabled.v1': true,
    });
    await SheetStore.init();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    AppDecorPolicy.debugDecorativeBackgroundOverride = false;
    expect(AppDecorPolicy.enableDecorativeBackground, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: AppBackgroundShell(
          disableDecorativeBackground:
              AppDecorPolicy.disableDecorativeBackground,
          backgroundColor: const Color(0xFFF5EFE4),
          debugLayerName: 'test-shell',
          child: const StartPage(
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
    final alpha = (baseFill.color.a * 255.0).round() & 0xff;
    expect(alpha, equals(0xFF));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void _noop() {}
