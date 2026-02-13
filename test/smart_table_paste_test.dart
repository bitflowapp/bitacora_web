import 'package:bitacora_web/services/smart_table_paste.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseSmartTable detects TSV blocks', () {
    final parsed = parseSmartTable('A\tB\n1\t2');

    expect(parsed.delimiter, SmartTableDelimiter.tab);
    expect(parsed.rowCount, 2);
    expect(parsed.columnCount, 2);
    expect(parsed.looksLikeTable, isTrue);
    expect(parsed.cells[1][0], '1');
    expect(parsed.cells[1][1], '2');
  });

  test('parseSmartTable supports CSV comma with quoted commas', () {
    final parsed = parseSmartTable('"obs,1",ok\n"obs,2",pendiente');

    expect(parsed.delimiter, SmartTableDelimiter.comma);
    expect(parsed.rowCount, 2);
    expect(parsed.columnCount, 2);
    expect(parsed.cells[0][0], 'obs,1');
    expect(parsed.cells[1][1], 'pendiente');
  });

  test('parseSmartTable supports CSV semicolon', () {
    final parsed = parseSmartTable('id;estado;obs\n1;OK;listo');

    expect(parsed.delimiter, SmartTableDelimiter.semicolon);
    expect(parsed.rowCount, 2);
    expect(parsed.columnCount, 3);
    expect(parsed.cells[1][2], 'listo');
  });

  test('planSmartTableBatch applies updates and inserts rows', () {
    final plan = planSmartTableBatch(
      existingRows: <List<String>>[
        <String>['a', 'b', 'c', ''],
      ],
      inputCells: <List<String>>[
        <String>['100', 'ok'],
        <String>['101', 'pendiente'],
      ],
      startRow: 0,
      startCol: 0,
      maxColsExclusive: 3,
      normalize: (col, value) => col == 1 ? value.toUpperCase() : value,
    );

    expect(plan.insertedRows, 1);
    expect(plan.changedCells, 4);
    expect(plan.rows.length, 2);
    expect(plan.rows[0][0], '100');
    expect(plan.rows[0][1], 'OK');
    expect(plan.rows[1][0], '101');
    expect(plan.rows[1][1], 'PENDIENTE');
    expect(plan.lastRow, 1);
    expect(plan.lastCol, 1);
  });

  test('planSmartTableBatch respects editable max column', () {
    final plan = planSmartTableBatch(
      existingRows: <List<String>>[
        <String>['', '', '', ''],
      ],
      inputCells: <List<String>>[
        <String>['a', 'b', 'c', 'SHOULD_NOT_WRITE'],
      ],
      startRow: 0,
      startCol: 0,
      maxColsExclusive: 3,
    );

    expect(plan.rows[0][0], 'a');
    expect(plan.rows[0][1], 'b');
    expect(plan.rows[0][2], 'c');
    expect(plan.rows[0][3], '');
  });

  test('planSmartTableBatch can insert rows at the active index', () {
    final plan = planSmartTableBatch(
      existingRows: <List<String>>[
        <String>['old-1', 'x', ''],
        <String>['old-2', 'y', ''],
      ],
      inputCells: <List<String>>[
        <String>['new-1', 'n'],
        <String>['new-2', 'm'],
      ],
      startRow: 1,
      startCol: 0,
      maxColsExclusive: 2,
      insertRowsAtStart: true,
    );

    expect(plan.insertedRows, 2);
    expect(plan.insertedAtRow, 1);
    expect(plan.rows.length, 4);
    expect(plan.rows[0][0], 'old-1');
    expect(plan.rows[1][0], 'new-1');
    expect(plan.rows[2][0], 'new-2');
    expect(plan.rows[3][0], 'old-2');
  });
}
