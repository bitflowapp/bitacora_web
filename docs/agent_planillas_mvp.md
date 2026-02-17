# Spreadsheet Agent MVP (BitFlow)

## Objetivo
Implementar un flujo local y vendible, sin APIs pagas, para importar planillas de clientes y producir una salida consistente:
- IMPORTAR -> MAPEAR -> VALIDAR -> EXPORTAR
- auditoria local para trazabilidad operativa
- compatibilidad web y movil
- cambios minimos y reversibles sobre el codigo existente

## Arquitectura MVP

### Pipeline principal
1. Ingest
2. Map
3. Validate
4. Export
5. Audit

### 1) Ingest
Entradas soportadas:
- CSV (`.csv`, delimitador `,` o `;`)
- XLSX (`.xlsx`, primera hoja)
- texto tabular pegado (copiado desde Excel, mail, WhatsApp)

Salida normalizada:
- `headers: List<String>`
- `rows: List<List<String>>`
- `sourceLabel` para identificar origen de la carga

### 2) Map
Motor de mapeo de columnas:
- automapeo por coincidencia de nombre/alias
- preserva mapeos previos del cliente
- permite ajuste manual columna a columna en UI

Persistencia de perfil:
- almacenamiento local con `SharedPreferences`
- clave: `spreadsheet_agent.mapping.v1.<templateId>.<clientId>`
- contenido: `headerToField`, `defaultValues`, `updatedAt`

### 3) Validate
Validaciones base del MVP:
- campos obligatorios
- fecha valida
- numero valido
- rango minimo/maximo
- duplicados por clave de plantilla
- total vs neto + IVA cuando aplica
- warning por IVA fuera de tolerancia cuando hay alicuota configurada

Salida:
- lista de issues por fila/campo
- conteo de errores y warnings

### 4) Export
Export principal:
- XLSX listo para produccion (cabecera, bordes, formato por tipo, anchos sensatos y autofit con fallback)

Export secundario:
- PDF solo porque ya existe libreria `pdf` en el proyecto
- si en otro entorno no estuviera disponible, mover PDF a fase 2 sin bloquear MVP

### 5) Audit
Auditoria local:
- eventos guardados en `SharedPreferences`
- acciones: guardado de perfil y exportaciones
- datos: fecha, plantilla, cliente, accion, detalle

## Alcance MVP (incluido)
- 3 plantillas iniciales:
  - `rendicion_gastos`
  - `parte_diario_obra`
  - `stock_materiales`
- pantalla unica de flujo extremo a extremo:
  - importar/pegar -> mapear -> validar -> preview -> exportar
- sin backend obligatorio
- sin dependencia de servicios externos pagos

## Fuera de alcance MVP
- OCR de comprobantes/fotos/PDF escaneado
- mapeo semantico con modelos pagos
- reconciliacion automatica multi-fuente
- versionado avanzado de reglas por cliente

## Backlog Premium (fase posterior)
- auto-mapeo semantico con IA
- extraccion de datos desde documentos escaneados
- sugerencia automatica de plantilla por contenido
- validaciones avanzadas por convenio/cliente
- reconciliacion contable automatica y scoring de riesgo

## Criterio de aceptacion MVP
- flujo completo funcionando localmente
- export XLSX util para operacion real
- validaciones legibles para usuarios no tecnicos
- sin regresion del editor principal ni del flujo actual de planillas
