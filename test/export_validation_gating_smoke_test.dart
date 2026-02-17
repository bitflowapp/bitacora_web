import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('export shows validation gating modal when there are errors',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EditorScreen(
            sheetId: 'export_gating_sheet',
            initialHeaders: <String>['Actividad', 'Estado', 'Fotos'],
            initialRows: <List<String>>[
              <String>['', '', ''],
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 800));

    final dynamic state = tester.state(find.byType(EditorScreen));
    state.debugConfirmExportValidationGateForTest();
    await tester.pumpAndSettle();

    expect(find.text('Hay errores de validacion'), findsOneWidget);
    expect(find.text('Exportar igual'), findsOneWidget);
    expect(find.text('Ir a errores'), findsOneWidget);
  });
}

