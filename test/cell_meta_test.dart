import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitacora_web/models/cell_meta.dart';
import 'package:bitacora_web/screens/editor_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CellMeta roundtrip', () {
    final meta = CellMeta(
      gps: GpsMeta(
        lat: -38.95,
        lng: -68.06,
        accuracyM: 12.0,
        timestamp: DateTime(2026, 2, 3, 10, 15, 30),
        source: 'current',
        provider: 'test',
      ),
      photos: [
        PhotoAttachment(
          id: 'p1',
          filename: 'foto.jpg',
          mime: 'image/jpeg',
          size: 1200,
          storedRef: 'mem://p1',
          thumbRef: 'mem://p1-thumb',
          addedAt: DateTime(2026, 2, 3, 10, 16, 0),
          lat: -38.95,
          lon: -68.06,
          accuracyM: 15.0,
          isLastKnown: false,
        ),
      ],
      audios: [
        AudioAttachment(
          id: 'a1',
          filename: 'audio.m4a',
          mime: 'audio/m4a',
          size: 3200,
          durationMs: 4200,
          storedRef: 'mem://a1',
          addedAt: DateTime(2026, 2, 3, 10, 17, 0),
        ),
      ],
    );

    final json = meta.toJson();
    final decoded = CellMeta.fromJson(json);

    expect(decoded, isNotNull);
    expect(decoded!.gps, isNotNull);
    expect(decoded.gps!.lat, closeTo(-38.95, 0.000001));
    expect(decoded.gps!.lng, closeTo(-68.06, 0.000001));
    expect(decoded.gps!.accuracyM, 12);
    expect(decoded.photos.length, 1);
    expect(decoded.photos.first.filename, 'foto.jpg');
    expect(decoded.audios.length, 1);
    expect(decoded.audios.first.filename, 'audio.m4a');
  });

  testWidgets('EditorScreen writes gps text into selected cell',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'test-sheet',
          engineBaseUrl: 'ftp://invalid',
          engineApiKey: '',
        ),
      ),
    );

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    state.debugApplyGpsFixToCell(
      0,
      0,
      lat: -38.95,
      lng: -68.06,
      accuracyM: 12.0,
      timestamp: DateTime(2026, 2, 3),
      writeText: true,
    );

    await tester.pump();

    final text = state.debugCellText(0, 0) as String;
    expect(text, contains('-38.950000'));
    expect(text, contains('-68.060000'));
    expect(state.debugCellHasGps(0, 0), isTrue);
  });

  testWidgets('GPS fix in-flight is reused for concurrent calls',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'gps-inflight-test',
          engineBaseUrl: 'ftp://invalid',
          engineApiKey: '',
        ),
      ),
    );

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    final completer = Completer<Map<String, Object?>>();
    var calls = 0;

    state.debugSetGpsOutcomeHook((Duration timeout) async {
      calls++;
      return completer.future;
    });

    final first = state.debugGetGpsFixForTest(
      timeout: const Duration(seconds: 4),
    ) as Future<Map<String, Object?>>;
    final second = state.debugGetGpsFixForTest(
      timeout: const Duration(seconds: 4),
    ) as Future<Map<String, Object?>>;

    await tester.pump();
    expect(calls, 1);

    completer.complete(<String, Object?>{
      'lat': -38.950001,
      'lng': -68.060001,
      'accuracyM': 9.0,
      'timestamp': DateTime(2026, 3, 1, 10, 30, 0).toIso8601String(),
      'source': 'debug',
      'provider': 'debug-hook',
    });

    final firstResult = await first;
    final secondResult = await second;

    expect(firstResult['ok'], true);
    expect(secondResult['ok'], true);
    expect(calls, 1);

    state.debugSetGpsOutcomeHook(null);
  });

  testWidgets(
      'GPS metadata keeps timestamp/coords and metadata-only does not overwrite text',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'gps-metadata-test',
          engineBaseUrl: 'ftp://invalid',
          engineApiKey: '',
        ),
      ),
    );

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    state.debugSetCellValue(0, 0, 'valor original');

    state.debugApplyGpsFixToCell(
      0,
      0,
      lat: -38.951,
      lng: -68.061,
      accuracyM: -7,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      writeText: false,
    );

    await tester.pump();

    expect(state.debugCellText(0, 0), 'valor original');
    final meta = state.debugCellMetaAt(0, 0) as CellMeta?;
    expect(meta, isNotNull);
    expect(meta!.gps, isNotNull);
    expect(meta.gps!.lat, closeTo(-38.951, 0.000001));
    expect(meta.gps!.lng, closeTo(-68.061, 0.000001));
    expect(meta.gps!.accuracyM, 0);
    expect(meta.gps!.timestamp.millisecondsSinceEpoch, greaterThan(0));
  });

  testWidgets('GPS timeout error copy is actionable in Spanish',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'gps-copy-test',
          engineBaseUrl: 'ftp://invalid',
          engineApiKey: '',
        ),
      ),
    );

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    final message = state.debugGpsErrorMessageForTest(
      code: 'timeout',
      targetLabel: 'fila 2, celda B2',
    ) as String;

    expect(message, contains('No pudimos guardar el GPS en fila 2, celda B2.'));
    expect(message, contains('No llego una posicion valida a tiempo'));
  });

  test('PhotoAttachment serialization keeps meta', () {
    final photo = PhotoAttachment(
      id: 'p_heic',
      filename: 'image.heic',
      mime: 'image/heic',
      size: 2048,
      storedRef: 'key:sheet:2:3:p_heic',
      thumbRef: '',
      addedAt: DateTime(2026, 2, 4, 12, 0),
    );

    final json = photo.toJson();
    final decoded = PhotoAttachment.fromJson(json);

    expect(decoded, isNotNull);
    expect(decoded!.mime, 'image/heic');
    expect(decoded.size, 2048);
    expect(decoded.storedRef, 'key:sheet:2:3:p_heic');
  });

  test('Cell meta attaches photo to target cell key', () {
    final key = CellKey(1, 2); // R2C3
    final attachment = PhotoAttachment(
      id: 'p2',
      filename: 'nota.png',
      mime: 'image/png',
      size: 5120,
      storedRef: 'mem:p2',
      thumbRef: '',
      addedAt: DateTime(2026, 2, 4, 12, 30),
    );

    final stored = <String, dynamic>{
      key.toKey(): CellMeta(photos: [attachment]).toJson(),
    };

    final restored = stored.map((k, v) => MapEntry(k, CellMeta.fromJson(v)));
    final cellMeta = restored[key.toKey()];

    expect(cellMeta, isNotNull);
    expect(cellMeta!.photos.length, 1);
    expect(cellMeta.photos.first.filename, 'nota.png');
    expect(cellMeta.photos.first.size, 5120);
  });
}
