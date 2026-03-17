# GPS Audit And Fixes

Fecha: 2026-03-12

Alcance de este pase:
- Sin nuevas dependencias.
- Sin reescritura de arquitectura.
- Enfocado en el flujo GPS real del editor y en el servicio web compartido.
- Objetivo: menos friccion en campo, mejor feedback y menos errores silenciosos.

Archivos auditados principalemente:
- `lib/features/editor/editor_state.dart`
- `lib/features/editor/actions/editor_actions.dart`
- `lib/services/location_web_impl_web.dart`
- `lib/services/location_web_service.dart`
- `lib/services/location_service.dart`

## Top 10 fricciones GPS

| # | Prioridad | Friccion detectada | Impacto en campo | Accion tomada | Estado |
|---|---|---|---|---|---|
| 1 | P0 | No habia guardia contra taps repetidos en acciones GPS del editor. | Doble pedido al GPS, feedback confuso y riesgo de carreras de UI. | Se agrego guardia `_gpsRequestInFlight` con mensaje claro de espera. | Corregido |
| 2 | P0 | El usuario no recibia feedback inmediato mientras BitFlow buscaba ubicacion. | Sensacion de app congelada o de boton "muerto". | Se agrega estado visible tipo "Buscando ubicacion para fila/celda...". | Corregido |
| 3 | P0 | El servicio de ubicacion apagado se descubria tarde y con mensaje poco accionable. | Perdia tiempo esperando timeouts innecesarios. | Se agrego preflight de GPS en editor para cortar antes y pedir activar ubicacion. | Corregido |
| 4 | P0 | El flujo GPS no tenia preflight propio de permiso/rationale en el editor. | Denegaciones mas bruscas y menos contexto para operacion en campo. | Se reutilizo el preflight existente de permisos para ubicacion. | Corregido |
| 5 | P0 | Los errores GPS eran demasiado genericos para distinguir permiso, GPS apagado, timeout, HTTPS o senal pobre. | El operador no sabia que accion tomar. | Se rehizo el mapeo de error a copy humano y accionable. | Corregido |
| 6 | P1 | El exito GPS no indicaba con claridad donde se guardo ni a que hora. | Duda sobre si se guardo en la celda correcta y con timestamp consistente. | Mensajes de exito ahora incluyen fila/celda destino y hora de captura. | Corregido |
| 7 | P1 | Las acciones genericas "Adjuntar GPS" ignoraban el modo GPS y forzaban pegado de texto. | El modo GPS resultaba confuso y parecia no funcionar. | Las acciones genericas ahora respetan el modo activo; las acciones explicitas "GPS -> Pegar" siguen forzando texto. | Corregido |
| 8 | P1 | El flujo por lote no explicaba suficientemente el destino real del GPS. | Ambiguedad entre fila, celda y columna al aplicar a varias filas. | El feedback por lote ahora nombra cantidad de filas, columna destino y modo de escritura. | Corregido |
| 9 | P1 | El modo "elegir celda" no confirmaba claramente que el GPS ya habia sido capturado. | El operador podia repetir el pedido pensando que habia fallado. | Nuevo mensaje: GPS listo y esperando celda destino. | Corregido |
| 10 | P2 | El servicio web compartido seguia exponiendo copy tecnico/heterogeneo. | El flujo web fuera del editor podia sentirse menos humano. | Se pulio `location_web_impl_web.dart` para unificar mensajes mas accionables. | Mitigado |

## Cambios aplicados

### Editor
- Guardia anti doble toque para requests GPS.
- Preflight GPS reutilizando el mecanismo de rationale/permiso ya existente.
- Corte temprano cuando el servicio de ubicacion del dispositivo esta apagado.
- Feedback de progreso durante la captura.
- Mensajes de exito con fila/celda y timestamp.
- Mensajes de error mas claros por causa probable.
- Respeto real del modo GPS en acciones genericas del editor.

### Servicios
- Normalizacion del copy web en `location_web_impl_web.dart`.
- Mensajes mas directos para HTTPS, permiso bloqueado, timeout y ubicacion no confiable.

## Riesgos que se evitaron a proposito

- No se deshabilitaron visualmente todos los botones GPS de la UI mientras una captura esta en curso.
  - La guardia logica ya evita dobles pedidos sin abrir refactor de widgets.
- No se unifico todo el GPS legado fuera del editor.
  - Se toco solo el servicio web compartido para no abrir una reestructuracion mayor.

## Tests agregados

- `test/editor_gps_flow_test.dart`
  - GPS metadata-only conserva texto y guarda timestamp.
  - Error `service_disabled` muestra copy humano y contextual.
  - Taps repetidos durante una captura activa quedan bloqueados.

## Resumen ejecutivo

El mayor problema no era el motor GPS sino la friccion operativa alrededor:
- poca claridad durante la espera,
- errores poco accionables,
- y ambiguedad entre fila, celda, lote y modo GPS.

Este pase endurece ese borde sin cambiar la logica de negocio ni la arquitectura base.
