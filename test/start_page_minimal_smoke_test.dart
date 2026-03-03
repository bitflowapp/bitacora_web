import 'package:bitacora_web/services/sheet_store.dart';
import 'package:bitacora_web/start_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('StartPage renders primary CTA, daily zone and collapsed Pro',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.onboarding_done.v1': true,
      'bitflow.demo_mode_enabled.v1': true,
    });

    await SheetStore.init();
    final a = SheetStore.createNew();
    final b = SheetStore.createNew();
    final c = SheetStore.createNew();
    SheetStore.rename(a, 'Smoke Sheet A');
    SheetStore.rename(b, 'Smoke Sheet B');
    SheetStore.rename(c, 'Smoke Sheet C');

    await tester.pumpWidget(
      const MaterialApp(
        home: StartPage(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );

    await _pumpFrames(tester);

    expect(find.byKey(const ValueKey('start-primary-new')), findsOneWidget);
    expect(find.byKey(const ValueKey('start-primary-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('start-daily-zone')), findsOneWidget);
    expect(find.text('Recientes'), findsOneWidget);
    expect(find.text('Favoritas'), findsOneWidget);
    expect(find.text('Smoke Sheet A'), findsOneWidget);
    expect(find.byKey(const ValueKey('start-pro-disclosure')), findsOneWidget);
    expect(find.text('Activar Pro'), findsNothing);
    expect(find.byKey(const ValueKey('start-pro-benefits')), findsNothing);

    final backdropOpacity =
        find.byKey(const ValueKey('start-hero-backdrop-opacity'));
    if (backdropOpacity.evaluate().isNotEmpty) {
      final widget = tester.widget<Opacity>(backdropOpacity.first);
      expect(widget.opacity, lessThanOrEqualTo(0.10));
    }

    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void _noop() {}
