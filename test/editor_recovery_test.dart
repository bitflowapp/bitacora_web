import 'dart:convert';

import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Editor restores from backup payload when current is corrupted',
      (tester) async {
    final backup = <String, Object>{
      'name': 'Recovered',
      'savedAt': '2026-02-07T10:00:00.000Z',
      'headers': <String>['A', 'Fotos'],
      'colIds': <String>['col_a', 'col_photos'],
      'rows': <Map<String, Object>>[
        <String, Object>{
          'id': 'row_1',
          'cells': <String>['restored', ''],
          'photos': <Object>[],
        },
      ],
    };

    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow:sheet:recovery-sheet': '{broken json',
      'bitflow:sheet:recovery-sheet:backup': jsonEncode(backup),
    });

    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(sheetId: 'recovery-sheet'),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    expect(state.debugCellText(0, 0), 'restored');
  });
}
