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
    slug: 'relevamiento-evidencias',
    name: 'Relevamiento con evidencias',
    sheetName: 'Relevamiento técnico con evidencias',
    headers: <String>[
      'Fecha',
      'Cliente',
      'Sector',
      'Hallazgo',
      'Criticidad',
      'Acción recomendada',
      'Responsable',
      'Foto / Evidencia'
    ],
    rows: <List<String>>[
      <String>[
        '2026-04-20',
        'Operadora Norte',
        'Manifold 3',
        'Etiqueta ilegible en válvula bypass',
        'Media',
        'Reponer identificación y fotografiar cierre.',
        'S. Pérez',
        ''
      ],
      <String>[
        '2026-04-20',
        'Operadora Norte',
        'Línea 6"',
        'Soporte con corrosión superficial',
        'Media',
        'Lijar, pintar y registrar evidencia final.',
        'S. Pérez',
        ''
      ],
      <String>[
        '2026-04-20',
        'Operadora Norte',
        'Caseta RTU',
        'Puerta cierra correctamente',
        'Baja',
        'Sin acción. Mantener control mensual.',
        'N. Ruiz',
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
    headers: <String>['SKU', 'Item', 'Cantidad', 'Unidad', 'Ubicación'],
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
  DemoTemplateSpec(
    slug: 'gastos',
    name: 'Control de gastos',
    sheetName: 'Control de Gastos',
    headers: <String>[
      'Fecha',
      'Categoria',
      'Descripcion',
      'Monto',
      'Medio',
      'Estado'
    ],
    rows: <List<String>>[
      <String>[
        '2026-03-01',
        'Movilidad',
        'Combustible',
        '42000',
        'Tarjeta',
        'OK'
      ],
      <String>[
        '2026-03-01',
        'Comidas',
        'Almuerzo equipo',
        '18500',
        'Efectivo',
        'OK'
      ],
      <String>[
        '2026-03-02',
        'Materiales',
        'Ferreteria',
        '63800',
        'Transferencia',
        'OK'
      ],
      <String>[
        '2026-03-02',
        'Servicios',
        'Mensajeria',
        '9200',
        'Tarjeta',
        'Obs'
      ],
      <String>[
        '2026-03-03',
        'Viaticos',
        'Taxi cliente',
        '12600',
        'Efectivo',
        'OK'
      ],
      <String>['2026-03-03', 'TOTAL', '', '=SUM(D1:D5)', '', ''],
    ],
  ),
  DemoTemplateSpec(
    slug: 'proyectos',
    name: 'Seguimiento de proyectos',
    sheetName: 'Seguimiento de Proyectos',
    headers: <String>[
      'Proyecto',
      'Responsable',
      'Inicio',
      'Fin objetivo',
      '% Avance',
      'Estado',
      'Riesgo'
    ],
    rows: <List<String>>[
      <String>[
        'Pipeline Norte',
        'Ana',
        '2026-02-10',
        '2026-04-30',
        '45',
        'OK',
        'Bajo'
      ],
      <String>[
        'SCADA Planta',
        'Luis',
        '2026-01-20',
        '2026-05-15',
        '62',
        'Obs',
        'Medio'
      ],
      <String>[
        'Relevamiento RTU',
        'Marta',
        '2026-03-01',
        '2026-03-25',
        '30',
        'Urgente',
        'Alto'
      ],
      <String>[
        'Backlog interno',
        'PMO',
        '2026-02-01',
        '2026-03-31',
        '=ROUND(AVERAGE(E1:E3), 0)',
        '',
        ''
      ],
    ],
  ),
  DemoTemplateSpec(
    slug: 'mediciones',
    name: 'Mediciones tecnicas',
    sheetName: 'Mediciones Tecnicas',
    headers: <String>[
      'Fecha',
      'Punto',
      'Parametro',
      'Lectura',
      'Unidad',
      'Limite',
      'Estado'
    ],
    rows: <List<String>>[
      <String>[
        '2026-03-02',
        'P-01',
        'Resistencia',
        '4.3',
        'Ohm',
        '5.0',
        '=IF(D1<=F1, "OK", "CHECK")'
      ],
      <String>[
        '2026-03-02',
        'P-02',
        'Resistencia',
        '5.8',
        'Ohm',
        '5.0',
        '=IF(D2<=F2, "OK", "CHECK")'
      ],
      <String>[
        '2026-03-02',
        'P-03',
        'Resistencia',
        '4.9',
        'Ohm',
        '5.0',
        '=IF(D3<=F3, "OK", "CHECK")'
      ],
      <String>[
        '2026-03-02',
        'PROM',
        'Lectura promedio',
        '=ROUND(AVERAGE(D1:D3),2)',
        'Ohm',
        '',
        ''
      ],
    ],
  ),
];

DemoTemplateSpec? resolveDemoTemplateFromSlug(String? slug) {
  final normalized = (slug ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return null;
  const aliases = <String, String>{
    'evidencias': 'relevamiento-evidencias',
    'relevamiento': 'relevamiento-evidencias',
    'demo-tecnica': 'relevamiento-evidencias',
  };
  final effective = aliases[normalized] ?? normalized;
  for (final spec in kDemoTemplateSpecs) {
    if (spec.slug == effective) return spec;
  }
  return null;
}
