# Editor Refactor Plan (Nextleague v4)

Fecha: 2026-02-06  
Branch: `codex/editor-nextleague-v3`
Backup: `_backups/bitacora_web_PRE_EDITOR_V4_20260206_1806.zip`

## Estado final (responsabilidades)
- `lib/features/editor/editor_screen.dart`: orquestador + imports + parts.
- `lib/features/editor/editor_state.dart`: estado principal, grid, navegacion, export/import, utilidades core.
- `lib/features/editor/attachments/*`: adjuntos (foto/audio), panel, tiles, preview.
- `lib/features/editor/dialogs/*`: dialogs premium (export, densidad, GPS, atajos, confirm).
- `lib/features/editor/actions/*`: acciones y shortcuts (command palette + key events).
- `lib/screens/editor_screen.dart`: wrapper/export para mantener API publica.

## Objetivo
- Editor modular, mantenible y con UX premium.
- `editor_screen.dart` <= 350 lineas y sin dialogs/attachments inline.
- Adjuntos y dialogs extraidos en modulos dedicados.
- Sin cambios de comportamiento ni regresiones en flujos clave.

## Cambios v4 (polish)
- Widgets de adjuntos publicos: `AttachmentTile`, `AttachmentPreviewModal`, `AttachmentsSheetHeader`.
- Adjuntos con tooltips, semantica y animaciones sutiles (AnimatedSwitcher).
- Dialogs consistentes con AppModal + AppButton.
- Shortcuts con guard cuando hay input activo.
- Scripts PS1 con UTF-8 output.

## Criterios de aceptacion
- `lib/features/editor/editor_screen.dart` <= 350 lineas.
- Actions/Shortcuts en `lib/features/editor/actions/`.
- Dialogs en `lib/features/editor/dialogs/`.
- Attachments en `lib/features/editor/attachments/`.
- `dart format .` sin cambios pendientes.
- Flujos: editar celda, adjuntos, export ZIP, reporte HTML, import ZIP (sin regresiones).

## Notas
- Se generaron archivos temporales de extraccion en `_legacy/` para trazar el split.
