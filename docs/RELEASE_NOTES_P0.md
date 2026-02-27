# Release Notes P0 (RC)

Fecha: 2026-02-27
Scope: estabilizacion P0 para release candidate (sin features nuevas, sin deps nuevas).

## Que se estabilizo (impacto usuario)

- Cancelado != error != exito:
  - pickers de foto/audio/video/archivo ya no muestran error rojo por cancelacion.
  - paths `unsupported` no se reportan como exito.
  - `failed` mantiene error real con reporte.
- Menos races async:
  - guardas `mounted` y `context` en async gaps criticos de Editor y StartPage.
- Menos reentrancia por doble tap:
  - guardas en operaciones largas (editor) y en apertura/import desde Inicio.
- Fallback web visible:
  - warning accionable cuando storage degrada de durable.
  - metadata/log debug para audio web (`store/reason`) sin ruido al usuario final.

## Bugs P0 cerrados

- False error por cancelacion en pickers de adjuntos.
- False success en caminos de export/share cancelados.
- Doble accion por taps rapidos en rutas criticas.
- Gaps de lifecycle post-`await` en puntos auditados.
- Fallback de audio web no observable.

## Validacion RC (evidencia real)

- `flutter analyze` -> EXITCODE 1 (deuda historica)
  - 376 issues: 66 warnings / 310 infos / 0 errors
- `flutter test --no-pub` -> EXITCODE 0
  - 135 tests OK
- `flutter build web --dart-define=DEMO_MODE=true --dart-define=AUTH_ENABLED=false` -> EXITCODE 0

## Lo que queda en P1 (no bloqueante RC)

- tests widget de reentrancia (double tap) en Inicio/Editor.
- unificar contrato comun de fallback storage (`store/reason`) entre servicios.
- consolidar helper unico para copy/severidad `unsupported` en todos los flows.
