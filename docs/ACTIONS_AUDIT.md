# UI Action Audit (Final)

Date: 2026-02-13  
Scope: Agent/FlowBot, editor toolbar, command palette, mobile quick actions, context menu.

## Result

- No main action remains as decorative/no-op.
- Every audited action now does one of these:
  - Executes a real state change/export/flow.
  - Shows explicit feedback with reason when it cannot run.
- Feedback standard is unified through `_ActionResult` + toast + haptic.

## ActionResult Standard

All primary user actions now converge to:

- `ok`: action executed with effect.
- `message`: user-facing result/reason.
- `undoToken` (optional): enables `Deshacer`.

Runtime behavior:

- `ok=true`: success toast + light haptic.
- `ok=false`: warning/error toast + distinct fail haptic.

## Audited Areas

| Area | Action | Final status |
|---|---|---|
| Desktop header | `+` (Nuevo registro) | Executes real automation (`fila + defaults + focus`) |
| Mobile quick bar | `+ Registro` | Executes real automation (`fila + defaults + focus`) |
| Command palette | `Nuevo registro` | Executes same automation |
| Command palette | `Pegar tabla inteligente` | Detects TSV/CSV and applies batch paste |
| FlowBot sheet | `Analizar` | Always returns plan or warning |
| FlowBot sheet | `Aplicar` | Disabled with reason if invalid; applies real actions when valid |
| FlowBot actions | `addRow/pasteTable` | Wired to real editor changes (`new record`, `smart paste`) |
| Command palette | `Centrar columna activa` | If no celda activa editable => explicit reason |
| Command palette | `Duplicar fila activa` | If no fila activa => explicit reason |
| Command palette | `Rellenar hacia abajo` | If no celda activa => explicit reason |
| Command palette | `Abrir adjuntos` | If no celda activa => explicit reason |
| Command palette | `Adjuntar foto/GPS/audio/video/archivo` | If no celda activa => explicit reason |
| Quick actions | `Lote` sin filas | Explicit reason (`No hay filas seleccionadas`) |
| Context menu | `Copiar/Pegar` | No silent return: success or reason message |

## New Real Automations (minimum set)

1. Nuevo registro:
- Inserts a new row.
- Applies persisted defaults:
  - fecha de hoy (if enabled)
  - progresiva/autoincrement (if enabled)
  - estado OK (if enabled)
- Focuses first editable column.
- Shows toast + supports undo token.

2. Pegar tabla inteligente:
- Detects delimiter: TSV, CSV comma, CSV semicolon.
- Parses quoted fields.
- Applies batch from active cell.
- Handles multi-row extension without per-cell rebuild loop.
- Gives explicit reason on empty clipboard/no-op/invalid target.
- Shows toast + supports undo token.

## Hermetic Testing Impact

- No outbound HTTP is introduced by these UI actions.
- Existing `flutter_test_config.dart` HTTP block remains active by default.
