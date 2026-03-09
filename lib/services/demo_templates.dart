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
      <String>['2026-02-14', 'Sur', 'Excavaci\u00f3n', 'OK', 'Cota verificada'],
      <String>['2026-02-14', 'Sur', 'Compactaci\u00f3n', 'Obs', 'Humedad alta'],
      <String>['2026-02-14', 'Este', 'Canaleta', 'OK', ''],
    ],
  ),
  DemoTemplateSpec(
    slug: 'inventario',
    name: 'Inventario',
    sheetName: 'Demo Inventario',
    headers: <String>['SKU', 'Item', 'Cantidad', 'Unidad', 'Ubicaci\u00f3n'],
    rows: <List<String>>[
      <String>['MAT-001', 'Cemento', '35', 'bolsas', 'Dep\u00f3sito A'],
      <String>['MAT-014', 'Hierro 8mm', '120', 'u', 'Dep\u00f3sito B'],
      <String>['MAT-032', 'Arena', '18', 'm3', 'Patio'],
      <String>['EPP-002', 'Guantes', '56', 'pares', 'Pa\u00f1uelo'],
      <String>['EPP-010', 'Cascos', '24', 'u', 'Oficina'],
    ],
  ),
  DemoTemplateSpec(
    slug: 'rendicion',
    name: 'Rendici\u00f3n',
    sheetName: 'Demo Rendici\u00f3n',
    headers: <String>['Fecha', 'Concepto', 'Categor\u00eda', 'Monto', 'Comprobante'],
    rows: <List<String>>[
      <String>['2026-02-10', 'Combustible', 'Movilidad', '45200', 'TK-1001'],
      <String>['2026-02-10', 'Peaje', 'Movilidad', '7800', 'TK-1002'],
      <String>[
        '2026-02-11',
        'Almuerzo cuadrilla',
        'Vi\u00e1ticos',
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
      'Categor\u00eda',
      'Descripci\u00f3n',
      'Monto',
      'Medio',
      'Estado'
    ],
    rows: <List<String>>[
      <String>['2026-03-01', 'Movilidad', 'Combustible', '42000', 'Tarjeta', 'OK'],
      <String>['2026-03-01', 'Comidas', 'Almuerzo equipo', '18500', 'Efectivo', 'OK'],
      <String>['2026-03-02', 'Materiales', 'Ferreteria', '63800', 'Transferencia', 'OK'],
      <String>['2026-03-02', 'Servicios', 'Mensajer\u00eda', '9200', 'Tarjeta', 'Obs'],
      <String>['2026-03-03', 'Vi\u00e1ticos', 'Taxi cliente', '12600', 'Efectivo', 'OK'],
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
      <String>['Pipeline Norte', 'Ana', '2026-02-10', '2026-04-30', '45', 'OK', 'Bajo'],
      <String>['SCADA Planta', 'Luis', '2026-01-20', '2026-05-15', '62', 'Obs', 'Medio'],
      <String>['Relevamiento RTU', 'Marta', '2026-03-01', '2026-03-25', '30', 'Urgente', 'Alto'],
      <String>['Backlog interno', 'PMO', '2026-02-01', '2026-03-31', '=ROUND(AVERAGE(E1:E3), 0)', '', ''],
    ],
  ),
  DemoTemplateSpec(
    slug: 'mediciones',
    name: 'Mediciones t\u00e9cnicas',
    sheetName: 'Mediciones Tecnicas',
    headers: <String>[
      'Fecha',
      'Punto',
      'Par\u00e1metro',
      'Lectura',
      'Unidad',
      'L\u00edmite',
      'Estado'
    ],
    rows: <List<String>>[
      <String>['2026-03-02', 'P-01', 'Resistencia', '4.3', 'Ohm', '5.0', '=IF(D1<=F1, "OK", "CHECK")'],
      <String>['2026-03-02', 'P-02', 'Resistencia', '5.8', 'Ohm', '5.0', '=IF(D2<=F2, "OK", "CHECK")'],
      <String>['2026-03-02', 'P-03', 'Resistencia', '4.9', 'Ohm', '5.0', '=IF(D3<=F3, "OK", "CHECK")'],
      <String>['2026-03-02', 'PROM', 'Lectura promedio', '=ROUND(AVERAGE(D1:D3),2)', 'Ohm', '', ''],
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

