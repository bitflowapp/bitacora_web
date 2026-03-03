# QA Checklist (A-I) - BitFlow

Fecha: 2026-03-03
Branch: `qa/bugbash-hardening`

## A) StartPage (inicio minimal)
- Archivos clave:
  - `lib/start_page.dart`
  - `lib/widgets/command_palette.dart` (sheet de busqueda usado por Inicio)
- Prueba manual:
  1. Abrir Inicio y verificar HERO con 2 CTAs (`Nueva planilla`, `Buscar`) + hint `Ctrl/Cmd+K`.
  2. Cambiar tab `Recientes/Favoritas`, abrir menu `⋯` de un item y ejecutar `Abrir/Renombrar/Duplicar/Eliminar`.

## B) Quick Switcher (Ctrl/Cmd+K)
- Archivos clave:
  - `lib/start_page.dart` (`_onHomeKeyEvent`, `_openQuickSwitcher`)
  - `lib/widgets/command_palette.dart`
- Prueba manual:
  1. Desde Inicio: `Ctrl/Cmd+K` abre, `Esc` cierra.
  2. Escribir filtro y confirmar con `Enter` para abrir accion/item.

## C) Find in Sheet (Ctrl/Cmd+F)
- Archivos clave:
  - `lib/features/editor/actions/editor_shortcuts.dart`
  - `lib/features/editor/editor_state.dart` (`_openInlineSearch`, `_refreshSearchMatches`, next/prev)
  - `lib/features/editor/widgets/mobile_editor_widgets.dart` (`_InlineSearchBar`)
- Prueba manual:
  1. En Editor: `Ctrl/Cmd+F`, buscar texto y validar foco en coincidencia.
  2. Cambiar alcance (`Todo/Fila/Columna`) y usar siguiente/anterior.

## D) Autosave + guardrails
- Archivos clave:
  - `lib/features/editor/editor_state.dart` (`_saveLocalNow`, `_tickAutosavePulse`, `PopScope`, `_handleEditorPopGuard`)
  - `lib/features/editor/widgets/save_status_chip.dart`
- Prueba manual:
  1. Editar una celda y esperar autosave (estado `Guardando` -> `Guardado`).
  2. Intentar salir con cambios sin guardar y validar dialogo (`Guardar/Descartar/Cancelar`).

## E) Export + validacion
- Archivos clave:
  - `lib/features/editor/editor_state.dart` (`_confirmExportWithValidationIfNeeded`, `_copyValidationIssuesToClipboard`)
  - `lib/features/editor/dialogs/export_dialogs.dart`
- Prueba manual:
  1. Forzar errores de validacion y exportar.
  2. Verificar modal gating con `Copiar errores` e `Ir a primera fila con error`.

## F) Theme toggle dia/noche
- Archivos clave:
  - `lib/app.dart` (`_toggleTheme`, persistencia ThemeMode)
  - `lib/start_page.dart` (boton toggle)
  - `lib/features/editor/editor_state.dart` (`_toggleTheme`)
- Prueba manual:
  1. Togglear tema varias veces (Inicio + Editor).
  2. Reabrir app y validar persistencia de tema.

## G) Update banner / version.json
- Archivos clave:
  - `lib/services/app_update_service.dart`
  - `lib/start_page.dart` (`_checkForUpdates`, `_buildPriorityNotice`, `_applyAvailableUpdate`)
  - `lib/services/force_update_service*.dart`
- Prueba manual:
  1. Simular `version.json` remoto con build/version mayor y validar notice.
  2. Ejecutar accion (`Recargar` en web / `Descargar`) y validar feedback.

## H) CRUD planillas + persistencia
- Archivos clave:
  - `lib/services/sheet_store.dart`
  - `lib/services/sheet_store_web.dart`
  - `lib/services/sheet_store_io.dart`
  - `lib/start_page.dart` (acciones CRUD/favoritas/recientes)
- Prueba manual:
  1. Crear, renombrar, duplicar, eliminar, restaurar y favoritar una planilla.
  2. Reiniciar app y verificar que cambios persisten en listas.

## I) Mobile ergonomics
- Archivos clave:
  - `lib/features/editor/editor_state.dart` (layout mobile, barras, fab)
  - `lib/features/editor/widgets/mobile_editor_widgets.dart`
  - `lib/start_page.dart` (cards/sheets/notice en viewport chico)
- Prueba manual:
  1. Probar viewport mobile: abrir modal/bottom sheet y verificar scroll sin overflow.
  2. Abrir teclado en edicion mobile y confirmar que FAB/top bar no tapan acciones.
