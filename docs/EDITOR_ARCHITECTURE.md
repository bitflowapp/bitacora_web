# Editor Architecture

Scope: `lib/features/editor/*`

## Product Goal
Keep the editor fast, predictable, and premium while preserving offline-first behavior across Android and Web/PWA.

## Main Modules
- `editor_screen.dart`
  - Entry point and part wiring.
  - Owns service imports and dependency surface for editor internals.
- `editor_state.dart`
  - Single source of truth for grid state, selection, drafts, history, sync status, and export/import orchestration.
  - Contains hot-path handlers for edit, save, batch actions, search, and quick capture.
- `editor_controller.dart`
  - Thin bridge between external callers and editor state/listenables.
- `actions/`
  - `editor_actions.dart`: command palette registry and action metadata.
  - `editor_shortcuts.dart`: keyboard map (`Ctrl/Cmd+K/S/F/J`, undo/redo, row ops).
- `widgets/`
  - `editor_app_bar.dart`: premium topbar/toolbar and status chips.
  - `grid_host.dart`: virtualized table shell, cell visuals, selection/focus rendering.
  - `mobile_editor_widgets.dart`: mobile quick actions, sheets, compact controls.
  - `save_status_chip.dart`: save/sync chips with animated state transitions.
- `attachments/`
  - Attachment flow (photo/audio/GPS metadata), list/detail panel, and preview.
- `dialogs/`
  - Density, export/import, confirm flows, shortcuts help.

## Supporting UI Infrastructure
- `lib/ui/app_motion.dart`
  - Shared motion tokens and transition helpers (`fadeSlide`, `fadeScale`, modal transition).
- `lib/ui/app_haptics.dart`
  - Cross-platform haptic facade for mobile confirmation feedback.
- `lib/widgets/command_palette.dart`
  - Global command launcher with search, keyboard navigation, and modal motion.

## Data and State Flow
1. User interaction enters through widget callbacks (grid, toolbar, shortcuts, command palette).
2. Callback routes to `editor_state.dart` method.
3. State mutation updates in-memory rows/cells/meta + dirty/history state.
4. UI refresh happens through controlled `setState` and local listenables (`_gridVersion`, save/sync snapshots).
5. Persistence and sync go through services (`SheetStore`, `AttachmentStore`, offline queue services).

## Performance Boundaries
- Grid paint boundary and scoped rebuilds are mandatory in edit loops.
- Selection/search overlays must avoid whole-screen recomposition.
- Batch actions should mutate only targeted rows/cells and clear only affected drafts.
- Motion must stay micro (short duration, small offset) and never block typing.

## Offline and Sync Boundaries
- Editing is local-first and must never hard-block on network.
- Sync state is represented by chips (`Offline / Pending sync`, `Syncing`, `Synced`, `Failed`).
- Queue retry/cleanup logic stays in services; UI only drives intent and status.

## How To Add Features Safely
1. Add/adjust state method in `editor_state.dart`.
2. Expose trigger in one or more channels:
- toolbar action
- command palette action
- keyboard shortcut
- mobile quick actions
3. Reuse shared UI primitives (`AppButton`, `AppModal`, `AppMotion`, `AppHaptics`).
4. Add/adjust smoke steps in `docs/release_checklist.md`.
5. Run validation gates before push.

## Validation Gates
- `dart format --set-exit-if-changed .`
- `flutter analyze --no-fatal-warnings --no-fatal-infos`
- `flutter test`
- `flutter build web --release --base-href "/bitacora_web/"`
- `flutter build apk --release`