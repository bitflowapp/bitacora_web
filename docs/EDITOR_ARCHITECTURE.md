# Editor Architecture

Scope: `lib/features/editor/*`

## Overview
- `editor_screen.dart` wires the UI and delegates logic.
- `editor_state.dart` holds core editor state and data operations.
- `actions/` contains keyboard shortcuts and command palette actions.
- `dialogs/` centralizes all modals and confirmation flows.
- `attachments/` contains photo/audio flows and attachment UI.
- `lib/screens/editor_screen.dart` is the public wrapper.

## File Map
- `editor_screen.dart`: app shell + layout + parts list.
- `editor_state.dart`: grid state, selection, persistence, export/import.
- `editor_controller.dart`: thin controller with UI callbacks.
- `attachments/attachments_controller.dart`: photo/audio flows + sheet UI.
- `attachments/attachment_tile.dart`: tile UI for one attachment.
- `attachments/attachment_preview_modal.dart`: preview modal content.
- `attachments/attachments_view.dart`: small UI helpers (header).
- `attachments/attachments_types.dart`: local enums/DTOs.
- `attachments/attachments_utils.dart`: pure helpers.
- `dialogs/editor_dialogs.dart`: density, GPS mode, shortcuts.
- `dialogs/export_dialogs.dart`: export menu (XLSX/ZIP/HTML).
- `dialogs/confirm_dialogs.dart`: confirm delete for evidence.
- `actions/editor_actions.dart`: command palette actions.
- `actions/editor_shortcuts.dart`: desktop shortcuts handler.

## Data Flow (High Level)
- User action -> `EditorScreen` -> handler in `editor_state.dart`.
- UI feedback -> `AppToast` / `AppModal`.
- Storage -> `SheetStore` / `AttachmentStore` services.
- Export -> build payload -> save bytes -> optional share.

## State Boundaries
- Grid state lives in `editor_state.dart`.
- Save status is exposed via `EditorController` (ValueListenable).
- Attachment UI reads state from `editor_state.dart` only.
- Dialogs never touch storage directly.

## Adding a New Action
1. Add a new method in `editor_state.dart` if needed.
2. Register a command in `actions/editor_actions.dart`.
3. Map a shortcut in `actions/editor_shortcuts.dart` if relevant.
4. Use `AppToast` for user feedback on success/failure.

## Adding a New Dialog
1. Create a method in `dialogs/` (new file or existing).
2. Use `showAppModal` and `AppButton` variants.
3. Keep microcopy short and clear.
4. Return a value via `Navigator.pop(result)`.

## Adding a New Attachment Type
1. Extend the storage/service layer (no new deps).
2. Create a UI tile in `attachments/` with type icon.
3. Add preview logic in `attachments_controller.dart`.
4. Update export/import to include new assets.
5. Add fallbacks for corrupt or missing data.

## Error Handling Rules
- No crashes on missing files.
- If preview fails, show a toast and a safe placeholder.
- Confirm destructive actions before deleting data.
- Avoid leaking exceptions to the user.

## Performance Rules
- Avoid global `setState` when a local notifier is enough.
- Keep AppBar rebuilds limited.
- Use `AnimatedSwitcher` for small transitions only.

## Design / UX Rules
- No inline dialogs inside `editor_state.dart` unless trivial.
- Prefer AppModal + AppButton for consistency.
- Tooltips and semantics on icon-only buttons.
- Keep empty states helpful and short.

## QA Checklist (when Flutter is available)
- `dart format .`
- `flutter analyze`
- `flutter test`
- `flutter run -d chrome`
- Edit cells + save
- Attach photo, preview, delete
- Export ZIP + HTML report
- Import ZIP and verify attachments
- Check console: 0 red errors
