# Workspace Migration

Date: 2026-02-13

Original workspace `D:\bit flow hoy actualizado 12.2` is not writable for the current user in critical paths.
Symptoms observed:
- `OS Error: Acceso denegado` when Flutter tries to create `.dart_tool`
- inability to create/delete write probes reliably at repo root

To keep development non-interactive and unblock build/test/commit flows, work was migrated to a writable clone:
`C:\Users\marco\dev\bitflow_p18`
