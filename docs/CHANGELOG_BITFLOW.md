# CHANGELOG BITFLOW

## 2026-02-27 - Stabilize P0

### Alcance
- Cierre P0 de estabilidad sin features nuevas ni dependencias nuevas.
- Hardening de lifecycle/reentrancia en Editor y StartPage.
- Semantica consistente de cancelado/unsupported/error real en attachments/export/import.
- Observabilidad de fallback de audio web con reason/store y warning accionable.

### Cambios clave
- `lib/features/editor/editor_state.dart`
  - gate central de operacion larga en guardado/manual y smart paste para evitar solape por double tap.
  - guardas `mounted` adicionales post-`await` en flujos de vistas/modales.
- `lib/start_page.dart`
  - anti-reentrancia en apertura de editor e import ZIP.
  - clasificacion de picker/import para cancelado/unsupported/error real.
- `lib/features/editor/attachments/attachments_controller.dart`
  - cancelaciones de foto/audio/video/archivo no se reportan como error.
  - excepciones de picker clasificadas con `classifyExportFlowOutcome`.
  - warning de fallback web para audio con `store|reason` deduplicado.
- `lib/services/audio_storage_service_web.dart`
  - metadata interna `lastSaveStore/lastSaveReason` + logging debug-only de fallback.
- `lib/services/export_flow_outcome.dart`
  - nuevos patrones de cancelacion de image/audio picker.
- `test/export_flow_outcome_test.dart`
  - guardrails extra para cancelacion de image/audio picker.

### Validacion
- `dart format` (archivos tocados) -> EXIT 0
- `flutter analyze` -> EXIT 1 (deuda historica, sin delta)
  - 376 issues: 66 warnings / 310 infos (sin errores)
- `flutter test --no-pub` -> EXIT 0 (135 tests)
- `flutter build web --dart-define=DEMO_MODE=true --dart-define=AUTH_ENABLED=false` -> EXIT 0

### Delta analyzer vs baseline de esta corrida
- issues: 376 -> 376
- warnings: 66 -> 66
- infos: 310 -> 310

### RC publication pack (LinkedIn + demo)
- Nuevos docs de salida comercial/tecnica:
  - `docs/RELEASE_NOTES_P0.md`
  - `docs/DEMO_SCRIPT_90S.md`
  - `docs/LINKEDIN_POST_DRAFT.md`
  - `docs/KNOWN_LIMITATIONS_P1.md`
- Se deja guion reproducible de demo corta (60-90s), post largo/corto, respuestas y DM de seguimiento.
- Se explicitan limites P1 de forma honesta para evitar sobreventa.

---
## 2026-02-24 — Auditoría integral (sin implementación P0/P1)

### Alcance
- Auditoría técnica, funcional y comercial de vendibilidad.
- Sin refactors grandes.
- Sin deploy.
- Sin cambios funcionales de producto.

### Archivos agregados
- `docs/AUDITORIA_BITFLOW.md`
- `docs/TODO_VENDIBLE_BITFLOW.md`
- `docs/CHANGELOG_BITFLOW.md`

### Validaciones ejecutadas
- `flutter analyze` → `ANALYZE_EXIT:1`
  - 429 issues (deuda histórica): 323 info + 106 warnings.
- `flutter test --no-pub` → `TEST_EXIT:0`
  - Suite completa en verde (118 tests).
- `flutter build web --dart-define=DEMO_MODE=true --dart-define=AUTH_ENABLED=false` → `BUILD_EXIT:0`
  - Build web demo OK.

---

## 2026-02-24 — P0 técnico (iteraciones seguras, sin deploy)

### Objetivo
Cerrar P0 técnico de bajo riesgo sin romper demo/auth ni hacer refactors grandes.

### Cambios aplicados

#### Iteración 1 (warnings críticos de flujo)
- `lib/widgets/gps_map_toolbar.dart`
  - `_zoom` pasó a `final`.
  - se eliminó `?? DateTime.now()` redundante en `position.timestamp`.
- `lib/widgets/mobile_notes_grid.dart`
  - se removieron `default` inalcanzables en switches de `_GridDensity`.
- `lib/widgets/typing_fx.dart`
  - se eliminó ejemplo widget muerto (`_CellEditorState`) e imports no usados.

#### Iteración 2 (P0 de continuidad)
- `lib/screens/start_page.dart`
  - se convirtió en **wrapper legacy** (`export '../start_page.dart';`) para dejar **una sola fuente de verdad** sin romper imports existentes.
- `lib/features/editor/editor_state.dart`
  - hardening de persistencia:
    - valida resultado de `setString` para staging/primary.
    - no ignora fallos en backup/staging cleanup (log controlado en debug).
    - nuevos códigos de error: `staging_write_failed`, `primary_write_failed`.

#### Iteración 3 (warnings críticos adicionales)
- `lib/features/editor/widgets/grid_host.dart`
  - se removió `default` inalcanzable en switch de `_GridDensity`.
- `lib/features/editor/editor_models.dart`
  - se removieron `default` inalcanzables en switches de alineación.
- `lib/services/location_service.dart`
  - se eliminaron null-aware redundantes en timestamps (`dead_null_aware_expression`).
  - se mantuvo `requireTimestamp` como guardia semántica sin operaciones frágiles.

### Validaciones por iteración
- Iteración 1:
  - analyze: `ANALYZE_EXIT:1`
  - test: `TEST_EXIT:0`
  - build web demo: `BUILD_EXIT:0`
- Iteración 2:
  - analyze: `ANALYZE_EXIT:1`
  - test: `TEST_EXIT:0`
  - build web demo: `BUILD_EXIT:0`
- Iteración 3:
  - analyze: `ANALYZE_EXIT:1`
  - test: `TEST_EXIT:0`
  - build web demo: `BUILD_EXIT:0`

### Impacto real en analyzer (deuda P0)
- Issues totales: **429 → 391**
- Warnings: **106 → 81**
- `unreachable_switch_default`: **14 → 0**
- `dead_null_aware_expression`: **7 → 4**
- `unused_element`: **32 → 28**

### Pendientes P0 que quedaron fuera de esta corrida
- Bloque de `unused_element` heredado en editor/start_page (no crítico funcional, sí deuda de mantenibilidad).

---

## 2026-02-24 — P0 técnico 2B (web dead-null + quota/storage)

### Cambios aplicados
- `lib/services/web_capabilities_web.dart`
  - Eliminado patrón null-aware redundante.
  - `isOnline` y `geolocationAvailable` ajustados para tipos web actuales sin `dead_null_aware_expression`.
- `lib/services/web_image_capture.dart`
  - Eliminado null-aware redundante en `document.visibilityState`.
- `lib/services/web_image_normalizer_web.dart`
  - Eliminados null-aware redundantes en dimensiones de imagen y cancelación de subscripciones.
- `lib/services/storage_diagnostics.dart`
  - Mensajes de error de persistencia convertidos a formato entendible para usuario (`quota`, modo temporal/incógnito, bloqueo de storage).
- `lib/features/editor/editor_state.dart`
  - Mensajes de warning de storage temporal mejorados para explicar riesgo de pérdida por recarga/cierre y acción recomendada (exportar ZIP).

### Validaciones
- `flutter analyze` → `ANALYZE_EXIT:1`
- `flutter test --no-pub` → `TEST_EXIT:0`
- `flutter build web --dart-define=DEMO_MODE=true --dart-define=AUTH_ENABLED=false` → `BUILD_EXIT:0`

### Delta analyzer (real)
- Totales: `391 -> 384`
- Warnings: `81 -> 74`
- `dead_null_aware_expression`: `4 -> 0`
- `unreachable_switch_default`: `0` (se mantiene)
- `unused_element`: `28` (sin cambio en esta subcorrida)

---

## 2026-02-24 — P1 vendible (iteración UX feedback save/export/share)

### Objetivo
Mejorar percepción de producto en feedback crítico (guardar/exportar/compartir), sin tocar lógica core.

### Cambios aplicados
- `lib/features/editor/editor_state.dart`
  - **Guardar (manual):** agrega feedback explícito de éxito (`Cambios guardados.`).
  - **Guardar (error):** mensaje de error más útil y accionable (con sugerencia de revisar conexión/storage local).
  - **Exportar/Compartir XLSX, PDF y ZIP (error):** mensajes diferenciados por acción:
    - compartir fallido → sugiere exportar y enviar manualmente,
    - exportar fallido → sugiere reintentar en segundos.
- `lib/start_page.dart`
  - Ajuste de compatibilidad de tests: CTA de banner demo renombrado de `Crear hoja` a `Nueva planilla` para evitar colisión de finder textual en test E2E.

### Validaciones de cierre de iteración
- corrida intermedia: `ANALYZE_EXIT:1`, `TEST_EXIT:1`, `BUILD_EXIT:0` (falla de test por colisión de texto/finder)
- corrida final (tras ajuste de compatibilidad):
  - `flutter analyze` → `ANALYZE_EXIT:1`
  - `flutter test --no-pub` → `TEST_EXIT:0`
  - `flutter build web --dart-define=DEMO_MODE=true --dart-define=AUTH_ENABLED=false` → `BUILD_EXIT:0`

### Estado analyzer (sin regresión)
- Totales: `384`
- Warnings: `74`

---

## 2026-02-24 - P0/P1 vendible (cancelacion de export + copy demo + docs)

### Objetivo
- Cerrar bug real de feedback/cancelacion en exportar/compartir.
- Pulir mensaje demo inicial para venta.
- Dejar guia corta de demo comercial.

### Cambios aplicados
- `lib/features/editor/editor_state.dart`
  - Fix P0 (export/share): cancelar selector de guardado ahora se trata como cancelacion real (no queda como pseudo-exito con haptic success).
  - Fix P0/P1 (feedback): cuando se pide `Compartir` y el dispositivo termina guardando archivo local, se muestra mensaje de fallback correcto (no "listo para compartir").
  - Diagnostico offline: cancelar export de diagnostico ya no cae en fallback a portapapeles por error.
- `lib/start_page.dart`
  - Copy demo vendible: flujo sugerido alineado con CTA (`Nueva planilla`) y nota clara sobre guardado local/modo temporal/incognito.
- `docs/README_DEMO_BITFLOW.md`
  - Guia comercial corta (que resuelve, flujo 5-10 min, que probar, limites web, faltantes para MVP cobrable).

### Validaciones
- `flutter analyze` -> `ANALYZE_EXIT:1` (sin regresion, deuda historica)
- `flutter test --no-pub` -> `TEST_EXIT:0`
- `flutter build web --dart-define=DEMO_MODE=true --dart-define=AUTH_ENABLED=false` -> `BUILD_EXIT:0`

### Estado analyzer (sin regresion)
- Totales: `384`
- Warnings: `74`

---

## 2026-02-25 — Estabilización (hardening de errores y trazabilidad)

### Objetivo
- Subir confiabilidad en flujos críticos (GPS web + fallback de storage + export stub).
- Mejorar diagnósticos sin cambiar UI/diseño.

### Cambios aplicados
- `lib/services/location_web_impl_web.dart`
  - Se corrigen textos de error corruptos (mojibake) en mensajes de geolocalización.
  - Se agrega fallback para errores inesperados con mensaje accionable y log debug.
- `lib/features/editor/editor_state.dart`
  - `classifyEditorStorageFallbackReason` ahora normaliza `reasonCode` (`trim + lowercase`).
  - `_warnStorageFallbackOnce` registra log debug útil con reason original + reason mapeado.
- `lib/services/export_xlsx_saver_stub.dart`
  - En no-web se lanza `UnsupportedError` explícito para evitar “éxitos” silenciosos.
- Tests
  - `test/editor_storage_fallback_reason_test.dart`: nuevo caso de normalización (whitespace/case).
  - `test/storage_diagnostics_test.dart`: nuevo caso case-insensitive.
- Documentación
  - `docs/ESTABILIZACION_BITFLOW_ETAPAS.md`: auditoría de flujos + checklist manual por etapa.

### Validaciones
- `flutter test test/editor_storage_fallback_reason_test.dart test/storage_diagnostics_test.dart` → `TEST_EXIT:0`
- `flutter test` → `TEST_EXIT:0`
- `flutter analyze lib/services/location_web_impl_web.dart lib/features/editor/editor_state.dart lib/services/export_xlsx_saver_stub.dart` → `ANALYZE_EXIT:1` (deuda histórica en `editor_state.dart`, sin regresión funcional)



