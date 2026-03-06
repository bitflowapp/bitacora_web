import 'package:bitacora_web/services/sheet_store.dart';
import 'package:bitacora_web/start_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('recent sheet quick menu exposes duplicate and share actions',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.onboarding_done.v1': true,
    });
    await SheetStore.init();
    final sheetId = SheetStore.createNew();
    SheetStore.rename(sheetId, 'Quick Menu Sheet');

    await tester.pumpWidget(
      const MaterialApp(
        home: StartPage(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );

    await _pumpFrames(tester);
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('start-sheet-more-$sheetId')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester
        .ensureVisible(find.byKey(ValueKey('start-sheet-more-$sheetId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('start-sheet-more-$sheetId')));
    await tester.pumpAndSettle();

    expect(find.text('Duplicar'), findsOneWidget);
    expect(find.text('Compartir por link'), findsOneWidget);
    expect(find.text('Exportar XLSX'), findsOneWidget);
    expect(find.text('Renombrar'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplicating a sheet keeps copy names unique', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.onboarding_done.v1': true,
    });
    await SheetStore.init();
    final sourceId = SheetStore.createNew();
    final existingCopyId = SheetStore.createNew();
    SheetStore.rename(sourceId, 'Budget');
    SheetStore.rename(existingCopyId, 'Budget (copia)');

    await tester.pumpWidget(
      const MaterialApp(
        home: StartPage(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );

    await _pumpFrames(tester);
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('start-sheet-more-$sourceId')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(ValueKey('start-sheet-more-$sourceId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicar'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(
      SheetStore.list().where((sheet) => sheet.title == 'Budget (copia 2)'),
      isNotEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('move to trash confirmation uses clear retention copy',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.onboarding_done.v1': true,
    });
    await SheetStore.init();
    final sheetId = SheetStore.createNew();
    SheetStore.rename(sheetId, 'Delete Me');

    await tester.pumpWidget(
      const MaterialApp(
        home: StartPage(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );

    await _pumpFrames(tester);
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('start-sheet-more-$sheetId')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(ValueKey('start-sheet-more-$sheetId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mover a papelera'));
    await tester.pumpAndSettle();

    expect(find.text('Mover a papelera'), findsWidgets);
    expect(
      find.textContaining('Podras recuperarla durante 14 dias'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void _noop() {}
