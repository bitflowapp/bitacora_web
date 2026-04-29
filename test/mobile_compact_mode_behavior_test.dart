import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile compact mode gates top-bar auto-hide', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'mobile-compact-mode',
          initialHeaders: <String>['Notas', 'Fotos'],
          initialRows: <List<String>>[
            <String>['A', ''],
            <String>['B', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;

    state.debugSetMobileCompactMode(true);
    state.debugSimulateMobileScrollDirection(ScrollDirection.reverse);
    await tester.pump();
    expect(state.debugMobileTopBarCollapsed, isTrue);

    state.debugSetMobileCompactMode(false);
    state.debugSimulateMobileScrollDirection(ScrollDirection.reverse);
    await tester.pump();
    expect(state.debugMobileTopBarCollapsed, isFalse);
    expect(state.debugMobileCompactModeEnabled, isFalse);
  });

  testWidgets('zen mode keeps top bar collapsed until explicitly disabled',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'mobile-zen-mode',
          initialHeaders: <String>['Notas', 'Fotos'],
          initialRows: <List<String>>[
            <String>['A', ''],
            <String>['B', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;

    state.debugSetZenMode(true);
    await tester.pump();
    expect(state.debugZenModeEnabled, isTrue);
    expect(state.debugMobileTopBarCollapsed, isTrue);

    state.debugSimulateMobileScrollDirection(ScrollDirection.forward);
    await tester.pump();
    expect(state.debugMobileTopBarCollapsed, isTrue);

    state.debugSetZenMode(false);
    await tester.pump();
    expect(state.debugZenModeEnabled, isFalse);
    expect(state.debugMobileTopBarCollapsed, isFalse);
  });

  testWidgets('compact mode remains stable with high text scale',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          );
        },
        home: const EditorScreen(
          sheetId: 'mobile-compact-text-scale',
          initialHeaders: <String>['Notas', 'Fotos'],
          initialRows: <List<String>>[
            <String>['A', ''],
            <String>['B', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    state.debugSetMobileCompactMode(true);

    state.debugSimulateMobileScrollDirection(ScrollDirection.reverse);
    await tester.pump();
    expect(state.debugMobileTopBarCollapsed, isTrue);

    state.debugSimulateMobileScrollDirection(ScrollDirection.forward);
    await tester.pump();
    expect(state.debugMobileTopBarCollapsed, isFalse);
    expect(tester.takeException(), isNull);
  });
}
