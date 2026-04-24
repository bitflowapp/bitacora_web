# Android offline build

Fecha: 2026-04-24

## Estado actual

- Android target existe y compila.
- `applicationId`: `com.bitflow.app`
- App label: `Bit Flow`
- Build release probado: OK
- APK generado: `build/app/outputs/flutter-apk/app-release.apk`
- Tamano observado: 73.5 MB

## Requisitos

- Flutter estable disponible en PATH.
- Android SDK instalado.
- Licencias Android aceptadas.
- Java/JDK configurado por Flutter.

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
4. Crear una planilla local.
5. Crear desde template.
6. Editar varias celdas.
7. Guardar.
8. Cerrar y reabrir la app.
9. Verificar que la planilla sigue disponible.
10. Exportar/compartir XLSX o ZIP.

## Permisos

Declarados:

- `INTERNET`: para funciones opcionales online (updates, servicios, sync futuro). La app local debe funcionar sin red.
- `CAMERA`: captura de evidencia.
- `RECORD_AUDIO`: audio en celda.
- `ACCESS_COARSE_LOCATION` / `ACCESS_FINE_LOCATION`: GPS.
- `READ_MEDIA_IMAGES` / `READ_MEDIA_AUDIO` y `READ_EXTERNAL_STORAGE` hasta SDK 32: adjuntos desde archivos/galeria.

## Limitaciones conocidas

- Si `SharedPreferences` nativo falla, la app cae a memoria de sesion. No cerrar la app antes de exportar.
- Export/share depende de apps instaladas que acepten archivos.
- No hay sync cloud completo ni resolucion de conflictos.
- El APK de release usa firma debug si no existe `android/key.properties`; sirve para QA/demo, no para Play Store.

## Comandos corridos

```powershell
flutter doctor -v
flutter pub get
flutter analyze android\app\build.gradle.kts android\app\src\main\AndroidManifest.xml --no-fatal-warnings --no-fatal-infos
flutter build apk --release
```
