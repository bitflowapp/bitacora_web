import 'package:bitacora_web/start_page_v2.dart';
import 'package:bitacora_web/widgets/animated_video_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('StartPageV2 keeps opaque base and no decorative background',
      (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: const StartPageV2(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AnimatedVideoBackground), findsNothing);
    expect(find.byKey(const ValueKey('start-hero-backdrop-art')), findsNothing);

    final fill = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('start-base-fill')),
    );
    expect((fill.color.a * 255).round(), 255);
  });
}

void _noop() {}
