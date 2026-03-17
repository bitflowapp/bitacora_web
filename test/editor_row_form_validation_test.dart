import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/ui/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('row form blocks save until required fields are valid',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EditorScreen(
            sheetId: 'row_form_validation_sheet',
            initialHeaders: <String>['Fecha', 'Actividad', 'Fotos'],
            initialRows: <List<String>>[
              <String>['', '', ''],
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 800));

    final dynamic state = tester.state(find.byType(EditorScreen));
    state.debugOpenRowFormForTest(rowIndex: 0);
    await tester.pumpAndSettle();

    expect(find.textContaining('Formulario - fila 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('row-form-quality')), findsOneWidget);
    expect(find.textContaining('Obligatorio'), findsWidgets);

    AppButton saveButton = tester.widget<AppButton>(
      find.byKey(const ValueKey('row-form-save')),
    );
    expect(saveButton.onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('row-form-field-0')),
      '17/03/2026',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('row-form-field-1')),
      'Inspeccion',
    );
    await tester.pumpAndSettle();

    saveButton = tester.widget<AppButton>(
      find.byKey(const ValueKey('row-form-save')),
    );
    expect(saveButton.onPressed, isNotNull);
    expect(find.text('Formulario listo para guardar.'), findsOneWidget);
  });
}
