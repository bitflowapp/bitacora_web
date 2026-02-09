import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/screens/sheets_screen.dart';
import 'package:bitacora_web/screens/start_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpMaterialWithScale(
    WidgetTester tester, {
    required Widget home,
    required double scale,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          );
        },
        home: home,
      ),
    );
  }

  Future<void> pumpCupertinoWithScale(
    WidgetTester tester, {
    required Widget home,
    required double scale,
  }) async {
    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          );
        },
        home: home,
      ),
    );
  }

  testWidgets('Key pages build with large text scale factors', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1700, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final scale in <double>[1.3, 1.6]) {
      await pumpMaterialWithScale(
        tester,
        scale: scale,
        home: const SheetsScreen(
          isLight: true,
          onToggleTheme: _noop,
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(SheetsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpMaterialWithScale(
        tester,
        scale: scale,
        home: const EditorScreen(
          sheetId: 'scale-test-sheet',
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(EditorScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpCupertinoWithScale(
        tester,
        scale: scale,
        home: const StartPage(
          isLight: true,
          onToggleTheme: _noop,
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(StartPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

void _noop() {}
