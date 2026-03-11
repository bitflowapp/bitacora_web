import 'package:bitacora_web/screens/landing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('landing renders BitFlow commercial copy without exceptions',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LandingScreen(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('BitFlow'), findsWidgets);
    expect(
      find.text('Planillas operativas con evidencias en un solo lugar'),
      findsOneWidget,
    );
    expect(find.text('Probar ahora'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
