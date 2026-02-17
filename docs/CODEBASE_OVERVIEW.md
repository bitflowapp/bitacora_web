# CODEBASE OVERVIEW

## Que es Bit Flow
Bit Flow es una app Flutter orientada a operaciones de campo: edicion de planillas tipo grilla, captura de evidencia (foto/audio/GPS), trabajo offline-first y exportaciones (XLSX/ZIP/HTML), con capacidades opcionales de sync remoto. El entrypoint operativo esta en `lib/main.dart`, que inicializa storage local, capa de sync y rutas de app (`/`, `/app`, `/perf`, `/privacy`, `/terms`).

## Stack real detectado
- Runtime/UI: Flutter + Dart (`pubspec.yaml`, `lib/main.dart`, `lib/features/editor/editor_screen.dart`).
- Navegacion: `go_router` (`lib/main.dart`).
- Persistencia local principal: `shared_preferences` para modelos de hoja (`lib/services/sheet_store_io.dart`, `lib/services/sheet_store_web.dart`).
- Persistencia binaria adjuntos:
  - Web: Hive + IndexedDB + Cache API + fallback RAM (`lib/services/photo_storage_service_web.dart`, `lib/services/web_blob_store_web.dart`).
  - IO (desktop/mobile): filesystem via `path_provider` (`lib/services/photo_storage_service_io.dart`).
- Cola y sync:
  - Outbox en Hive (`lib/core/sync/outbox_store.dart`).
  - Coordinador de reintentos con backoff (`lib/core/sync/sync_coordinator.dart`).
  - Cola offline por hoja en IndexedDB (web) o archivo atomico (io) (`lib/services/offline_queue_store_web.dart`, `lib/services/offline_queue_store_io.dart`).
- Cloud opcional: Firestore (`lib/services/firestore_sheet_store.dart`) y cliente HTTP placeholder (`lib/services/cloud_store.dart`).
- PWA shell: `web/index.html` + `web/manifest.json` + logica de instalacion y boot fallback.

## Mapa del repo
- `lib/`: codigo de aplicacion Flutter.
  - `lib/main.dart`: bootstrap, init de storage/sync/firebase, router.
  - `lib/features/editor/`: editor principal (estado, acciones, adjuntos, widgets).
  - `lib/services/`: storage, sync, export, audio/foto/gps, diagnosticos.
  - `lib/core/`: errores, snapshot atomico, outbox/sync.
  - `lib/screens/`: landing, sheets, legal, diagnostics, etc.
- `web/`: shell web fuente (HTML, manifest, iconos, config).
- `assets/`: config y recursos embebidos (sfx, branding, etc).
- `docs/`: documentacion funcional/tecnica y landing estatica (`docs/bitflow/*`).
- `test/`: cobertura automatizada (editor, storage, export, regresiones).
- `scripts/`: utilidades de release/qa.
- `run.ps1` / `release.ps1` / `verify.ps1`: flujo operativo local y validaciones.

## Flujos criticos

### a) Grilla y edicion
- Pantalla principal: `EditorScreen` en `lib/features/editor/editor_screen.dart`.
- Estado y reglas de edicion: `lib/features/editor/editor_state.dart` (archivo `part` grande, ~19.5k lineas).
- Render de grilla/celdas: `lib/features/editor/widgets/grid_host.dart`.
- Control de acciones/atajos: `lib/features/editor/actions/editor_actions.dart` y `lib/features/editor/actions/editor_shortcuts.dart`.
- Persistencia del modelo de hoja: `SheetStore` (`lib/services/sheet_store_*.dart`) con clave `bitflow:sheet:<id>` y compatibilidad legacy `sheet:<id>`.

### b) Adjuntos (guardar local y subir/sync)
- Orquestacion de flujo de adjunto: `AttachmentPipeline` (`lib/services/attachment_pipeline.dart`) con pasos `capability -> pick -> normalize -> persist -> bind -> preview`.
- Integracion en editor: `lib/features/editor/attachments/attachments_controller.dart`.
- Persistencia local de referencia y estado de upload: `AttachmentStore` (`lib/services/attachment_store.dart`) con metadata Hive `attachment_upload_meta_v1`.
- Binarios:
  - Web: `WebBlobStore` (`lib/services/web_blob_store_web.dart`) usa IndexedDB/Cache API y fallback RAM.
  - IO: `PhotoStorageServiceImpl` (`lib/services/photo_storage_service_io.dart`) guarda en `bitflow_photos` bajo documentos de app.
- Encolado de upload/sync:
  - `ensureQueuedAttachmentUpload(...)` en `OutboxStore`.
  - `SyncCoordinator` ejecuta `upload_attachment` y `sync_dirty_attachments`.

### c) Estado de sync (pendiente/sincronizado/reintentos)
- Outbox global: `lib/core/sync/outbox_store.dart` (`bitflow_outbox_v1`).
- Pump/reintentos: `lib/core/sync/sync_coordinator.dart` (tick periodico, max ops por ciclo, backoff exponencial y tratamiento transient vs no transient).
- Estado de UI: `OfflineSyncSnapshot` + chips en `lib/features/editor/widgets/save_status_chip.dart`.
- Cola offline por hoja (quick capture y cambios diferidos): `lib/services/offline_queue_store_*.dart` + manejo en `lib/features/editor/editor_state.dart` (`_tickQuickCaptureSync`, `_offlineRetryBackoff`, `_openOfflineQueueDialog`).

### d) PWA y service worker: fuente vs build
- Fuente web:
  - `web/index.html` implementa boot guard, fallback visual, FAB de instalacion, detection de capabilities y cache-busting por build id.
  - `web/manifest.json` define install metadata/iconos.
- En fuente NO estan versionados `web/flutter_bootstrap.js` ni `web/flutter_service_worker.js`.
- Esos artefactos se generan en `flutter build web --release` y luego `release.ps1` empaqueta a `dist_release/web`.
- `web/index.html` incluye logica para desregistrar service workers/caches al detectar cambio de build (`bitflow_last_build`).

## Strings / UI copy
- Strings centralizados (parcial):
  - `lib/ui/app_strings.dart`
  - `lib/core/i18n/app_strings.dart`
- Tambien existe copy hardcodeado en widgets/pantallas (ej. `lib/features/editor/editor_state.dart`, `lib/screens/*`).
- Estado i18n: no se observa pipeline ARB (`l10n.yaml`, `intl_*.arb`) ni delegates de localizacion configurados en `MaterialApp`; hay soporte de dependencias (`flutter_localizations`, `intl`) pero la estrategia es mayormente strings constantes + hardcoded.

## Known issues / riesgos observados en codigo
- Riesgo de mantenibilidad por modulo monolitico:
  - `lib/features/editor/editor_state.dart` tiene ~19.5k lineas.
- I18n parcial y dualidad de fuentes de texto:
  - coexisten `lib/ui/app_strings.dart` y `lib/core/i18n/app_strings.dart` + strings inline.
- Sync remoto ambiguo en runtime:
  - `lib/services/cloud_store.dart` usa `_baseUrl = 'https://tu-backend.com/api'` (placeholder) pero tambien usa `FirestoreSheetStore`.
- Historial de problemas de encoding:
  - `verify.ps1` incluye guardrails explicitos anti-mojibake y anti-labels en ingles.
- Complejidad por compatibilidad legacy:
  - `SheetStore` mezcla formato nuevo (`bitflow:sheet:*`) y legacy (`sheet:*`).

## Desconocido (y como confirmarlo)
- Endpoint/productivo real de sync remoto: desconocido.
  - Confirmar con: `rg -n "tu-backend.com|FirestoreSheetStore|saveSheet\(" lib/services`
- Estrategia final de autenticacion en produccion (AuthGate + Google + Firebase): desconocido.
  - Confirmar con: `rg -n "AuthGate|google_sign_in|firebase_auth|FirebaseAuth" lib`
- Destino final de despliegue web (dist_release vs otro pipeline CI): desconocido.
  - Confirmar con: `rg -n "dist_release|build web|Compress-Archive|deploy" release.ps1 scripts/*.ps1`

## Como correr local (dev)
- Flutter dev (web):
  - `flutter pub get`
  - `flutter run -d chrome`
- Servir build ya generado (sin recompilar):
  - `powershell -ExecutionPolicy Bypass -File .\run.ps1`

## Como build web
- Build release directo:
  - `flutter pub get`
  - `flutter build web --release`
- Pipeline local de entrega:
  - `powershell -ExecutionPolicy Bypass -File .\release.ps1`
- Verificacion rapida:
  - `powershell -ExecutionPolicy Bypass -File .\verify.ps1 -Fast`

## Checklist QA manual rapida
1. Boot y persistencia:
- Abrir `/app`, crear/editar hoja, recargar y verificar que persiste.

2. Modo avion / offline:
- Desconectar red.
- Editar celdas y adjuntar evidencia.
- Verificar chip de sync en estado offline/pending.

3. Adjuntos:
- Foto: agregar, ver miniatura/badge, recargar.
- Audio: grabar/reproducir, recargar.
- GPS: capturar y validar badge/texto.

4. Reconexion:
- Volver online.
- Abrir cola offline y/o esperar tick automatico.
- Confirmar transicion de estado a syncing/synced.

5. Export:
- Exportar XLSX y ZIP/backup ZIP.
- Validar archivos esperados y apertura en cliente destino.

6. Diagnosticos:
- Abrir pantalla de diagnosticos y exportar informe.
- Validar counters de errores y traces recientes si hubo fallos.
