# Pre-PR Android Emulator QA Report

Fecha: 2026-04-29  
Rama: `premium-linkedin-real-app`  
ApplicationId: `com.bitflow.app`  
APK debug probado: `build\app\outputs\flutter-apk\app-debug.apk`  
APK release validado: `build\app\outputs\flutter-apk\app-release.apk`

## Entorno

Validado en:

- AVD: `BitFlow_QA_API36`
- Device id: `emulator-5554`
- Android: 16 / API 36
- Modelo: `sdk_gphone64_x86_64`

Emuladores detectados por `flutter emulators`:

- `Medium_Phone_API_36.0`
- `Operis_API_34`

Dispositivos conectados por `flutter devices`:

- `emulator-5554` Android 16 / API 36
- Windows desktop
- Chrome web

## Resultado de matriz

| Emulador | Resultado |
| --- | --- |
| `BitFlow_QA_API36` | Probado correctamente. |
| `Medium_Phone_API_36.0` | Detectado, pero no conecto a ADB dentro de 5 minutos. No bloquea PR. |
| `Operis_API_34` | Detectado, pero no conecto a ADB dentro de 4 minutos. No bloquea PR. |

No hay Android fisico disponible en esta etapa. Se documenta como pendiente no bloqueante.

## Flujos probados en BitFlow_QA_API36

- Instalacion debug con `adb install -r`.
- Arranque directo con `adb shell am start -W -n com.bitflow.app/.MainActivity`.
- Landing y workspace premium.
- Creacion de nueva hoja desde `Nuevo relevamiento`.
- Apertura de editor.
- Dismiss de onboarding.
- Flujo mobile de edicion de celda.
- Menu de exportacion, incluyendo opciones `XLSX`, `PDF` y `ZIP`.
- Persistencia basica tras `adb shell am force-stop com.bitflow.app` y reapertura.
- Rotacion landscape y retorno a portrait.
- Revision de logcat del smoke pre-PR.

## Evidencia local

Carpeta generada localmente:

- `docs\qa\android_emulator\pre_pr`

Capturas principales:

- `bitflow_api36_01_home.png`
- `bitflow_api36_02_new_sheet_editor.png`
- `bitflow_api36_03_editor_after_onboarding.png`
- `bitflow_api36_05_edit_cell_text.png`
- `bitflow_api36_08_persistence_reopen.png`
- `bitflow_api36_09_landscape.png`
- `bitflow_api36_10_portrait_back.png`
- `bitflow_api36_21_export_menu_confirmed.png`

Logcat:

- `bitflow_api36_logcat.txt`

## Logcat pre-PR

Busqueda sobre logcat del smoke:

- `FATAL EXCEPTION`: 0
- `AndroidRuntime: FATAL`: 0
- `FlutterError`: 0
- `RenderFlex overflowed`: 0
- `MissingPluginException`: 0
- `PlatformException`: 0
- `E/flutter`: 0

## Validacion de release local

- `flutter pub get`: OK
- `dart format --set-exit-if-changed .`: OK
- `flutter test`: OK, 199 tests passed
- `flutter build web --release`: OK
- `flutter build apk --release`: OK, 68.2 MB
- `flutter analyze`: 284 issues, deuda conocida

## Bugs encontrados en esta pasada

No se encontraron blockers ni majors nuevos en el emulador probado.

Observaciones:

- La navegacion automatizada por coordenadas puede caer en pantallas distintas si la app conserva estado entre aperturas. Para la evidencia final se corrigio usando `am start`, dumps de UI y capturas confirmadas.
- Los AVD adicionales listados no arrancaron/conectaron a ADB de forma confiable en esta maquina durante la ventana de prueba.
- Audio, GPS y camara reales requieren Android fisico para una aprobacion final comercial.

## Veredicto QA

Listo para abrir PR hacia `main` con observaciones:

- Tests y builds release verdes.
- Android Emulator principal verde para smoke pre-PR.
- Analyzer aun falla por deuda conocida y no debe bloquear este PR.
- Android fisico queda pendiente para una etapa posterior de QA.
