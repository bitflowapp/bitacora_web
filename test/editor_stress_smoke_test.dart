import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Editor handles burst edits and scroll without exceptions',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final headers = List<String>.generate(8, (i) => 'Col ${i + 1}');
    final rows = List<List<String>>.generate(
      140,
      (r) => List<String>.generate(8, (c) => 'R${r + 1}C${c + 1}'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(
          sheetId: 'editor-stress',
          initialHeaders: headers,
          initialRows: rows,
        ),
      ),
    );
    await tester.pump();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;

    for (int i = 0; i < 72; i++) {
      final row = i % 120;
      final col = i % 6;
      state.debugApplyGpsFixToCell(
        row,
        col,
        lat: -38.95 + (i * 0.0001),
        lng: -68.06 - (i * 0.0001),
        accuracyM: (8 + (i % 5)).toDouble(),
        timestamp: DateTime(2026, 2, 7, 12, 0, i % 60),
        writeText: true,
      );

      if (i % 8 == 0) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -260));
      } else if (i % 8 == 4) {
        await tester.drag(find.byType(ListView).first, const Offset(0, 220));
      }

      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(EditorScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
