# Known Limitations P1 (post P0 RC)

Fecha: 2026-02-27

## Principio

Estos puntos no bloquean el release candidate P0, pero quedan priorizados como P1 por alcance o costo de refactor.

## Limitaciones abiertas

- Deuda historica de analyzer:
  - warnings/infos acumulados fuera del foco P0.
  - no bloquean runtime de RC, pero impactan mantenibilidad.

- Cobertura de test para reentrancia UI:
  - faltan widget/integration tests especificos de double tap en Inicio/Editor.

- Contrato de fallback storage entre servicios:
  - audio y blob web exponen metadata similar, pero no hay interfaz comun tipada para `store/reason`.

- Compatibilidad wasm:
  - el build web actual pasa, pero `wasm dry run` reporta incompatibilidades en dependencias web de terceros.

- Paths comerciales no-core:
  - quedan mejoras de copy unificado para todos los mensajes `unsupported`.

## Propuesta concreta P1

1. Definir outcome comun de persistencia web:
   - `storageStore`, `storageReason`, `isDurable`.
2. Agregar guardrail tests de reentrancia:
   - doble tap en open/import/export.
3. Plan de reduccion de deuda analyzer por lotes:
   - lotes de warnings por modulo para no mezclar con fixes funcionales.
4. Revisar estrategia wasm:
   - documentar soporte objetivo o aislar dependencias incompatibles.
