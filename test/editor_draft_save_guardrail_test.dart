import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('save persists cell draft without explicit commit',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const sheetId = 'draft-save-guardrail';

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: sheetId,
          initialHeaders: ['Col 1', 'Photos'],
          initialRows: [
            ['valor inicial', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    state.debugSetCellDraft(0, 0, 'draft sin commit');

    await state.debugSaveNow();
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      const MaterialApp(home: EditorScreen(sheetId: sheetId)),
    );
    await tester.pumpAndSettle();

    final reloaded = tester.state(find.byType(EditorScreen)) as dynamic;
    expect(reloaded.debugCellText(0, 0), 'draft sin commit');
  });
}
