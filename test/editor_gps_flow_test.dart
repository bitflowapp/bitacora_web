import 'dart:async';

import 'package:bitacora_web/screens/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<dynamic> pumpEditor(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(sheetId: 'editor-gps-flow'),
      ),
    );
    await tester.pump();
    return tester.state(find.byType(EditorScreen)) as dynamic;
  }

  testWidgets('metadata only GPS keeps cell text and saves timestamped meta',
      (tester) async {
    final state = await pumpEditor(tester);
    final capturedAt = DateTime(2026, 3, 11, 15, 42);

    await state.debugSetGpsModeForTest('metadata');
    state.debugSetCellValue(0, 0, 'Valor base');
    state.debugSetGpsOutcomeHook((Duration timeout) async {
      return <String, Object?>{
        'lat': -38.95,
        'lng': -68.06,
        'accuracyM': 9.0,
        'timestamp': capturedAt,
        'source': 'debug',
        'provider': 'debug',
      };
    });

    await state.debugRequestGpsForCell(0, 0);
    await tester.pump();

    final meta = state.debugCellMetaAt(0, 0) as dynamic;
    expect(state.debugCellText(0, 0), 'Valor base');
    expect(state.debugCellHasGps(0, 0), isTrue);
    expect(meta.gps.timestamp, capturedAt);
    expect(
      state.debugLastToastMessage(),
      contains('No cambie el texto; solo actualice la metadata.'),
    );
    expect(state.debugLastToastMessage(), contains('fila 1, celda A1'));

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('GPS error shows field friendly service disabled feedback',
      (tester) async {
    final state = await pumpEditor(tester);

    state.debugSetGpsOutcomeHook((Duration timeout) async {
      return <String, Object?>{
        'error': 'service_disabled',
        'code': 'service_disabled',
      };
    });

    await state.debugRequestGpsForCell(0, 0);
    await tester.pump();

    expect(state.debugCellHasGps(0, 0), isFalse);
    expect(
      state.debugLastToastMessage(),
      contains('GPS del dispositivo esta apagado'),
    );
    expect(
      state.debugEngineStatusMessage(),
      contains('fila 1, celda A1'),
    );
  });

  testWidgets('GPS request ignores repeated taps while one request is active',
      (tester) async {
    final state = await pumpEditor(tester);
    final completer = Completer<Map<String, Object?>>();
    var callCount = 0;

    state.debugSetGpsOutcomeHook((Duration timeout) {
      callCount++;
      return completer.future;
    });

    final first = state.debugRequestGpsForCell(0, 0);
    await tester.pump();

    expect(state.debugGpsRequestInFlight, isTrue);
    expect(state.debugGpsRequestLabel(), 'fila 1, celda A1');

    await state.debugRequestGpsForCell(0, 0);
    await tester.pump();

    expect(callCount, 1);
    expect(
      state.debugLastToastMessage(),
      contains('Ya estamos buscando el GPS'),
    );

    completer.complete(<String, Object?>{
      'lat': -38.95,
      'lng': -68.06,
      'accuracyM': 7.0,
      'timestamp': DateTime(2026, 3, 11, 16, 10),
      'source': 'debug',
      'provider': 'debug',
    });
    await first;
    await tester.pump();

    expect(state.debugGpsRequestInFlight, isFalse);
    expect(state.debugCellHasGps(0, 0), isTrue);

    await tester.pump(const Duration(seconds: 3));
  });
}
