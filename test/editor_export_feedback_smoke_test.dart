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
      contains(
          'No pudimos abrir la opción de compartir. El archivo ya quedó listo:'),
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
      contains(
          'No pudimos abrir la opción de compartir. El archivo ya quedó listo:'),
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
      contains('No pudimos completar la operación.'),
    );
  });
}
