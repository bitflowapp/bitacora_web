# DEBUG PLAYBOOK

## Objetivo
Playbook para diagnosticar fallos de arranque, storage, adjuntos, sync offline y build web en Bit Flow sin cambiar logica de producto.

## 1) Activar logs utiles

### Modo debug Flutter web
- Ejecutar:
  - `flutter pub get`
  - `flutter run -d chrome --dart-define=SHOW_BUILD_BADGE=true --dart-define=BITFLOW_DEBUG_EDITOR_PERF=true --dart-define=BITFLOW_DEBUG_GRID_REBUILDS=true`

Flags detectados en codigo:
- `SHOW_BUILD_BADGE` (`lib/main.dart`): fuerza badge de build.
- `BITFLOW_DEBUG_EDITOR_PERF` (`lib/features/editor/editor_state.dart`): activa instrumentacion de perf del editor.
- `BITFLOW_DEBUG_GRID_REBUILDS` (`lib/features/editor/editor_state.dart`): contador/log de rebuilds.

### Rutas y query params de diagnostico
- Editor con smoke test automatico: `/app?smoke=1`
- Editor con modo perf harness: `/app?perf=1`
- Ruta dedicada perf: `/perf`
- Override de engine remoto: `/?engine=https://host:puerto`

### Diagnosticos dentro de la app
- Pantalla: `lib/screens/diagnostics_screen.dart`.
- Fuente de eventos:
  - `AppErrorReporter` (`lib/services/app_error_reporter.dart`)
  - `DiagnosticsLog` (`lib/services/diagnostics_log.dart`)
- Exporta informe TXT/JSON con errores y attachment traces.

## 2) Comandos de captura de estado

### Salud toolchain
- `flutter doctor -v`
- `dart --version`
- `flutter --version`

### Estado del proyecto
- `flutter pub get`
- `flutter analyze --no-pub lib`
- `powershell -ExecutionPolicy Bypass -File .\verify.ps1 -Fast`

### Build/repro web release
- `flutter build web --release`
- `powershell -ExecutionPolicy Bypass -File .\release.ps1`
- `powershell -ExecutionPolicy Bypass -File .\run.ps1`

### Inspeccion rapida de zonas sensibles (grep)
- Sync y cola:
  - `rg -n "OutboxStore|SyncCoordinator|offline_queue|_tickQuickCaptureSync" lib`
- Adjuntos y storage:
  - `rg -n "AttachmentPipeline|AttachmentStore|WebBlobStore|photo_store_v2|attachment_upload_meta_v1" lib`
- PWA/service worker:
  - `rg -n "serviceWorker|flutter_bootstrap|bitflow_last_build|beforeinstallprompt" web/index.html lib/services/web_capabilities_web.dart`
- Riesgos de encoding/UI copy:
  - `rg -n "AppStrings|mojibake|Acciones rapidas|Guardar|Sincroniz" lib verify.ps1`

### Verificar artefactos de build web
- `Get-ChildItem build/web`
- `Get-ChildItem dist_release/web`
- `Test-Path web/flutter_service_worker.js`
- `Test-Path web/flutter_bootstrap.js`

Nota: en este repo, `web/flutter_service_worker.js` y `web/flutter_bootstrap.js` no estan en fuente; aparecen en artefactos generados de `flutter build web`.

## 3) Donde mirar errores en Flutter web

### Browser DevTools
1. Console:
- Excepciones Dart/JS.
- Logs `debugPrint` de editor/sync/engine.

2. Network:
- Fallos de `version.json`, `flutter_bootstrap.js`, assets, y endpoints engine/cloud.
- CORS/timeouts de engine (ver mensajes en `editor_state.dart`).

3. Application:
- IndexedDB:
  - `bf_blob_store_v1` (adjuntos web)
  - `bitflow_offline_queue_v1` (cola offline por hoja)
- Cache Storage:
  - `bf_blob_store_cache_v1`
- Local Storage:
  - `bitflow_last_build` (control de invalidacion de caches en `web/index.html`)

### UI de fallback de arranque
- `web/index.html` muestra `#boot-fallback` si el arranque se demora o falla la carga de bootstrap.
- Si aparece recurrentemente:
  - revisar consola + network
  - validar build id/version.json
  - limpiar SW/caches del sitio

### Diagnostico de storage
- Probar escritura con `StorageDiagnostics.check()` (`lib/services/storage_diagnostics.dart`).
- Si falla storage, editor puede caer a fallback en memoria para ciertos componentes.

## 4) Escenarios comunes y triage rapido

### A) "No sincroniza" / cola crece
1. Ver estado de red (`NetworkStatusService`).
2. Revisar estado del chip sync en editor.
3. Abrir cola offline desde editor y leer ultimo error.
4. Confirmar outbox en Hive (`bitflow_outbox_v1`) y logs `[sync]`.
5. Verificar si backend esta configurado (ojo placeholder en `cloud_store.dart`).

### B) "Adjunto no persiste"
1. Revisar `DiagnosticsLog` de attachment pipeline (paso que falla).
2. Verificar capacidades web (secure context, indexeddb, media recorder).
3. Confirmar fallback usado (`indexeddb`, `cache`, `ram`) en metadata de adjunto.
4. Si queda en `ram`, advertir que persistencia es de sesion.

### C) "Build web arranca pero pantalla vacia"
1. Abrir DevTools Console y buscar excepciones de bootstrap.
2. Revisar Network para `flutter_bootstrap.js` y assets faltantes.
3. Verificar que `build/web` fue generado completo.
4. Servir con `run.ps1` y reintentar.

## 5) Evidencia minima para bug report
Adjuntar siempre:
- Comando usado + salida relevante (`flutter doctor -v`, `verify -Fast`, `analyze`).
- URL exacta (incluyendo query params como `?smoke=1` o `?engine=...`).
- Captura de Console + Network.
- Informe exportado desde `DiagnosticsScreen` (TXT o JSON).
- Plataforma/navegador y modo (desktop/mobile, webview/in-app browser, HTTPS/no HTTPS).
