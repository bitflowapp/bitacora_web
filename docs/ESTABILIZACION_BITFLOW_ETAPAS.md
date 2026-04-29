# Estabilización BitFlow (sin features nuevas)

Fecha: 2026-02-25
Objetivo: confiabilidad y reducción de bugs sin cambios estéticos ni nuevas dependencias.

---

## Resumen ejecutivo (cierre P0 - 2026-02-27)

- Problema resuelto:
  - se estabilizaron flujos criticos para evitar falsos positivos y estados inconsistentes:
  - cancelado != error != exito (pickers/export/import/share)
  - hardening de `mounted/context` post-`await` en Editor y StartPage
  - guardas de reentrancia (double tap) en navegacion/import y operaciones largas
  - fallback de storage web observable (audio/foto/archivo/video) con warning accionable y dedupe
- Validacion tecnica (corrida completa):
  - `flutter analyze` -> EXIT 1 (deuda historica), 376 issues (66 warnings / 310 infos)
  - `flutter test --no-pub` -> EXIT 0, 135 tests OK
  - `flutter build web --dart-define=DEMO_MODE=true --dart-define=AUTH_ENABLED=false` -> EXIT 0
- Delta final vs baseline de esta corrida:
  - analyze sin regresion: 376 -> 376 issues, warnings 66 -> 66, infos 310 -> 310
- Estado comercial:
  - flujo demo listo para venta tecnica (sin crash en paths auditados de P0)
  - cancelaciones y fallbacks visibles para usuario, sin exito falso

---
## Etapa 1 — Auditoría funcional (flujo por flujo)

### Flujos principales auditados

1. **Crear planilla**
   - Entrada: Home (`lib/start_page.dart`) → `_createAndOpenSheet`, `_newSheet`, `_newTemplateSheet`
   - Persistencia: `SheetStore` (`lib/services/sheet_store.dart` + impl)

2. **Abrir / listar / renombrar / mover a papelera / restaurar / borrar**
   - Entrada: Home (`lib/start_page.dart`) → `_open`, `_rename`, `_moveToTrash`, `_restoreFromTrash`, `_deleteForever`

3. **Editar celdas en planilla**
   - Entrada: Editor (`lib/features/editor/editor_screen.dart` + `editor_state.dart`)
   - Operaciones: edición de texto, selección, duplicado de filas, pegar inteligente, validación por reglas

4. **Guardar cambios**
   - Entrada: `_saveLocalNow` y guardado automático (Editor)
   - Persistencia segura: staging/backup/snapshot (`editor_state.dart`)

5. **Adjuntos por celda (GPS, foto, audio, archivos)**
   - Entrada: barra acciones + command palette (`editor_actions.dart`)
   - Almacenamiento: `AttachmentStore`, `AudioStorageService`, `WebBlobStore`

6. **Exportar**
   - XLSX / ZIP / Backup ZIP / HTML / PDF
   - Entrada: menú exportación y command palette
   - Archivos clave: `editor_state.dart`, `services/export_*`

7. **Compartir**
   - Entrada: flujo de export + share
   - Servicios: `share_plus`, helpers de exportación

8. **Importar backup ZIP**
   - Entrada: Home → `_importBackupZip`

9. **Diagnósticos y smoke test**
   - Entrada: Home → `_openDiagnostics`, `_createSmokeTestSheet`
   - Cobertura: GPS/Foto/Audio + storage + versión

---

## Etapa 2 — Bugs detectados y correcciones aplicadas

### A. Bug real de texto corrupto (mojibake) en mensajes de geolocalización web
- **Impacto:** mensajes con caracteres corruptos al usuario en errores GPS web.
- **Archivo:** `lib/services/location_web_impl_web.dart`
- **Corrección:** normalización de textos (UTF-8 correcto) + fallback explícito para errores inesperados sin romper los errores específicos existentes.

### B. Manejo de error genérico faltante en geolocalización web
- **Impacto:** excepciones no mapeadas podían llegar crudas o poco claras.
- **Archivo:** `lib/services/location_web_impl_web.dart`
- **Corrección:** `catch` final con mensaje accionable y log en debug (`[web-gps] unexpected error: ...`).

### C. Clasificación de fallback de storage sensible a mayúsculas/espacios
- **Impacto:** reason codes válidos con formato distinto terminaban en fallback genérico.
- **Archivo:** `lib/features/editor/editor_state.dart`
- **Corrección:** normalización con `trim().toLowerCase()` en `classifyEditorStorageFallbackReason`.

### D. Falta de log útil al degradar a almacenamiento temporal
- **Impacto:** difícil diagnóstico cuando adjuntos caían en modo temporal RAM/session-only.
- **Archivo:** `lib/features/editor/editor_state.dart`
- **Corrección:** log debug con tipo, reason original y reason mapeado:
  - `[EditorScreen] storage_fallback kind=... reason=... mapped=...`

### E. Stub XLSX no-web con comportamiento ambiguo
- **Impacto:** en plataformas no-web podía parecer éxito silencioso.
- **Archivo:** `lib/services/export_xlsx_saver_stub.dart`
- **Corrección:** lanza `UnsupportedError` explícito para evitar falsos positivos de exportación.

---

## Etapa 3 — Validación de estabilidad (automatizada)

### Tests agregados/actualizados

1. `test/editor_storage_fallback_reason_test.dart`
   - Nuevo caso: normalización de `reasonCode` con espacios + mayúsculas.

2. `test/storage_diagnostics_test.dart`
   - Nuevo caso: clasificación case-insensitive de errores de cuota.

### Resultado de corrida

- `flutter test test/editor_storage_fallback_reason_test.dart test/storage_diagnostics_test.dart` ✅
- `flutter test` (suite completa) ✅

---

## Checklist manual de estabilización (QA)

### Home / gestión de planillas
- [ ] Crear planilla nueva desde Home.
- [ ] Abrir planilla existente.
- [ ] Renombrar planilla.
- [ ] Mover a papelera, restaurar y borrar definitivo.
- [ ] Importar backup ZIP válido e inválido (ver mensaje claro).

### Edición y guardado
- [ ] Editar 3-5 celdas y guardar manual.
- [ ] Recargar navegador y confirmar persistencia.
- [ ] Probar deshacer/rehacer en cambios simples.

### GPS/foto/audio
- [ ] GPS: permiso denegado (mensaje claro) y permiso concedido.
- [ ] Foto: adjuntar, recargar, verificar miniatura y persistencia.
- [ ] Audio: grabar/reproducir, recargar, verificar persistencia.

### Exportar/compartir
- [ ] Exportar XLSX y abrir en Excel.
- [ ] Exportar ZIP y verificar `manifest.json` + `attachments/`.
- [ ] Exportar Backup ZIP e importar nuevamente.
- [ ] Compartir: cancelar selector (no debe mostrar éxito falso).

### Diagnóstico/storage
- [ ] Abrir Diagnósticos y validar estado de storage.
- [ ] Simular navegador en modo incógnito: verificar aviso de guardado temporal.
- [ ] Revisar logs debug para fallback storage y errores GPS.

---

## Archivos modificados en esta etapa

- `lib/services/location_web_impl_web.dart`
- `lib/features/editor/editor_state.dart`
- `lib/services/export_xlsx_saver_stub.dart`
- `test/editor_storage_fallback_reason_test.dart`
- `test/storage_diagnostics_test.dart`
- `docs/ESTABILIZACION_BITFLOW_ETAPAS.md`

---

## Etapa 4 - P0 async/export/import (2026-02-26)

### Riesgos encontrados (P0)

- `StartPage` import ZIP (`_importBackupZip`) abria el file picker fuera de `try/catch`; una excepcion de plataforma no soportada podia escapar sin clasificacion de cancelado/unsupported.
- `Editor` export PDF/ZIP trataba `cancelled` y `unsupported` como error generico en `catch`, a diferencia de XLSX y de `StartPage`.
- Reentrancia de export/import en los flujos auditados ya estaba cubierta por guardias existentes (`_busy` en Home y `longOperation` en Editor), sin cambio en esta iteracion.
- En los bloques auditados no se detecto `setState` post-`await` sin guard `mounted`.

### Fixes aplicados (esta iteracion)

- `lib/start_page.dart`
  - Clasificacion explicita de errores al abrir selector de archivo para import ZIP:
    - cancelado por usuario -> info (no error)
    - no soportado -> mensaje accionable
    - error real -> reporte con `operation=import_backup_open_picker`
- `lib/features/editor/editor_state.dart`
  - `_exportPdf`: ahora clasifica `cancelled` y `unsupported` antes del error generico (misma semantica que XLSX).
  - `_exportZipBundle`: idem `_exportPdf`, evitando errores falsos al cancelar compartir/exportar en plataformas no compatibles.
- `test/export_flow_outcome_test.dart`
  - Guardrail unitario para clasificacion `cancelled` y `unsupported` en `classifyExportFlowOutcome`.

### Checklist manual rapido (10-15 min)

- Home:
  - Intentar `Importar ZIP` y cancelar selector -> no debe mostrarse error.
  - Intentar `Importar ZIP` en plataforma/no-contexto no soportado (si aplica) -> mensaje comercial/accionable, no crash.
- Editor (misma planilla):
  - Exportar PDF y cancelar -> mensaje de cancelacion, no error.
  - Compartir PDF y cancelar -> mensaje de cancelacion, no exito.
  - Exportar ZIP y cancelar -> mensaje de cancelacion, no error.
  - Compartir ZIP y cancelar -> mensaje de cancelacion, no exito.
- Guardado/edicion smoke:
  - Editar una celda, guardar, recargar y verificar persistencia.
  - Repetir tap rapido en export/import mientras hay overlay de progreso -> no debe duplicar la accion.

---

## Etapa 5 - P0 semantica cancel/unsupported en exports restantes (2026-02-26)

### Riesgos cerrados

- `Editor` `_exportBackupZip(...)` tenia `catch` generico: un cancelado por picker/save podia terminar como error en lugar de cancelacion.
- `Editor` `_exportHtmlReport(...)` tenia `catch` generico: misma inconsistencia semantica (cancelado/unsupported/error real).
- Reentrancia/doble tap revisada en ambos entrypoints:
  - ya usan `_tryBeginLongOperation(...)` al inicio, por lo que no se agrego otra guardia.

### Fix aplicado

- Se extendio `classifyExportFlowOutcome(...)` en los `catch` de:
  - `_exportBackupZip(...)`
  - `_exportHtmlReport(...)`
- Semantica final:
  - `cancelled` -> snack informativo (sin error, sin exito)
  - `unsupported` -> mensaje de error accionable/comercial (sin exito)
  - `failed` -> error real (fallback existente)

### Checklist manual rapido (10-15 min) - Etapa 5

- Export Backup ZIP:
  - Ejecutar export y cancelar selector/guardado -> debe mostrar cancelacion (no error, no exito).
  - Probar en entorno/plataforma no soportado (si aplica) -> mensaje de no soportado, no exito.
  - Ejecutar export normal -> debe finalizar con "Backup ZIP listo" solo si el archivo se guardo.
- Export HTML:
  - Ejecutar export y cancelar selector/guardado -> debe mostrar cancelacion (no error, no exito).
  - Probar en entorno/plataforma no soportado (si aplica) -> mensaje de no soportado, no exito.
  - Ejecutar export normal -> debe finalizar con "Reporte HTML listo" solo si el archivo se guardo.
- Reentrancia:
  - Doble tap rapido en Backup ZIP/HTML mientras aparece overlay de progreso -> no debe lanzar dos exports paralelos.

---

## Etapa 6 - P0 async/state StartPage (2026-02-26)

### Riesgo cerrado

- `StartPage` tenia callbacks async en action sheet con patron `Navigator.of(ctx).pop(); await ...` sin guarda inmediata de `mounted`.
- Si la pantalla se desmontaba durante la transicion/cierre del sheet, podia dispararse uso de `context` o navegacion sobre widget ya descartado.
- `_openCommercialInfo()` retenia `Navigator.of(context)` sin validar `mounted` previo.

### Fix aplicado

- `lib/start_page.dart`
  - Se agrego `if (!mounted) return;` inmediatamente despues de `Navigator.of(ctx).pop();` en callbacks async de `_openMoreSheet(...)`.
  - Se agrego `if (!mounted) return;` antes de `final navigator = Navigator.of(context);` en `_openCommercialInfo()`.
- Alcance:
  - evita crashes/races (`deactivated widget ancestor`, uso de context tras dispose)
  - no cambia UX ni copy; solo corta el flujo cuando la pantalla ya no existe

### Checklist manual rapido (10-15 min) - Etapa 6

- Action sheet / navegacion:
  - Abrir `Opciones` y tocar rapido varias acciones (Carpetas, Premium, About) cerrando/abriendo la pantalla.
  - Abrir `Opciones`, tocar una accion y navegar atras/adelante rapido.
  - Repetir en mobile/web para confirmar que no hay crash ni warning visual.
- Inicio / import-export:
  - Desde Inicio, exportar planilla y cancelar (sin exito falso).
  - Desde Inicio, importar ZIP y cancelar selector (sin error falso).
  - Abrir `Opciones` -> `Importar paquete ZIP...`, cancelar, volver a abrir `Opciones` y navegar a otra seccion.
- Estabilidad:
  - Revisar consola/logs por ausencia de errores tipo `Looking up a deactivated widget's ancestor`.

---

## Etapa 7 - P0 adjuntos grandes / cuota / degradacion (2026-02-26)

### Riesgos cerrados

- El web blob store no dejaba trazado debug minimo del resultado final de guardado (bytes + store + reason).
- En fallback de adjuntos, el dedupe de warning era solo por motivo; podia ocultar un cambio de store (por ejemplo, otro fallback distinto) o mezclar causas.
- Faltaba una clave de dedupe por sesion con granularidad `store|reason`.

### Fix aplicado

- `lib/services/web_blob_store_web.dart`
  - Se explicita metadata final del ultimo guardado web:
    - `lastSaveStore` (best effort: `indexeddb` / `cache` / `ram`)
    - `lastSaveReason` final normalizado (incluye fallback a `unknown_storage_error`)
  - Log debug-only (via `assert`) por guardado:
    - `[web-blob] save bytes=<N> store=<store> reason=<reason>`
- `lib/features/editor/editor_state.dart`
  - `_warnStorageFallbackOnce(...)` ahora deduplica por clave `store|reason` (once-per-session).
  - Mantiene mensajes accionables existentes (liberar espacio / evitar incognito / exportar ZIP).
  - Inferencia best-effort de `store/reason` desde `WebBlobStore` en web (sin cambiar callers).

### Como reproducir (manual)

- Adjunto grande:
  - En web, adjuntar una foto/video suficientemente grande para forzar degradacion si el sitio ya tiene storage ocupado.
- Incognito / temporal:
  - Abrir la app en modo incognito/privado y adjuntar foto.
- Storage limitado:
  - Llenar storage del sitio (otras pruebas/datos) y volver a adjuntar.

### Checklist manual rapido (10-15 min) - Etapa 7

- Adjuntar foto grande en web y observar warning:
  - Debe ser accionable (exportar ZIP / liberar espacio / evitar incognito).
- Repetir el mismo fallback varias veces:
  - El warning no debe spamear (solo 1 vez por sesion y por `store|reason`).
- Provocar otro motivo/store distinto (si posible):
  - Puede aparecer 1 warning adicional (nuevo `store|reason`).
- Recargar pagina tras fallback:
  - Verificar si el adjunto persiste o no segun store (cache/ram).
- Exportar ZIP luego del fallback:
  - Confirmar que el flujo sigue disponible como camino de conservacion.

---

## Etapa 8 - P0 async/state race conditions en Editor (2026-02-26)

### Riesgos encontrados (cerrados)

- `setState(...)` despues de `await showAppModal(...)` en flujo de vistas guardadas (`Guardar vista` / editar vista), con riesgo de `setState() called after dispose`.
- Uso de snack/context despues de `await` en vistas guardadas (guardar/eliminar), con riesgo de ejecutar feedback cuando el editor ya no esta montado.

### Fixes aplicados

- `lib/features/editor/editor_state.dart`
  - `_openSaveViewDialog(...)`:
    - guarda `if (!mounted) return;` inmediatamente despues del `await showAppModal(...)` (con dispose de controllers antes de salir)
    - guarda `if (!mounted) return;` despues de `await _persistSavedViewsPref()` antes del snack de exito
  - `_renameSavedView(...)`:
    - guarda `if (!mounted) return;` inmediatamente despues del `await showAppModal(...)` (con dispose del controller)
  - `_deleteSavedView(...)`:
    - guarda `if (!mounted) return;` despues de `await _persistSavedViewsPref()` antes del snack

### Checklist manual rapido (10-15 min) - Etapa 8

- Abrir editor y gestionar vistas guardadas:
  - Guardar vista nueva, renombrarla y eliminarla (verificar feedback normal).
- Repetir guardado/rename y navegar rapido atras/cerrar pantalla durante el modal:
  - No debe haber crash ni errores de `setState after dispose`.
- Guardar vista y salir rapido de la pantalla mientras persiste:
  - No deben aparecer errores por `ScaffoldMessenger`/context deactivado.
- Probar export rapido y cancelar:
  - Confirmar que no aparece exito falso y que el editor sigue estable.

---

## Etapa 9 - P0 warning garantizado en fallbacks web de adjuntos (2026-02-26)

### Riesgo cerrado

- En adjuntos web (foto / archivo / video) el warning de degradacion solo se disparaba en `ram`/session-only y podia omitir el caso `cache` (fallback desde IndexedDB sin spam, pero sin aviso).

### Fix aplicado

- `lib/features/editor/attachments/attachments_controller.dart`
  - En los callers reales de persistencia web (foto y archivo/video), el warning ahora se dispara siempre que el store final no sea `indexeddb`.
  - Se reutiliza `_warnStorageFallbackOnce(...)` del editor (dedupe `store|reason` ya existente).
  - `reasonCode` y `store` siguen resolviendose desde `WebBlobStore` dentro del warning (best effort), sin duplicar copy ni mapping.

### Paths cubiertos

- Web + foto: `indexeddb -> cache` y `indexeddb/cache -> ram` (warning accionable once-per-session por `store|reason`).
- Web + archivo/video: `indexeddb -> cache` y `indexeddb/cache -> ram`.
- Audio: mantiene warning en fallback a memoria; no usa `WebBlobStore` (path separado, sin `reason/store` explicito de WebBlobStore).

### Como reproducir (manual)

- Web, adjuntar foto/video/archivo con storage del sitio presionado para forzar degradacion.
- Repetir en incognito/privado para provocar storage temporal o bloqueo.
- Repetir varias veces el mismo caso para validar dedupe (no spam).

### Checklist manual rapido (10-15 min) - Etapa 9

- Adjuntar foto grande en web hasta provocar fallback:
  - Debe aparecer warning accionable (cache o ram).
- Adjuntar archivo/video en el mismo escenario:
  - Debe aparecer warning si el store final no fue IndexedDB.
- Repetir el mismo motivo/store varias veces:
  - No debe spamear (una vez por sesion y `store|reason`).
- Recargar pagina luego de fallback:
  - Verificar persistencia esperada (cache vs ram).
- Exportar ZIP tras warning:
  - Confirmar camino de conservacion disponible.

## Etapa 10 - P0 anti reentrancia (double tap) en export/import (2026-02-26)

### Reentrancias cerradas

- `Editor`: segundo tap en acciones largas (export/share/import) ya no dispara una segunda operacion mientras exista una operacion larga activa, incluso si la actual ya fue marcada para cancelar pero todavia no termino.
- `StartPage`: doble tap en importar ZIP desde Inicio ya no puede abrir dos file pickers/imports en paralelo durante el gap previo a `_beginBusyOperation(...)`.

### Fix aplicado

- `lib/features/editor/editor_state.dart`
  - `_tryBeginLongOperation(...)` ahora retorna silenciosamente si `_longOperation != null` (guardia central unica reutilizada por export/share/import).
- `lib/start_page.dart`
  - `_importBackupZip()` usa guardia minima `_importBackupZipInFlight` alrededor del file picker (`openFile`) con reset en `finally`.
  - Luego del picker, el flujo sigue protegido por `_busy` como antes.

### Checklist manual rapido (10-15 min) - Etapa 10

- En editor: doble tap rapido en exportar ZIP.
  - Debe ejecutarse una sola operacion.
- En editor: doble tap rapido en exportar PDF / compartir.
  - No deben arrancar tareas duplicadas ni quedar overlays inconsistentes.
- En editor: cancelar export y volver a tocar export rapido.
  - Mientras la operacion anterior no termine de cerrar, no debe arrancar otra.
- En inicio: doble tap en Importar ZIP (antes de elegir archivo).
  - Debe abrirse un solo selector de archivos.
- En inicio: cancelar picker y repetir.
  - Debe seguir distinguiendo cancelado vs error real sin exito falso.
- En editor/inicio: salir rapido de la pantalla durante operacion.
  - No debe haber crashes ni estados de busy colgados.

## Etapa 11 - P0 no false-success en fallback de export (2026-02-26)

### Caso cerrado (false-success)

- En `Editor`, cuando un export normal (no share) caia al fallback movil via `Share.shareXFiles(...)`, podia mostrarse un mensaje de exito tipo "exportado con exito" aunque en realidad solo se habia abierto compartir (sin confirmacion de guardado real).
- Ademas, una cancelacion de ese share fallback podia no clasificarse como cancelado en ese branch especifico.

### Fix aplicado

- `lib/features/editor/editor_state.dart` (`_saveExportBytes(...)`)
  - Fallback movil por share en export no-share:
    - ya no muestra success de "exportado"; muestra mensaje neutral/accionable indicando que se abrio compartir para que el usuario guarde o envie.
  - Si el usuario cancela el share fallback y el plugin lo reporta como cancelacion:
    - ahora se respeta como cancelado (`_EditorLongOperationCancelled`) en vez de seguir como si nada.

### Como reproducir (manual)

- En Android/iOS (o emulador), disparar export de PDF/XLSX/ZIP en un escenario donde el guardado directo no este disponible y el flujo caiga a compartir.
- Cancelar la hoja de compartir.
- Reintentar y elegir una app/accion de compartir.

### Checklist manual rapido (10-15 min) - Etapa 11

- Exportar XLSX (no share) en mobile con fallback a compartir:
  - No debe decir "exportado con exito" si solo se abrio compartir.
- Exportar PDF (no share) con fallback a compartir:
  - Debe mostrar mensaje neutral/accionable.
- Exportar ZIP y cancelar share fallback:
  - Debe quedar como cancelado (no exito).
- Probar share explicito (share=true) y cancelar:
  - Debe mantener semantica de cancelado/no soportado/error real sin exito falso.
- Probar unsupported (si plataforma aplica):
  - Debe mantener mensaje comercial/accionable y no marcar exito.

## Etapa 12 - P0 lifecycle (timer debounce + callbacks post-dispose) (2026-02-26)

### Riesgo lifecycle cerrado

- En `Editor`, el modal de "Busqueda global" usa un debounce local (`Timer`) para disparar `runSearch(...)`.
- Si el usuario escribe y cierra el modal rapido (o navega fuera) antes de que dispare el debounce/termine la busqueda, el callback podia intentar actualizar `StatefulBuilder` (`setModalState`) cuando el modal ya estaba desmontado.
- Riesgo: excepciones tipo `setState() called after dispose`/callbacks tardios fuera de pantalla.

### Fix aplicado

- `lib/features/editor/editor_state.dart` (`_openSearchEverywhereDialog()`)
  - `runSearch(...)` ahora recibe el `BuildContext` del modal (`modalCtx`) y valida `mounted && modalCtx.mounted` antes de:
    - leer el `TextEditingController`
    - ejecutar `setModalState(...)`
    - aplicar resultados al volver del `await _searchEverywhere(...)`
  - Los disparos debounced e inmediatos reutilizan el mismo guard pasando `ctx`.

### Como reproducir (manual)

- Abrir "Busqueda global" en el editor.
- Escribir rapido 2-3 caracteres y cerrar el modal inmediatamente (boton cerrar o tap fuera).
- Repetir activando/desactivando "Buscar en todas las planillas" mientras la busqueda arranca.

### Checklist manual rapido (10-15 min) - Etapa 12

- Abrir "Busqueda global", escribir y cerrar antes de 180 ms:
  - No debe haber crash ni errores de `setState after dispose`.
- Escribir, esperar spinner, cerrar mientras busca:
  - No deben aparecer callbacks tardios ni errores en consola.
- Toggle "Buscar en todas las planillas" y cerrar rapido:
  - No debe quedar actividad de modal fuera de pantalla.
- Navegar fuera del editor mientras se uso la busqueda global:
  - No deben aparecer errores por lifecycle/mounted/context.
- Repetir export/import/adjunto y salir rapido del editor:
  - Confirmar que no aparecen mensajes tardios ni crashes.

### P1 (test guardrail pendiente, no implementado)

- Cobertura automatizada del modal de "Busqueda global" con widget test:
  - abrir modal
  - escribir para armar debounce
  - cerrar modal antes de 180 ms
  - avanzar reloj fake
  - verificar ausencia de excepciones / callbacks tardios
- No se agrego en P0 para evitar test UI frágil con mayor costo de mantenimiento que el fix puntual.

## Etapa 13 - P0 StartPage async/context (carpetas + acciones externas) (2026-02-26)

### Riesgos encontrados (StartPage)

- `lib/start_page.dart` (`_deleteFolderFlow`, `_createFolderDialog`, `_renameFolderDialog`)
  - habia `await` sobre confirm/dialog y luego mutacion de estado/persistencia sin validar `mounted` ni `ctx.mounted`
  - riesgo: acciones "fantasma" (crear/renombrar/eliminar carpeta) si la pantalla o el route de carpetas se cerraban durante el dialogo
- `lib/start_page.dart` (`_applyAvailableUpdate`)
  - habia `await launchUrl(...)` y luego `_toast(...)` sin guarda explicita
  - `_toast` ya se protege internamente con `mounted`, pero quedaba async gap innecesario (toast tardio silenciado)

### Fix aplicado

- `lib/start_page.dart`
  - Guardas post-`await` en flujos de carpetas:
    - `_deleteFolderFlow(...)`: `if (!mounted || !ctx.mounted) return;`
    - `_createFolderDialog(...)`: `if (!mounted || !ctx.mounted) return null;`
    - `_renameFolderDialog(...)`: `if (!mounted || !ctx.mounted) return null;`
  - Guardas post-`await launchUrl(...)` en `_applyAvailableUpdate()` (Android/iOS fallback release page) antes de `_toast(...)`.

### Semantica cancelado/unsupported/false-success (auditoria)

- En los paths auditados de `StartPage` para esta etapa no se detecto un nuevo caso concreto de false-success.
- Se mantiene la semantica estabilizada en iteraciones previas (import/export desde Inicio con distincion `cancelled` / `unsupported` / error real).

### Checklist manual rapido (10-15 min) - Etapa 13

- Abrir action sheet (`Opciones`), tocar una accion y cerrar rapido / volver atras durante el await:
  - repetir 3 veces (carpetas, diagnostico, premium)
  - no debe haber crash ni mensajes tardios
- Abrir gestor de carpetas:
  - crear carpeta, cerrar rapido el dialogo / salir de la pantalla durante el dialogo
  - renombrar carpeta y salir rapido
  - eliminar carpeta y cerrar rapido
  - confirmar: cero crashes, cero acciones fantasma tras cerrar
- Probar "Buscar actualizaciones" y salir rapido de Inicio mientras intenta abrir enlace/actualizacion:
  - sin excepciones de `mounted/context`
  - sin toast tardio al volver atras
- Revalidar import/export desde Inicio (cancelar y unsupported si aplica):
  - sin exito falso, sin errores de context/mounted

## Etapa 14 - P0 StartPage reentrancia + semantica de import/export (2026-02-26)

### Riesgo encontrado

- `lib/start_page.dart` (`_openEditorRoute(...)`)
  - no tenia guardia de reentrancia; doble tap en "abrir planilla" podia disparar dos navegaciones al editor en paralelo (router push / fallback push)
- `lib/start_page.dart` (`_importBackupZip(...)`)
  - el catch general de import trataba `UnsupportedError`/cancelaciones tardias como error generico en vez de respetar semantica `cancelled` / `unsupported`

### Fix aplicado

- `lib/start_page.dart`
  - `_openEditorRoute(...)`
    - nueva guardia minima `_openEditorRouteInFlight`
    - bloquea el segundo tap desde antes del `await`
    - resetea en `finally` (sin UI nueva, sin overlay extra)
  - `_importBackupZip(...)`
    - el catch general ahora clasifica con `classifyExportFlowOutcome(...)`
    - `cancelled` -> mensaje de cancelacion (sin error generico, sin exito)
    - `unsupported` -> mensaje accionable/comercial consistente
    - error real -> path existente de `_reportStartPageError(...)`

### Checklist manual rapido (10-15 min) - Etapa 14

- Doble tap en abrir planilla desde Inicio:
  - no deben abrirse dos editores ni quedar dos pushes encadenados
- Doble tap en exportar desde Inicio:
  - confirmar que sigue una sola operacion (guardia `_busy` existente)
- Doble tap en importar ZIP desde Inicio:
  - confirmar que sigue un solo picker/import (`_importBackupZipInFlight`)
- Importar ZIP y cancelar picker:
  - no debe haber snack de exito
  - debe mantenerse cancelado (no error generico)
- Probar unsupported (si plataforma aplica) en import/export desde Inicio:
  - mensaje accionable/comercial, sin exito falso

### P1 (guardrail test, no implementado)

- Widget/integration test para doble tap en tile de planilla y verificacion de una sola navegacion.
- No se agrego en esta iteracion por limite de 3 hunks y para evitar test UI frágil en P0.

## Etapa 15 - P0 Editor (Smart Paste) reentrancia + gate de long operation (2026-02-26)

### Riesgo encontrado

- `lib/features/editor/editor_state.dart` (camino de Smart Paste / pegado de tabla)
  - el procesamiento grande de pegado usaba `_beginLongOperation(...)` directo
  - si el usuario disparaba pegado mientras ya habia export/import/share en curso, el paste podia pisar el estado de `longOperation`
  - riesgo: reentrancia/solapamiento de overlays, cancelacion cruzada y estado inconsistente

### Auditoria de `unawaited(...)` (export/share/import)

- Los entrypoints auditados de export/import/share llamados con `unawaited(...)` delegan en funciones que ya:
  - usan `_tryBeginLongOperation(...)`
  - capturan `cancelled / unsupported / error real`
- En esta iteracion no se detecto un caso nuevo de `unawaited` critico sin gate/catch en esos flows.

### Fix aplicado

- `lib/features/editor/editor_state.dart`
  - Smart Paste ahora usa `_tryBeginLongOperation(...)` en vez de `_beginLongOperation(...)` para el tramo pesado.
  - Si ya hay una operacion larga activa:
    - no arranca el pegado pesado
    - devuelve feedback de fallo controlado (sin excepcion, sin exito falso)
  - Se mantiene el mismo manejo de cancelacion (`_EditorLongOperationCancelled`) y cleanup (`_clearLongOperation()`).

### Checklist manual rapido (10-15 min) - Etapa 15

- En editor: iniciar export ZIP/PDF/XLSX y, mientras corre, intentar pegar una tabla grande:
  - no debe pisar el overlay/progreso existente
  - no debe arrancar una segunda operacion larga
- En editor: doble tap rapido en acciones de export (ZIP/PDF/XLSX):
  - confirmar que sigue una sola operacion (gate central)
- Cancelar picker/share sheet en export/share:
  - confirmar que no hay snack de exito ante cancelacion
- Reintentar Smart Paste cuando termina la exportacion:
  - debe funcionar normal (sin quedar bloqueado)

### P1 (test guardrail, no implementado)

- Widget test de reentrancia: mantener `longOperation` activo y disparar `_pasteFromClipboard()` para verificar que devuelve fallo controlado sin pisar el estado.
- No se agrego en esta iteracion por limite de hunks y por costo de harness UI.

## Etapa 16 - P0 pickers/cancelacion en adjuntos (2026-02-26)

### Riesgo encontrado

- `lib/features/editor/attachments/attachments_controller.dart`
  - cancelar pickers de adjuntos (archivo/video/audio) podia mostrarse como error (`snack` rojo) aunque fuera cancelacion del usuario
  - `openFile(...)` en video/documento/audio no clasificaba excepciones de picker (`cancelled` / `unsupported`), cayendo en fallos silenciosos o error generico si el plugin lanzaba
- `lib/features/editor/attachments/attachments_controller.dart` (`_offerAudioFileFallback`)
  - faltaba guarda `mounted` despues del `await showDialog(...)` antes de continuar con el flujo

### Fix aplicado

- `lib/features/editor/attachments/attachments_controller.dart`
  - Video / Archivo:
    - `openFile(...)` ahora clasifica excepciones con `classifyExportFlowOutcome(...)`
    - `cancelled` -> snack informativo (sin error)
    - `unsupported` -> mensaje accionable (sin error tecnico generico)
    - `failed` -> reporte de error real
    - guard `if (!mounted) return;` luego del picker antes de seguir
  - Archivo/Video generico (`_attachGenericFileToCell`)
    - `picked == null` (cancelacion del usuario) deja de mostrarse como error (`isError: false`)
  - Audio desde archivo (`_attachAudioFromFile`)
    - mismo esquema de clasificacion `cancelled / unsupported / failed` para `openFile(...)`
    - `xf == null` deja de mostrarse como error (`isError: false`)
  - Audio fallback (`_offerAudioFileFallback`)
    - guarda `if (!mounted) return false;` despues del dialogo

### Checklist manual rapido (10-15 min) - Etapa 16

- Adjuntar foto/archivo/video/audio y cancelar picker:
  - no debe aparecer error rojo (cancelado != error)
  - no debe aparecer exito falso
- Probar adjuntar archivo/video/audio en plataforma/no contexto no soportado (si aplica):
  - mensaje accionable/comercial, sin error tecnico confuso
- Importar ZIP desde Inicio y cancelar picker:
  - mantener semantica de cancelado (sin exito, sin error falso)
- Repetir cancelar 2-3 veces y navegar rapido atras:
  - sin crashes ni errores de `mounted/context`

### P1 (no implementado)

- Alinear tambien el snack de cancelacion de foto (`_processPhotoOutcome`) para que no use estilo de error en cancelaciones de usuario.
- Se dejo fuera por limite de hunks en esta iteracion.

## Etapa 17 - P0 consolidacion semantica foto (2026-02-26)

### Riesgo encontrado

- `lib/features/editor/attachments/attachments_controller.dart`
  - la clasificacion/mensaje de `cancelled / unsupported / failed` en FOTO estaba duplicada entre:
    - `catch` del picker
    - manejo de `PhotoAcquireOutcome` con error
  - riesgo de drift: una rama podia quedar alineada y la otra volver a marcar cancelacion como error rojo o tratar `unsupported` distinto

### Fix aplicado

- `lib/features/editor/attachments/attachments_controller.dart`
  - se centralizo la clasificacion en helper privado (`_classifyPhotoPickerOutcome(...)`)
  - se centralizo el branch de mensaje cancelado/no soportado en helper privado compartido
  - ambos caminos (excepcion del picker y error de `PhotoAcquireOutcome`) ahora reutilizan la misma semantica:
    - `cancelled` -> snack informativo (`isError: false`), sin `_reportFlowError`
    - `unsupported` -> mensaje accionable
    - `failed` -> error real (se mantiene reporte)

### Checklist manual rapido (10 min) - Etapa 17

- Adjuntar foto desde galeria y cancelar picker:
  - no debe aparecer snack rojo
  - no debe aparecer exito falso
- Adjuntar foto desde camara y cancelar:
  - si ofrece fallback, cancelar tambien
  - confirmar que sigue siendo cancelacion (no error rojo)
- Forzar / probar escenario no soportado (si aplica en navegador/dispositivo):
  - mensaje accionable consistente entre camara/galeria
- Adjuntar foto OK:
  - flujo normal sin regresion (sin cambios visuales extra)

## Etapa 18 - P0 semantica cancelacion audio picker/fallback (2026-02-26)

### Riesgo encontrado

- `lib/features/editor/attachments/attachments_controller.dart`
  - la semantica de audio estaba parcialmente alineada en el picker de archivo, pero seguia con riesgo de drift:
    - snack de cancelacion duplicado (`catch` y `xf == null`)
    - cancelacion del dialogo de fallback de audio (`_offerAudioFileFallback`) podia terminar mostrando luego un mensaje de `unsupported` (false error por cancelacion)

### Fix aplicado

- `lib/features/editor/attachments/attachments_controller.dart`
  - se centralizo la clasificacion de picker de audio con helper privado (`_classifyAudioPickerOutcome(...)`)
  - se centralizo el branch de mensajes `cancelled / unsupported` con helper privado compartido
  - `openFile(...)` en audio:
    - `cancelled` -> snack informativo (`isError: false`), sin `_reportFlowError`
    - `unsupported` -> mensaje accionable
    - `failed` -> mantiene `_reportFlowError`
  - `xf == null` (cancelacion) reutiliza el mismo branch de cancelado
  - cancelar el dialogo de fallback de audio ahora se trata como cancelacion manejada (snack informativo) y evita el falso `unsupported` posterior

### Checklist manual rapido (10-15 min) - Etapa 18

- Audio: abrir fallback (navegador sin grabacion) y cancelar dialogo:
  - no debe aparecer error/unsupported despues de cancelar
  - debe quedar como cancelacion informativa
- Audio: elegir "Adjuntar audio desde archivo" y cancelar picker:
  - no snack rojo
  - no exito falso
- Audio: escenario no soportado real del picker (si aplica):
  - mensaje accionable consistente
- Audio: adjuntar archivo valido y guardar:
  - sin regresion en guardado/preview/export

### P1 (no implementado por limite de 3 archivos)

- `lib/services/audio_storage_service_web.dart`
  - agregar `kDebugMode` logging minimo al fallback a memoria (`catch` en `saveRecording`) con:
    - `bytesLength`
    - store elegido (`hive` / `mem`)
    - reason sugerida (`session_only`/`blocked`/`quota`/`unknown`)
  - propuesta concreta:
    - loguear `hive_save_failed` + error resumido en `catch`
    - loguear `audio_store=mem` al retornar `StoredAudio(storageKey: 'mem:...')`
  - no se aplico en esta iteracion para respetar el limite de 3 archivos junto con fix + test + docs.

## Etapa 19 - P0 observabilidad fallback audio web (2026-02-26)

### Riesgo encontrado

- `lib/services/audio_storage_service_web.dart`
  - el fallback de guardado de audio web a memoria (`mem:`) podia ocurrir sin observabilidad local (sin logging debug ni reason/store expuestos)
- `lib/features/editor/attachments/attachments_controller.dart`
  - el warning del editor para audio fallback se disparaba solo por `mem:` y sin reason/store del servicio, dificultando diagnostico y dedupe fino

### Fix aplicado

- `lib/services/audio_storage_service_web.dart`
  - se agrego metadata interna de ultimo guardado:
    - `lastSaveStore`
    - `lastSaveReason`
  - se agrego logging solo debug (`kDebugMode + debugPrint`) con:
    - `bytesLength`
    - store final (`indexeddb` o `mem`)
    - reasonCode final (heuristico; default `unknown_storage_error`)
  - heuristica minima de reasonCode:
    - `quota_exceeded`
    - `storage_session_only`
    - `storage_blocked`
    - fallback `unknown_storage_error`

- `lib/features/editor/attachments/attachments_controller.dart`
  - en persistencia de audio (`_saveAudioAttachment`) se leen `lastSaveStore/lastSaveReason` via acceso dinámico al servicio web (sin tocar interfaces globales)
  - se normaliza `store` y `reason` antes de advertir (`unknown_storage_error` cuando no hay reason)
  - si el store final web no es durable (`indexeddb`) se dispara `_warnStorageFallbackOnce('audio', reasonCode, storageLabel)`
  - se mantiene dedupe del editor por clave `store|reason` (warning accionable sin spam)

### Checklist manual rapido (10-15 min) - Etapa 19

- Adjuntar audio chico en web normal:
  - guarda OK
  - sin warning de fallback si usa store durable
- Forzar fallback (incognito / storage bloqueado / cuota si es posible) y adjuntar audio:
  - aparece warning de modo temporal para audio
  - no se spamea al repetir 2-3 veces (dedupe)
- Revisar consola debug:
  - ver log con `bytes`, `store`, `reason`
- Guardar/exportar despues del fallback:
  - flujo sigue operativo (sin crash, sin falso exito extra)

### Validacion ejecutada (iteracion actual)

- `dart format lib/services/audio_storage_service_web.dart lib/features/editor/attachments/attachments_controller.dart` -> `EXIT 0`
- `flutter analyze` -> `EXIT 1` (deuda historica del repo; sin nuevas alerts P0 del cambio)
- `flutter test --no-pub` -> `EXIT 0`
- `flutter build web --dart-define=DEMO_MODE=true --dart-define=AUTH_ENABLED=false` -> `EXIT 0`

---

## Checklist demo final (10-15 min)

1. Inicio:
   - abrir app, crear planilla nueva, abrir/cerrar sin errores.
2. Cancelaciones sin rojo:
   - adjuntar foto -> cancelar picker (no error rojo, no exito falso).
   - adjuntar audio archivo -> cancelar picker (no error rojo, no exito falso).
   - exportar PDF/ZIP -> cancelar selector/share (cancelado informativo).
3. Unsupported accionable:
   - provocar path no soportado (si aplica en dispositivo) y validar mensaje accionable.
4. Reentrancia:
   - doble tap rapido en abrir planilla e importar ZIP desde Inicio -> una sola accion.
   - disparar export y volver a tocar export/paste rapido -> sin solape de operacion larga.
5. Fallback web observable:
   - en web/incognito o storage limitado, adjuntar audio/foto/archivo.
   - validar warning de modo temporal (sin spam) y continuidad operativa.
6. Cierre tecnico:
   - guardar cambios, refrescar pagina y validar persistencia.
   - exportar ZIP backup como mecanismo de resguardo.

## P1 propuesto (sin ejecutar en P0)

- Estandarizar telemetry de storage fallback en interfaz comun (`store/reason`) para evitar acceso dinamico por plataforma.
- Agregar widget tests de reentrancia (doble tap en rutas Inicio/Editor) para prevenir regresiones.
- Consolidar copy y severidad de `unsupported` en un helper unico para todo attachment/export flow.

