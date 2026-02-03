# Bitacora Web

Planilla tipo Excel con UX premium para bitácoras de obra. Funciona en Web, iOS, Android y Desktop.

Demo (GitHub Pages): `https://marcoluna-nqn.github.io/bitacora_web/`

## Requisitos
- Flutter 3.22+

## Configuración de Engine (opcional)
Si querés usar el engine remoto, setear `ENGINE_BASE_URL`.

Local (opcional):
```bash
flutter run -d chrome --dart-define-from-file=.env
```

Ejemplo `.env`:
```
ENGINE_BASE_URL=https://engine.tu-dominio.com
```

Si no hay `ENGINE_BASE_URL`, la calculadora funciona offline con el evaluador local.

## Desarrollo
```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

## Build
```bash
flutter build web --release --base-href "/bitacora_web/" --dart-define=ENGINE_BASE_URL=...
flutter build apk --release
```

## Exportar / Compartir
- `Exportar XLSX`: genera planilla con fotos embebidas (1ra por celda) y hoja `Attachments`.
- `Exportar ZIP (adjuntos)`: `Sheet.xlsx` + `attachments/` + `manifest.json`.
- `Compartir ZIP`: abre share sheet (WhatsApp / Gmail / Outlook en móvil).

## GPS / Fotos / Audio
- GPS por celda: pega texto en la celda seleccionada y guarda metadata por celda.
- Fotos por celda: múltiples fotos, thumbnails, renombrar/borrar.
- Audio por celda: grabar/reproducir/renombrar/borrar (web + mobile + desktop).

## GitHub Pages
Workflow recomendado: `.github/workflows/deploy_pages.yml`
- Usa `flutter build web --release --base-href "/bitacora_web/"`
- Toma `ENGINE_BASE_URL` desde `vars.ENGINE_BASE_URL`
