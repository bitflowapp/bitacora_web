# Release Checklist

## 0) Pre-flight gates (must pass)
1. `dart format <changed files>`
2. `flutter analyze 2>&1 | Select-String " error - "` (must return no matches)
3. `flutter analyze --no-fatal-warnings --no-fatal-infos` (must exit 0)
4. `flutter test` (must be green repo-wide)

## 0.1) Platform files are tracked
1. Root `.gitignore` keeps `android/` and `ios/` mostly ignored but explicitly unignores store-pack files.
2. Required tracked Android files:
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/drawable/launch_background.xml`
- `android/app/src/main/res/drawable-v21/launch_background.xml`
- `android/app/src/main/res/mipmap-*/ic_launcher.png`
- `android/app/src/main/res/mipmap-*/ic_launcher_round.png`
- `android/key.properties.example`
3. Required tracked iOS files:
- `ios/Runner/Info.plist`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/*`
4. If any expected file is missing from `git status`, re-check `.gitignore` negation rules first.

## 1) Android signing and AAB (deterministic)
1. Generate an upload keystore locally (do not commit keystore):
```powershell
keytool -genkeypair -v -keystore "$env:USERPROFILE\\.android\\bitflow-upload.jks" -alias upload -keyalg RSA -keysize 2048 -validity 10000
```
2. Create `android/key.properties` (do not commit) using `android/key.properties.example` as reference.
3. `android/key.properties` format:
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=C:\\Users\\<you>\\.android\\bitflow-upload.jks
```
4. Release signing behavior:
- `android/app/build.gradle.kts` loads `key.properties` when present and signs release with `signingConfigs.release`.
- If `key.properties` is absent, it falls back to debug signing (not for store upload).
5. Build release artifacts:
- `flutter build appbundle --release`
- `flutter build apk --release`
6. Expected outputs:
- `build/app/outputs/bundle/release/app-release.aab`
- `build/app/outputs/flutter-apk/app-release.apk`

## 1.1) Windows Android SDK setup
1. Install Android SDK (Android Studio or command line tools).
2. Set environment variables and verify tooling.
3. Accept licenses before first release build.

PowerShell quick setup example:
```powershell
$env:ANDROID_HOME = "C:\\Users\\<you>\\AppData\\Local\\Android\\Sdk"
$env:Path += ";$env:ANDROID_HOME\\platform-tools;$env:ANDROID_HOME\\cmdline-tools\\latest\\bin"
flutter doctor --android-licenses
flutter doctor -v
flutter build appbundle --release
```

## 1.2) Release Preflight (copy/paste PowerShell)
```powershell
$env:ANDROID_HOME = "C:\Users\<you>\AppData\Local\Android\Sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:Path += ";$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin"

flutter doctor --android-licenses
powershell -ExecutionPolicy Bypass -File .\scripts\doctor_android.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\release_android.ps1
```

Expected release output:
- `build/app/outputs/bundle/release/app-release.aab`
- `build/app/outputs/flutter-apk/app-release.apk`
- `dist/BitFlow-<version>-android.apk` (via `scripts/build_android_release.ps1`)

Android release automation:
- Workflow: `.github/workflows/android_release.yml`
- Triggers: `workflow_dispatch` y tags `v*`
- Resultado esperado:
  - En `workflow_dispatch`, artifact QA `bitflow-android-apk` con `BitFlow-android.apk`
  - En push de tag `v*`, APK adjuntado al GitHub Release con nombre estable `BitFlow-android.apk`
  - Opcional: asset versionado `BitFlow-android-vX.Y.Z.apk`

Publicar release Android (1 comando):
- Ejecutar `powershell -ExecutionPolicy Bypass -File .\scripts\tag_release.ps1`
- El script toma la version de `pubspec.yaml` (y muestra `buildId` de `version.json` si existe), crea `vX.Y.Z` y hace `push` del tag a `origin`.
- Verificar publicacion/asset estable con `powershell -ExecutionPolicy Bypass -File .\scripts\verify_release.ps1`.

## 2) iOS (IPA)
1. Open `ios/Runner.xcworkspace` in Xcode and configure Team / Bundle ID / signing.
2. Confirm runtime permission keys in `ios/Runner/Info.plist`:
- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`
- `NSLocationWhenInUseUsageDescription`
3. Build IPA:
- `flutter build ipa --release`
4. Artifact:
- `build/ios/ipa/*.ipa`

## 3) Web
1. Confirm `web/index.html` keeps `<base href="$FLUTTER_BASE_HREF" />`.
2. Set the GitHub Actions variable `BASE_HREF` in `Settings > Secrets and variables > Actions > Variables`.
- Project page (this repo `bitacora_web`): `/bitacora_web/`
- User/org page root: `/`
3. Build locally with the expected base href, for example:
- `flutter build web --release --base-href /bitacora_web/`
4. Confirm `web/manifest.json` brand fields (name/description/icons) are correct.

## 3.1) Web smoke test (post-deploy)
1. Chrome hard refresh and service worker reset:
- Open DevTools > Application > Service Workers > click `Unregister`.
- Open DevTools > Application > Storage > click `Clear site data`.
- Reload with `Ctrl+Shift+R` (or `Cmd+Shift+R` on macOS).
2. iOS Safari site data reset:
- iPhone/iPad: `Ajustes > Safari > Avanzado > Datos de sitios web`.
- Search the deployed domain and remove it, then reopen Safari and reload.
3. Functional smoke flow:
- Enter app from landing and verify no red console errors.
- If empty state appears, click `Crear planilla` and confirm a new sheet is created.
- Open the sheet, enter editor, edit a few cells, and verify values persist.
- Return to sheets and confirm list/metadata update (title, rows, date).
- Test empty state CTA again by removing/cleaning local data and recreating one sheet.

## 3.2) P2 smoke test (Modo Campo + Plantillas + Lote + Atajos)
1. Plantillas:
- En `Crear planilla`, abrir galeria y crear al menos una planilla por template (`Plantilla base`, `Resistividades`, `Inventario`, `Checklist`).
- Verificar columnas y defaults iniciales.
- En columnas `Estado`, comprobar selector con `OK / Obs / Urgente`.
- En columnas `Fecha`, validar formato `YYYY-MM-DD HH:mm`.
- En `Progresiva/ID`, ingresar texto no numerico y confirmar validacion.
2. Modo Campo (`+ Registro`):
- Desde editor, ejecutar `+ Registro` y confirmar: foto/archivo, timestamp en columna de fecha, nota opcional y nueva fila creada.
- Con permisos de ubicacion, verificar metadata GPS (lat/lon/precision/timestamp) en la fila/celda destino.
- Desconectar red, crear registro y confirmar banner `Pendiente de sync`.
- Reconectar red y validar sync automatico + limpieza de pendientes.
3. Acciones por lote:
- Seleccionar filas desde el indice (Ctrl/Cmd-click y Shift-click rango).
- Ejecutar `Aplicar mismo valor` y validar cambio en todas las filas seleccionadas.
- Activar `Auto GPS`, ejecutar `Aplicar GPS a seleccion` y validar aplicacion masiva.
- Ejecutar `Duplicar fila(s)` y validar metadatos/copias.
4. Command Palette y shortcuts:
- `Ctrl/Cmd+K`: abre paleta con `Crear fila`, `Buscar`, `Exportar`, `Adjuntar foto`, `Adjuntar GPS`.
- `Ctrl/Cmd+F`: abre busqueda y navega a coincidencias.
- `Ctrl/Cmd+S`: guarda y actualiza estado de guardado.
5. Cache busting web:
- Verificar que `/version.json` tenga `buildId` nuevo tras deploy.
- Confirmar que `flutter_bootstrap.js` se carga con query `?v=<buildId>`.
- Abrir una pestana con build anterior, desplegar version nueva y comprobar recarga en version nueva sin limpiar manualmente caches.

## 3.3) P3 smoke test (Spreadsheet UI Polish)
1. Grilla premium monocroma:
- Abrir editor en desktop y validar contenedor principal de planilla con fondo blanco, borde gris sutil, radio grande y sombra suave.
- Verificar header sticky con fondo gris claro y tipografia semibold.
- Revisar zebra en filas (muy sutil, sin contraste agresivo).
2. Seleccion y foco:
- Seleccionar celdas y confirmar fill gris suave + borde gris oscuro.
- Entrar en edicion y validar focus ring de 2px gris (sin azul default del navegador/SO).
- Hover/pressed en celdas y botones: solo tonos grises.
3. Chips y panel de adjuntos:
- En una celda con foto/audio/GPS, confirmar chips minimalistas monocromo.
- Click/tap en chip abre panel de adjuntos redondeado.
- En el panel validar acciones: `Ver`, `Reemplazar`, `Eliminar`, `Copiar coordenadas`.
- Validar metadata visible: fecha/hora, lat/lon y precision.
4. Toolbar y menu contextual:
- Verificar barra superior con acciones `+ Registro`, `Buscar`, `Exportar`, `Acciones`.
- Abrir menu contextual y confirmar acciones base: `Copiar`, `Pegar`, `Duplicar fila`, `Aplicar valor a seleccion`, `Adjuntar foto`, `Adjuntar GPS`.
5. Accesibilidad y responsive:
- Con text scale alto (>= 130%), confirmar que toolbar, top bars y paneles no desbordan.
- Validar uso correcto en desktop y mobile sin overflows visuales.

## 3.4) P6 smoke test (Android-first: offline real + share + perf)
1. Android install / release:
- Ejecutar `powershell -ExecutionPolicy Bypass -File .\\scripts\\build_android_release.ps1`.
- Confirmar APK en `dist/BitFlow-<version>-android.apk`.
- Ejecutar `powershell -ExecutionPolicy Bypass -File .\\scripts\\tag_release.ps1` para publicar tag `vX.Y.Z`.
- Verificar workflow `Android Release` en GitHub:
  - En `workflow_dispatch`: artifact QA `bitflow-android-apk`.
  - En tag `v*`: APK adjuntado al Release (`BitFlow-android.apk`).
- En `docs/bitflow/index.html`, boton `Descargar Android APK` debe abrir `/releases/latest/download/BitFlow-android.apk`.
- En la app (Start/About), validar chequeo de updates:
  - Si hay version nueva, aparece banner discreto `Actualizacion disponible`.
  - CTA Android abre `/releases/latest/download/BitFlow-android.apk`.
  - En Web/PWA, CTA `Actualizar` fuerza recarga con limpieza de caches.
- iPhone Safari (install helper + hardening):
  - Abrir en Safari iPhone y validar banner `Instalar: Compartir -> Anadir a inicio`.
  - Tap en `No mostrar mas`, recargar y confirmar que el banner no reaparece.
  - Editar una celda, volver al inicio y reabrir; confirmar `Ultimo guardado local: hh:mm`.
  - Instalar como PWA y confirmar que el banner de instalacion ya no aparece.
2. Offline real (persistente):
- Conectar red, abrir editor y confirmar chip de sync en toolbar (`Sincronizado`).
- Desconectar red, crear `+ Registro` y editar celdas; validar chip `Offline/Pendiente`.
- Cerrar y reabrir app: pendientes deben mantenerse (cola persistida).
- Abrir `Cola offline`: validar listado de Quick Capture + edicion, botones `Reintentar` y `Borrar`.
- Reconectar red: validar transicion `Sincronizando...` -> `Sincronizado`.
3. Share Pro (2 taps):
- Abrir modal `Exportar planilla`.
- Elegir `XLSX` y luego `PDF`; alternar `Incluir adjuntos`.
- Confirmar nombre `BitFlow_YYYY-MM-DD_<sheet>.<ext>`.
- Android:
  - Compartir intenta primero correo con adjunto real.
  - Si falla, fallback a `mailto:`.
  - Si falla, fallback a share sheet (WhatsApp/apps).
- Web/iOS Safari:
  - Si Web Share soporta archivos, compartir directo.
  - Si no, fallback a descarga con mensaje claro.
4. Performance editor:
- Abrir planilla grande y escribir en varias filas seguidas (desktop y mobile).
- Confirmar input fluido sin lag visible ni perdida de teclas.
- Hacer scroll + edicion alternada; validar que la UI sigue responsiva y sin jank evidente.

## 3.5) P7 smoke test (Editor Pro + Backup/Restore package)
1. Editor UX premium:
- Verificar topbar/toolbar monocroma con acciones clave en 1 tap: `Guardar`, `+ Registro`, `Buscar`, `Exportar`.
- Confirmar chips de estado: guardado y sync (`Offline / Pendiente sync` cuando aplica).
- En mobile: abrir `Acciones` y validar accesos a `Adjuntar`, `Exportar`, `Importar paquete`.
- Atajos: `Ctrl/Cmd+K`, `Ctrl/Cmd+S`, `Ctrl/Cmd+F`, `Ctrl/Cmd+Shift+B`, `Ctrl/Cmd+Shift+L`, `Ctrl/Cmd+Shift+E`, `Ctrl/Cmd+Shift+I`.
2. Exportar paquete BitFlow:
- Desde editor, `Exportar paquete (.bitflow.zip)` y validar archivo generado.
- Descomprimir y verificar estructura minima:
  - `sheet.json`
  - `manifest.json` (con `appVersion`, `buildId`, `exportedAt`, `platform`, `counts`)
  - `attachments/...`
  - `export.xlsx`
- Con adjuntos en celdas (foto/audio), confirmar que los binarios existen en `attachments/`.
3. Importar paquete (crear/reemplazar):
- Abrir `Importar paquete` y validar preview (fecha, filas, adjuntos, version/build).
- Probar `Crear nueva (recomendado)` y confirmar que abre una nueva planilla con datos restaurados.
- Probar `Reemplazar actual` (con confirmacion fuerte) y validar restauracion atomica.
- Verificar colisiones de IDs: no crashea y conserva integridad de adjuntos.
4. Offline + iOS/PWA:
- Con red off, editar y confirmar estado offline visible sin bloqueos.
- En iPhone Safari: validar helper de instalacion y que no aparece en standalone.
- En iPhone Safari: editar celda, background/volver, y validar `Ultimo guardado local`.

## 3.6) Public links sanity (post push)
1. Pages:
- Abrir `https://marcoluna-nqn.github.io/bitacora_web/` y confirmar carga limpia (sin errores rojos en consola).
2. APK release estable:
- Probar `https://github.com/marcoluna-nqn/bitacora_web/releases/latest/download/BitFlow-android.apk`.
- Confirmar descarga directa del APK sin depender de artifacts de Actions.

## 3.7) P8 smoke test (Editor premium + motion + Android stable)
1. Editor premium interactions:
- Open a sheet and confirm topbar pills show key actions in one tap (`Guardar`, `Buscar`, `Jump to...`, `+ Registro`, `Exportar`).
- Select one or more rows/cells and verify `Selection Quick Actions Bar` appears with:
  - `Pegar valor`
  - `Duplicar fila`
  - `Adjuntar foto`
  - `Adjuntar GPS`
  - `Jump to...`
  - status shortcuts (`OK`, `Obs`, `Urgente`) when status column exists.
2. Search and navigation:
- `Ctrl/Cmd+F` opens inline search bar with match counter and prev/next controls.
- Search highlights matching cells in-grid and navigation moves selection correctly.
- `Ctrl/Cmd+J` opens `Jump to...` and jumps by row or by ID/progressive value.
3. Motion and feedback:

## 3.8) P12 smoke test (Data Quality + Workflows + Views)
1. Centro de calidad:
- Configurar reglas por columna: `required`, `number(min/max)`, `date`, `enum`, `regex`.
- Ingresar datos invalidos y validar:
  - resaltado monocromo en celda
  - hint inline al editar
  - panel `Errores` con salto a celda
  - chip/contador de errores en header
2. Export gating:
- Con errores activos, abrir export y confirmar modal:
  - `Exportar igual`
  - `Ir a errores`
3. Saved Views:
- Crear vista con filtros (`Estado`, `Fecha`, `Texto contiene`) y orden.
- Guardar, aplicar, renombrar y eliminar.
- Recargar web/reiniciar Android y verificar persistencia de vista activa.
4. Workflow revision:
- Marcar filas como revisadas y pendientes.
- Activar `Vista pendientes de revision`.
- Exportar PDF y verificar columnas `Revisado`, `Revisado por`, `Revisado en`.
5. Productividad:
- Abrir command palette (`Ctrl/Cmd+K`) y ejecutar:
  - `Ir a errores`
  - `Vista Urgentes`
  - `Marcar revisado`
  - `Duplicar ultima fila`
  - `Auto-ID`
  - `Usar ultimo valor`
6. Performance:
- Pegar bloque grande (TSV/CSV) y confirmar UI responsiva sin freeze visible.
- Validar que seleccion/edicion no pierden foco en el flujo de pegado.
- `Ctrl/Cmd+K` command palette opens/closes with smooth fade/slide/scale.
- Inline search and quick actions bars animate in/out without jank.
- Save/sync chips animate state transitions (dirty/saving/saved/syncing) without visual flicker.
- On mobile, haptics fire on confirmable actions (search navigation, command execution, status updates).
4. Android stable download and release verification:
- Run `powershell -ExecutionPolicy Bypass -File .\scripts\tag_release.ps1` to create/push `vX.Y.Z`.
- Wait for GitHub Actions `Android Release` on that tag.
- Run `powershell -ExecutionPolicy Bypass -File .\scripts\verify_release.ps1`.
- Confirm stable link downloads APK:
  - `https://github.com/marcoluna-nqn/bitacora_web/releases/latest/download/BitFlow-android.apk`
5. Update flow sanity:
- In app About/Settings, verify local `Version + BuildId` are visible.
- Trigger `Buscar actualizaciones` and confirm update banner + CTA behavior:
  - Android: opens stable APK link.
  - Web/PWA: hard refresh + cache cleanup path.

## 3.8) P9 smoke test (onboarding + productivity + resilience + a11y)
1. First-run onboarding and help:
- Abrir editor en una planilla nueva y confirmar banner `Tour rapido del editor`.
- Tap en `Entendido`: se oculta para la sesion.

## 3.11) P11 smoke test (persistencia + validacion premium + editor rapido)
1. Persistencia de columnas por planilla:
- Abrir `Columnas`, cambiar tipo/required/enum, ocultar, fijar y reordenar.
- Guardar como plantilla y aplicar plantilla en la misma planilla.
- Refrescar web y confirmar que toda la configuracion persiste.
- En Android: cerrar y reabrir app; confirmar persistencia.
- En iOS PWA standalone: cerrar/reabrir y confirmar persistencia.
2. Validacion premium:
- Dejar un campo requerido vacio y cargar valores invalidos en numero/fecha/estado.
- Confirmar:
  - resaltado sutil monocromo de celdas invalidas
  - hints inline al editar
  - panel `Errores` con salto a celda al tocar item
- Intentar exportar y validar modal: `Exportar igual / Revisar errores`.
3. Edicion ultrarrapida:
- Navegar con `Tab`/`Shift+Tab` y `Enter`/`Shift+Enter`.
- Pegar bloque multi-celda grande (TSV/CSV) y confirmar que la UI no se congela.
- Verificar sugerencias de historial por columna en editor.
4. Export/share Android premium:
- Exportar y compartir `XLSX`, `PDF` y `ZIP`.
- Confirmar archivo real en share sheet (WhatsApp/correo).
- Verificar fallback a mail/share cuando el cliente principal falla.
5. Release Android estable:
- Publicar tag `vX.Y.Z` (workflow `Android Release`).
- Verificar asset estable en release latest:
  - `BitFlow-android.apk`
- Verificar URL estable:
  - `https://github.com/marcoluna-nqn/bitacora_web/releases/latest/download/BitFlow-android.apk`
- Reabrir editor en primera ejecucion y usar `No mostrar mas`: confirmar persistencia.
- Abrir Command Palette (`Ctrl/Cmd+K`) y ejecutar `Ver atajos`; validar modal de cheat sheet.
2. Defaults inteligentes y autocomplete:
- Abrir `Preferencias de editor` y activar:
  - Fecha por defecto
  - Estado `OK`
  - Autoincremento ID/Progresiva
- Crear fila nueva y verificar defaults aplicados.
- Escribir valores repetidos en una columna de texto, cerrar/reabrir editor y confirmar sugerencias persistentes.
3. Smart paste:
- Copiar TSV/CSV multi-columna y pegar desde una celda activa.
- Verificar distribucion por rango y normalizacion por tipo (fecha/status).
- Con multiples filas seleccionadas, pegar texto simple y validar aplicacion a toda la seleccion.
4. Resilience y cola offline:
- Forzar estado offline y generar pendientes (edicion o quick capture).
- Abrir `Cola offline` y validar:
  - retry por item
  - `Reintentar todo`
  - `Diag` (exporta diagnostico de cola)
- Simular staging recovery (cerrar en guardado o inyectar staging) y validar banner de restauracion.
5. PWA helper y accesibilidad:
- En Android Chrome web (no standalone), confirmar helper de instalacion discreto.
- Validar acciones `No mostrar mas` y cierre por sesion.
- En desktop, recorrer toolbar/topbar con teclado (Tab/Shift+Tab) y confirmar orden de foco consistente.
- Probar text scale alto (>= 120%) y confirmar sin overflow en chrome principal del editor.
## 3.9) P10 smoke test (Grid Pro + Form mode + Report presets)
1. Column menu and panel:
- En header de columna, abrir menu contextual y validar:
  - cambiar tipo (Texto/Numero/Fecha/Estado/Checkbox)
  - ordenar asc/desc
  - fijar/desfijar
  - ocultar/mostrar
- Abrir `Panel columnas` y validar:
  - toggle visible
  - reorder (arriba/abajo)
  - reset template
  - persistencia tras cerrar/reabrir planilla.
2. Form mode:
- Abrir `Formulario` desde toolbar y editar la fila activa.
- Verificar inputs por tipo:
  - fecha (`dd/MM/yyyy`)
  - numero (acepta `,` y `.`)
  - estado con chips
  - checkbox con switch.
- Validar acciones rapidas dentro del formulario:
  - `Adjuntar foto`
  - `Adjuntar GPS`
  - `Timestamp`.
- Guardar y confirmar cambios visibles en grilla sin perdida de foco/estado.
3. Quick capture integration:
- Ejecutar `+ Registro` y confirmar que, luego de captura, abre formulario de la fila creada.
- Verificar pre-carga de fecha/hora, foto y GPS cuando aplica.
4. Premium PDF report + presets:
- En `Exportar planilla`, seleccionar presets `Reporte PDF`, `Planilla XLSX`, `Paquete ZIP`.
- Confirmar que el ultimo preset queda recordado al reabrir el modal.
- Exportar `Reporte PDF` y validar contenido:
  - header con `Version` y `Build`
  - resumen de filas/celdas/adjuntos
  - tabla de datos
  - seccion de evidencias con metadatos y link `Abrir en mapas` cuando hay GPS.
## 4) Icons and splash sanity
1. Source reference for generated app icons:
- `assets_branding/bitflow_mark_1024.png`
2. Android launcher icons present in all mipmap densities:
- `ic_launcher.png`
- `ic_launcher_round.png`
3. Android launch splash uses branded asset path:
- `android/app/src/main/res/drawable/launch_background.xml`
- `android/app/src/main/res/drawable-v21/launch_background.xml`
4. iOS AppIcon set populated:
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`
- all required `Icon-App-*.png` files
5. iOS LaunchImage set populated:
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json`
- `LaunchImage.png`, `LaunchImage@2x.png`, `LaunchImage@3x.png`

## 5) Store metadata hooks (<=2 taps from Start and Sheets)
1. About (`Acerca de`)
2. Privacy (`Privacidad`)

## 3.12) P13 smoke test (audit + search + collab + template packs)
1. Historial/auditoria:
- Editar celdas, insertar/eliminar fila, aplicar batch, quick capture y revisar filas.
- Abrir `Historial` y validar:
  - eventos registrados con timestamp/tipo/origen
  - filtros `Hoy` / `Semana` / `Tipo`
  - `Ir a celda` navega al destino correcto.
2. Busqueda global:
- `Ctrl/Cmd+Shift+F` abre `Busqueda global`.
- Buscar texto libre y `col:valor` (ej: `Estado:Urgente`).
- Activar/desactivar `Buscar en todas las planillas` y validar resultados agrupados por planilla.
- Tap/click resultado en otra planilla y confirmar apertura con foco en celda encontrada.
3. Colaboracion por paquetes:
- Exportar paquete desde `Colaborar`.
- Importar en misma planilla y elegir `Merge con actual`.
- Caso sin conflicto (celdas distintas): merge automatico.
- Caso con conflicto (misma celda): modal con opciones `Mantener local` / `Usar importado`.
- Confirmar evento de merge en `Historial`.
4. Template packs:
- En `Nueva plantilla`, abrir `Template Packs`.
- Verificar 3 packs (`Campo/Inspeccion`, `Obra/Avance`, `Relevamiento/GPS`) con 3 templates cada uno.
- Abrir preview de un template y validar:
  - columnas + reglas
  - vistas preconfiguradas
  - indicador de workflow review cuando aplica.
- Crear template y confirmar apertura del editor con columnas/vistas iniciales.
5. No regresion de performance:
- Pegar bloque grande en editor y verificar que no hay freeze visible.
- Scroll + edicion + busqueda global sin jank notorio.
3. Terms (`Terminos`)
4. Diagnostics (`Diagnostico / Soporte`)
5. Licenses (`Licencias`)

## 3.13) P14 smoke test (120Hz editor + inline previews + Android stable)
1. Typing/scroll perf (desktop + mobile):
- Abrir planilla grande (>= 120 filas) y editar rapido varias celdas consecutivas.
- Confirmar sin perdida de foco/caret ni reconstrucciones visibles de toda la grilla.
- Hacer scroll mientras editas y validar ausencia de jank perceptible.
2. Inline previews en celdas:
- Adjuntar imagen en una celda de datos (no columna Fotos) y verificar mini preview inmediato.
- Adjuntar multiples archivos y validar badge `+N`.
- Adjuntar PDF/doc y validar fallback monocromo (icono + nombre + tamano).
- Verificar que tocar el preview abre adjuntos sin bloquear typing.
3. Preferencias de editor:
- Abrir `Preferencias de editor` y confirmar toggle `Previews en celdas` ON por defecto.
- Desactivar y validar que la celda vuelve a render de texto/chips sin preview inline.
4. Motion premium:
- Revisar toolbar, quick actions y panel inline mobile:
  - transiciones cortas (120-180ms)
  - fade/scale/slide sutiles sin latencia.
5. Android release estable:
- Verificar workflow `.github/workflows/android_release.yml` en tag `v*`:
  - adjunta `BitFlow-android.apk`
  - marca release como `latest`
  - valida URL estable.
- Probar descarga:
  - `https://github.com/marcoluna-nqn/bitacora_web/releases/latest/download/BitFlow-android.apk`

## 3.14) P15 smoke test (performance + confiabilidad premium)
1. Web:
- Abrir `https://marcoluna-nqn.github.io/bitacora_web/`, entrar a una planilla y editar 10 celdas rapido (sin lag visible ni perdida de foco/teclado).
- Pegar un bloque grande `10x10`; validar que no se congela y que los valores quedan correctos.
- Adjuntar imagen y confirmar thumbnail inline sin click; abrir viewer y validar carga correcta.
- Validar shortcuts: `Ctrl/Cmd+K`, `Ctrl/Cmd+S`, `Ctrl/Cmd+F`.
2. Perf harness:
- Correr `flutter run -d chrome --web-renderer canvaskit --route /perf` o abrir editor con `?perf=1`.
- Ejecutar escenario completo y copiar reporte (frame timings + rebuild counters + cache usage).
- Confirmar que typing no dispara rebuild global de grilla.
3. Android:
- Editar celdas rapido y confirmar fluidez sin perdida de caracteres.
- Adjuntar imagen desde galeria/camara (si aplica) y validar preview/visor.
- Validar que export/share sigue operativo.
4. FlowBot:
- Abrir pill `FlowBot` (o atajo `Ctrl/Cmd+Shift+R`) y ejecutar comando de prueba.
- Ver preview de acciones y aplicar; confirmar cambios correctos en celdas.
- Sin API key/red, validar fallback a parser offline (sin bloquear UI).
