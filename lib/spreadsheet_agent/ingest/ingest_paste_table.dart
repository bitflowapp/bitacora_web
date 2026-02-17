import '../../services/smart_table_paste.dart';
import '../spreadsheet_models.dart';

class SpreadsheetPasteIngest {
  const SpreadsheetPasteIngest();

  SpreadsheetIngestResult fromText(
    String raw, {
    String sourceLabel = 'Pegado',
  }) {
    final parsed = parseSmartTable(raw);
    if (parsed.cells.isEmpty) {
      return SpreadsheetIngestResult(
        headers: const <String>[],
        rows: const <List<String>>[],
        sourceLabel: sourceLabel,
      );
    }

    final hasHeader = _looksLikeHeader(parsed.cells.first);
    final width = parsed.columnCount;
    final headers = hasHeader
        ? List<String>.generate(
            width,
            (index) {
              final value = index < parsed.cells.first.length
                  ? parsed.cells.first[index].trim()
                  : '';
              return value.isEmpty ? 'col_${index + 1}' : value;
            },
            growable: false,
          )
        : List<String>.generate(
            width,
            (index) => 'col_${index + 1}',
            growable: false,
          );

    final rows = <List<String>>[];
    final startIndex = hasHeader ? 1 : 0;
    for (var i = startIndex; i < parsed.cells.length; i++) {
      final source = parsed.cells[i];
      final row = List<String>.generate(
        headers.length,
        (col) => col < source.length ? source[col].trim() : '',
        growable: false,
      );
      if (row.every((value) => value.isEmpty)) continue;
      rows.add(row);
    }

    return SpreadsheetIngestResult(
      headers: headers,
      rows: rows,
      sourceLabel: sourceLabel,
    );
  }

  bool _looksLikeHeader(List<String> row) {
    if (row.isEmpty) return false;
    var alphaCells = 0;
    for (final value in row) {
      final text = value.trim();
      if (text.isEmpty) continue;
      if (RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]').hasMatch(text)) {
        alphaCells++;
      }
    }
    return alphaCells >= (row.length / 2).ceil();
  }
}
