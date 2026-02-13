enum SmartTableDelimiter {
  tab,
  comma,
  semicolon,
  singleValue,
}

typedef SmartTableCellNormalizer = String Function(int column, String value);

class SmartTableParseResult {
  const SmartTableParseResult({
    required this.cells,
    required this.delimiter,
  });

  final List<List<String>> cells;
  final SmartTableDelimiter delimiter;

  bool get isEmpty => cells.isEmpty;

  int get rowCount => cells.length;

  int get columnCount {
    var max = 0;
    for (final row in cells) {
      if (row.length > max) max = row.length;
    }
    return max;
  }

  bool get looksLikeTable => rowCount > 1 || columnCount > 1;
}

class SmartTableCellUpdate {
  const SmartTableCellUpdate({
    required this.row,
    required this.col,
    required this.previous,
    required this.next,
  });

  final int row;
  final int col;
  final String previous;
  final String next;
}

class SmartTableBatchPlan {
  const SmartTableBatchPlan({
    required this.rows,
    required this.updates,
    required this.insertedRows,
    required this.insertedAtRow,
    required this.lastRow,
    required this.lastCol,
  });

  final List<List<String>> rows;
  final List<SmartTableCellUpdate> updates;
  final int insertedRows;
  final int insertedAtRow;
  final int lastRow;
  final int lastCol;

  int get changedCells => updates.length;
}

SmartTableParseResult parseSmartTable(String raw) {
  final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  if (normalized.isEmpty) {
    return const SmartTableParseResult(
      cells: <List<String>>[],
      delimiter: SmartTableDelimiter.singleValue,
    );
  }

  final lines = normalized
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty) {
    return const SmartTableParseResult(
      cells: <List<String>>[],
      delimiter: SmartTableDelimiter.singleValue,
    );
  }

  final hasTabs = lines.any((line) => line.contains('\t'));
  final delimiter =
      hasTabs ? SmartTableDelimiter.tab : _resolveCsvDelimiter(lines);

  final cells = <List<String>>[];
  for (final line in lines) {
    switch (delimiter) {
      case SmartTableDelimiter.tab:
        cells.add(_parseDelimitedLine(line, '\t'));
        break;
      case SmartTableDelimiter.comma:
        cells.add(_parseDelimitedLine(line, ','));
        break;
      case SmartTableDelimiter.semicolon:
        cells.add(_parseDelimitedLine(line, ';'));
        break;
      case SmartTableDelimiter.singleValue:
        cells.add(<String>[line.trimRight()]);
        break;
    }
  }

  return SmartTableParseResult(
    cells: cells,
    delimiter: delimiter,
  );
}

SmartTableBatchPlan planSmartTableBatch({
  required List<List<String>> existingRows,
  required List<List<String>> inputCells,
  required int startRow,
  required int startCol,
  required int maxColsExclusive,
  bool insertRowsAtStart = false,
  SmartTableCellNormalizer? normalize,
}) {
  final rows = existingRows
      .map((row) => List<String>.from(row, growable: false))
      .toList(growable: true);
  if (rows.isEmpty || inputCells.isEmpty || maxColsExclusive <= 0) {
    return SmartTableBatchPlan(
      rows: rows,
      updates: const <SmartTableCellUpdate>[],
      insertedRows: 0,
      insertedAtRow: -1,
      lastRow: startRow,
      lastCol: startCol,
    );
  }

  final width = rows.first.length;
  var insertedRows = 0;
  var insertedAtRow = -1;
  var baseRow = startRow;
  if (insertRowsAtStart) {
    insertedRows = inputCells.length;
    insertedAtRow = startRow.clamp(0, rows.length).toInt();
    final generated = List<List<String>>.generate(
      insertedRows,
      (_) => List<String>.filled(width, '', growable: false),
      growable: false,
    );
    rows.insertAll(insertedAtRow, generated);
    baseRow = insertedAtRow;
  } else {
    final requiredRows = startRow + inputCells.length;
    insertedRows = requiredRows > rows.length ? requiredRows - rows.length : 0;
    insertedAtRow = insertedRows > 0 ? rows.length : -1;
    for (var i = 0; i < insertedRows; i++) {
      rows.add(List<String>.filled(width, '', growable: false));
    }
  }

  final updates = <SmartTableCellUpdate>[];
  var lastRow = startRow;
  var lastCol = startCol;

  for (var dr = 0; dr < inputCells.length; dr++) {
    final row = inputCells[dr];
    final rr = baseRow + dr;
    if (rr < 0 || rr >= rows.length) continue;
    lastRow = rr;
    for (var dc = 0; dc < row.length; dc++) {
      final cc = startCol + dc;
      if (cc < 0) continue;
      if (cc >= maxColsExclusive) break;
      if (cc >= rows[rr].length) continue;
      final rawValue = row[dc];
      final nextValue = normalize != null ? normalize(cc, rawValue) : rawValue;
      final previous = rows[rr][cc];
      if (previous == nextValue) continue;
      rows[rr][cc] = nextValue;
      updates.add(
        SmartTableCellUpdate(
          row: rr,
          col: cc,
          previous: previous,
          next: nextValue,
        ),
      );
      lastCol = cc;
    }
  }

  return SmartTableBatchPlan(
    rows: rows,
    updates: updates,
    insertedRows: insertedRows,
    insertedAtRow: insertedAtRow,
    lastRow: lastRow,
    lastCol: lastCol,
  );
}

SmartTableDelimiter _resolveCsvDelimiter(List<String> lines) {
  var commaScore = 0;
  var semicolonScore = 0;
  for (final line in lines) {
    commaScore += _countDelimiterOutsideQuotes(line, ',');
    semicolonScore += _countDelimiterOutsideQuotes(line, ';');
  }
  if (commaScore <= 0 && semicolonScore <= 0) {
    return SmartTableDelimiter.singleValue;
  }
  if (semicolonScore > commaScore) {
    return SmartTableDelimiter.semicolon;
  }
  return SmartTableDelimiter.comma;
}

int _countDelimiterOutsideQuotes(String input, String delimiter) {
  var inQuotes = false;
  var count = 0;
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char == '"') {
      if (inQuotes && i + 1 < input.length && input[i + 1] == '"') {
        i++;
        continue;
      }
      inQuotes = !inQuotes;
      continue;
    }
    if (!inQuotes && char == delimiter) {
      count++;
    }
  }
  return count;
}

List<String> _parseDelimitedLine(String line, String delimiter) {
  final out = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
        continue;
      }
      inQuotes = !inQuotes;
      continue;
    }
    if (!inQuotes && ch == delimiter) {
      out.add(buffer.toString().trimRight());
      buffer.clear();
      continue;
    }
    buffer.write(ch);
  }
  out.add(buffer.toString().trimRight());
  return out;
}
