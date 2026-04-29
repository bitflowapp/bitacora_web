# Bit Flow Android Emulator QA - Phase 3

Fecha: 2026-04-28 22:47:49 -03:00  
Rama: `premium-linkedin-real-app`  
Commit base probado al iniciar la fase: `a9cf26c fix(android): stabilize emulator launch layout`

## Entorno

- Emulador: `BitFlow_QA_API36`
- Device id: `emulator-5554`
- Android: 16 / API 36
- APK de QA instalado: `build\app\outputs\flutter-apk\app-debug.apk`
- APK release validado: `build\app\outputs\flutter-apk\app-release.apk`
- ApplicationId antes: `com.example.bitacora_web`
- ApplicationId final: `com.bitflow.app`
- App label final: `Bit Flow`

## Commits de esta fase

- `da61117 style: refine premium Android app experience`
- `32d8856 chore(android): use commercial Bit Flow application id`

Este reporte y la evidencia se guardan como documentacion de QA de la fase.

## Flujos probados

- Arranque: la app abre en emulador sin pantalla blanca permanente, sin crash y con branding visible.
- Landing y workspace: se valido el modo oscuro premium, cards, CTAs, lista de recientes y jerarquia visual.
- Nueva hoja: se creo `Nuevo relevamiento` desde el workspace y navego al editor.
- Editor/tabla: se abrio una hoja, se reviso app bar, chip de guardado, quick actions y grilla.
- Edicion de celda: se abrio el flujo de texto; Gboard mostro overlay de stylus y el emulador se volvio inestable en una pasada. No hubo crash confirmado de Bit Flow.
- Adjuntos/evidencias: se abrio panel de adjuntos, se pidio permiso de camara, se tomo foto y se adjunto correctamente a la celda.
- GPS: se simulo Neuquen con `adb emu geo fix -68.0591 -38.9516`. Android mostro dialogo de Location Accuracy; Bit Flow no crasheo y mostro feedback de timeout.
- Exportaciones: se probaron PDF, XLSX y ZIP. PDF no crasheo, XLSX abrio share sheet con archivo generado, ZIP quedo expuesto en UI y genero un `.zip` compartible.
- Persistencia: se reabrio la app y el workspace mostro `Nuevo relevamiento` en recientes.
- Rotacion: se probo landscape y vuelta a portrait; no hubo crash ni overflow grave visible.
- Audio: se busco el flujo desde la UI mobile visible; no aparecio como accion directa en quick actions. Queda como cobertura pendiente con una ruta de UI especifica o real device.

## Evidencia generada

Carpeta: `docs\qa\android_emulator\phase3`

Capturas principales:

- `qa_phase3_01_launch.png`
- `qa_phase3_02_home.png`
- `qa_phase3_03_new_sheet.png`
- `qa_phase3_04_editor.png`
- `qa_phase3_05_keyboard_edit.png`
- `qa_phase3_12_attachments_panel.png`
- `qa_phase3_13_permission_dialog_camera.png`
- `qa_phase3_14_attachment_result_final.png`
- `qa_phase3_15_gps_result.png`
- `qa_phase3_17_landscape.png`
- `qa_phase3_18_portrait_back.png`
- `qa_phase3_19_design_home_after.png`
- `qa_phase3_19b_workspace_after.png`
- `qa_phase3_20_design_editor_after.png`
- `qa_phase3_21_design_export_after.png`
- `qa_phase3_11_export_zip_result.png`
- `qa_phase3_16_audio_probe.png`

Logs:

- `qa_phase3_logcat_final.txt`
- `qa_phase3_flutter_analyze_final.txt`
- `qa_phase3_flutter_test_final.txt`
- `qa_phase3_flutter_build_web_final.txt`
- `qa_phase3_flutter_build_apk_release_confirm.txt`

## Bugs encontrados

### Blocker

- Ninguno confirmado.

### Major

- Branding Android no comercial: permission dialogs y launcher usaban `bitacora_web` / `com.example.bitacora_web`. Corregido a `Bit Flow` / `com.bitflow.app`.

### Minor

- El modo inicial seguia abriendo claro y no respetaba la intencion premium dark. Corregido para abrir en dark.
- El modal de exportacion no exponia ZIP aunque existia logica interna de bundle. Corregido agregando opcion ZIP.
- Algunas strings visibles y de reportes tenian mojibake potencial (`Ã`, `Â`). Corregido en strings tocadas durante esta fase.
- Nuevas hojas podian iniciar con nombre generico o vacio. Corregido a `Nuevo relevamiento`.

### Polish

- Botones primarios en dark tenian contraste debil en texto. Corregido a foreground blanco.
- Copy de workspace/editor era demasiado tecnico en varios puntos. Ajustado hacia lenguaje comercial de campo.
- Cards del workspace dark necesitaban mas profundidad y separacion visual. Refinadas con superficie graphite, borde/acento y sombra sobria.

## Fixes aplicados

- Default dark premium en la app.
- Workspace con copy comercial, hero/card dark y recientes mas limpios.
- Botones primarios/destructivos con contraste correcto.
- Quick actions mobile mas claras: `Completar`, `Duplicar`, `Ir a celda`.
- Export dialog con opcion `ZIP`, copy de adjuntos y dispatch hacia `_exportZipBundle`.
- Nombres iniciales de hojas: `Nuevo relevamiento`.
- Correccion de mojibake visible/potencial en strings de editor/export/reportes.
- Android application id y package Kotlin movidos a `com.bitflow.app`.
- Android label cambiado a `Bit Flow`.

## Logs relevantes

Busqueda en `qa_phase3_logcat_final.txt`:

- `FATAL EXCEPTION`: 0
- `AndroidRuntime: FATAL`: 0
- `FlutterError`: 0
- `RenderFlex overflowed`: 0
- `MissingPluginException`: 0
- `PlatformException`: 0
- `E/flutter`: 0
- `permission denied`: 0
- `Force removing ActivityRecord`: 1, asociado a cierre/back de task durante prueba, sin stack fatal de app.

Ruido observado del emulador: Google Play Services / Location Accuracy / audio HAL del emulador. No se atribuye a Bit Flow.

## Validacion final

- `flutter pub get`: OK, con warnings de paquetes con versiones nuevas incompatibles.
- `dart format .`: OK, 373 archivos evaluados, 0 cambiados.
- `flutter analyze`: falla por deuda existente, 284 issues.
- `flutter test`: OK, 199 tests passed.
- `flutter build web --release`: OK, `build\web`.
- `flutter build apk --debug`: OK, instalado en `emulator-5554`.
- `flutter build apk --release`: OK confirmado, `build\app\outputs\flutter-apk\app-release.apk` (68.2 MB).

Analyzer final por categoria:

- `deprecated_member_use`: 107
- `unused_element`: 29
- `unnecessary_string_escapes`: 26
- `avoid_web_libraries_in_flutter`: 16
- `unreachable_switch_default`: 11
- `curly_braces_in_flow_control_structures`: 10
- `library_private_types_in_public_api`: 9
- `unnecessary_this`: 8
- `use_build_context_synchronously`: 7
- `unnecessary_type_check`: 7
- Otros: 54

## No tocado por seguridad

- No se modifico logica critica de guardado, offline queue, navegacion, GPS/audio/camara mas alla del wiring visible de export ZIP ya existente.
- No se hizo merge a `main`.
- No se hizo force push.
- No se agregaron dependencias.
- No se commitearon APKs, `build/`, `.dart_tool/`, ZIPs, sesiones, caches, `node_modules` ni credenciales.
- No se commitearon scripts `clawbot` ni `tools/`.

## Limitaciones y riesgos pendientes

- Audio requiere una pasada dirigida: la accion no quedo accesible desde la UI mobile visible durante esta QA.
- GPS en emulador pidio Location Accuracy y devolvio timeout; no hubo crash, pero conviene validar en telefono real con ubicacion fisica.
- El teclado Gboard del emulador mostro overlay de stylus y volvio inestable una pasada de edicion; repetir en real device o con teclado fisico.
- `flutter analyze` sigue fallando con 284 issues de deuda previa.
- El primer arranque debug despues del cambio de applicationId fue lento en el emulador; no se observo crash.

## Veredicto

Listo para demo Android con observaciones.  
Listo para PR desde el punto de vista de builds/tests/QA visual, dejando explicita la deuda de analyzer y la cobertura pendiente de audio/GPS en dispositivo real.
