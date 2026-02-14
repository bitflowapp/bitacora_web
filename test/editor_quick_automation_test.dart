import 'package:bitacora_web/services/editor_quick_automation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('autonumber progressive generates expected series', () {
    final values = buildProgressiveSeries(start: 1000, step: 10, count: 5);
    expect(values, <int>[1000, 1010, 1020, 1030, 1040]);
  });

  test('date today formatter returns yyyy-mm-dd', () {
    final value = formatDateTodayYmd(DateTime.utc(2026, 2, 14));
    expect(value, '2026-02-14');
  });
}
