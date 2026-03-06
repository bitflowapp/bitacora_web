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

    await state.debugTriggerExportForTest(
      format: 'xlsx',
      share: true,
      includeAttachments: false,
    );
    await tester.pumpAndSettle();

    expect(
      state.debugLastToastMessage(),
      contains('No pudimos abrir compartir. Archivo listo:'),
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

    await state.debugTriggerExportForTest(
      format: 'xlsx',
      share: false,
      includeAttachments: false,
    );
    await tester.pumpAndSettle();

    expect(
      state.debugLastErrorFeedbackMessage(),
      contains('No pudimos exportar el XLSX.'),
    );
  });
}
