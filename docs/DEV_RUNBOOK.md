# DEV_RUNBOOK

## 1) Stack detectado (repo real)

### Framework y lenguaje
- **Flutter (Dart)**
  - Evidencia: `pubspec.yaml` (`environment: sdk >=3.4.0 <4.0.0`, `flutter >=3.22.0`)
- **No Node/npm como stack principal**
  - Evidencia: no existe `package.json` en raíz.

### Targets/build
- **Target principal**: Web (PWA), con soporte móvil/desktop desde Flutter.
- **Targets presentes en repo**: `web/`, `android/`, `ios/`.
- **Build tool**: Flutter CLI (`flutter run`, `flutter build web`, `flutter build apk`).
- **Automatización CI**: GitHub Actions en `.github/workflows/pages.yml` y `android_release.yml`.

### Dependencias relevantes (resumen)
- Navegación: `go_router`
- Persistencia local: `shared_preferences`, `hive`, `hive_flutter`
- Datos/red: `http`, `dio`, `dio_web_adapter`
- Firebase: `firebase_core`, `cloud_firestore`, `google_sign_in`
- UI y utilidades: `syncfusion_*`, `flutter_animate`, `lottie`, `pdf`, etc.

### Service Worker / PWA
- **PWA habilitada**: `web/manifest.json` + `beforeinstallprompt` en `web/index.html`.
- **Service worker custom en source**: **no detectado** (no hay `web/sw.js` ni `web/service-worker.js`).
- **Service worker generado por Flutter build**: `build/web/flutter_service_worker.js`.
- En `web/index.html` hay lógica para limpiar caches y desregistrar SW cuando cambia el build ID.

### Storage local detectado
- **SharedPreferences** en múltiples servicios/flujo de app.
- **localStorage (web)**: `lib/services/local_store_web.dart` (key `bitflow_state_v1`).
- **Hive** para adjuntos/medios (`att_store`, `attachments_service_web`, `photo_storage_service_web`, etc.).
- **IndexedDB** explícito en `lib/services/offline_queue_store_web.dart` (db `bitflow_offline_queue_v1`).

---

## 2) Cómo correr en desarrollo

### Opción recomendada (Flutter)
```powershell
flutter pub get
flutter run -d chrome
```

### Activar build badge en dev/QA
```powershell
flutter run -d chrome --dart-define=SHOW_BUILD_BADGE=true
```

### Opción script del repo
```powershell
.\run.ps1 -Dev
```

---

## 3) Cómo buildear producción

### Build web release (artifact en `build/web`)
```powershell
flutter pub get
flutter build web --release
```

### Build web release con build badge visible
```powershell
flutter build web --release --dart-define=SHOW_BUILD_BADGE=true
```

### Empaquetado release del repo (ZIP para entrega)
```powershell
.\release.ps1 -Clean
```
Genera `bitacora_web_RELEASE_*.zip` en raíz (y staging en `dist_release/`).

---

## 4) Lint / tests / verify

### Lint
```powershell
flutter analyze
```

### Tests
```powershell
flutter test
```

### Verify (agregado en esta tarea)
Script nuevo en raíz: `verify.ps1`.

Ejecuta en orden:
1. guardrail anti-`Â` (escaneo en `lib/`, `web/`, `assets/`, `test/`; ignora dos archivos legacy con mojibake histórico)
2. `flutter --version`
3. `flutter doctor -v` (opcional)
4. `flutter pub get`
5. `flutter analyze`
6. `flutter test` (si hay tests)
7. `flutter build web --release`

Uso (completo):
```powershell
.\verify.ps1
```

Uso rápido para OpenClaw (timeouts cortos + saltea doctor):
```powershell
powershell -ExecutionPolicy Bypass -File .\verify.ps1 -Fast -SkipDoctor
```

Si `verify.ps1` no encuentra Flutter:
- seteá `FLUTTER_BIN` con ruta directa al ejecutable (ej: `C:\src\flutter\bin\flutter.bat`)
- o seteá `FLUTTER_HOME` apuntando a la carpeta raíz del SDK (ej: `C:\src\flutter`)
- o pasá ruta explícita: `./verify.ps1 -Flutter "C:\ruta\a\flutter.bat"`

Nota importante (gateway/OpenClaw):
- el gateway puede correr como servicio/tarea programada con un `PATH` distinto al de tu sesión interactiva.
- si en chat aparece "flutter no encontrado" pero en tu terminal sí existe, configurá `FLUTTER_BIN` o `FLUTTER_HOME` en el entorno del proceso gateway.

> No se detectan scripts npm de lint/test/build porque el proyecto no está basado en Node.

---

## 5) Estructura de carpetas relevante

- `lib/` → código fuente Flutter (features, services, UI)
- `test/` → suite de tests (unit/widget/smoke)
- `web/` → shell web/PWA (index, manifest, config)
- `android/`, `ios/` → plataformas móviles
- `docs/` → documentación técnica y funcional
- `scripts/` → scripts auxiliares de release/ops
- `build/` → artifacts generados (no fuente)
- `dist_release/` → paquete release listo para distribuir (cuando se ejecuta `release.ps1`)

---

## 6) Prueba brutal offline (Outbox v1)

Checklist manual:

1. Abrir la app y entrar al editor en modo normal (online).
2. Activar modo avión o cortar la conexión.
3. Hacer una acción que marque dirty en adjuntos/meta (por ejemplo: agregar, renombrar o borrar un adjunto).
4. Verificar badge de sync con `Pendientes: 1` (o mayor si acumulaste cambios).
5. Cerrar y volver a abrir la app.
6. Confirmar que los pendientes siguen visibles (persistencia durable).
7. Volver a online.
8. Esperar el ciclo de sync.
9. Confirmar que `Pendientes` baja a `0` (puede pasar por estado de sincronización intermedio).

Checklist de estado por adjunto (UI):

1. Adjuntar archivo/foto/audio en modo avión → cada adjunto debería mostrar `En cola`.
2. Volver online y esperar sync → el estado debería pasar por `Subiendo…` y terminar en `Listo`.
3. Forzar una falla (cortar red a mitad del sync) → estado `Error`.
4. Tocar `Reintentar` en ese adjunto → vuelve a `En cola` y luego completa en `Listo` cuando hay conectividad.
