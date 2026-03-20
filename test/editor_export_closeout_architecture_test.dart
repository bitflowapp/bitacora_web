import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/models/cell_meta.dart';
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
            sheetId: 'closeout-architecture-sheet',
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

  testWidgets('export save publishes through the official closeout entry point',
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
    );

    await state.debugRunExportSaveFlowForTest(
      name: 'control_diario.xlsx',
      mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      share: false,
      includeAttachments: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final List<String> trail = state.debugCloseoutAuditTrail();
    expect(
      trail.where((event) => event.startsWith('publish:export:saved:')).length,
      1,
    );
  });

  testWidgets(
      'attachment download publishes through the same closeout entry point',
      (tester) async {
    final dynamic state = await pumpEditor(tester);
    state.debugSetExportHooks(
      shareHook: (_) async => throw UnsupportedError('share not supported'),
      saveLocationHook: ({
        required String suggestedName,
        required List<XTypeGroup> acceptedTypeGroups,
      }) async =>
          const FileSaveLocation('/tmp/cierre/evidencia.jpg'),
      saveFileHook: (_, __) async {},
    );
    state.debugSetCellMetaForTest(
      0,
      0,
      CellMeta(
        photos: <PhotoAttachment>[
          PhotoAttachment(
            id: 'photo-download',
            filename: 'evidencia.jpg',
            mime: 'image/jpeg',
            size: _tinyPngBytes().lengthInBytes,
            storedRef: 'b64:${base64Encode(_tinyPngBytes())}',
            thumbRef: '',
            addedAt: DateTime(2026, 3, 18, 10, 0),
          ),
        ],
      ),
    );

    await state.debugDownloadPhotoAttachmentForTest(0, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final List<String> trail = state.debugCloseoutAuditTrail();
    expect(
      trail
          .where((event) => event.startsWith('publish:attachment:saved:'))
          .length,
      1,
    );
  });

  testWidgets('retry and dismiss stay inside the same closeout circuit',
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
    );

    await state.debugTriggerExportForTest(
      format: 'xlsx',
      share: false,
      includeAttachments: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(
      find.byKey(const ValueKey('export-flow-result-action-retryCurrent')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const ValueKey('export-flow-result-dismiss')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final List<String> trail = state.debugCloseoutAuditTrail();
    expect(
      trail.any((event) => event.startsWith('publish:export:error:')),
      isTrue,
    );
    expect(trail, contains('dismiss:export:error:retryCurrent'));
    expect(
      trail.any((event) => event.startsWith('publish:export:saved:')),
      isTrue,
    );
    expect(trail, contains('dismiss:export:saved:user'));
  });

  test('closeout architecture keeps a single publish circuit and no UI leaks',
      () {
    final editorStateSource =
        File('lib/features/editor/editor_state.dart').readAsStringSync();
    final attachmentSource = File(
      'lib/features/editor/attachments/attachments_controller.dart',
    ).readAsStringSync();
    final helperSource = File(
      'lib/features/editor/actions/editor_export_share_helpers.dart',
    ).readAsStringSync();

    expect(
      _countMatches(
        editorStateSource,
        '_exportResultController.publishCloseoutOutcome(',
      ),
      1,
    );
    expect(_countMatches(editorStateSource, '_lastExportFlowResult = result;'), 1);
    expect(attachmentSource.contains('_publishAttachmentOutcome(result);'),
        isTrue);
    expect(attachmentSource.contains('_publishExportOutcome('), isFalse);
    expect(helperSource.contains('_showActionSnack('), isFalse);
    expect(helperSource.contains('_publishCloseoutOutcome('), isFalse);
  });
}

int _countMatches(String source, String needle) {
  var count = 0;
  var start = 0;
  while (true) {
    final index = source.indexOf(needle, start);
    if (index == -1) return count;
    count++;
    start = index + needle.length;
  }
}

Uint8List _tinyPngBytes() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO8B'
    'G6sAAAAASUVORK5CYII=',
  );
}
