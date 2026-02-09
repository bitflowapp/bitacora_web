import 'package:bitacora_web/screens/about_screen.dart';
import 'package:bitacora_web/screens/diagnostics_screen.dart';
import 'package:bitacora_web/screens/privacy_screen.dart';
import 'package:bitacora_web/screens/sheets_screen.dart';
import 'package:bitacora_web/screens/terms_screen.dart';
import 'package:bitacora_web/services/sheet_store.dart';
import 'package:bitacora_web/start_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Start menu routes About/Privacy/Terms/Diagnostics/Licenses',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.onboarding_done.v1': true,
    });
    await SheetStore.init();
    tester.view.physicalSize = const Size(1700, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StartPage(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );
    await _pumpFrames(tester);

    await _openStartMenu(tester);
    await tester.tap(find.textContaining('Acerca').first);
    await _pumpFrames(tester);
    expect(find.text(AboutScreen.routeTitle), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await _pumpFrames(tester);

    await _openStartMenu(tester);
    await tester.tap(find.text('Privacidad').first);
    await _pumpFrames(tester);
    expect(find.text(PrivacyScreen.routeTitle), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await _pumpFrames(tester);

    await _openStartMenu(tester);
    await tester.tap(find.textContaining('rminos').first);
    await _pumpFrames(tester);
    expect(find.text(TermsScreen.routeTitle), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await _pumpFrames(tester);

    await _openStartMenu(tester);
    await tester.tap(find.textContaining('Diagn').first);
    await _pumpFrames(tester);
    expect(find.text(DiagnosticsScreen.routeTitle), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await _pumpFrames(tester);

    await _openStartMenu(tester);
    await tester.tap(find.textContaining('Licencias').first);
    await _pumpFrames(tester);
    expect(find.byType(LicensePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sheets menu routes About/Privacy/Terms/Diagnostics/Licenses',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SheetStore.init();
    tester.view.physicalSize = const Size(1700, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: SheetsScreen(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );
    await _pumpFrames(tester);

    await _openSheetsInfoMenu(tester);
    await tester.tap(find.textContaining('Acerca').first);
    await _pumpFrames(tester);
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await _pumpFrames(tester);

    await _openSheetsInfoMenu(tester);
    await tester.tap(find.text('Privacidad').first);
    await _pumpFrames(tester);
    expect(find.byType(PrivacyScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await _pumpFrames(tester);

    await _openSheetsInfoMenu(tester);
    await tester.tap(find.textContaining('rminos').first);
    await _pumpFrames(tester);
    expect(find.byType(TermsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await _pumpFrames(tester);

    await _openSheetsInfoMenu(tester);
    await tester.tap(find.textContaining('Diagn').first);
    await _pumpFrames(tester);
    expect(find.byType(DiagnosticsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await _pumpFrames(tester);

    await _openSheetsInfoMenu(tester);
    await tester.tap(find.textContaining('Licencias').first);
    await _pumpFrames(tester);
    expect(find.byType(LicensePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openStartMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(CupertinoIcons.ellipsis).first);
  await _pumpFrames(tester);
}

Future<void> _openSheetsInfoMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
  await _pumpFrames(tester);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void _noop() {}
