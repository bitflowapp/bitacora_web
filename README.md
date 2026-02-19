# BitFlow
Bitácora operativa para equipos de campo: planillas editables, evidencia por celda (foto/audio/GPS), trabajo offline y exportación profesional.

## Para quién
- Equipos de inspección, obra, mantenimiento, logística y auditoría.
- Operaciones que necesitan trazabilidad diaria sin depender de servidor.

## Valor en 3 bullets
- Captura y ordena evidencia en una sola planilla (sin fricción en campo).
- Funciona offline-first y sincroniza/recupera cuando vuelve la conectividad.
- Exporta en formatos vendibles (XLSX/PDF/paquete) para entrega inmediata.

## Abrir en web
- GitHub Pages: `https://marcoluna-nqn.github.io/bitacora_web/`
- Local (Windows): ejecutar `run.bat` o `run.ps1`.

## Build web para Pages
```powershell
C:\src\flutter\bin\flutter.bat pub get
C:\src\flutter\bin\flutter.bat build web --release --base-href "/bitacora_web/" --no-wasm-dry-run
```

Checklist completo de publicación: `docs/release_checklist_pages.md`.

## Configuración comercial (opcional)
- `web/config.json`: marca, contacto y pricing para landing comercial.
- `assets/config.json` o `--dart-define`: overrides por build.

## Nota de seguridad/producto
- Auth queda OFF por defecto: `BITFLOW_AUTH=false`.
- No subir claves ni secretos al repo.
