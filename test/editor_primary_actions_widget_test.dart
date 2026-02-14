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
          sheetId: 'primary-actions-test',
          initialHeaders: <String>['Fecha', 'Estado', 'Progresiva', 'Photos'],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('primary new record action inserts a real row (not no-op)',
      (tester) async {
    await pumpEditor(tester);

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    final initialRowCount = state.debugRowCount as int;

    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('mobile-fab-main')),
    );
    fab.onPressed?.call();
    await tester.pumpAndSettle();
    final action = tester.widget(
      find.byKey(const ValueKey('mobile-fab-action-new-record')),
    ) as dynamic;
    action.onPressed?.call();
    await tester.pumpAndSettle();

    expect(state.debugRowCount, initialRowCount + 1);
    expect(find.textContaining('Nuevo registro listo'), findsOneWidget);
  });

  testWidgets('new record undo removes the inserted row', (tester) async {
    await pumpEditor(tester);

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    final initialRowCount = state.debugRowCount as int;

    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('mobile-fab-main')),
    );
    fab.onPressed?.call();
    await tester.pumpAndSettle();
    final action = tester.widget(
      find.byKey(const ValueKey('mobile-fab-action-new-record')),
    ) as dynamic;
    action.onPressed?.call();
    await tester.pumpAndSettle();

    expect(state.debugRowCount, initialRowCount + 1);
    expect(find.text('Deshacer'), findsOneWidget);

    await tester.tap(find.text('Deshacer').first);
    await tester.pumpAndSettle();

    expect(state.debugRowCount, initialRowCount);
  });
}
