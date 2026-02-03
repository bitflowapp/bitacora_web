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
}
