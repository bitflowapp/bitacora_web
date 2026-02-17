import '../spreadsheet_models.dart';

class SpreadsheetValidator {
  const SpreadsheetValidator();

  SpreadsheetValidationReport validate({
    required SpreadsheetTemplate template,
    required List<Map<String, String>> rows,
  }) {
    final issues = <SpreadsheetValidationIssue>[];
    final duplicateBuckets = <String, int>{};

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNumber = i + 2;

      for (final field in template.fields) {
        final value = (row[field.key] ?? '').trim();

        if (field.required && value.isEmpty) {
          issues.add(
            SpreadsheetValidationIssue(
              row: rowNumber,
              field: field.key,
              message: 'Campo obligatorio vacío',
            ),
          );
          continue;
        }

        if (value.isEmpty) continue;

        switch (field.type) {
          case SpreadsheetFieldType.date:
            if (parseLooseDate(value) == null) {
              issues.add(
                SpreadsheetValidationIssue(
                  row: rowNumber,
                  field: field.key,
                  message: 'Fecha inválida',
                  value: value,
                ),
              );
            }
            break;
          case SpreadsheetFieldType.number:
          case SpreadsheetFieldType.currency:
          case SpreadsheetFieldType.integer:
            final number = parseLooseNumber(value);
            if (number == null) {
              issues.add(
                SpreadsheetValidationIssue(
                  row: rowNumber,
                  field: field.key,
                  message: 'Número inválido',
                  value: value,
                ),
              );
              break;
            }
            if (field.type == SpreadsheetFieldType.integer &&
                (number % 1).abs() > 0.0001) {
              issues.add(
                SpreadsheetValidationIssue(
                  row: rowNumber,
                  field: field.key,
                  message: 'Debe ser entero',
                  value: value,
                ),
              );
            }
            if (field.min != null && number < field.min!) {
              issues.add(
                SpreadsheetValidationIssue(
                  row: rowNumber,
                  field: field.key,
                  message: 'Valor menor al mínimo (${field.min})',
                  value: value,
                ),
              );
            }
            if (field.max != null && number > field.max!) {
              issues.add(
                SpreadsheetValidationIssue(
                  row: rowNumber,
                  field: field.key,
                  message: 'Valor mayor al máximo (${field.max})',
                  value: value,
                ),
              );
            }
            break;
          case SpreadsheetFieldType.text:
            break;
        }
      }

      _validateTemplateSpecific(template, row, rowNumber, issues);

      if (template.duplicateKeyFields.isNotEmpty) {
        final duplicateKey = template.duplicateKeyFields
            .map((field) => (row[field] ?? '').trim().toLowerCase())
            .join('|');
        if (duplicateKey.replaceAll('|', '').isNotEmpty) {
          final previous = duplicateBuckets[duplicateKey];
          if (previous != null) {
            issues.add(
              SpreadsheetValidationIssue(
                row: rowNumber,
                field: template.duplicateKeyFields.join(', '),
                message: 'Posible duplicado (coincide con fila $previous)',
                isWarning: true,
              ),
            );
          } else {
            duplicateBuckets[duplicateKey] = rowNumber;
          }
        }
      }
    }

    return SpreadsheetValidationReport(issues: issues);
  }

  void _validateTemplateSpecific(
    SpreadsheetTemplate template,
    Map<String, String> row,
    int rowNumber,
    List<SpreadsheetValidationIssue> issues,
  ) {
    final netField = template.netField;
    final vatField = template.vatField;
    final totalField = template.totalField;

    if (netField != null && vatField != null && totalField != null) {
      final net = parseLooseNumber(row[netField] ?? '');
      final vat = parseLooseNumber(row[vatField] ?? '');
      final total = parseLooseNumber(row[totalField] ?? '');

      if (net != null && vat != null && total != null) {
        final expected = net + vat;
        if ((expected - total).abs() > 0.05) {
          issues.add(
            SpreadsheetValidationIssue(
              row: rowNumber,
              field: totalField,
              message: 'Total no coincide con neto + IVA',
              value: row[totalField],
            ),
          );
        }
      }

      final vatRate = template.vatRate;
      if (vatRate != null && net != null && vat != null) {
        final expectedVat = net * vatRate;
        if ((expectedVat - vat).abs() > 1.0) {
          issues.add(
            SpreadsheetValidationIssue(
              row: rowNumber,
              field: vatField,
              message: 'IVA fuera de tolerancia para alícuota ${(vatRate * 100).toStringAsFixed(0)}%',
              value: row[vatField],
              isWarning: true,
            ),
          );
        }
      }
    }

    final unitField = template.fieldByKey('unidad');
    if (unitField != null) {
      final unit = (row['unidad'] ?? '').trim().toLowerCase();
      if (unit.isNotEmpty) {
        const allowed = <String>{
          'u',
          'un',
          'kg',
          'm',
          'm2',
          'm3',
          'lts',
          'lt',
          'bolsa',
          'caja',
          'hora',
          'hh',
        };
        if (!allowed.contains(unit)) {
          issues.add(
            SpreadsheetValidationIssue(
              row: rowNumber,
              field: 'unidad',
              message: 'Unidad no estándar (revisar catálogo interno)',
              value: unit,
              isWarning: true,
            ),
          );
        }
      }
    }
  }
}
