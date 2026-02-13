import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpEditor(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'empty-state-test',
          initialHeaders: <String>['Fecha', 'Estado', 'Progresiva', 'Photos'],
          initialRows: <List<String>>[],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('premium empty state appears for empty sheet', (tester) async {
    await pumpEditor(tester);
    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    // ignore: avoid_print
    print('debugRowCount=${state.debugRowCount}');
    // ignore: avoid_print
    print('debugCell00=${state.debugCellText(0, 0)}');
    expect(
      find.byKey(const ValueKey('editor-premium-empty-state')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('empty-state-cta-new-record')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('empty-state-cta-smart-paste')),
        findsOneWidget);
    expect(
      find.byKey(const ValueKey('empty-state-cta-import-disabled')),
      findsOneWidget,
    );
  });

  testWidgets('empty state new record CTA inserts a row', (tester) async {
    await pumpEditor(tester);
    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    final before = state.debugRowCount as int;

    await tester.tap(find.byKey(const ValueKey('empty-state-cta-new-record')));
    await tester.pumpAndSettle();

    expect(state.debugRowCount, before + 1);
    expect(find.textContaining('Nuevo registro listo'), findsOneWidget);
  });
}
