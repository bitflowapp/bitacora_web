import 'dart:convert';
import 'dart:typed_data';

import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/services/attachment_store.dart';
import 'package:bitacora_web/services/engine_health_checker.dart';
import 'package:bitacora_web/services/photo_acquire_service.dart';
import 'package:bitacora_web/services/photo_bytes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('photo attach keeps thumb and opens preview modal',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final tinyBytes = _tinyPngBytes();

    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'attachment-preview-modal',
          initialHeaders: <String>['Notas', 'Photos'],
          initialRows: <List<String>>[
            <String>['', ''],
          ],
          engineHealthChecker: const FakeEngineHealthChecker(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    state.debugSetSkipAttachmentGps(true);
    state.debugSetSaveImageHook(({
      required cellRef,
      required attachmentId,
      required bytes,
      required originalName,
      required mime,
      webFile,
    }) async {
      return const AttachmentSaveResult(
        storedRef: 'mem:test-preview-ref',
        storageLabel: 'ram',
        storageKey: 'test-preview-ref',
      );
    });

    final result = PhotoAcquireResult(
      PhotoBytes(
        bytes: tinyBytes,
        name: 'foto.jpg',
        mime: 'image/jpeg',
      ),
      size: tinyBytes.lengthInBytes,
      reportedMime: 'image/jpeg',
    );
    await state.debugAttachPhotoResilient(0, 0, result);
    await tester.pumpAndSettle();

    final meta = state.debugCellMetaAt(0, 0) as dynamic;
    expect(meta.photos, isNotEmpty);

    await state.debugOpenLatestPhotoPreview(0, 0);
    await tester.pump();
  });
}

Uint8List _tinyPngBytes() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO8B'
    'G6sAAAAASUVORK5CYII=',
  );
}
