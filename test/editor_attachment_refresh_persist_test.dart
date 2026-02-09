import 'dart:convert';
import 'dart:typed_data';

import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/models/cell_meta.dart';
import 'package:bitacora_web/services/attachment_store.dart';
import 'package:bitacora_web/services/photo_acquire_service.dart';
import 'package:bitacora_web/services/photo_bytes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('attach photo survives save + refresh simulated', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const sheetId = 'attachment-refresh-sheet';
    await tester.pumpWidget(
      const MaterialApp(home: EditorScreen(sheetId: sheetId)),
    );
    await tester.pump();

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
        storedRef: 'mem:test-refresh-ref',
        storageLabel: 'ram',
        storageKey: 'test-refresh-ref',
        sessionOnly: true,
      );
    });

    final result = PhotoAcquireResult(
      PhotoBytes(
        bytes: _tinyPngBytes(),
        name: 'camara.jpg',
        mime: 'image/jpeg',
      ),
      size: _tinyPngBytes().lengthInBytes,
      reportedMime: 'image/jpeg',
    );
    await state
        .debugAttachPhotoResilient(0, 0, result)
        .timeout(const Duration(seconds: 10));
    await state.debugSaveNow().timeout(const Duration(seconds: 10));
    await tester.pump();

    final CellMeta? before = state.debugCellMetaAt(0, 0) as CellMeta?;
    expect(before, isNotNull);
    expect(before!.photos, isNotEmpty);
    final storedRefBefore = before.photos.first.storedRef;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(
      const MaterialApp(home: EditorScreen(sheetId: sheetId)),
    );
    await tester.pump();
    final stateReloaded = tester.state(find.byType(EditorScreen)) as dynamic;
    await stateReloaded.debugReloadFromLocal().timeout(
          const Duration(seconds: 10),
        );
    await tester.pump();

    final CellMeta? after = stateReloaded.debugCellMetaAt(0, 0) as CellMeta?;
    expect(after, isNotNull);
    expect(after!.photos, isNotEmpty);
    expect(after.photos.first.storedRef, storedRefBefore);
  });
}

Uint8List _tinyPngBytes() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO8B'
    'G6sAAAAASUVORK5CYII=',
  );
}
