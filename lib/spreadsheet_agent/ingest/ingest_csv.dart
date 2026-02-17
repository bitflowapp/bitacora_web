import 'dart:convert';

import 'package:csv/csv.dart';

import '../spreadsheet_models.dart';

class SpreadsheetCsvIngest {
  const SpreadsheetCsvIngest();

  SpreadsheetIngestResult fromBytes(
    List<int> bytes, {
    String sourceLabel = 'CSV',
  }) {
    final text = _decodeBestEffort(bytes);
    return fromText(text, sourceLabel: sourceLabel);
  }

  SpreadsheetIngestResult fromText(
    String text, {
    String sourceLabel = 'CSV',
  }) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final firstLine = normalized
        .split('\n')
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');

    final delimiter = _resolveDelimiter(firstLine);
    final parsed = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(
      normalized,
      fieldDelimiter: delimiter,
    );

    if (parsed.isEmpty) {
      return const SpreadsheetIngestResult(
        headers: <String>[],
        rows: <List<String>>[],
        sourceLabel: 'CSV',
      );
    }

    final headers = parsed.first
        .map((cell) => cell?.toString().trim() ?? '')
        .toList(growable: false);

    final safeHeaders = List<String>.generate(
      headers.length,
      (index) {
        final value = headers[index].trim();
        return value.isEmpty ? 'col_${index + 1}' : value;
      },
      growable: false,
    );

    final rows = <List<String>>[];
    for (var i = 1; i < parsed.length; i++) {
      final sourceRow = parsed[i];
      final row = List<String>.generate(
        safeHeaders.length,
        (col) => col < sourceRow.length
            ? (sourceRow[col]?.toString() ?? '').trim()
            : '',
        growable: false,
      );
      if (row.every((value) => value.isEmpty)) continue;
      rows.add(row);
    }

    return SpreadsheetIngestResult(
      headers: safeHeaders,
      rows: rows,
      sourceLabel: sourceLabel,
    );
  }

  String _decodeBestEffort(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  String _resolveDelimiter(String line) {
    final commaCount = ','.allMatches(line).length;
    final semicolonCount = ';'.allMatches(line).length;
    return semicolonCount > commaCount ? ';' : ',';
  }
}
