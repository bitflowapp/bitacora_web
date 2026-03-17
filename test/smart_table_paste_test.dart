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

  test('parseSmartTable preserves trailing empty TSV cells', () {
    final parsed = parseSmartTable('A\tB\t\n1\t2\t');

    expect(parsed.delimiter, SmartTableDelimiter.tab);
    expect(parsed.rowCount, 2);
    expect(parsed.columnCount, 3);
    expect(parsed.cells[0][2], '');
    expect(parsed.cells[1][2], '');
  });

  test('parseSmartTable flags malformed quoted CSV', () {
    final parsed = parseSmartTable('"obs,1,ok\n2,pendiente');

    expect(parsed.hasError, isTrue);
    expect(
      parsed.errorMessage,
      contains('No pudimos interpretar el formato pegado'),
    );
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

  test('planSmartTableBatch preserves data outside the pasted range', () {
    final plan = planSmartTableBatch(
      existingRows: <List<String>>[
        <String>['r0c0', 'r0c1', 'r0c2', 'r0c3'],
        <String>['r1c0', 'r1c1', 'r1c2', 'r1c3'],
        <String>['r2c0', 'r2c1', 'r2c2', 'r2c3'],
      ],
      inputCells: <List<String>>[
        <String>['A', 'B'],
        <String>['C', 'D'],
      ],
      startRow: 1,
      startCol: 1,
      maxColsExclusive: 4,
    );

    expect(plan.rows[1][1], 'A');
    expect(plan.rows[1][2], 'B');
    expect(plan.rows[2][1], 'C');
    expect(plan.rows[2][2], 'D');
    expect(plan.rows[1][0], 'r1c0');
    expect(plan.rows[0][1], 'r0c1');
    expect(plan.rows[2][3], 'r2c3');
  });

  test('planSmartTableExpansion computes added columns from active cell', () {
    final expansion = planSmartTableExpansion(
      existingEditableColumns: 14,
      startCol: 13,
      requiredColumns: 3,
    );

    expect(expansion.requiredEditableColumns, 16);
    expect(expansion.finalEditableColumns, 16);
    expect(expansion.addedColumns, 2);
  });
}
