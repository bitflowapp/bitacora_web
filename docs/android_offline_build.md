# Android offline build

Fecha: 2026-04-24

## Estado actual

- Android target existe y compila desde el mismo proyecto Flutter.
- Rama validada: `codex/android-offline-worker-mode`.
- `applicationId`: `com.bitflow.app`
- App label: `Bit Flow`
- Build release probado: OK
- APK generado: `build/app/outputs/flutter-apk/app-release.apk`
- Tamano observado en esta pasada: 35.1 MB
- No se requiere internet para abrir la app, crear planillas locales, cargar templates locales, editar, guardar ni generar export local.

## Requisitos para compilar

- Flutter estable disponible en PATH.
- Android SDK instalado y licencias aceptadas.
- JDK compatible configurado en Flutter.
- Espacio libre suficiente en el disco donde vive el worktree y en el cache de Gradle.
- Para Play Store: keystore real configurado en `android/key.properties`.

Validacion de entorno usada:

```powershell
flutter doctor -v
flutter pub get
```

## Compilar APK

Desde la raiz del repo/worktree:

```powershell
flutter pub get
flutter build apk --release
```

Salida esperada:

```text
build/app/outputs/flutter-apk/app-release.apk
```

En esta maquina, la ruta absoluta fue:

```text
C:\Users\marco\dev\bitflow_p18_android_offline_worker_mode\build\app\outputs\flutter-apk\app-release.apk
```

## Instalar manualmente en Android

1. Copiar `app-release.apk` al telefono.
2. Abrir el archivo desde Files/Drive/WhatsApp/USB, segun el metodo usado.
3. Permitir "instalar apps desconocidas" para esa fuente si Android lo pide.
4. Instalar `Bit Flow`.
5. Abrir la app con Wi-Fi y datos desactivados para validar modo offline.

Nota: si no existe `android/key.properties`, el release usa firma debug como fallback. Sirve para QA/demo manual; no sirve como artefacto final de Play Store.

## Compilar appbundle

```powershell
flutter build appbundle --release
```

Salida esperada:

```text
build/app/outputs/bundle/release/app-release.aab
```

## Probar sin internet

1. Instalar el APK en el dispositivo.
2. Activar modo avion o desactivar Wi-Fi/datos.
3. Abrir Bit Flow.
4. Entrar al modo local/demo.
5. Crear una planilla vacia.
6. Crear una planilla desde template.
7. Editar varias celdas.
8. Guardar y cerrar la app.
9. Reabrir y confirmar que la planilla sigue disponible.
10. Exportar XLSX desde la lista o desde el editor.
11. Compartir XLSX/PDF/ZIP desde el editor si hay una app compatible instalada.
12. Probar permisos de camara, audio y ubicacion cuando se adjunte evidencia.

## Que funciona offline

- Arranque local de la app.
- Creacion de planillas.
- Templates demo/locales.
- Edicion de celdas.
- Guardado local con `SharedPreferences` en Android.
- Carga de planillas guardadas.
- Export XLSX local en IO mediante saver de plataforma.
- Export/share desde el editor usando archivo temporal y share sheet de Android.
- Evidencia local si el permiso correspondiente fue otorgado y el dispositivo soporta el recurso.

## Que no funciona todavia offline

- Sync cloud real y resolucion de conflictos.
- Backend/auth/engine remoto cuando no hay red.
- Envio por correo si el cliente de correo necesita conectividad.
- Mapas remotos o servicios que dependan de internet.
- Publicacion Play Store sin keystore, iconos finales, politica de permisos y revision de versioning.

## Permisos Android

Declarados en `android/app/src/main/AndroidManifest.xml`:

- `INTERNET`: funciones opcionales online y sync futuro; los flujos locales no deben depender de red.
- `CAMERA`: captura de evidencia.
- `RECORD_AUDIO`: audio en celda.
- `ACCESS_COARSE_LOCATION` / `ACCESS_FINE_LOCATION`: GPS.
- `READ_MEDIA_IMAGES` / `READ_MEDIA_AUDIO`: adjuntos desde galeria/media en Android moderno.
- `READ_EXTERNAL_STORAGE` con `maxSdkVersion=32`: compatibilidad con Android viejo.

La camara y el microfono estan declarados como features no obligatorias para no bloquear instalacion en dispositivos sin ese hardware.

## Riesgos conocidos

- Si `SharedPreferences` nativo falla, la app cae a memoria de sesion. En ese modo no hay persistencia despues de cerrar la app; exportar antes de cerrar.
- El share sheet depende de que el telefono tenga apps capaces de recibir archivos.
- El export desde la lista guarda un XLSX local; para entrega a terceros, el flujo mas claro es compartir desde el editor.
- El APK de QA puede estar firmado con debug si no hay keystore release.
- El worktree en C: puede quedarse sin espacio durante Gradle. En esta pasada el primer build fallo por `Espacio en disco insuficiente` y se resolvio moviendo `build/` y `android/.gradle/` a un disco con espacio.

## Troubleshooting

Si Gradle falla con `Espacio en disco insuficiente`:

1. Liberar espacio en el disco del worktree.
2. Detener daemons:

```powershell
cd android
.\gradlew.bat --stop
cd ..
```

3. Limpiar artefactos generados:

```powershell
flutter clean
flutter pub get
flutter build apk --release
```

Si el disco del worktree sigue muy justo, usar un worktree en un disco con mas espacio o mover solo artefactos generados (`build/`, `android/.gradle/`) a un disco amplio mediante junctions locales no versionados.

## Proximos pasos Play Store

- Crear keystore release y completar `android/key.properties`.
- Revisar versionCode/versionName en `pubspec.yaml`.
- Revisar iconos finales y adaptive icon si se quiere acabado de tienda.
- Revisar permisos y politica de privacidad para camara, audio, ubicacion y archivos.
- Ejecutar `flutter build appbundle --release`.
- Probar instalacion limpia, upgrade desde APK anterior y uso offline con datos reales.

## Comandos corridos en esta pasada

```powershell
flutter doctor -v
flutter pub get
flutter analyze --no-fatal-warnings --no-fatal-infos lib\services\export_xlsx_service.dart test\export_xlsx_service_io_test.dart
flutter test test\export_xlsx_service_io_test.dart
flutter test test\store_storage_fallback_test.dart test\editor_sheet_store_resilience_test.dart test\export_xlsx_with_photos_test.dart
flutter test
flutter build apk --release
flutter build web --release --base-href /bitacora_web/
```
