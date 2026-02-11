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
## Validation gates
- `dart format --set-exit-if-changed .`
- `flutter analyze --no-fatal-warnings --no-fatal-infos`
- `flutter test`
- `flutter build web --release --base-href "/bitacora_web/"`
- `flutter build apk --release`
