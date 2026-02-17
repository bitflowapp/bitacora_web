import 'package:flutter/foundation.dart';

enum SpreadsheetFieldType { text, date, number, currency, integer }

@immutable
class SpreadsheetTemplateField {
  const SpreadsheetTemplateField({
    required this.key,
    required this.label,
    this.type = SpreadsheetFieldType.text,
    this.required = false,
    this.min,
    this.max,
  });

  final String key;
  final String label;
  final SpreadsheetFieldType type;
  final bool required;
  final double? min;
  final double? max;
}

@immutable
class SpreadsheetTemplate {
  const SpreadsheetTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.fields,
    this.duplicateKeyFields = const <String>[],
    this.vatRate,
    this.totalField,
    this.netField,
    this.vatField,
  });

  final String id;
  final String name;
  final String description;
  final List<SpreadsheetTemplateField> fields;
  final List<String> duplicateKeyFields;
  final double? vatRate;
  final String? totalField;
  final String? netField;
  final String? vatField;

  List<String> get fieldKeys =>
      fields.map((f) => f.key).toList(growable: false);

  SpreadsheetTemplateField? fieldByKey(String key) {
    for (final field in fields) {
      if (field.key == key) return field;
    }
    return null;
  }
}

@immutable
class SpreadsheetIngestResult {
  const SpreadsheetIngestResult({
    required this.headers,
    required this.rows,
    required this.sourceLabel,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final String sourceLabel;

  bool get isEmpty => headers.isEmpty || rows.isEmpty;
}

@immutable
class SpreadsheetValidationIssue {
  const SpreadsheetValidationIssue({
    required this.row,
    required this.field,
    required this.message,
    this.value,
    this.isWarning = false,
  });

  final int row;
  final String field;
  final String message;
  final String? value;
  final bool isWarning;
}

@immutable
class SpreadsheetValidationReport {
  const SpreadsheetValidationReport({required this.issues});

  final List<SpreadsheetValidationIssue> issues;

  bool get hasErrors => issues.any((issue) => !issue.isWarning);

  int get errorCount => issues.where((issue) => !issue.isWarning).length;

  int get warningCount => issues.where((issue) => issue.isWarning).length;
}

@immutable
class SpreadsheetExportArtifact {
  const SpreadsheetExportArtifact({
    required this.fileName,
    required this.location,
    required this.bytes,
  });

  final String fileName;
  final String location;
  final int bytes;
}

String normalizeHeader(String input) {
  var value = input.trim().toLowerCase();
  const replacements = <String, String>{
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
  };
  replacements.forEach((k, v) => value = value.replaceAll(k, v));
  value = value
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp('_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return value;
}

DateTime? parseLooseDate(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  final iso = DateTime.tryParse(text);
  if (iso != null) return iso;

  final compactIso =
      RegExp(r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})$').firstMatch(text);
  if (compactIso != null) {
    final y = int.tryParse(compactIso.group(1) ?? '');
    final mm = int.tryParse(compactIso.group(2) ?? '');
    final d = int.tryParse(compactIso.group(3) ?? '');
    if (y != null && mm != null && d != null) {
      if (mm >= 1 && mm <= 12 && d >= 1 && d <= 31) {
        return DateTime(y, mm, d);
      }
    }
  }

  final m = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$').firstMatch(text);
  if (m != null) {
    final d = int.tryParse(m.group(1) ?? '');
    final mm = int.tryParse(m.group(2) ?? '');
    final yRaw = int.tryParse(m.group(3) ?? '');
    if (d != null && mm != null && yRaw != null) {
      final year = yRaw < 100 ? 2000 + yRaw : yRaw;
      if (mm >= 1 && mm <= 12 && d >= 1 && d <= 31) {
        return DateTime(year, mm, d);
      }
    }
  }

  // Excel serial date fallback (common on XLSX raw values):
  // 1 = 1899-12-31 in Excel, but using 1899-12-30 base aligns with modern readers.
  if (RegExp(r'^\d+([.,]\d+)?$').hasMatch(text)) {
    final serial = parseLooseNumber(text);
    if (serial != null && serial >= 1 && serial <= 80000) {
      final wholeDays = serial.floor();
      return DateTime(1899, 12, 30).add(Duration(days: wholeDays));
    }
  }

  return null;
}

double? parseLooseNumber(String raw) {
  final input = raw.trim();
  if (input.isEmpty) return null;
  var cleaned = input.replaceAll(RegExp(r'[^0-9,.-]'), '');

  final hasComma = cleaned.contains(',');
  final hasDot = cleaned.contains('.');
  if (hasComma && hasDot) {
    if (cleaned.lastIndexOf(',') > cleaned.lastIndexOf('.')) {
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else {
      cleaned = cleaned.replaceAll(',', '');
    }
  } else if (hasComma && !hasDot) {
    cleaned = cleaned.replaceAll(',', '.');
  }

  return double.tryParse(cleaned);
}
