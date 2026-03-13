import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpMobileEditor(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'mobile-palette-button-test',
          initialHeaders: <String>['Col A', 'Col B', 'Fotos'],
          initialRows: <List<String>>[
            <String>['a', 'b', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mobile FAB exists and expands actions', (tester) async {
    await pumpMobileEditor(tester);

    expect(find.byKey(const ValueKey('mobile-fab-main')), findsOneWidget);

    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('mobile-fab-main')),
    );
    fab.onPressed?.call();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mobile-fab-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-fab-action-new-record')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-fab-action-add-row')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-fab-action-add-column')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-fab-action-smart-paste')),
        findsOneWidget);
  });

  testWidgets('mobile FAB closes on outside tap', (tester) async {
    await pumpMobileEditor(tester);

    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('mobile-fab-main')),
    );
    fab.onPressed?.call();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mobile-fab-panel')), findsOneWidget);

    final scrim = tester.widget<GestureDetector>(
      find.byKey(const ValueKey('mobile-fab-scrim')),
    );
    scrim.onTap?.call();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mobile-fab-panel')), findsNothing);
  });

  testWidgets('mobile FAB new record action inserts a row', (tester) async {
    await pumpMobileEditor(tester);
    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    final before = state.debugRowCount as int;

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

    expect(state.debugRowCount, before + 1);
  });
}
