import 'package:bitacora_web/start_page.dart';
import 'package:bitacora_web/widgets/animated_video_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('StartPage keeps opaque base and no decorative background',
      (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    final theme = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const StartPage(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AnimatedVideoBackground), findsNothing);
    expect(find.byKey(const ValueKey('start-hero-backdrop-art')), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    // ignore: deprecated_member_use
    expect(scaffold.backgroundColor, theme.colorScheme.background);

    final fill = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('start-base-fill')),
    );
    expect((fill.color.a * 255).round(), 255);
  });
}

void _noop() {}
