# QA Report

## QA Run: 2026-02-07 03:54:34
Branch: codex/qa-release-nextleague-v1  
Commit: d4a3617

### Toolchain detect
- `C:\tools\flutter\bin\flutter.bat --version`: OK (Flutter 3.38.9, Dart 3.10.8)
- `C:\tools\flutter\bin\dart.bat --version`: OK (Dart 3.10.8)
- `flutter doctor -v` (ejecutado desde `C:\` con PATH temporal): OK
  - Warnings: Android SDK ausente, Visual Studio ausente (no bloquea Flutter Web)
- `flutter config --enable-web`: OK

### Resultado
- Toolchain OK para Web. Se ajusto PATH del usuario para incluir `C:\tools\flutter\bin`.
- Nota: si `flutter` no se reconoce en una consola nueva, reiniciar PowerShell para leer el PATH actualizado.

---

## QA Run: 2026-02-06 18:45:04
Branch: codex/qa-release-polish-v1  
Commit: 62171a9

### Toolchain detect
- `flutter --version`: FAIL
  - `flutter : El término 'flutter' no se reconoce como nombre de un cmdlet, función, archivo de script o programa ejecutable.`
- `dart --version`: FAIL
  - `dart : El término 'dart' no se reconoce como nombre de un cmdlet, función, archivo de script o programa ejecutable.`
- `flutter doctor -v`: FAIL
  - `flutter : El término 'flutter' no se reconoce como nombre de un cmdlet, función, archivo de script o programa ejecutable.`

### Resultado
- QA BLOQUEADA: Flutter/Dart no instalado en este entorno. No se puede continuar con fases 2–5.

### Pasos exactos para desbloquear (Windows)
1) Descargar Flutter SDK (stable) y descomprimir en `E:\tools\flutter`
2) Agregar `E:\tools\flutter\bin` al `PATH` del usuario
3) Reabrir PowerShell y ejecutar:
   - `flutter --version`
   - `flutter doctor -v`
   - `flutter config --enable-web`
4) Reintentar esta fase desde FASE 1.

---

## QA Run: 2026-02-06 18:19:54
Branch: codex/editor-nextleague-v3  
Commit: d280128 (audio modal visual polish)

### Resultado
- QA NO EJECUTADA: Flutter/Dart no instalado en este entorno.
- Cambios relevantes: ajuste visual de audio modal para consistencia premium.
- Pendiente: ejecutar analyze/test/run/build cuando Flutter este disponible.

---

## QA Run: 2026-02-06 18:18:50
Branch: codex/editor-nextleague-v3  
Commit: 96e431d (editor v4 polish)

### Resultado
- QA NO EJECUTADA: Flutter/Dart no instalado en este entorno.
- Cambios relevantes: adjuntos premium, dialogs AppModal, shortcuts hardening, PS1 UTF-8.
- Pendiente: ejecutar analyze/test/run/build cuando Flutter este disponible.

---

## QA Run: 2026-02-06 15:43:49
Branch: codex/editor-nextleague-v3  
Commit: ef3a3f6 (refactor editor modular v3)

### Resultado
- QA NO EJECUTADA: Flutter/Dart no instalado en este entorno.
- Cambios relevantes: Editor modularizado (attachments/dialogs/actions) + controller con callbacks de adjuntos.
- Pendiente: ejecutar analyze/test/run/build cuando Flutter este disponible.

---

## QA Run: 2026-02-06 04:47:14
Branch: codex/editor-refactor-nextleague  
Commit: e5a3d30b09934987ff969d32c2dc3862459318f1

### Resultado
- QA NO EJECUTADA: Flutter/Dart no instalado en este entorno.
- Cambios relevantes: fix de `part of` en widgets de editor para compilar.
- Pendiente: ejecutar analyze/test/run/build cuando Flutter este disponible.

---

## QA Run: 2026-02-06 04:45:23
Branch: codex/editor-refactor-nextleague  
Commit: adcf10de7d14ec6fc7f3ab3e5a7f2895cc7532be

### Resultado
- QA NO EJECUTADA: Flutter/Dart no instalado en este entorno.
- Cambios relevantes: refactor editor a `part` files + SaveStatusChip + hover sutil en header.
- Pendiente: ejecutar analyze/test/run/build cuando Flutter este disponible.

---

## QA Run: 2026-02-06 03:59:13
Branch: productize/qa-polish-attachments-v2  
Commit: 2b3544fdb9ead927c4764d0a9053eda2790f1253

### Toolchain detect
- `Get-Command flutter`: NOT FOUND
- `Get-Command dart`: NOT FOUND

### Resultado
- QA BLOQUEADA: Flutter/Dart no instalado en este entorno.
- Se preparo `qa_run.ps1` para ejecutar QA + release + smoke test cuando Flutter este disponible.

---

## QA Run: 2026-02-06 00:53:25
Branch: productize/qa-polish-attachments-v2  
Commit base: 06fe2d49c1a9f012af315d6b3104f2e3f7dd8507

### Toolchain detect
- `Get-Command flutter`: NOT FOUND
- `Get-Command dart`: NOT FOUND
- `where.exe flutter`: `C:\bitflow1122\flutter.js` (archivo local, no CLI)

### Archivos tocados (git status --porcelain)
```
?? _backups/
```

### (1) Preparacion + Baseline
- flutter --version: FAIL (Flutter no instalado en el entorno)
- flutter doctor -v: FAIL (Flutter no instalado)
- flutter pub get: SKIPPED (bloqueado por Flutter missing)
- dart format .: SKIPPED (bloqueado por Flutter missing)
- flutter analyze: SKIPPED (bloqueado por Flutter missing)
- flutter test: SKIPPED (bloqueado por Flutter missing)

### (2) Smoke tests reales
#### DEV
- flutter run -d chrome: SKIPPED (Flutter no instalado)
- Validacion rutas / y /app: NO EJECUTADO
- Onboarding 1ra vez: NO EJECUTADO

#### RELEASE
- flutter build web --release: SKIPPED (Flutter no instalado)
- Servir build/web con http: NO EJECUTADO
- Validacion / y /app en release: NO EJECUTADO

### (3) Verificacion de CONFIG
- web/config.json: OK (archivo presente en repo)
- assets/config.json: OK (archivo presente en repo)
- build/web/config.json: NO (build no generado en este entorno)
- Fallback configurado por codigo: OK (AppConfig carga web/config.json -> assets/config.json -> defaults)

### (4) Flujos core vendibles
No ejecutados (Flutter no disponible en el entorno).

### (5) Release ZIP
No generado (Flutter no disponible en el entorno).

## Bloqueos
- Flutter/Dart no estan instalados en este entorno. Sin esto no se puede:
  - Ejecutar analyze/test
  - Correr app en Chrome
  - Generar build release y ZIP

## Acciones tomadas en este entorno
- Se agrego verificacion de toolchain en `run.ps1` y `release.ps1` con mensaje de instalacion portable.

## Pasos exactos para desbloquear (Windows, instalacion portable)
1) Descargar Flutter SDK (canal stable) y descomprimir en: `E:\tools\flutter`
2) Agregar `E:\tools\flutter\bin` al `PATH` del usuario
3) Abrir una nueva PowerShell y ejecutar:
   - `flutter --version`
   - `flutter doctor -v`
4) Volver a correr esta fase con los comandos de baseline.

---
## QA Run anterior (archivado): 2026-02-05 23:55:04
Se conserva este log para trazabilidad. Esta corrida tambien fallo por falta de Flutter en el entorno.

## QA Run: 2026-02-07 03:55:34
Branch: codex/qa-release-nextleague-v1
Commit: d4a3617536ee50fb0e49df7796e40327359012d5

- Toolchain: FAIL (Flutter/Dart no instalado)
- Recomendado: instalar en E:\tools\flutter y agregar E:\tools\flutter\bin al PATH

## QA Run: 2026-02-07 03:56:01
Branch: codex/qa-release-nextleague-v1
Commit: d4a3617536ee50fb0e49df7796e40327359012d5

- flutter --version: PASS
- flutter doctor -v: PASS
- flutter pub get: PASS
- dart format .: FAIL
- flutter analyze: FAIL
- flutter test: FAIL
- flutter build web --release: FAIL
- release.ps1 -Clean: FAIL

- Release ZIP: NOT FOUND
- Smoke test HTTP: SKIPPED


## QA Run: 2026-02-07 03:57:37
Branch: codex/qa-release-nextleague-v1
Commit: d4a3617536ee50fb0e49df7796e40327359012d5

- flutter --version: PASS
- flutter doctor -v: PASS
- flutter pub get: PASS
- dart format .: PASS
- flutter analyze: FAIL
- flutter test: FAIL
- flutter build web --release: FAIL
- release.ps1 -Clean: FAIL

- Release ZIP: NOT FOUND
- Smoke test HTTP: SKIPPED

