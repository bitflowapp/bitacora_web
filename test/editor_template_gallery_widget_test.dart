import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('template gallery applies Inventario template', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'template-gallery-test',
          initialHeaders: <String>['Fecha', 'Estado', 'Progresiva', 'Photos'],
          initialRows: <List<String>>[],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const ValueKey('empty-state-cta-template')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('template-item-inventario')));
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    expect(state.debugRowCount, greaterThan(0));
    expect(state.debugCellText(0, 0), 'MAT-001');
  });
}
