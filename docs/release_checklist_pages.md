# Release Checklist (GitHub Pages)

## 1) Pre-flight local
```powershell
C:\src\flutter\bin\flutter.bat pub get
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed .
C:\src\flutter\bin\flutter.bat test
```

## 2) Build Pages release
```powershell
C:\src\flutter\bin\flutter.bat build web --release --base-href "/bitacora_web/" --no-wasm-dry-run
```

## 3) Guardrails de producto
- `BITFLOW_AUTH=false` (auth OFF por defecto).
- Sin build badges/stamps visibles en home/landing en release.
- Sin overlays no intencionales capturando taps.
- Update banner y helper iOS con targets táctiles consistentes (44px+).

## 4) Sanidad de bundle (auth off)
Revisar que no aparezcan copys de login/google/correo en `build/web/main.dart.js`.

Ejemplo:
```powershell
rg -n --fixed-strings "Continuar con Google" build/web/main.dart.js
rg -n --fixed-strings "Inicia sesi" build/web/main.dart.js
```

## 5) Smoke en Pages
- Abrir `https://marcoluna-nqn.github.io/bitacora_web/`
- Verificar navegación `Landing -> /app`.
- Crear planilla, editar celdas, recargar y confirmar persistencia.
- Validar banner de actualización y flujo de refresh en web.

## 6) Publicación
- Push de rama/PR a `main`.
- Ejecutar workflow de Pages definido en el repo.
- Confirmar que la URL pública carga con hard refresh (`Ctrl+Shift+R`).
