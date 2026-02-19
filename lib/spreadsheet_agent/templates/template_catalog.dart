import '../spreadsheet_models.dart';

class SpreadsheetTemplateCatalog {
  const SpreadsheetTemplateCatalog._();

  static const List<SpreadsheetTemplate> templates = <SpreadsheetTemplate>[
    SpreadsheetTemplate(
      id: 'rendicion_gastos',
      name: 'Rendición de gastos / viáticos',
      description:
          'Caja chica, facturas y rendición mensual por centro de costo.',
      duplicateKeyFields: <String>['comprobante'],
      vatRate: 0.21,
      netField: 'neto',
      vatField: 'iva',
      totalField: 'total',
      fields: <SpreadsheetTemplateField>[
        SpreadsheetTemplateField(
          key: 'fecha',
          label: 'Fecha',
          type: SpreadsheetFieldType.date,
          required: true,
        ),
        SpreadsheetTemplateField(
          key: 'comprobante',
          label: 'Comprobante',
          required: true,
        ),
        SpreadsheetTemplateField(
          key: 'proveedor',
          label: 'Proveedor',
          required: true,
        ),
        SpreadsheetTemplateField(
          key: 'concepto',
          label: 'Concepto',
          required: true,
        ),
        SpreadsheetTemplateField(
          key: 'centro_costo',
          label: 'Centro de costo',
        ),
        SpreadsheetTemplateField(
          key: 'obra',
          label: 'Obra',
        ),
        SpreadsheetTemplateField(
          key: 'neto',
          label: 'Neto',
          type: SpreadsheetFieldType.currency,
          min: 0,
        ),
        SpreadsheetTemplateField(
          key: 'iva',
          label: 'IVA',
          type: SpreadsheetFieldType.currency,
          min: 0,
        ),
        SpreadsheetTemplateField(
          key: 'total',
          label: 'Total',
          type: SpreadsheetFieldType.currency,
          min: 0,
          required: true,
        ),
      ],
    ),
    SpreadsheetTemplate(
      id: 'parte_diario_obra',
      name: 'Parte diario / avance de obra',
      description: 'Registro diario de frente, cuadrilla y avance.',
      duplicateKeyFields: <String>['fecha', 'frente'],
      fields: <SpreadsheetTemplateField>[
        SpreadsheetTemplateField(
          key: 'fecha',
          label: 'Fecha',
          type: SpreadsheetFieldType.date,
          required: true,
        ),
        SpreadsheetTemplateField(
          key: 'obra',
          label: 'Obra',
          required: true,
        ),
        SpreadsheetTemplateField(
          key: 'frente',
          label: 'Frente',
          required: true,
        ),
        SpreadsheetTemplateField(
          key: 'actividad',
          label: 'Actividad',
          required: true,
        ),
        SpreadsheetTemplateField(
          key: 'cuadrilla',
          label: 'Cuadrilla',
          type: SpreadsheetFieldType.integer,
          min: 0,
        ),
        SpreadsheetTemplateField(
          key: 'avance_pct',
          label: 'Avance %',
          type: SpreadsheetFieldType.number,
          min: 0,
          max: 100,
        ),
        SpreadsheetTemplateField(
          key: 'horas',
          label: 'Horas',
          type: SpreadsheetFieldType.number,
          min: 0,
        ),
        SpreadsheetTemplateField(
          key: 'unidad',
          label: 'Unidad',
          required: true,
        ),
      ],
    ),
    SpreadsheetTemplate(
      id: 'stock_materiales',
      name: 'Stock / ingreso-egreso de materiales',
      description: 'Movimientos de materiales, saldos y control de unidad.',
      duplicateKeyFields: <String>['fecha', 'material', 'tipo_movimiento'],
      fields: <SpreadsheetTemplateField>[
        SpreadsheetTemplateField(
          key: 'fecha',
          label: 'Fecha',
          type: SpreadsheetFieldType.date,
          required: true,
        ),
        SpreadsheetTemplateField(
          key: 'material',
          label: 'Material',
          required: true,
        ),
        SpreadsheetTemplateField(
          key: 'tipo_movimiento',
          label: 'Tipo movimiento',
          required: true,
        ),
        SpreadsheetTemplateField(
          key: 'cantidad',
          label: 'Cantidad',
          type: SpreadsheetFieldType.number,
          required: true,
          min: 0,
        ),
        SpreadsheetTemplateField(
          key: 'unidad',
          label: 'Unidad',
          required: true,
        ),
        SpreadsheetTemplateField(
          key: 'deposito',
          label: 'Depósito',
        ),
        SpreadsheetTemplateField(
          key: 'obra',
          label: 'Obra',
        ),
        SpreadsheetTemplateField(
          key: 'saldo',
          label: 'Saldo',
          type: SpreadsheetFieldType.number,
          min: 0,
        ),
      ],
    ),
  ];

  static SpreadsheetTemplate byId(String id) {
    for (final template in templates) {
      if (template.id == id) return template;
    }
    return templates.first;
  }
}
