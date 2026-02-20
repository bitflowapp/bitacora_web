# OpenClaw + WhatsApp Setup (Windows, Jariel CODEX_HOME)

## Objetivo
Dejar OpenClaw gateway + WhatsApp listos en Windows usando por defecto la cuenta Codex de Jariel.

## Variables usadas
- `CODEX_HOME=C:\Users\marco\.codex_plus_jariel`
- `OPENAI_MODEL=openai-codex/gpt-5.3-codex`

Nota de modelo:
- Se probó `openai-codex/gpt-5.3-codex-high`.
- OpenClaw lo marca como `missing` en `openclaw models list`.
- Se dejó el mejor válido cercano detectado en catálogo: `openai-codex/gpt-5.3-codex`.

## Arranque por defecto (login)
Se usa la tarea ya existente:
- `OpenClaw Gateway Jariel`
- Acción de tarea: `C:\Users\marco\openclaw_gateway_jariel.cmd`

El `.cmd` fue actualizado para delegar al script robusto:
- `C:\Users\marco\openclaw_jariel_start.ps1`

## Script de arranque robusto
Ruta:
- `C:\Users\marco\openclaw_jariel_start.ps1`

Qué hace:
1. Setea en sesión `CODEX_HOME` y `OPENAI_MODEL`.
2. Revisa si `18789` ya está en uso.
3. Si el gateway ya está sano en `18789`, no duplica procesos.
4. Si el puerto está ocupado por otro proceso, lo detiene para liberar el puerto.
5. Inicia gateway en `18789` con Node + OpenClaw CLI.
6. Escribe logs de arranque/STDOUT/STDERR en el repo (`logs\`).

## Reinicio manual
- Inicio manual robusto:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\marco\openclaw_jariel_start.ps1"
```
- Ejecutar la tarea de login manualmente:
```powershell
schtasks /Run /TN "OpenClaw Gateway Jariel"
```

## Ver logs
En el repo:
- `logs\openclaw_gateway_start_*.log`
- `logs\openclaw_gateway_stdout_*.log`
- `logs\openclaw_gateway_stderr_*.log`
- `logs\openclaw_gateway_latest.log`
- `logs\openclaw_audit_*.log`
- `logs\openclaw_config_*.log`
- `logs\openclaw_verify_*.log`

Checks rápidos:
```powershell
openclaw status
openclaw health --json
Get-NetTCPConnection -LocalPort 18789 -State Listen
```

## WhatsApp
Estado esperado si está vinculado:
- `openclaw status` muestra canal WhatsApp `ON`/`OK`.
- En logs de stdout aparece:
  - `starting provider`
  - `Listening for personal WhatsApp inbound messages.`

Si NO está vinculado (pairing):
```powershell
openclaw channels login --verbose
```
Luego escanear QR en WhatsApp y verificar con `openclaw status`.

## Troubleshooting
- `openclaw gateway --force` en Windows puede fallar por `lsof not found`.
  - Usar el script `openclaw_jariel_start.ps1` (manejo de puerto nativo Windows).
- Puerto 18789 ocupado:
  - El script detecta PID y lo detiene antes de iniciar gateway.
- `API rate limit reached` en WhatsApp (causa real vista en P11):
  - OpenClaw puede estar usando un `auth-profiles.json` viejo en `C:\Users\marco\.openclaw\agents\main\agent\` con otra cuenta distinta al `CODEX_HOME` actual.
  - Verificar identidad activa sin exponer secretos:
```powershell
openclaw logs --plain --limit 200
```
  - Buscar en log:
    - `API rate limit reached`
    - `No API key found for provider "openai-codex"`
  - Reparación usada:
    1. Backup de `auth-profiles.json` y `auth.json` (timestamp).
    2. Sincronizar auth de OpenClaw con `C:\Users\marco\.codex_plus_jariel\auth.json`.
    3. Si el gateway queda en `No API key found`, regenerar perfil con:
```powershell
openclaw models auth paste-token --provider openai-codex --profile-id openai-codex:default --expires-in 240h
```
    4. Reiniciar gateway con `openclaw_jariel_start.ps1`.
- WhatsApp no responde aunque esté vinculado:
  - Relanzar script de arranque y revisar líneas de provider en `openclaw_gateway_stdout_*.log`.
