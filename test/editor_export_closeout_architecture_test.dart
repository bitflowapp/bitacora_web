import 'dart:io';
import 'dart:typed_data';

import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/features/editor/export/editor_export_result_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('closeout publish wiring uses a single official entry point', () {
    final editorStatePath = File(
      'lib/features/editor/editor_state.dart',
    );
    final attachmentsPath = File(
      'lib/features/editor/attachments/attachments_controller.dart',
    );

    final editorStateCode = editorStatePath.readAsStringSync();
    final attachmentsCode = attachmentsPath.readAsStringSync();

    final publishCalls = RegExp(r'_exportResultController\.publish\(')
        .allMatches(editorStateCode)
        .length;
    final dismissCalls = RegExp(r'_exportResultController\.dismiss\(')
        .allMatches(editorStateCode)
        .length;

    expect(editorStateCode.contains('_publishCloseoutOutcome('), isTrue);
    expect(editorStateCode.contains('_publishExportOutcome('), isTrue);
    expect(editorStateCode.contains('_publishAttachmentOutcome('), isTrue);
    expect(publishCalls, 1,
        reason:
            'Solo el entry point oficial debe llamar _exportResultController.publish().');
    expect(dismissCalls, 1,
        reason:
            'Solo el entry point oficial debe llamar _exportResultController.dismiss().');

    expect(
        attachmentsCode.contains('_publishAttachmentOutcome(result);'), isTrue,
        reason: 'El closeout de adjuntos debe usar el circuito oficial.');
  });

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
            sheetId: 'closeout-arch-sheet',
            initialName: 'Control Diario',
            initialHeaders: <String>['Actividad', 'Estado', 'Fotos'],
            initialRows: <List<String>>[
              <String>['Inspeccion', 'OK', ''],
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 700));
    return tester.state(find.byType(EditorScreen));
  }

  testWidgets(
      'export + attachment + retry + dismiss keep official closeout path',
      (tester) async {
    final dynamic state = await pumpEditor(tester);

    state.debugSetExportHooks(
      shareHook: (_) async {},
      persistShareTempFileHook:
          ({required String fileName, required bytes}) async => null,
    );

    await state.debugRunExportSaveFlowForTest(
      name: 'control_diario.xlsx',
      mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      share: true,
    );
    await tester.pumpAndSettle();

    expect(state.debugLastCloseoutPublishChannel(), 'export');
    expect(state.debugLastExportFlowResultKind(), 'shareOpened');

    await state.debugRunAttachmentSaveFlowForTest(
      name: 'adjunto.jpg',
      mime: 'image/jpeg',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
    await tester.pumpAndSettle();

    expect(state.debugLastCloseoutPublishChannel(), 'attachment');
    expect(state.debugLastExportFlowResultKind(), 'systemSheetOpened');

    await state.debugHandleCloseoutActionForTest(
      EditorExportResultAction.continueEditing,
    );
    await tester.pumpAndSettle();
    expect(state.debugLastExportFlowResultKind(), isNull);

    await state.debugRunExportSaveFlowForTest(
      name: 'control_diario.xlsx',
      mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      share: true,
    );
    await tester.pumpAndSettle();

    expect(state.debugLastExportFlowResultKind(), 'shareOpened');

    await state.debugHandleCloseoutActionForTest(
      EditorExportResultAction.retryShare,
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(state.debugLastCloseoutPublishChannel(), 'export');
    expect(state.debugLastExportFlowResultKind(), 'shareOpened');
    expect(tester.takeException(), isNull);
  });
}
