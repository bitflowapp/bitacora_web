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
    name: 'Proteccion catodica',
    sheetName: 'Demo - Proteccion catodica Loma Norte',
    headers: <String>[
      'Fecha',
      'Progresiva',
      'Punto de medición',
      'Potencial ON (V)',
      'Potencial OFF (V)',
      'IR drop (V)',
      'Cupon',
      'Estado',
      'Observaciones',
      'Responsable',
      'Foto / Evidencia'
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
        'M. Luna',
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
        'Sin dano visible. Tapa identificada y accesible.',
        'M. Luna',
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
        'Revisar continuidad y repetir medición en contraprueba.',
        'A. Rojas',
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
        'A. Rojas',
        ''
      ],
    ],
  ),
  DemoTemplateSpec(
    slug: 'puesta-a-tierra',
    name: 'Puesta a tierra',
    sheetName: 'Demo - Puesta a tierra planta compresora',
    headers: <String>[
      'Fecha',
      'Sector',
      'Punto PAT',
      'Resistencia (Ohm)',
      'Continuidad',
      'Estado',
      'Observaciones',
      'Responsable',
      'Foto / Evidencia'
    ],
    rows: <List<String>>[
      <String>[
        '2026-04-21',
        'Tablero bombas',
        'PAT-TB-01',
        '2.8',
        'OK',
        'OK',
        'Bornes limpios. Se adjunta foto de jabalina.',
        'L. Vega',
        ''
      ],
      <String>[
        '2026-04-21',
        'Sala MCC',
        'PAT-MCC-02',
        '4.6',
        'OK',
        'Obs',
        'Valor alto para criterio interno. Repetir con terreno humedo.',
        'L. Vega',
        ''
      ],
      <String>[
        '2026-04-21',
        'Skid medición',
        'PAT-SK-03',
        '1.9',
        'OK',
        'OK',
        'Cable identificado y continuidad verificada.',
        'N. Ruiz',
        ''
      ],
    ],
  ),
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
    name: 'Inspección de campo',
    sheetName: 'Demo - Inspección operativa de campo',
    headers: <String>[
      'Fecha',
      'Frente',
      'Actividad',
      'Estado',
      'Observaciones',
      'Responsable',
      'Foto / Evidencia'
    ],
    rows: <List<String>>[
      <String>[
        '2026-04-19',
        'Norte',
        'Replanteo de traza',
        'OK',
        'Puntos marcados y fotografiados.',
        'J. Soto',
        ''
      ],
      <String>[
        '2026-04-19',
        'Norte',
        'Cruce de camino',
        'Obs',
        'Permiso pendiente para ingreso de equipo.',
        'J. Soto',
        ''
      ],
      <String>[
        '2026-04-19',
        'Sur',
        'Verificacion de tapada',
        'OK',
        'Cota verificada contra plano IFC.',
        'A. Rojas',
        ''
      ],
      <String>[
        '2026-04-19',
        'Sur',
        'Orden y limpieza',
        'Pendiente',
        'Retirar sobrante de material al cierre del turno.',
        'A. Rojas',
        ''
      ],
    ],
  ),
  DemoTemplateSpec(
    slug: 'control-operativo',
    name: 'Control operativo simple',
    sheetName: 'Demo - Control operativo diario',
    headers: <String>[
      'Fecha',
      'Equipo / Area',
      'Control',
      'Valor',
      'Estado',
      'Accion',
      'Responsable'
    ],
    rows: <List<String>>[
      <String>[
        '2026-04-18',
        'Bomba P-101',
        'Presion descarga',
        '8.4 bar',
        'OK',
        'Sin acción',
        'G. Molina'
      ],
      <String>[
        '2026-04-18',
        'Compresor C-02',
        'Nivel aceite',
        'Bajo',
        'Obs',
        'Completar nivel y registrar foto.',
        'G. Molina'
      ],
      <String>[
        '2026-04-18',
        'Tablero TG-01',
        'Temperatura',
        '36 C',
        'OK',
        'Seguimiento normal',
        'V. Castro'
      ],
    ],
  ),
  DemoTemplateSpec(
    slug: 'inventario',
    name: 'Inventario técnico',
    sheetName: 'Demo - Inventario de materiales de frente',
    headers: <String>['SKU', 'Item', 'Cantidad', 'Unidad', 'Ubicación'],
    rows: <List<String>>[
      <String>['MAT-001', 'Cable Cu desnudo 35mm2', '120', 'm', 'Deposito A'],
      <String>['MAT-014', 'Jabalina cobreada 5/8"', '18', 'u', 'Deposito B'],
      <String>['MAT-032', 'Caja inspeccion PAT', '12', 'u', 'Patio'],
      <String>['EPP-002', 'Guantes dielectricos', '8', 'pares', 'Panuelo'],
      <String>['EPP-010', 'Cascos con barbijo', '24', 'u', 'Oficina'],
    ],
  ),
  DemoTemplateSpec(
    slug: 'rendicion',
    name: 'Rendicion de campo',
    sheetName: 'Demo - Rendicion de cuadrilla',
    headers: <String>['Fecha', 'Concepto', 'Categoria', 'Monto', 'Comprobante'],
    rows: <List<String>>[
      <String>[
        '2026-04-16',
        'Combustible camioneta',
        'Movilidad',
        '45200',
        'TK-1001'
      ],
      <String>['2026-04-16', 'Peaje Ruta 7', 'Movilidad', '7800', 'TK-1002'],
      <String>[
        '2026-04-17',
        'Almuerzo cuadrilla',
        'Viaticos',
        '23500',
        'TK-1003'
      ],
      <String>[
        '2026-04-17',
        'Terminales y precintos',
        'Materiales',
        '68400',
        'TK-1004'
      ],
      <String>[
        '2026-04-18',
        'Lavado EPP contaminado',
        'Servicios',
        '9800',
        'TK-1005'
      ],
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
    'pat': 'puesta-a-tierra',
    'puesta': 'puesta-a-tierra',
    'puesta_tierra': 'puesta-a-tierra',
    'evidencias': 'relevamiento-evidencias',
    'inspeccion': 'campo',
    'operativo': 'control-operativo',
  };
  final effective = aliases[normalized] ?? normalized;
  for (final spec in kDemoTemplateSpecs) {
    if (spec.slug == effective) return spec;
  }
  return null;
}
