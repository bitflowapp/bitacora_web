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
1. `flutter --version`
2. `flutter doctor -v` (opcional)
3. `flutter pub get`
4. `flutter analyze`
5. `flutter test` (si hay tests)
6. `flutter build web --release`

Uso (completo):
```powershell
.\verify.ps1
```

Uso rápido para OpenClaw (timeouts cortos + saltea doctor):
```powershell
powershell -ExecutionPolicy Bypass -File .\verify.ps1 -Fast -SkipDoctor
```

Si `verify.ps1` no encuentra Flutter:
- seteá `FLUTTER_HOME` o `FLUTTER_ROOT` apuntando al SDK
- o pasá ruta explícita: `./verify.ps1 -Flutter "C:\ruta\a\flutter.bat"`

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
