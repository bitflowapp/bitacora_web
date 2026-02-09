# PRODUCTIZE_NOTES
Fecha: 2026-02-05
Branch: productize/windows-release

## Stack detectado
- Flutter Web (sin servidor) con entrypoint `lib/main.dart`.
- UI principal: `lib/start_page.dart` (home/listado de planillas) y editor: `lib/screens/editor_screen.dart`.
- Persistencia:
  - Planillas y metadata base en `localStorage` via `lib/services/sheet_store_web.dart`.
  - Preferencias y organizacion (carpetas, notas, papelera) en `SharedPreferences` (web = localStorage).
  - Adjuntos (fotos/audio) en IndexedDB via Hive (`lib/services/photo_storage_service_web.dart`) y/o `lib/services/web_blob_store_web.dart`.
  - Fallback RAM cuando falla IndexedDB.

## Inventario rapido
Pantallas principales:
- Home / StartPage (listado y gestion de planillas, carpetas, papelera, export XLSX): `lib/start_page.dart`.
- Editor de planilla (grilla, fotos, audio, GPS, export ZIP + XLSX): `lib/screens/editor_screen.dart`.
- Diagnosticos: `lib/screens/diagnostics_screen.dart`.
- AuthGate (guest) y login legacy: `lib/screens/auth_gate.dart`, `lib/screens/login_screen.dart`.
- Otras (legacy/demo): `lib/screens/sheets_screen.dart`, `lib/screens/xlsx_demo_screen.dart`.

Features visibles hoy:
- Planillas tipo Excel (grid editable) + carpetas/papelera.
- Adjuntos por celda (fotos y audio), GPS por celda.
- Export XLSX, ZIP con adjuntos y Backup ZIP del proyecto (con restore).
- Reporte HTML imprimible (evidencias embebidas en thumbnails).
- Importar Backup ZIP desde Home > Opciones.
- Landing comercial con precios y CTA (ruta `/`).
- App en `/app` con onboarding inicial.
- Modo offline/guest con SharedPreferences.

## Dependencias y riesgos
- `firebase_core` y `cloud_firestore` estan en deps y `lib/main.dart` inicializa Firebase: en offline puro provoca modo "demo" y agrega friccion (pantalla de reintento/entrar igual).
- Persistencia base en `localStorage` (cuota baja). Para adjuntos se usa IndexedDB; riesgo de cuota o fallback a RAM (perdida si se cierra).
- Doble StartPage (`lib/start_page.dart` y `lib/screens/start_page.dart`) + muchos `.bak` en `lib/` aumentan confusion y riesgo de editar el archivo equivocado.
- Dependencias grandes/no-web-friendly (record, permission_handler, geolocator) pueden fallar en Web si no se controlan permisos.
- Integracion a Engine remoto (FastAPI) configurable; para producto offline debe quedar opcional o desactivado por defecto.

## Bugs y quick wins (prioridad)
P0
- Arranque offline bloqueado por Firebase: si falla init, requiere "Entrar igual" en `lib/main.dart`. Deberia entrar directo sin friccion o hacer init lazy.
- Fallback RAM para adjuntos puede perder datos al refrescar si falla IndexedDB. Mejorar deteccion y warning en `lib/services/attachment_store.dart` y `lib/services/web_blob_store_web.dart`.

P1
- Unificar y documentar punto de entrada UI: usar solo `lib/start_page.dart` y mover legacy a `/_legacy/`.
- Consolidar config offline: quitar dependencia de engine por defecto o dejarla por `assets/config.json`.
- Documentar esquema y migracion de `cellMeta` en `lib/screens/editor_screen.dart`.

P2
- Exceso de archivos `.bak` en `lib/` y zips antiguos en raiz: mover a `/_legacy/` para reducir ruido.

## Fase 3/4 completado (parcial)
- Routing: `/` (landing) y `/app` (aplicacion) en `lib/main.dart`.
- Landing: `lib/screens/landing_screen.dart` con beneficios, pricing, CTA.
- Onboarding inicial: wizard 3 pasos en `lib/start_page.dart`.
- Configuracion: `assets/config.json` + `web/config.json` y `.env.example`.
- Scripts Windows: `run.ps1`, `run.bat`, `release.ps1`.
- Run local: `run.ps1` sirve `dist_release/web` o `build/web`.
- Release: `release.ps1` crea `dist_release/` y ZIP.

## Legacy / tmp (2026-02-06)
- Movidos a `/_legacy/tmp_20260206/`: `tmp.txt`, `tmp_update_photo.py`, `--exclude=node_modules`.

## Backups
- 2026-02-06 03:36: `_backups/bitacora_web_PRE_20260206_0336.zip` (antes de refactor UI premium).
- 2026-02-06 04:18: `_backups/bitacora_web_PRE_EDITOR_REFACTOR_20260206_0418.zip` (antes del refactor del editor).

## Decisiones UX (premium)
- Design system en `lib/ui/` (tokens, theme, botones, cards, modales, toasts).
- Landing y legal pages unificadas con AppShell y componentes.
- Top bar en Home con acciones directas (Nuevo, Exportar, Importar, Ayuda).


[2026-02-06] Refactor editor v3: se usaron archivos temporales de extraccion en _legacy/_tmp_photo_extract.txt y _legacy/_tmp_audio_extract.txt para separar adjuntos.

[2026-02-06] _legacy/_tmp_photo_extract.txt y _legacy/_tmp_audio_extract.txt son trazas de extraccion. No se usan en runtime.
