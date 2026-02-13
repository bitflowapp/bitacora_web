# UI Action Audit (P0)

Date: 2026-02-13  
Scope: Agent/FlowBot/command palette/mobile quick actions in `EditorScreen`.

## Summary

- No decorative/no-op action was kept in the audited set.
- FlowBot apply path now returns standardized action outcome (`ok`, `message`, `undoToken`) and always shows feedback.
- Disabled states now expose explicit reason text in FlowBot sheet.

## Audited Actions

| Area | Action | Current behavior | Disabled reason / guard |
|---|---|---|---|
| Command palette | `FlowBot` | Opens FlowBot sheet (`_openFlowBotSheet`) | N/A |
| FlowBot sheet | `Analizar` | Parses text/voice into preview actions | Disabled while parsing |
| FlowBot sheet | `Aplicar` | Applies preview actions, shows success/error toast, exposes undo token on success | Disabled with reason when preview is empty or still parsing |
| FlowBot sheet | `Voz` | Starts/stops speech capture | If speech unavailable, shows warning text |
| FlowBot sheet | `Motor: Local/Offline` | Toggles parser engine preference | If local model missing, warning shown and parser falls back to offline deterministic mode |
| FlowBot sheet | `Descargar modelo` | Triggers local model download flow | Disabled while download is in progress |
| Command palette | `Aplicar valor a seleccion` | Opens batch apply dialog and applies in selection | Action validates selection and input |
| Mobile quick bar | `Aplicar mismo valor` | Batch applies to selected rows | Guarded by selection state in editor logic |

## Standardized Outcome (new)

FlowBot apply now uses a uniform outcome object:

- `ok`: whether at least one action was applied.
- `message`: user-facing feedback.
- `undoToken`: present when undo is available (`flowbot_apply`).

Behavior:

- Success: toast with applied count + undo action.
- No-op: warning toast with explicit reason, never silent.

## Test Coverage Added/Updated

- `test/no_network_hermetic_test.dart`: verifies outbound HTTP is blocked by default in tests.
- `test/editor_flowbot_apply_widget_test.dart`: verifies no-op apply returns explicit failure result and successful apply returns `undoToken`.
