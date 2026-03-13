import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/services/sheet_store.dart';
import 'package:bitacora_web/start_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpStart(
    WidgetTester tester, {
    Future<void> Function()? seed,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.onboarding_done.v1': true,
      'bitflow.demo_mode_enabled.v1': true,
    });
    await SheetStore.init();
    if (seed != null) {
      await seed();
    }
    await tester.pumpWidget(
      const MaterialApp(
        home: StartPage(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('abrir reciente opens expected sheet', (tester) async {
    late String expectedId;
    await pumpStart(
      tester,
      seed: () async {
        final idA = SheetStore.createNew();
        final idB = SheetStore.createNew();
        SheetStore.rename(idA, 'Sheet A');
        SheetStore.rename(idB, 'Sheet B');
        expectedId = SheetStore.list().first.id;
      },
    );

    await tester.tap(find.byKey(const ValueKey('start-primary-open-recent')));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.byType(EditorScreen), findsOneWidget);
    final opened = tester.widget<EditorScreen>(find.byType(EditorScreen));
    expect(opened.sheetId, expectedId);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recent stale sheet shows clear not found feedback',
      (tester) async {
    late String staleId;
    await pumpStart(
      tester,
      seed: () async {
        staleId = SheetStore.createNew();
        SheetStore.rename(staleId, 'To Delete');
      },
    );

    // Simulate stale recent: deleted after list rendered.
    SheetStore.delete(staleId);

    await tester.tap(find.byKey(const ValueKey('start-primary-open-recent')));
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('No encontramos el archivo reciente.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history shortcut is visible and opens command palette',
      (tester) async {
    await pumpStart(
      tester,
      seed: () async {
        SheetStore.createNew();
      },
    );

    expect(find.byKey(const ValueKey('start-primary-history')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('start-history-open-all')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('start-history-open-all')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('command_palette_dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
