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
    slug: 'proteccion-catodica',
    name: 'Proteccion Catodica',
    sheetName: 'Demo Proteccion Catodica',
    headers: <String>[
      'Fecha',
      'Progresiva',
      'Punto de medicion',
      'Potencial ON (V)',
      'Potencial OFF (V)',
      'IR drop (V)',
      'Cupon',
      'Estado',
      'Observaciones',
      'Fotos'
    ],
    rows: <List<String>>[
      <String>[
        '2026-04-22',
        '12+000',
        'CMP-120',
        '-1.12',
        '-0.92',
        '0.20',
        'Polarizado',
        'OK',
        'Caja limpia. Referencia Cu/CuSO4 estable.',
        ''
      ],
      <String>[
        '2026-04-22',
        '12+025',
        'CMP-121',
        '-1.08',
        '-0.88',
        '0.20',
        'Polarizado',
        'OK',
        'Sin dano visible. Registrar foto de tapa.',
        ''
      ],
      <String>[
        '2026-04-22',
        '12+050',
        'CMP-122',
        '-0.82',
        '-0.61',
        '0.21',
        'Despolarizado',
        'Obs',
        'Revisar continuidad y repetir medicion en contraprueba.',
        ''
      ],
      <String>[
        '2026-04-22',
        '12+075',
        'Junta aislante',
        '-1.01',
        '-0.84',
        '0.17',
        'N/A',
        'OK',
        'Lectura dentro de rango operativo del tramo.',
        ''
      ],
    ],
  ),
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
  final aliases = <String, String>{
    'pc': 'proteccion-catodica',
    'proteccion': 'proteccion-catodica',
    'proteccioncatodica': 'proteccion-catodica',
    'proteccion_catodica': 'proteccion-catodica',
  };
  final effective = aliases[normalized] ?? normalized;
  for (final spec in kDemoTemplateSpecs) {
    if (spec.slug == effective) return spec;
  }
  return null;
}
