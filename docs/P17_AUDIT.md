# P17 Audit Report (Editor Hardening)

Date: 2026-02-12  
Scope: EditorScreen, FlowBot, attachments pipeline, perf overlay, mobile compact/focus behavior.

## Top Risks Found
1. FlowBot still depended on OpenAI API key path (policy mismatch and runtime fragility).
2. Incomplete migration left undefined identifiers in editor state/dialogs.
3. FlowBot action enum drift (`fillDown` vs `fillRange`) caused compile/test breakage risk.
4. Missing persisted history for FlowBot commands (repeated command UX degraded).
5. Local model lifecycle was not managed (no download/install path).
6. Perf harness overlay lacked cache hit/miss visibility for thumbnail decode cache.
7. Thumbnail cache metrics were opaque, making regressions harder to detect.
8. Mobile focus-cell mode toggle existed in state but was not wired into behavior.
9. Shortcut map conflicted with new productivity goals (center/wrap actions).
10. Camera attach path had async context risk around permission preflight.

## Fixes Applied
- Removed remote-token FlowBot path from editor runtime:
  - dropped OpenAI key usage from editor preferences/UI.
  - parser now uses deterministic rule engine by default.
  - optional local LLM path uses on-device provider contract (`MethodChannel`) only.
- Added local model management:
  - `lib/services/flowbot_local_model_manager.dart`
  - `lib/services/flowbot_local_model_manager_io.dart`
  - `lib/services/flowbot_local_model_manager_stub.dart`
- Added FlowBot persisted state:
  - local LLM toggle
  - local model path
  - command history ring (dedup + bounded)
- Reworked FlowBot action handling in editor:
  - supports `setCell`, `fillRange`, `addRow`, `setColumnAlign`, `setWrap`, `applyStatus`, `setToday`, `autoId`, `copyGps`, `duplicateRow`, `attachPhotoToCell`, `exportPdfPreset`.
- Updated keyboard shortcuts:
  - `Ctrl/Cmd+E`: center active column
  - `Ctrl/Cmd+Shift+L`: wrap toggle 1/2/3 lines
  - `Ctrl/Cmd+Alt+C`: center align action
- Enabled focus-cell guardrail:
  - mobile focus mode now gates automatic row centering behavior.
- Added cache instrumentation:
  - `ThumbDecodeLruCache` now tracks `hits/misses/evictions`.
  - perf report + overlay show cache metrics.
- Attach flow reliability:
  - mounted guard after camera permission preflight before using UI context.

## Regression Guardrails Added/Updated
- Updated `test/flowbot_parser_test.dart` for `fillRange` and added align/wrap parsing case.
- Extended `test/thumb_decode_lru_cache_test.dart` with deterministic hit/miss/eviction assertions.

## Residual Risks
- Local LLM runtime plugin integration (actual llama.cpp native bridge) remains platform-dependent and may return `MissingPluginException` until runtime plugin is shipped.
- Existing non-fatal analyzer warnings remain in unrelated legacy areas and should be cleaned in a separate pass.
