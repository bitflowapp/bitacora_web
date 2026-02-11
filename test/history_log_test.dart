import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('history record json roundtrip', () {
    final now = DateTime.now();
    final event = HistoryEventRecord(
      id: 'hist_1',
      at: now,
      type: 'edit_cell',
      message: 'Editar A1',
      origin: 'manual',
      row: 0,
      col: 0,
      beforeValue: 'a',
      afterValue: 'b',
    );
    final encoded = event.toJson();
    final decoded = HistoryEventRecord.fromJson(encoded);
    expect(decoded, isNotNull);
    expect(decoded!.id, event.id);
    expect(decoded.type, event.type);
    expect(decoded.message, event.message);
    expect(decoded.origin, event.origin);
    expect(decoded.row, 0);
    expect(decoded.col, 0);
    expect(decoded.beforeValue, 'a');
    expect(decoded.afterValue, 'b');
  });

  test('history trim keeps latest and applies age limit', () {
    final base = DateTime(2026, 2, 11, 12, 0, 0);
    final events = <HistoryEventRecord>[
      for (int i = 0; i < 10; i++)
        HistoryEventRecord(
          id: 'e$i',
          at: base.subtract(Duration(days: i)),
          type: 'edit_cell',
          message: 'm$i',
          origin: 'manual',
        ),
    ];
    final trimmed = HistoryEventRecord.trim(
      events,
      maxEvents: 5,
      maxDays: 3,
      now: base,
    );
    expect(trimmed.length, 3);
    expect(trimmed.first.id, 'e0');
    expect(trimmed.last.id, 'e2');
  });
}
