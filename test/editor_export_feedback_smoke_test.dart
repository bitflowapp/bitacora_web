import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<dynamic> pumpEditor(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EditorScreen(
            sheetId: 'export_feedback_sheet',
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
    return tester.state(find.byType(EditorScreen));
  }

  testWidgets('share fallback reports saved file clearly', (tester) async {
    final dynamic state = await pumpEditor(tester);
    state.debugSetExportHooks(
      shareHook: (_) async => throw UnsupportedError('share not supported'),
      saveLocationHook: ({
        required String suggestedName,
        required List<XTypeGroup> acceptedTypeGroups,
      }) async =>
          const FileSaveLocation('/tmp/export-fallback.xlsx'),
      saveFileHook: (_, __) async {},
      persistShareTempFileHook: ({
        required String fileName,
        required bytes,
      }) async =>
          null,
    );

    await state.debugRunExportSaveFlowForTest(
      name: 'control_diario.xlsx',
      mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      share: true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      state.debugLastToastMessage(),
      contains('No pudimos abrir compartir. Guardamos control_diario.xlsx en'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('share fallback message adapts to PDF format', (tester) async {
    final dynamic state = await pumpEditor(tester);
    state.debugSetExportHooks(
      shareHook: (_) async => throw UnsupportedError('share not supported'),
      saveLocationHook: ({
        required String suggestedName,
        required List<XTypeGroup> acceptedTypeGroups,
      }) async =>
          const FileSaveLocation('/tmp/export-fallback.pdf'),
      saveFileHook: (_, __) async {},
      persistShareTempFileHook: ({
        required String fileName,
        required bytes,
      }) async =>
          null,
    );

    await state.debugRunExportSaveFlowForTest(
      name: 'control_diario.pdf',
      mime: 'application/pdf',
      share: true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      state.debugLastToastMessage(),
      contains('No pudimos abrir compartir. Guardamos control_diario.pdf en'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('share success says that the share sheet was opened',
      (tester) async {
    final dynamic state = await pumpEditor(tester);
    state.debugSetExportHooks(
      shareHook: (_) async {},
      persistShareTempFileHook: ({
        required String fileName,
        required bytes,
      }) async =>
          null,
    );

    await state.debugRunExportSaveFlowForTest(
      name: 'control_diario.pdf',
      mime: 'application/pdf',
      share: true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      state.debugLastToastMessage(),
      contains('Abrimos compartir para control_diario.pdf'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile export says that system options were opened',
      (tester) async {
    final dynamic state = await pumpEditor(tester);
    state.debugSetExportHooks(
      shareHook: (_) async {},
      persistShareTempFileHook: ({
        required String fileName,
        required bytes,
      }) async =>
          null,
    );

    await state.debugRunExportSaveFlowForTest(
      name: 'control_diario.xlsx',
      mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      share: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      state.debugLastToastMessage(),
      contains(
        'Abrimos las opciones del sistema para guardar o compartir control_diario.xlsx',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('export fallback save feedback says where the file was written',
      (tester) async {
    final dynamic state = await pumpEditor(tester);
    state.debugSetExportHooks(
      shareHook: (_) async => throw UnsupportedError('share not supported'),
      saveLocationHook: ({
        required String suggestedName,
        required List<XTypeGroup> acceptedTypeGroups,
      }) async =>
          const FileSaveLocation('/tmp/cierre/control_diario.xlsx'),
      saveFileHook: (_, __) async {},
      persistShareTempFileHook: ({
        required String fileName,
        required bytes,
      }) async =>
          null,
    );

    await state.debugRunExportSaveFlowForTest(
      name: 'control_diario.xlsx',
      mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      share: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      state.debugLastToastMessage(),
      contains('Excel guardado en /tmp/cierre/control_diario.xlsx'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('export failure reports a clear non-technical message',
      (tester) async {
    final dynamic state = await pumpEditor(tester);
    state.debugSetExportHooks(
      shareHook: (_) async => throw UnsupportedError('share not supported'),
      saveLocationHook: ({
        required String suggestedName,
        required List<XTypeGroup> acceptedTypeGroups,
      }) async =>
          throw Exception('disk full'),
      persistShareTempFileHook: ({
        required String fileName,
        required bytes,
      }) async =>
          null,
    );

    await state.debugRunExportSaveFlowForTest(
      name: 'control_diario.xlsx',
      mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      share: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      state.debugLastErrorFeedbackMessage(),
      contains('No pudimos dejar listo el Excel.'),
    );
  });
}
