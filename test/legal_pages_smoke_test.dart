import 'package:bitacora_web/screens/about_screen.dart';
import 'package:bitacora_web/screens/privacy_screen.dart';
import 'package:bitacora_web/screens/terms_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('About, Privacy and Terms screens build', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AboutScreen()),
    );
    await tester.pump();
    expect(find.text(AboutScreen.routeTitle), findsOneWidget);
    expect(find.text('Licencias'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: PrivacyScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text(PrivacyScreen.routeTitle), findsOneWidget);
    expect(find.text('Datos guardados'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: TermsScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text(TermsScreen.routeTitle), findsOneWidget);
    expect(find.text('Uso responsable'), findsOneWidget);
  });

  testWidgets('About screen opens licenses page', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AboutScreen()),
    );
    await tester.pump();
    await tester.tap(find.text('Licencias'));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
  });
}
