import 'package:bitacora_web/services/formula_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormulaEngine', () {
    const engine = FormulaEngine();

    test('evaluates aggregate functions over ranges', () {
      final values = <String, String>{
        'A1': '10',
        'A2': '20',
        'A3': '30',
        'B1': '2',
        'B2': '4',
        'B3': 'x',
        'B4': '8',
      };

      final sum = engine.evaluate(
        '=SUM(A1:A3)',
        readCell: (cell) => values[cell.a1] ?? '',
      );
      final avg = engine.evaluate(
        '=AVERAGE(B1:B4)',
        readCell: (cell) => values[cell.a1] ?? '',
      );
      final min = engine.evaluate(
        '=MIN(B1:B4)',
        readCell: (cell) => values[cell.a1] ?? '',
      );
      final max = engine.evaluate(
        '=MAX(B1:B4)',
        readCell: (cell) => values[cell.a1] ?? '',
      );
      final count = engine.evaluate(
        '=COUNT(B1:B4)',
        readCell: (cell) => values[cell.a1] ?? '',
      );

      expect(sum.hasError, isFalse);
      expect(sum.value, 60);
      expect(sum.references.length, 3);
      expect(avg.value, closeTo(14 / 3, 0.0001));
      expect(min.value, 2);
      expect(max.value, 8);
      expect(count.value, 3);
    });

    test('supports IF, ROUND, DATE, NOW and TODAY date helpers', () {
      final values = <String, String>{
        'C1': '11',
      };
      final fixedNow = DateTime(2026, 3, 5, 12, 30, 45);

      final ifResult = engine.evaluate(
        '=IF(C1 > 10, "OK", "CHECK")',
        readCell: (cell) => values[cell.a1] ?? '',
      );
      final roundResult = engine.evaluate(
        '=ROUND(10.127, 2)',
        readCell: (_) => '',
      );
      final dateResult = engine.evaluate(
        '=DATE(2026, 3, 5)',
        readCell: (_) => '',
      );
      final nowResult = engine.evaluate(
        '=NOW()',
        readCell: (_) => '',
        now: fixedNow,
      );
      final todayResult = engine.evaluate(
        '=TODAY()',
        readCell: (_) => '',
        now: fixedNow,
      );
      final yearResult = engine.evaluate(
        '=YEAR(DATE(2026, 3, 5))',
        readCell: (_) => '',
      );
      final monthResult = engine.evaluate(
        '=MONTH(DATE(2026, 3, 5))',
        readCell: (_) => '',
      );
      final dayResult = engine.evaluate(
        '=DAY(DATE(2026, 3, 5))',
        readCell: (_) => '',
      );

      expect(ifResult.value, 'OK');
      expect(roundResult.value, 10.13);
      expect(dateResult.value, DateTime(2026, 3, 5));
      expect(nowResult.value, fixedNow);
      expect(todayResult.value, DateTime(2026, 3, 5));
      expect(yearResult.value, 2026);
      expect(monthResult.value, 3);
      expect(dayResult.value, 5);
    });

    test('supports lookup functions', () {
      final values = <String, String>{
        'A1': 'SKU',
        'B1': 'Price',
        'C1': 'Stock',
        'A2': 'AX1',
        'B2': '12.5',
        'C2': '7',
        'A3': 'BZ9',
        'B3': '20',
        'C3': '4',
      };

      final vlookup = engine.evaluate(
        '=VLOOKUP("BZ9", A2:C3, 2)',
        readCell: (cell) => values[cell.a1] ?? '',
      );
      final hlookup = engine.evaluate(
        '=HLOOKUP("Stock", A1:C3, 3)',
        readCell: (cell) => values[cell.a1] ?? '',
      );
      final index = engine.evaluate(
        '=INDEX(B2:C3, 2, 1)',
        readCell: (cell) => values[cell.a1] ?? '',
      );
      final match = engine.evaluate(
        '=MATCH("BZ9", A2:A3, 0)',
        readCell: (cell) => values[cell.a1] ?? '',
      );

      expect(vlookup.hasError, isFalse);
      expect(vlookup.value, 20);
      expect(hlookup.value, 4);
      expect(index.value, 20);
      expect(match.value, 2);
    });

    test('supports FILTER and CONCAT with ranges', () {
      final values = <String, String>{
        'A1': 'Alice',
        'A2': 'Bob',
        'A3': 'Cara',
        'B1': '1',
        'B2': '0',
        'B3': '1',
        'C1': 'Hola',
        'C2': 'Mundo',
      };

      final filter = engine.evaluate(
        '=FILTER(A1:A3, B1:B3)',
        readCell: (cell) => values[cell.a1] ?? '',
      );
      final concat = engine.evaluate(
        '=CONCAT(C1, " ", C2, " - ", A1:A2)',
        readCell: (cell) => values[cell.a1] ?? '',
      );

      expect(filter.hasError, isFalse);
      expect(engine.formatValue(filter.value), 'Alice, Cara');
      expect(concat.value, 'Hola Mundo - AliceBob');
    });

    test('supports text and math utility functions', () {
      final values = <String, String>{
        'D1': 'BitFlow',
        'D2': '-9',
      };

      final len = engine.evaluate(
        '=LEN(D1)',
        readCell: (cell) => values[cell.a1] ?? '',
      );
      final lower = engine.evaluate(
        '=LOWER(D1)',
        readCell: (cell) => values[cell.a1] ?? '',
      );
      final upper = engine.evaluate(
        '=UPPER("bitflow")',
        readCell: (_) => '',
      );
      final abs = engine.evaluate(
        '=ABS(D2)',
        readCell: (cell) => values[cell.a1] ?? '',
      );
      final power = engine.evaluate(
        '=POWER(3, 4)',
        readCell: (_) => '',
      );

      expect(len.value, 7);
      expect(lower.value, 'bitflow');
      expect(upper.value, 'BITFLOW');
      expect(abs.value, 9);
      expect(power.value, 81);
    });

    test('returns spreadsheet style errors', () {
      final div0 = engine.evaluate(
        '=1/0',
        readCell: (_) => '',
      );
      final valueError = engine.evaluate(
        '=ABS("x")',
        readCell: (_) => '',
      );
      final refError = engine.evaluate(
        '=A2',
        readCell: (_) => '',
        isCellAvailable: (cell) => cell.row == 0 && cell.col == 0,
      );

      expect(div0.error, FormulaErrors.div0);
      expect(valueError.error, FormulaErrors.value);
      expect(refError.error, FormulaErrors.ref);
    });

    test('accepts semicolon separators', () {
      final result = engine.evaluate(
        '=IF(1>0; "YES"; "NO")',
        readCell: (_) => '',
      );

      expect(result.hasError, isFalse);
      expect(result.value, 'YES');
    });

    test('returns autocomplete suggestions from registered functions', () {
      final su = engine.suggestFunctions('=SU');
      final av = engine.suggestFunctions('=AV');
      final nested = engine.suggestFunctions('=IF(A1>0, PO');

      expect(su.map((item) => item.name), contains('SUM'));
      expect(av.map((item) => item.name), contains('AVERAGE'));
      expect(nested.map((item) => item.name), contains('POWER'));
      expect(su.first.apply('=SU'), '=SUM()');
    });

    test('returns parse failure for invalid formula', () {
      final parsed = engine.tryParse('=SUM(A1:A)');
      expect(parsed, isNull);
    });
  });
}
