import 'package:bitacora_web/screens/sheets_screen.dart';
import 'package:bitacora_web/services/sheet_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('template gallery collapses to one column on narrow mobile',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SheetStore.init();

    tester.view.physicalSize = const Size(390, 844);
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

    await tester.ensureVisible(find.text('Plantillas').first);
    await tester.tap(find.text('Plantillas').first);
    await tester.pumpAndSettle();

    expect(find.text('Galer\u00eda de plantillas'), findsOneWidget);

    final grid = tester.widget<GridView>(
      find.byKey(const ValueKey('sheets-template-gallery-grid')),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(delegate.crossAxisCount, 1);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void _noop() {}
