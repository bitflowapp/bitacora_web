import 'dart:convert';
import 'dart:typed_data';

import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/models/cell_meta.dart';
import 'package:bitacora_web/services/audio_service.dart';
import 'package:bitacora_web/services/audio_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<dynamic> pumpEditor(
    WidgetTester tester, {
    required String sheetId,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1280, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: EditorScreen(sheetId: sheetId)),
    );
    await tester.pump();
    return tester.state(find.byType(EditorScreen)) as dynamic;
  }

  testWidgets('ojo desaparece cuando no hay preview valido', (tester) async {
    final state = await pumpEditor(tester, sheetId: 'media-disabled');
    state.debugSetCellMetaForTest(
      0,
      0,
      CellMeta(
        photos: <PhotoAttachment>[
          PhotoAttachment(
            id: 'missing-photo',
            filename: 'evidencia.jpg',
            mime: 'image/jpeg',
            size: 0,
            storedRef: '',
            thumbRef: '',
            addedAt: DateTime(2026, 3, 18, 10, 0),
          ),
        ],
      ),
    );

    await tester.pump();
    state.debugOpenPhotosSheetForTest(0, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('attachment-tile-preview-0')),
      findsNothing,
    );
  });

  testWidgets('tap en ojo abre preview real para imagen', (tester) async {
    final state = await pumpEditor(tester, sheetId: 'media-preview');
    state.debugSetCellMetaForTest(
      0,
      0,
      CellMeta(
        photos: <PhotoAttachment>[
          PhotoAttachment(
            id: 'photo-preview',
            filename: 'evidencia.jpg',
            mime: 'image/jpeg',
            size: _tinyPngBytes().lengthInBytes,
            storedRef: 'b64:${base64Encode(_tinyPngBytes())}',
            thumbRef: '',
            addedAt: DateTime(2026, 3, 18, 10, 1),
          ),
        ],
      ),
    );

    await tester.pump();
    state.debugOpenPhotosSheetForTest(0, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('attachment-tile-preview-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
        find.byKey(const ValueKey('attachment-preview-modal')), findsOneWidget);
  });

  testWidgets('media faltante muestra error claro en preview', (tester) async {
    final state = await pumpEditor(tester, sheetId: 'media-missing');
    state.debugSetCellMetaForTest(
      0,
      0,
      CellMeta(
        photos: <PhotoAttachment>[
          PhotoAttachment(
            id: 'missing-binary',
            filename: 'faltante.jpg',
            mime: 'image/jpeg',
            size: 12,
            storedRef: 'mem:missing-binary',
            thumbRef: '',
            addedAt: DateTime(2026, 3, 18, 10, 2),
          ),
        ],
      ),
    );

    await tester.pump();
    state.debugOpenPhotosSheetForTest(0, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('attachment-tile-preview-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('No se pudo abrir'), findsOneWidget);
  });

  testWidgets('grabar celda guarda el resultado en la celda correcta',
      (tester) async {
    final state = await pumpEditor(tester, sheetId: 'audio-record');
    state.debugSetAudioHooks(
      start: ({required String sheetId}) async {},
      stop: () async {
        return RecordedAudio(
          fileName: 'nota.webm',
          mime: 'audio/webm',
          duration: const Duration(seconds: 2),
          bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
        );
      },
      save: ({
        required String sheetId,
        required String cellKey,
        required String attachmentId,
        required RecordedAudio recording,
      }) async {
        return const StoredAudio(
          storageKey: 'mem:test-audio',
          fileName: 'nota.webm',
          mime: 'audio/webm',
          bytesLength: 4,
        );
      },
    );

    await state.debugToggleAudioRecordingForCell(0, 0);
    await tester.pump();
    expect(state.debugIsAudioRecording(), isTrue);
    expect(
      (state.debugEngineStatusMessage() ?? '').toString(),
      contains('Grabando audio'),
    );

    await state.debugToggleAudioRecordingForCell(0, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final CellMeta? meta = state.debugCellMetaAt(0, 0) as CellMeta?;
    expect(state.debugIsAudioRecording(), isFalse);
    expect(meta, isNotNull);
    expect(meta!.audios, hasLength(1));
    expect(meta.audios.first.filename, 'nota.webm');
    expect((state.debugEngineStatusMessage() ?? '').toString(),
        contains('Audio guardado'));
  });

  testWidgets('acciones invalidas no quedan activas en el panel',
      (tester) async {
    final state =
        await pumpEditor(tester, sheetId: 'attachment-panel-disabled');
    state.debugSetCellMetaForTest(
      0,
      0,
      CellMeta(
        photos: <PhotoAttachment>[
          PhotoAttachment(
            id: 'stale-photo',
            filename: 'stale.jpg',
            mime: 'image/jpeg',
            size: 10,
            storedRef: '',
            thumbRef: '',
            addedAt: DateTime(2026, 3, 18, 10, 3),
          ),
        ],
      ),
    );

    await tester.pump();
    await state.debugOpenAttachmentPanelForTest(0, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('attachment-panel-view-button')),
      findsNothing,
    );
    expect(
      find.textContaining('no estan disponibles para abrir'),
      findsOneWidget,
    );
  });
}

Uint8List _tinyPngBytes() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO8B'
    'G6sAAAAASUVORK5CYII=',
  );
}
