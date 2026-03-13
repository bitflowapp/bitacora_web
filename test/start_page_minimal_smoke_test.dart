import 'package:bitacora_web/services/sheet_store.dart';
import 'package:bitacora_web/start_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('StartPage renders productivity control center sections',
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
    expect(find.byKey(const ValueKey('start-primary-open-recent')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('start-primary-history')), findsOneWidget);
    expect(find.byKey(const ValueKey('start-primary-search')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('start-primary-automate')), findsOneWidget);
    expect(find.byKey(const ValueKey('start-more-button')), findsOneWidget);
    expect(find.text('Acciones principales'), findsOneWidget);
    expect(find.text('Nueva planilla'), findsOneWidget);
    expect(find.text('Abrir reciente'), findsOneWidget);
    expect(find.text('Todas las planillas'), findsOneWidget);
    expect(find.text('Buscar archivos'), findsOneWidget);
    expect(find.text('Plantillas'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('start-continue-work')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Trabajo reciente'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('start-history-open-all')), findsOneWidget);
    expect(find.text('Smoke Sheet A'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('start-automation-zone')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('start-automation-zone')), findsOneWidget);
    expect(find.text('Sugerencias'), findsOneWidget);
    expect(find.byKey(const ValueKey('start-pro-disclosure')), findsNothing);

    final baseFill = tester
        .widget<ColoredBox>(find.byKey(const ValueKey('start-base-fill')));
    expect(baseFill.color.a, closeTo(1.0, 0.0001));

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
