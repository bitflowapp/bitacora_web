import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Editor shows load error feedback when local data is invalid',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(sheetId: 'broken-load'),
      ),
    );

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    state.debugEmitLoadErrorFeedback('invalid json payload');

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      state.debugLastErrorFeedbackMessage(),
      'No pudimos abrir la planilla porque los datos estan danados.',
    );
  });
}
