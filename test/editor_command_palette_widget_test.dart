import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpEditor(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1700, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'command-palette-test',
          initialHeaders: <String>['Fecha', 'Estado', 'Progresiva', 'Photos'],
          initialRows: <List<String>>[
            <String>['2026-02-13', 'OK', '1200', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('command palette executes Nuevo registro', (
    tester,
  ) async {
    await pumpEditor(tester);
    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    final before = state.debugRowCount as int;

    state.debugOpenCommandPalette();
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('command_palette_dialog')), findsOneWidget);

    final searchFinder = find.byKey(const ValueKey('command_palette_search'));
    expect(searchFinder, findsOneWidget);
    await tester.enterText(searchFinder, 'Nuevo registro');
    await tester.pumpAndSettle();

    final actionFinder =
        find.byKey(const ValueKey('command_palette_action_create_row'));
    expect(actionFinder, findsOneWidget);
    await tester.tap(actionFinder);
    await tester.pumpAndSettle();

    expect(state.debugRowCount, before + 1);
    expect(find.textContaining('Nuevo registro listo'), findsOneWidget);
  });
}
