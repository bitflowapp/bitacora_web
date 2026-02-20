# Release Checklist (sell-ready web)

## 1) Preflight local
Run with explicit Windows paths:

```powershell
C:\src\flutter\bin\flutter.bat pub get
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed .
C:\src\flutter\bin\flutter.bat test
C:\src\flutter\bin\flutter.bat analyze --no-fatal-infos --no-fatal-warnings
```

Expected:
- `format`: 0 changed files
- `test`: all green
- `analyze`: no nuevos errores bloqueantes en el PR

## 2) Build release for Pages
```powershell
C:\src\flutter\bin\flutter.bat build web --release --base-href "/bitacora_web/" --dart-define=BITFLOW_AUTH=false --no-wasm-dry-run
```

Expected:
- `build/web` generado sin errores
- auth en modo demo: `BITFLOW_AUTH=false`

## 3) Release hygiene
- Sin build badge/stamp visible en release UI.
- Sin overlays capturando taps en superficies clave.
- Safe areas correctas para iPhone Safari (bottom inset).

## 4) Bundle scan (post build)
```powershell
rg -n "Continuar con Google|login-google|FirebaseAuth|google_sign_in" build\web\main.dart.js
rg -n "debug badge|build stamp|SHOW_BUILD_BADGE" build\web\main.dart.js
```

Expected:
- Sin matches bloqueantes de login UI para auth OFF.
- Sin rastros de badge/stamp visible en release.

## 5) Smoke manual (2-3 min)
1. Abrir landing y validar CTA principal visible.
2. Ir a `/app`, crear planilla, editar, guardar, exportar.
3. Abrir Premium y Agent: copy claro, CTA visibles, sin overflow.
4. Simular viewport movil: validar targets tactiles y toasts sin solaparse con bottom bar.

## 6) Pages deploy
1. Push a rama + PR a `main`.
2. Ejecutar workflow de Pages.
3. Verificar deploy con hard refresh (`Ctrl+Shift+R`) en URL publica.
