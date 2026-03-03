# CHANGELOG

## [1.3.1] - 2026-03-03

Release
- Daily driver + hardening + polish copy.

## [1.3.0] - 2026-02-28

Release
- Version comercial estable para despliegue Flutter Web (`1.3.0+4`).
- Packaging web profesional con metadatos SEO/social, loading de arranque pulido y branding BitFlow consistente.
- Home orientada a cliente con bloque visible Pro/Licencia, CTA comercial configurable y soporte customer-facing.
- Demo mode de primer uso mejorado: carga de ejemplo reversible para no ensuciar datos reales.

Quality
- `flutter analyze` en cero issues y budget CI endurecido para bloquear regresiones.
- Script de entrega repetible para Windows: `scripts/release_web.ps1` (pub get + analyze + test + build).

## [1.2.6-rc.1] - 2026-02-28

Added
- Nuevos componentes UI base: `AppTable` y `AppErrorState` para estandarizar tabla y errores.
- `docs/quickstart.md` (guia corta para usuario final).
- `LICENSE` comercial (all rights reserved).

Changed
- Home (`StartPage`) con estados de inicializacion mas claros, acceso visible a `Soporte` y `Version`.
- Landing comercial con estado `loading` y manejo de configuracion incompleta (`error/empty`) con CTA.
- About rediseñada con design system (cards, botones pill, tabla minimalista de version/build) y boton de feedback.
- README actualizado para entrega cliente (install/run/build/deploy/troubleshooting).

Quality
- Validacion de regresion: tests de onboarding y About pasando.
- Build web release verificado en entorno local.

## [1.2.5] - 2026-02-13

Added
- P21: Empty state premium con CTAs, acceso rapido mobile (boton rayo) a command palette y flujo Export PRO XLSX/PDF.
- P22: About in-app con links (Privacidad, Terminos, Issues) y boton para copiar diagnostico en texto plano.
- Android release automation en GitHub Actions para publicar `BitFlow-android.apk` en `releases/latest`.

Changed
- Versionado app a `1.2.5+3` y notas de release derivadas de CHANGELOG en CI.

## [1.2.4] - 2026-02-06

Added
- QA: bloqueo documentado por toolchain ausente (Flutter/Dart) en este entorno.

## [1.2.3] - 2026-02-06

Added
- Attachments UI premium: tiles publicos, tooltips, semantica y animaciones sutiles.
- Dialogs consistentes con AppModal/AppButton (export, densidad, GPS, atajos, audio).
- Encoding UTF-8 en scripts PowerShell.

Changed
- Microcopy de adjuntos y confirmaciones mas claro.
- Shortcuts con guard extra cuando hay input activo.

## [1.2.2] - 2026-02-06

Added
- Modulo de adjuntos separado (attachments/) con UI y preview dedicados.
- Dialogs extraidos (densidad, GPS, export, ayuda) en dialogs/.
- Actions/Shortcuts extraidos en actions/.

Changed
- Editor refactorizado a estructura modular sin cambiar comportamiento.
- Controller expone callbacks de adjuntos para integracion limpia.

## [1.2.1] - 2026-02-06

Added
- Editor refactor structure (feature-first parts) + wrapper export.
- SaveStatusChip con animacion sutil en header.

Changed
- Editor header microcopy y tooltips mas claros.
- Botones del header con hover/scale suave en web.

## [1.2.0] - 2026-02-06

Added
- Design system (tokens, theme, componentes UI reutilizables).
- Landing premium actualizada + paginas /privacy y /terms.
- AppShell basico y top bar con acciones principales en Home.
- README_CLIENTE.md para usuarios no tecnicos.

Changed
- Tema tipografico y estilos Apple-minimal consistentes.
- Editor: previews y dialogos con UX mas claro.
- Scripts Windows: checks de Flutter y copia de config en release.

Fixed
- Microcopy de guardado en editor.

## [1.1.0] - 2026-02-06

Added
- Landing con propuesta de valor, precios, casos de uso y CTA.
- Routing `/` (landing) y `/app` (aplicacion).
- Onboarding inicial en 3 pasos dentro de la app.
- Backup ZIP + Reporte HTML imprimible.
- Importar backup ZIP desde Home.
- Configuracion via `web/config.json` y `assets/config.json`.
- Scripts Windows `run.ps1`, `run.bat` y `release.ps1`.

Changed
- Export permite HTML y backup ZIP.

Fixed
- Persistencia y metadata en adjuntos y filas (IDs estables).
