import 'dart:convert';
import 'dart:typed_data';

import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/models/cell_meta.dart';
import 'package:bitacora_web/services/attachment_store.dart';
import 'package:bitacora_web/services/photo_acquire_service.dart';
import 'package:bitacora_web/services/photo_bytes.dart';
import 'package:bitacora_web/services/web_image_normalizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'photo attach persists storedRef when browser normalize/transcode fails',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(sheetId: 'editor-attachment-resilience'),
      ),
    );
    await tester.pump();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    state.debugSetSkipAttachmentGps(true);
    state.debugSetForceWebImageNormalization(true);
    state.debugSetWebImageNormalizer(const _FailingWebImageNormalizer());
    state.debugSetSaveImageHook(
      ({
        required cellRef,
        required attachmentId,
        required bytes,
        required originalName,
        required mime,
        webFile,
      }) async {
        return const AttachmentSaveResult(
          storedRef: 'mem:test_photo_ref',
          storageLabel: 'ram',
          storageKey: 'test_photo_ref',
        );
      },
    );

    final bytes = _tinyPngBytes();
    final result = PhotoAcquireResult(
      PhotoBytes(
        bytes: bytes,
        name: 'camara.heic',
        mime: 'image/heic',
      ),
      size: bytes.lengthInBytes,
      reportedMime: 'image/heic',
      webFile: Object(),
    );

    await state.debugAttachPhotoResilient(0, 0, result);
    await tester.pump();

    final CellMeta? meta = state.debugCellMetaAt(0, 0) as CellMeta?;
    expect(meta, isNotNull);
    expect(meta!.photos, isNotEmpty);
    expect(meta.photos.first.storedRef.trim(), isNotEmpty);

    final String lastError =
        (state.debugLastErrorFeedbackMessage() ?? '').toString().toLowerCase();
    expect(lastError.contains('no se pudo guardar la foto'), isFalse);
    expect(lastError.contains('error adjuntar'), isFalse);
  });
}

class _FailingWebImageNormalizer implements WebImageNormalizer {
  const _FailingWebImageNormalizer();

  @override
  Future<WebImageNormalizationResult?> normalize(
    WebImageNormalizationRequest request,
  ) async {
    throw const WebImageNormalizationException(
      code: 'decode_unsupported',
      message: 'forced normalize failure',
    );
  }
}

Uint8List _tinyPngBytes() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO8B'
    'G6sAAAAASUVORK5CYII=',
  );
}
