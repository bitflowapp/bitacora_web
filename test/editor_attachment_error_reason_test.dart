import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('attachment failure shows friendly message and detail action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: EditorScreen(sheetId: 'attachment-error-reason')),
    );
    await tester.pump();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    state.debugEmitAttachmentErrorFeedback(
      code: 'storage_blocked',
      detail: 'cause=storage_blocked\nua=test',
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      (state.debugLastErrorFeedbackMessage() ?? '').toString(),
      allOf(
        contains('almacenamiento local'),
        isNot(contains('storage_blocked')),
      ),
    );
    expect(find.text('Ver detalle tecnico'), findsOneWidget);
  });
}
