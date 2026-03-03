# QA Bug Bash - Hallazgos

Fecha: 2026-03-03  
Branch: `qa/bugbash-hardening`

## P1 - Guardrail de salida no cubria drafts sin commit
- Feature: D) Autosave + guardrails
- Pasos:
  1. Abrir Editor.
  2. Escribir un draft sin commit (estado en `_draftCells`).
  3. Intentar salir con back.
- Esperado: mostrar confirmacion `Cambios sin guardar`.
- Actual: la ruta podia cerrarse sin prompt (perdida potencial de cambios).
- Archivo probable: `lib/features/editor/editor_state.dart`
- Estado: `FIXED`
- Fix aplicado:
  - `PopScope.canPop` y `_handleEditorPopGuard` ahora contemplan drafts activos/persistidos.
  - `_updateSaveStatus` considera pending drafts.
  - Se fuerza rebuild de guardrail cuando cambia el estado draft (toggle vacio/no vacio).
- Test regresion:
  - `test/editor_unsaved_exit_guardrail_test.dart`
- Commit:
  - `a640f6c` (`fix: guard unsaved draft exits in editor`)
  - `6bb197f` (`test: cover start and editor QA regressions`)

## P2 - Quick Switcher ejecutaba “Nueva planilla” con Enter por defecto
- Feature: B) Quick Switcher (Ctrl/Cmd+K)
- Pasos:
  1. Abrir Quick Switcher con `Ctrl/Cmd+K`.
  2. Presionar `Enter` sin filtrar.
- Esperado: abrir la planilla mas reciente por defecto.
- Actual: ejecutaba accion de creacion (flujo no esperado para “switch”).
- Archivo probable: `lib/start_page.dart`
- Estado: `FIXED`
- Fix aplicado:
  - Reorden de acciones en `_openQuickSwitcher`: planillas primero, acciones de crear despues.
- Test regresion:
  - `test/start_quick_switcher_smoke_test.dart` (`quick switcher enter opens most recent sheet by default`)
- Commit:
  - `fbb98e7` (`fix: harden start quick switcher and create sheet modal`)
  - `6bb197f` (`test: cover start and editor QA regressions`)

## P2 - Overflow en modal “Crear planilla” en viewport compacto
- Feature: I) Mobile ergonomics
- Pasos:
  1. Abrir Inicio en viewport compacto.
  2. Abrir CTA `Nueva planilla`.
- Esperado: modal usable y scrolleable sin overflow.
- Actual: `RenderFlex overflowed` en el contenido del bottom sheet.
- Archivo probable: `lib/start_page.dart`
- Estado: `FIXED`
- Fix aplicado:
  - `showModalBottomSheet` con `isScrollControlled: true`.
  - `ConstrainedBox(maxHeight)` + `SingleChildScrollView` en la galeria de creacion.
- Test regresion:
  - `test/start_create_sheet_modal_smoke_test.dart`
- Commit:
  - `fbb98e7` (`fix: harden start quick switcher and create sheet modal`)
  - `6bb197f` (`test: cover start and editor QA regressions`)

## P2 - Lifecycle leak en command palette
- Feature: B) Quick Switcher / command palette base
- Pasos:
  1. Abrir/cerrar palette repetidamente.
  2. Revisar ciclo de vida de controllers.
- Esperado: disposal completo de controllers al cerrar.
- Actual: `ScrollController` local no se liberaba explicitamente.
- Archivo probable: `lib/widgets/command_palette.dart`
- Estado: `FIXED`
- Fix aplicado:
  - `listCtl` movido a scope externo y `dispose()` en `finally`.
- Commit:
  - `63d8e94` (`chore: dispose command palette scroll controller`)
  - `6bb197f` (`test: cover start and editor QA regressions`)

## P2 - Fase 2 propuesta (no abordado en esta pasada)
- Tema: normalizacion de textos legacy con mojibake en algunos strings historicos.
- Riesgo: menor (copy/UI), pero afecta presentacion comercial.
- Propuesta concreta:
  1. Barrido de strings no ASCII corruptos.
  2. Migrar a UTF-8 consistente y revisar snapshots/tests de texto.

## Edge cases ejecutados (A-I)

### A) StartPage
- `HERO + CTAs + Daily + Pro colapsada` renderiza sin excepcion (PASS, `test/start_page_minimal_smoke_test.dart`).
- Abrir CTA `Nueva planilla` en viewport compacto no produce overflow (PASS, `test/start_create_sheet_modal_smoke_test.dart`).
- Notice de update visible con servicio que reporta update (PASS, `test/start_update_notice_smoke_test.dart`).

### B) Quick Switcher (Ctrl/Cmd+K)
- `Ctrl/Cmd+K` abre palette y `Esc` cierra (PASS, `test/start_quick_switcher_smoke_test.dart`).
- `Enter` por defecto abre planilla reciente (PASS tras fix, `test/start_quick_switcher_smoke_test.dart`).
- Apertura/cierre repetida durante smoke de teclado sin excepciones (PASS, misma suite).

### C) Find in Sheet (Ctrl/Cmd+F)
- Abrir buscar y encontrar coincidencia inicial (PASS, `test/editor_find_in_sheet_smoke_test.dart`).
- `next` avanza a la siguiente coincidencia visible (PASS, misma suite).
- `prev` vuelve a coincidencia previa (PASS, misma suite).

### D) Autosave + guardrails
- Guardado manual persiste draft sin commit (PASS, `test/editor_draft_save_guardrail_test.dart`).
- Salida con draft-only ahora bloquea y pide confirmacion (PASS tras fix, `test/editor_unsaved_exit_guardrail_test.dart`).
- Estado de guardado refleja drafts pendientes (PASS por inspeccion + regresion de guardrail).

### E) Export + validacion
- Gating aparece cuando hay errores (PASS, `test/export_validation_gating_smoke_test.dart`).
- Accion `Copiar errores` disponible en modal (PASS, misma suite).
- Accion `Ir a primera fila con error` disponible en modal (PASS, misma suite).

### F) Theme toggle dia/noche
- Toggle presente y funcional en StartPage (PASS por smoke existente de StartPage + interaccion manual local).
- Cambio de tema no rompe layout de inicio minimal (PASS por suite StartPage).
- Editor usa callback de toggle sin doble-toggle interno (PASS por revision de codigo, sin regresion detectada).

### G) Update banner / version.json
- Decodificacion UTF-8 de `version.json` (PASS, `test/app_update_service_utf8_test.dart`).
- Notice de update prioritaria sobre demo (PASS por inyeccion de snapshot update en StartPage test).
- CTA de update visible y accionable en aviso compacto (PASS, `test/start_update_notice_smoke_test.dart`).

### H) CRUD planillas + persistencia
- Crear y listar planillas en Inicio (PASS, smoke StartPage + Quick Switcher).
- Abrir planilla desde Quick Switcher (PASS, `test/start_quick_switcher_smoke_test.dart`).
- Persistencia de guardado local entre reaperturas de editor (PASS, `test/editor_draft_save_guardrail_test.dart`).

### I) Mobile ergonomics
- Modal de crear planilla scrollable en viewport compacto (PASS tras fix, `test/start_create_sheet_modal_smoke_test.dart`).
- Editor mobile mantiene celda visible al editar (PASS, `test/editor_mobile_edit_centering_test.dart`).
- Compact/zen mode no rompe top bar con escalas altas (PASS, `test/mobile_compact_mode_behavior_test.dart`).
