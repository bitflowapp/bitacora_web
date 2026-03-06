# BitFlow RC

BitFlow es una app Flutter (Web + Mobile) para bitacoras operativas con grilla tipo hoja, adjuntos por celda y exportaciones listas para cliente.

## Stack y entrypoints

- Stack: `Flutter 3.x`, `Dart 3.x`
- Entry web/app: `lib/main.dart`
- Home operativa: `lib/start_page.dart`
- Landing comercial: `lib/screens/landing_screen.dart`
- About/version/support: `lib/screens/about_screen.dart`

## Requisitos

- Windows 10/11 (recomendado para equipo comercial)
- Flutter SDK instalado y en `PATH`
- Chrome/Edge para web

## Primer arranque (Windows)

1. `flutter pub get`
1. `flutter run -d chrome`

Atajo no técnico:

1. Ejecutar `run.bat` o `run.ps1`
1. Abrir URL local mostrada por consola

## Scripts de calidad (RC gate)

- Analisis estricto del repo: `flutter analyze`
- Analisis usable para CI RC (sin bloquear por deuda historica):  
  `flutter analyze --no-fatal-infos --no-fatal-warnings`
- Tests: `flutter test`
- Build web: `flutter build web`

## Configuracion y seguridad

BitFlow no usa secretos runtime en frontend.

- Variables comerciales: `.env.example` (referencia)
- En web productivo, usar:
  - `web/config.json` (entrega cliente)
  - `assets/config.json` (build desde codigo)
  - `--dart-define` para overrides de release

Ejemplo:

```powershell
flutter build web --release `
  --pwa-strategy=none `
  --base-href=/bitacora_web/ `
  --dart-define=PRO_CTA_URL=https://tuempresa.com/bitflow-pro `
  --dart-define=SUPPORT_EMAIL=soporte@tuempresa.com `
  --dart-define=SUPPORT_WHATSAPP=+5491122334455
```

Notas de seguridad:

- Claves Firebase Web (`AIza...`) son identificadores publicos del proyecto, no secretos. Ver [SECURITY.md](SECURITY.md).
- No commitear tokens privados, credenciales SMTP ni llaves privadas.

## Packaging y deploy

- Artifact principal web: `build/web`
- Publicacion GitHub Pages: `.github/workflows/pages.yml`
- Android release (APK): `.github/workflows/android_release.yml`
- Release web local (Windows, validaciones incluidas): `scripts/release_web.ps1`
- Deploy opcional a `gh-pages`: `scripts/deploy_gh_pages.ps1`
- URL live (Pages): `https://marcoluna-nqn.github.io/bitacora_web/`
- Web release usa `--pwa-strategy=none` para evitar cache persistente de Service Worker y asegurar updates inmediatos en Pages.
- Release estable: `https://github.com/marcoluna-nqn/bitacora_web/releases/tag/v1.3.0`

Entrega tipica a cliente:

1. Build web release
1. Copiar `build/web` a hosting o `docs/` segun estrategia
1. Entregar quickstart de usuario final: `docs/quickstart.md`

Release recomendado (PowerShell):

```powershell
.\scripts\release_web.ps1 `
  -BaseHref "/bitacora_web/" `
  -ProCtaUrl "https://tuempresa.com/bitflow-pro" `
  -SupportEmail "soporte@tuempresa.com" `
  -SupportWhatsApp "+5491122334455"
```

Deploy opcional a GitHub Pages (branch `gh-pages`):

```powershell
.\scripts\deploy_gh_pages.ps1
```

## Troubleshooting (Windows)

- PowerShell bloqueado:
  - `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
- Flutter no encontrado:
  - validar `flutter --version`
  - reiniciar terminal tras configurar `PATH`
- Puerto ocupado:
  - usar `run.ps1` (intenta fallback)
- Export/import ZIP falla:
  - validar que el archivo contenga `backup.json`

## Documentacion de release

- Cambios de version: [CHANGELOG.md](CHANGELOG.md)
- Guia usuario final: [docs/quickstart.md](docs/quickstart.md)
- Licencia comercial: [LICENSE](LICENSE)
