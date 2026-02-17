import '../spreadsheet_models.dart';

class SpreadsheetColumnMapper {
  const SpreadsheetColumnMapper();

  static const Map<String, List<String>> _aliasesByField =
      <String, List<String>>{
    'fecha': <String>['fecha', 'date', 'dia'],
    'comprobante': <String>['comprobante', 'factura', 'nro_factura', 'numero'],
    'proveedor': <String>['proveedor', 'vendor', 'empresa'],
    'concepto': <String>['concepto', 'detalle', 'descripcion'],
    'centro_costo': <String>['centro_costo', 'centro', 'cc', 'cost_center'],
    'obra': <String>['obra', 'proyecto', 'site'],
    'neto': <String>['neto', 'subtotal', 'importe_neto'],
    'iva': <String>['iva', 'vat', 'impuesto'],
    'total': <String>['total', 'importe', 'monto_total'],
    'frente': <String>['frente', 'sector'],
    'actividad': <String>['actividad', 'task', 'trabajo'],
    'cuadrilla': <String>['cuadrilla', 'equipo', 'personal'],
    'avance_pct': <String>['avance_pct', 'avance', 'avance_%', 'progreso'],
    'horas': <String>['horas', 'hh', 'horas_hombre'],
    'unidad': <String>['unidad', 'uom', 'um'],
    'material': <String>['material', 'insumo', 'item'],
    'tipo_movimiento': <String>['tipo_movimiento', 'movimiento', 'tipo'],
    'cantidad': <String>['cantidad', 'qty', 'cant'],
    'deposito': <String>['deposito', 'almacen', 'warehouse'],
    'saldo': <String>['saldo', 'stock_final', 'balance'],
  };

  Map<String, String> autoMap({
    required SpreadsheetTemplate template,
    required List<String> sourceHeaders,
    Map<String, String> profileMap = const <String, String>{},
  }) {
    final out = <String, String>{};
    final availableFields = template.fieldKeys.toSet();

    for (final header in sourceHeaders) {
      final profileCandidate = profileMap[header];
      if (profileCandidate != null && availableFields.contains(profileCandidate)) {
        out[header] = profileCandidate;
        continue;
      }

      final normalizedHeader = normalizeHeader(header);
      final direct = _directMatch(template, normalizedHeader);
      if (direct != null) {
        out[header] = direct;
        continue;
      }

      final alias = _aliasMatch(template, normalizedHeader);
      if (alias != null) {
        out[header] = alias;
      }
    }

    return out;
  }

  List<Map<String, String>> transformRows({
    required SpreadsheetTemplate template,
    required List<String> headers,
    required List<List<String>> rows,
    required Map<String, String> headerToField,
    Map<String, String> defaultValues = const <String, String>{},
  }) {
    final mappedRows = <Map<String, String>>[];

    for (final sourceRow in rows) {
      final rowMap = <String, String>{};

      for (var i = 0; i < headers.length; i++) {
        final header = headers[i];
        final fieldKey = headerToField[header];
        if ((fieldKey ?? '').isEmpty) continue;
        final value = i < sourceRow.length ? sourceRow[i].trim() : '';
        if (value.isNotEmpty) {
          rowMap[fieldKey!] = value;
        }
      }

      for (final field in template.fields) {
        if ((rowMap[field.key] ?? '').trim().isNotEmpty) continue;
        final fallback = (defaultValues[field.key] ?? '').trim();
        if (fallback.isNotEmpty) {
          rowMap[field.key] = fallback;
        }
      }

      mappedRows.add(rowMap);
    }

    return mappedRows;
  }

  String? _directMatch(SpreadsheetTemplate template, String normalizedHeader) {
    for (final field in template.fields) {
      if (normalizeHeader(field.key) == normalizedHeader) return field.key;
      if (normalizeHeader(field.label) == normalizedHeader) return field.key;
    }
    return null;
  }

  String? _aliasMatch(SpreadsheetTemplate template, String normalizedHeader) {
    final available = template.fieldKeys.toSet();
    for (final entry in _aliasesByField.entries) {
      if (!available.contains(entry.key)) continue;
      for (final alias in entry.value) {
        if (normalizeHeader(alias) == normalizedHeader) {
          return entry.key;
        }
      }
    }
    return null;
  }
}
