# Editor Architecture

Scope: `lib/features/editor/*`

## Product goal
BitFlow editor must stay fast, predictable, offline-first, and premium in UI/UX across Android and Web/PWA.

## Module map

### Entry and state
- `editor_screen.dart`
  - Entry point and part wiring.
  - Service imports and dependency surface.
- `editor_state.dart`
  - Single source of truth for:
    - grid rows/headers/cell meta
    - selection, drafts, undo/redo
    - save/sync/offline queue status
    - search/jump/batch/productivity flows
    - onboarding/recovery/install-helper banners
    - import/export package orchestration

### Actions and shortcuts
- `actions/editor_actions.dart`
  - Command Palette action catalog.
  - Includes onboarding/help/defaults actions.
- `actions/editor_shortcuts.dart`
  - Keyboard map (`Ctrl/Cmd+K/S/F/J`, undo/redo, paste, export/import, queue).

### UI composition
- `widgets/editor_app_bar.dart`
  - Premium topbar/toolbar, status chips, pill actions, focus order.
- `widgets/grid_host.dart`
  - Table rendering shell, selection/focus visuals, cell hit targets.
- `widgets/mobile_editor_widgets.dart`
  - Inline search, quick actions, mobile bars, status/auxiliary banners.
- `widgets/save_status_chip.dart`
  - Save and sync chips with animated state transitions.

### Attachments and dialogs
- `attachments/`
  - Photo/audio/GPS metadata flow, attachment panel and preview actions.
- `dialogs/`
  - Editor preferences, density/GPS mode, shortcuts help, export/import, confirmations.

### Supporting infra
- `lib/ui/app_motion.dart`
  - Shared motion tokens and transitions.
- `lib/ui/app_haptics.dart`
  - Mobile haptics facade.
- `lib/widgets/command_palette.dart`
  - Global command launcher.
- `lib/services/web_flush_signal*.dart`
  - Flush hooks for `visibilitychange/pagehide/beforeunload`.
- `lib/services/web_capabilities*.dart`
  - Web feature detection (iOS Safari, Android Chrome, standalone, in-app browser).

## Core flows

### Edit/save flow
1. User action enters via grid, toolbar, command palette, or shortcut.
2. `editor_state.dart` mutates local model.
3. Dirty/save state and offline queue snapshots are updated.
4. Save pipeline persists atomically (current + backup + staging + snapshot fallback).

### Smart productivity flow (P9)
1. Row insertion routes through smart defaults:
  - Date columns -> now
  - Status columns -> `OK`
  - ID/Progresiva columns -> autoincrement (if enabled)
2. Column value history is remembered and persisted per sheet.
3. Smart paste supports TSV/CSV/text and normalizes values per column type.

### Resilience flow (P9)
1. On load, staging payload is inspected.
2. If recoverable, a recovery banner offers explicit restore.
3. Offline queue viewer exposes:
  - retry item
  - retry all
  - diagnostic export
4. Web/PWA install helpers are shown only when context matches platform constraints.

## State boundaries
- Hot-path state lives in `editor_state.dart`.
- Rebuild control uses:
  - `_gridVersion`
  - row-scoped `ValueNotifier`s
  - `RepaintBoundary` around grid layers
- Do not push global `setState` for single-cell updates.

## How to add a new feature safely
1. Add/adjust one state method in `editor_state.dart`.
2. Expose the action in at least one entry:
  - toolbar/topbar
  - command palette
  - keyboard shortcut
  - mobile actions menu
3. Reuse existing primitives:
  - `AppButton`, `showAppModal`, `AppMotion`, `AppHaptics`
4. Keep offline-first behavior:
  - local state update first
  - async network/sync second
5. Update `docs/release_checklist.md` smoke steps.

## Grid Pro (P10)
- Source of truth:
  - `_columnPrefsById`: tipo + visibilidad por columna.
  - `_columnOrder`: orden persistente de columnas de datos.
  - `_frozenColId`: columna priorizada en orden visual.
- Entry points:
  - Menu contextual de header (`_openContextMenu`).
  - Panel `Columnas` (`_openColumnPanel`).
  - Command Palette: `Panel de columnas`.
- Current behavior:
  - Tipos soportados: Texto, Numero, Fecha, Estado, Checkbox.
  - Visibilidad por columna con guardrails (siempre queda al menos una visible).
  - Reordenado por columna (up/down) persistido por planilla.
  - Ordenar asc/desc por columna con parse por tipo.
- Integration rule:
  - Toda lectura/escritura de grilla usa mapeo display->actual (`_displayColumnIndexes`, `_actualColumnFromDisplay`).

## Form mode (P10)
- Entry points:
  - Boton `Formulario` en topbar premium.
  - Command Palette: `Formulario de fila`.
  - Menu movil: `Formulario`.
  - `+Registro` (quick capture) abre formulario al finalizar captura.
- Data flow:
  1. Resolver fila objetivo (`_resolveFormRowIndex`).
  2. Renderizar campos por tipo (`_buildFormFieldForColumn`).
  3. Acciones rapidas del formulario: foto, GPS, timestamp.
  4. Guardar normaliza por tipo (`_normalizeCellValueForColumn`) y marca dirty.
- Extension guideline:
  - Si agregas un nuevo tipo de columna, actualiza:
    - `_ColType`
    - `_normalizeCellValueForColumn`
    - `_recomputeValidation`
    - `_buildFormFieldForColumn`

## Column Config Persistence (P11)
- Persistencia por planilla en `_SheetModel`:
  - `columnPrefsById`
  - `columnOrder`
  - `frozenColId`
- Persistencia adicional de plantillas de columnas:
  - SharedPreferences key: `bitflow.editor.column_templates.v1`
  - Payload: `_ColumnTemplate` (prefs por label, orden, columna fijada, timestamp).
- Migracion suave:
  - `sheet_store_io/web` preserva claves de configuracion de columnas al normalizar/guardar (`columnPrefs`, `columnOrder`, `frozenColId`).
  - Modelos legacy siguen siendo legibles.

## Validation UX (P11)
- Reglas soportadas:
  - required
  - number
  - date
  - enum/dropdown (`status` con `enumValues`)
- Motor central:
  - `_validationMessageForValue`
  - `_recomputeValidation`
- Superficie UX:
  - resaltado de celda invalida monocromo en grilla
  - hint inline en editor desktop/mobile
  - panel opcional `Errores` con salto directo a celda
  - modal de confirmacion de export cuando hay errores

## Perf Strategy (P11)
- Navegacion rapida por teclado:
  - `Tab`/`Shift+Tab`
  - `Enter`/`Shift+Enter`
  - movimiento sobre columnas editables visibles
- Smart paste chunked:
  - pegado multi-celda procesado en lotes con yield de event loop (`Future.delayed(Duration.zero)`).
  - evita freezes con payloads grandes.
- Rebuild guardrails:
  - `ValueNotifier` por fila + `_gridVersion`
  - contadores debug siguen detras del flag `BITFLOW_DEBUG_GRID_REBUILDS`.

## Motion System (P11)
- Tokens base en `lib/ui/app_motion.dart`.
- Aplicaciones en editor:
  - transiciones de paneles (`AnimatedSwitcher` + `AppMotion.fadeSlide`)
  - microanimaciones en celdas (`AnimatedContainer`, `AnimatedScale`)
  - feedback tactil afinado con throttling en `_blink` (iOS/Android)
- Objetivo visual:
  - monocromo premium, bordes redondeados consistentes y sombras suaves.

## Data Quality Center (P12)
- Reglas de validacion centralizadas:
  - `validation/validation_rules.dart`
  - `_validationMessageForValue` + `_recomputeValidation`
- Superficie UX:
  - celdas invalidas monocromas
  - hint inline
  - panel de errores navegable (`_ValidationErrorsPanel`)
  - export gating (`_confirmExportWithValidationIfNeeded`)

## Saved Views (P12)
- Modelo:
  - `_SavedView` en `editor_models.dart`
- Persistencia:
  - `SharedPreferences` por planilla (`_prefsSavedViewsKey`, `_prefsActiveViewKey`)
- Runtime:
  - filtros/orden/columnas se aplican en capa de proyeccion de filas:
    - `_visibleRowIndexes`
    - `_actualRowFromDisplay`
    - `_displayRowForActual`
  - no reordena ni muta dataset base para render de vistas

## Review Workflow (P12)
- Metadata por fila en `_RowModel`:
  - `reviewed`
  - `reviewedBy`
  - `reviewedAt`
- Acciones:
  - `_markSelectedRowsReviewed`
  - `_markSelectedRowsPendingReview`
  - `_togglePendingReviewView`
- Export PDF:
  - agrega columnas de revision cuando hay metadata disponible

## Productivity Layer (P12)
- Command palette extendida (`actions/editor_actions.dart`):
  - `Ir a errores`
  - `Vista Urgentes`
  - `Marcar revisado`
  - `Duplicar ultima fila`
  - `Auto-ID`
  - `Usar ultimo valor`
- Mantiene entrypoints multiples:
  - topbar/toolbar
  - menu mobile
  - palette

## Perf Notes (P12)
- Paste:
  - chunking por celdas procesadas (no solo cambiadas) para mantener responsividad.
- Review updates:
  - bump por fila (`_bumpRowVersionById`) y rebuild global solo cuando afecta vista.
- Saved views:
  - cache token liviano para evitar `jsonEncode` en cada build.

## Audit History (P13)
- Modelo:
  - `HistoryEventRecord` en `editor_models.dart`.
- Persistencia:
  - `SharedPreferences` por planilla (`_kPrefHistoryLog`).
  - recorte por politica rolling (`HistoryEventRecord.trim`).
- UX:
  - panel `Historial` con filtros (`hoy`, `semana`, `tipo`) y jump-to-cell.
  - entradas desde toolbar y command palette.
- Integracion:
  - hooks en mutaciones relevantes (`edit_cell`, `insert/delete`, `batch`, `quick_capture`, `review`, `import/merge`).

## Search Everywhere (P13)
- Query parser:
  - `SearchEverywhereQuery` (plain text + `col:valor` + alias de columnas).
- Motor:
  - `_searchSheetRows` + `_searchEverywhere`.
  - chunking/yield para no bloquear UI.
  - debounce en modal de busqueda global.
- UX:
  - resultados agrupados por planilla.
  - jump directo a celda en la planilla actual o al abrir otra planilla.

## Async Collaboration (P13)
- Export paquete:
  - snapshot full + metadata colaborativa (`snapshotMode: full`, revision origen).
- Import paquete:
  - `createNew`, `replaceCurrent`, `mergeCurrent`.
  - merge sobre celdas por `rowId::colId`.
  - politica de conflicto: `keepLocal` o `useImported`.
- Motor reusable:
  - `PackageMergeEngine.mergeMaps`.
  - tests unitarios en `test/package_merge_engine_test.dart`.
- Auditoria:
  - eventos `package_import_*` y `package_merge`.

## Template Packs (P13)
- Start page:
  - galeria por packs + preview antes de crear.
  - creacion via `SheetStore.createFromModel`.
- Presets:
  - `columnPrefs` (tipos/validacion/defaults).
  - seed de vistas guardadas por planilla en key editor (`bitflow:sheet:<id>:bitflow.editor.saved_views.v1`).
- Objetivo:
  - onboarding comercial (templates listos para uso de campo/obra/relevamiento).

## Editor Perf Instrumentation (P14)
- Flag de runtime:
  - `BITFLOW_DEBUG_EDITOR_PERF`.
- Mide hot-path sin ruido por defecto:
  - builds de grid/fila/celda
  - eventos de input
  - latencia input -> rebuild de fila (avg/p95/max)
- Objetivo:
  - detectar regresiones de typing/scroll sin afectar release UX.

## Inline Cell Previews (P14)
- Fuente de verdad:
  - metadata de adjuntos por celda (`cellMeta`).
- Render en grilla:
  - desktop `grid_host.dart`
  - mobile `mobile_notes_grid.dart`
- Estrategia:
  - thumbnails comprimidos al adjuntar (downscale)
  - decode lazy + cache LRU en memoria para evitar decodificacion repetida
  - fallback monocromo para docs/PDF cuando no hay thumb usable
- Guardrails:
  - toggle `cellInlinePreviewsEnabled` persistido en preferencias de editor
  - previews nunca bloquean typing ni fuerzan rebuild global.

## Sheet Key Hygiene (P14 bugfix)
- `SheetStore.list()` ahora ignora claves de metadata por planilla:
  - `<id>:backup`
  - `<id>:bk:list`
  - `<id>:bk:<timestamp>`
- Evita que backups internos aparezcan como planillas fantasma en listados/tests.

## Validation gates
- `dart format --set-exit-if-changed .`
- `flutter analyze --no-fatal-warnings --no-fatal-infos`
- `flutter test`
- `flutter build web --release --base-href "/bitacora_web/"`
- `flutter build apk --release`
