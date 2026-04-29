import 'dart:convert';

import 'package:archive/archive.dart';

import '../spreadsheet_models.dart';

class SpreadsheetXlsxIngest {
  const SpreadsheetXlsxIngest();

  SpreadsheetIngestResult fromBytes(
    List<int> bytes, {
    String sourceLabel = 'XLSX',
  }) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    String? sharedStringsXml;
    final worksheetEntries = <ArchiveFile>[];

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name;
      if (name == 'xl/sharedStrings.xml') {
        sharedStringsXml = _asUtf8(file.content);
      }
      if (name.startsWith('xl/worksheets/') && name.endsWith('.xml')) {
        worksheetEntries.add(file);
      }
    }

    if (worksheetEntries.isEmpty) {
      return SpreadsheetIngestResult(
        headers: const <String>[],
        rows: const <List<String>>[],
        sourceLabel: sourceLabel,
      );
    }

    worksheetEntries.sort((a, b) => a.name.compareTo(b.name));
    final firstSheetXml = _asUtf8(worksheetEntries.first.content);
    final sharedStrings = _parseSharedStrings(sharedStringsXml ?? '');
    final matrix = _parseSheetRows(firstSheetXml, sharedStrings);

    if (matrix.isEmpty) {
      return SpreadsheetIngestResult(
        headers: const <String>[],
        rows: const <List<String>>[],
        sourceLabel: sourceLabel,
      );
    }

    final headers = List<String>.generate(
      matrix.first.length,
      (index) {
        final value = matrix.first[index].trim();
        return value.isEmpty ? 'col_${index + 1}' : value;
      },
      growable: false,
    );

    final rows = <List<String>>[];
    for (var i = 1; i < matrix.length; i++) {
      final sourceRow = matrix[i];
      final row = List<String>.generate(
        headers.length,
        (col) => col < sourceRow.length ? sourceRow[col] : '',
        growable: false,
      );
      if (row.every((value) => value.trim().isEmpty)) continue;
      rows.add(row);
    }

    return SpreadsheetIngestResult(
      headers: headers,
      rows: rows,
      sourceLabel: sourceLabel,
    );
  }

  String _asUtf8(Object? content) {
    if (content is List<int>) {
      return utf8.decode(content, allowMalformed: true);
    }
    return content?.toString() ?? '';
  }

  List<String> _parseSharedStrings(String xml) {
    if (xml.trim().isEmpty) return const <String>[];

    final out = <String>[];
    final siMatches = RegExp(r'<si[^>]*>([\s\S]*?)</si>').allMatches(xml);
    for (final match in siMatches) {
      final value = match.group(1) ?? '';
      final textParts = RegExp(r'<t[^>]*>([\s\S]*?)</t>').allMatches(value);
      if (textParts.isEmpty) {
        out.add('');
        continue;
      }
      final buffer = StringBuffer();
      for (final t in textParts) {
        buffer.write(_decodeXmlText(t.group(1) ?? ''));
      }
      out.add(buffer.toString());
    }
    return out;
  }

  List<List<String>> _parseSheetRows(
      String sheetXml, List<String> sharedStrings) {
    final rows = <int, Map<int, String>>{};
    var maxCol = 0;
    var maxRow = 0;

    final cellRegex = RegExp(
      r'<c([^>]*)>([\s\S]*?)</c>',
      multiLine: true,
    );

    for (final match in cellRegex.allMatches(sheetXml)) {
      final attrs = match.group(1) ?? '';
      final body = match.group(2) ?? '';
      final refMatch = RegExp(r'\sr="([A-Z]+)(\d+)"').firstMatch(attrs);
      if (refMatch == null) continue;

      final colLetters = refMatch.group(1) ?? '';
      final rowNumber = int.tryParse(refMatch.group(2) ?? '') ?? 0;
      if (rowNumber <= 0) continue;

      final colIndex = _colLettersToIndex(colLetters);
      if (colIndex < 0) continue;

      final type = RegExp(r'\st="([^"]+)"').firstMatch(attrs)?.group(1) ?? '';
      var value = '';
      if (type == 'inlineStr') {
        final inline =
            RegExp(r'<t[^>]*>([\s\S]*?)</t>').firstMatch(body)?.group(1) ?? '';
        value = _decodeXmlText(inline);
      } else {
        final raw =
            RegExp(r'<v>([\s\S]*?)</v>').firstMatch(body)?.group(1) ?? '';
        if (type == 's') {
          final idx = int.tryParse(raw.trim());
          if (idx != null && idx >= 0 && idx < sharedStrings.length) {
            value = sharedStrings[idx];
          }
        } else {
          value = _decodeXmlText(raw);
        }
      }

      rows.putIfAbsent(rowNumber, () => <int, String>{})[colIndex] = value;
      if (colIndex > maxCol) maxCol = colIndex;
      if (rowNumber > maxRow) maxRow = rowNumber;
    }

    final matrix = <List<String>>[];
    for (var row = 1; row <= maxRow; row++) {
      final rowMap = rows[row];
      if (rowMap == null) continue;
      final values = List<String>.filled(maxCol + 1, '', growable: false);
      rowMap.forEach((col, value) {
        if (col >= 0 && col < values.length) {
          values[col] = value.trim();
        }
      });
      matrix.add(values);
    }

    return matrix;
  }

  int _colLettersToIndex(String letters) {
    var value = 0;
    for (var i = 0; i < letters.length; i++) {
      final code = letters.codeUnitAt(i);
      if (code < 65 || code > 90) return -1;
      value = (value * 26) + (code - 64);
    }
    return value - 1;
  }

  String _decodeXmlText(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
}
