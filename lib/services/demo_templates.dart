class DemoTemplateSpec {
  const DemoTemplateSpec({
    required this.slug,
    required this.name,
    required this.sheetName,
    required this.headers,
    required this.rows,
  });

  final String slug;
  final String name;
  final String sheetName;
  final List<String> headers;
  final List<List<String>> rows;
}

const List<DemoTemplateSpec> kDemoTemplateSpecs = <DemoTemplateSpec>[
  DemoTemplateSpec(
    slug: 'campo',
    name: 'Campo',
    sheetName: 'Demo Campo',
    headers: <String>[
      'Fecha',
      'Frente',
      'Actividad',
      'Estado',
      'Observaciones'
    ],
    rows: <List<String>>[
      <String>['2026-02-14', 'Norte', 'Replanteo', 'OK', 'Sin novedad'],
      <String>[
        '2026-02-14',
        'Norte',
        'Hormigonado',
        'Pendiente',
        'Falta mixer'
      ],
      <String>['2026-02-14', 'Sur', 'Excavacion', 'OK', 'Cota verificada'],
      <String>['2026-02-14', 'Sur', 'Compactacion', 'Obs', 'Humedad alta'],
      <String>['2026-02-14', 'Este', 'Canaleta', 'OK', ''],
    ],
  ),
  DemoTemplateSpec(
    slug: 'inventario',
    name: 'Inventario',
    sheetName: 'Demo Inventario',
    headers: <String>['SKU', 'Item', 'Cantidad', 'Unidad', 'Ubicacion'],
    rows: <List<String>>[
      <String>['MAT-001', 'Cemento', '35', 'bolsas', 'Deposito A'],
      <String>['MAT-014', 'Hierro 8mm', '120', 'u', 'Deposito B'],
      <String>['MAT-032', 'Arena', '18', 'm3', 'Patio'],
      <String>['EPP-002', 'Guantes', '56', 'pares', 'Panuelo'],
      <String>['EPP-010', 'Cascos', '24', 'u', 'Oficina'],
    ],
  ),
  DemoTemplateSpec(
    slug: 'rendicion',
    name: 'Rendicion',
    sheetName: 'Demo Rendicion',
    headers: <String>['Fecha', 'Concepto', 'Categoria', 'Monto', 'Comprobante'],
    rows: <List<String>>[
      <String>['2026-02-10', 'Combustible', 'Movilidad', '45200', 'TK-1001'],
      <String>['2026-02-10', 'Peaje', 'Movilidad', '7800', 'TK-1002'],
      <String>[
        '2026-02-11',
        'Almuerzo cuadrilla',
        'Viaticos',
        '23500',
        'TK-1003'
      ],
      <String>['2026-02-12', 'Ferreteria', 'Materiales', '68400', 'TK-1004'],
      <String>['2026-02-13', 'Taxi', 'Movilidad', '9800', 'TK-1005'],
    ],
  ),
];

DemoTemplateSpec? resolveDemoTemplateFromSlug(String? slug) {
  final normalized = (slug ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return null;
  for (final spec in kDemoTemplateSpecs) {
    if (spec.slug == normalized) return spec;
  }
  return null;
}
