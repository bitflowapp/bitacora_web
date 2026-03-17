import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/ui/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('export dialog exposes xlsx pdf and zip presets', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EditorScreen(
            sheetId: 'export_dialog_sheet',
            initialName: 'Control Diario',
            initialHeaders: <String>['Actividad', 'Estado'],
            initialRows: <List<String>>[
              <String>['Inspeccion', 'OK'],
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 800));

    final dynamic state = tester.state(find.byType(EditorScreen));
    state.debugOpenExportMenuForTest();
    await tester.pumpAndSettle();

    expect(find.text('Excel (.xlsx)'), findsOneWidget);
    expect(find.text('Reporte PDF (.pdf)'), findsOneWidget);
    expect(find.text('Paquete completo (.ZIP)'), findsOneWidget);
    expect(
      find.textContaining('Reporte PDF (.pdf): listo para presentar'),
      findsOneWidget,
    );

    await tester.tap(find.text('Paquete completo (.ZIP)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Archivo: BitFlow_'), findsOneWidget);
    expect(
      find.textContaining('Paquete completo (.zip): planilla + evidencias'),
      findsOneWidget,
    );
    expect(find.text('Exportar paquete ZIP'), findsOneWidget);
    expect(find.text('Compartir paquete ZIP'), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-export-submit')), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-export-share')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'export dialog disables actions while another operation is running',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EditorScreen(
            sheetId: 'export_dialog_busy_sheet',
            initialName: 'Control Diario',
            initialHeaders: <String>['Actividad', 'Estado'],
            initialRows: <List<String>>[
              <String>['Inspeccion', 'OK'],
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 800));

    final dynamic state = tester.state(find.byType(EditorScreen));
    state.debugShowOperationProgress();
    state.debugOpenExportMenuForTest();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final exportButton = tester.widget<AppButton>(
      find.byKey(const ValueKey('editor-export-submit')),
    );
    final shareButton = tester.widget<AppButton>(
      find.byKey(const ValueKey('editor-export-share')),
    );

    expect(exportButton.onPressed, isNull);
    expect(shareButton.onPressed, isNull);
    expect(
      find.textContaining('Ya hay una operaci\u00f3n en curso'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
