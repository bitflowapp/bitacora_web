# BitFlow
BitFlow es una app web Flutter para operacion de campo local-first: crear planillas, capturar evidencia y exportar entregables sin depender de backend.

## Propuesta de valor
- Menos friccion en campo: datos + evidencia en una sola planilla.
- Modo local-first real: funciona sin red y mantiene continuidad de trabajo.
- Entregables listos para cliente: exportacion XLSX/PDF/ZIP.

## Features premium
- Editor orientado a uso movil (tap targets consistentes y feedback claro).
- Evidencia por celda (foto/audio/GPS) con flujo operativo directo.
- Plantillas y agente de planillas para acelerar carga/importacion.
- Pantallas comerciales listas para demo (landing, premium, marketing/legal).

## Stack
- Flutter (Web)
- Dart
- GoRouter
- Persistencia local (modo local-first)

## Auth policy (importante)
- Auth esta OFF por defecto: `BITFLOW_AUTH=false`.
- Este repo no requiere login obligatorio para demo sell-ready.

## Ejecutar local (Windows)
```powershell
C:\src\flutter\bin\flutter.bat pub get
C:\src\flutter\bin\flutter.bat run -d chrome --dart-define=BITFLOW_AUTH=false
```

## Build web release (GitHub Pages)
```powershell
C:\src\flutter\bin\flutter.bat build web --release --base-href "/bitacora_web/" --dart-define=BITFLOW_AUTH=false --no-wasm-dry-run
```

## Gates de calidad
```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed .
C:\src\flutter\bin\flutter.bat test
C:\src\flutter\bin\flutter.bat analyze --no-fatal-infos --no-fatal-warnings
```

## Documentacion de venta/release
- `docs/RELEASE_CHECKLIST.md`
- `docs/SALES_DEMO_SCRIPT.md`
- `docs/KNOWN_LIMITS.md`
- `docs/release_checklist_pages.md`
