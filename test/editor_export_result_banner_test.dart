import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<dynamic> pumpEditor(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EditorScreen(
            sheetId: 'export-result-banner-sheet',
            initialName: 'Control Diario',
            initialHeaders: <String>['Actividad', 'Estado', 'Fotos'],
            initialRows: <List<String>>[
              <String>['Inspeccion', 'OK', ''],
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 800));
    return tester.state(find.byType(EditorScreen));
  }

  testWidgets('share opened keeps a persistent export result visible',
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

    final banner = find.byKey(const ValueKey('export-flow-result-banner'));
    expect(banner, findsOneWidget);
    expect(find.text('Compartir abierto'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('export-flow-result-file')), findsOneWidget);
    expect(
      find.descendant(
        of: banner,
        matching: find.textContaining('control_diario.pdf'),
      ),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('export-flow-result-action-retryShare')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('export-flow-result-action-continueEditing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('export-flow-result-action-closeEditor')),
      findsOneWidget,
    );
    expect(state.debugLastExportFlowResultKind(), 'shareOpened');
  });

  testWidgets('system sheet opened keeps a persistent export result visible',
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

    final banner = find.byKey(const ValueKey('export-flow-result-banner'));
    expect(find.text('Opciones del sistema abiertas'), findsOneWidget);
    expect(
      find.descendant(
        of: banner,
        matching: find.textContaining(
          'Abrimos las opciones del sistema para guardar o compartir control_diario.xlsx',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('export-flow-result-action-retryShare')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('export-flow-result-action-closeEditor')),
      findsOneWidget,
    );
    expect(state.debugLastExportFlowResultKind(), 'systemSheetOpened');
  });

  testWidgets('saved fallback shows file name path and saved actions',
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

    final banner = find.byKey(const ValueKey('export-flow-result-banner'));
    expect(find.text('Archivo guardado'), findsOneWidget);
    expect(
      find.descendant(
        of: banner,
        matching: find.textContaining(
          'Excel guardado en /tmp/cierre/control_diario.xlsx',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('export-flow-result-location')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: banner,
        matching: find.textContaining('/tmp/cierre/control_diario.xlsx'),
      ),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('export-flow-result-action-openFile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('export-flow-result-action-retryShare')),
      findsNothing,
    );
    expect(state.debugLastExportFlowResultKind(), 'saved');
  });

  testWidgets(
      'cancelled result says no file was generated and can be dismissed',
      (tester) async {
    final dynamic state = await pumpEditor(tester);
    state.debugSetExportHooks(
      shareHook: (_) async => throw UnsupportedError('share not supported'),
      saveLocationHook: ({
        required String suggestedName,
        required List<XTypeGroup> acceptedTypeGroups,
      }) async =>
          null,
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

    final banner = find.byKey(const ValueKey('export-flow-result-banner'));
    expect(find.text('Salida cancelada'), findsOneWidget);
    expect(
      find.descendant(
        of: banner,
        matching: find.textContaining('No se genero ningun archivo'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('export-flow-result-action-retryCurrent')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('export-flow-result-dismiss')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('export-flow-result-banner')), findsNothing);
    expect(state.debugLastExportFlowResultKind(), isNull);
  });

  testWidgets('error result stays visible with honest format-specific copy',
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

    final banner = find.byKey(const ValueKey('export-flow-result-banner'));
    expect(find.text('Salida no completada'), findsOneWidget);
    expect(
      find.descendant(
        of: banner,
        matching: find.textContaining('No pudimos dejar listo el Excel.'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('export-flow-result-action-retryCurrent')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('export-flow-result-action-continueEditing')),
      findsOneWidget,
    );
    expect(state.debugLastExportFlowResultKind(), 'error');
  });

  testWidgets('retry from persistent result dispatches the export flow again',
      (tester) async {
    final dynamic state = await pumpEditor(tester);
    var saveLocationCalls = 0;
    state.debugSetExportHooks(
      shareHook: (_) async => throw UnsupportedError('share not supported'),
      saveLocationHook: ({
        required String suggestedName,
        required List<XTypeGroup> acceptedTypeGroups,
      }) async {
        saveLocationCalls++;
        if (saveLocationCalls == 1) {
          throw Exception('disk full');
        }
        return const FileSaveLocation('/tmp/retry/control_diario.xlsx');
      },
      saveFileHook: (_, __) async {},
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
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Salida no completada'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('export-flow-result-action-retryCurrent')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final banner = find.byKey(const ValueKey('export-flow-result-banner'));
    expect(saveLocationCalls, 2);
    expect(find.text('Archivo guardado'), findsOneWidget);
    expect(
      find.descendant(
        of: banner,
        matching: find.textContaining('/tmp/retry/control_diario.xlsx'),
      ),
      findsWidgets,
    );
    expect(state.debugLastExportFlowResultKind(), 'saved');
  });
}
