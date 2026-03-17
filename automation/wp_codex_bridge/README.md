# WhatsApp Codex Bridge

This bridge listens to allowlisted WhatsApp inbound messages that start with one
of these prefixes:

- `codex:`
- `bitflow:`
- `repo:`

Flow:

1. OpenClaw receives the inbound WhatsApp message.
2. The workspace plugin in `.openclaw/extensions/wp-codex-bridge` forwards the
   event into this bridge.
3. The bridge validates allowlist, prefix, and direct-chat scope.
4. The bridge runs `codex exec` in read-only mode against this repo.
5. The final response is formatted, chunked, and sent back through the existing
   WhatsApp runtime.

Files:

- `config.mjs`: repo path, allowlist, prefixes, timeout, chunk size
- `whatsapp-adapter.mjs`: inbound parsing and outbound sending
- `prompt-builder.mjs`: WhatsApp message -> Codex prompt
- `codex-runner.mjs`: local Codex CLI execution
- `output-formatter.mjs`: normalize, trim, and truncate long replies
- `smoke-test.mjs`: fully local reproducible flow with a fake Codex CLI

Smoke test:

```powershell
node automation/wp_codex_bridge/smoke-test.mjs
```
