# P10 Audit Checklist (Vendibilidad)

## P0 (bloqueante release)
- [x] `lib/main.dart:40` Manejo global de errores no reportaba ni recuperaba UI.
  Plan: capturar errores en `FlutterError.onError`, `PlatformDispatcher.onError` y zona; mostrar fallback recuperable.
- [x] `lib/main.dart:440` Rutas inválidas podían terminar en experiencia en blanco/no recuperable.
  Plan: `GoRouter.errorBuilder` con pantalla de recuperación y CTA a inicio.
- [x] `lib/ui/app_toast.dart:21` Snackbars flotantes sin ajuste explícito por `viewPadding.bottom` (iOS Safari/home indicator).
  Plan: margen inferior seguro calculado por `MediaQuery.viewPaddingOf`.

## P1 (alto impacto UX/comercial)
- [ ] `lib/start_page.dart:620` Onboarding de primer uso en modal pesado.
  Plan: mover a bloque inline de 3 bullets en primer arranque y acción de descarte.
- [ ] `lib/screens/landing_screen.dart:72` Microcopy con mojibake (`BitÃ¡cora`, `CÃ³mo`, `fricciÃ³n`).
  Plan: normalizar copy visible ES para landing vendible.
- [ ] `web/index.html` Metadata social incompleta para share comercial.
  Plan: OG/Twitter/title/description orientado a producto.

## P2 (mejoras iterativas, no bloqueantes)
- [ ] `lib/start_page.dart:3806` `build()` extenso con múltiples secciones en un solo árbol.
  Plan: extraer bloques estáticos y añadir `RepaintBoundary` puntual donde aporte.
- [ ] `lib/screens/landing_screen.dart` Revisar coherencia final de enlaces legales/comerciales (`/contact`, `/changelog`).
  Plan: agregar rutas y links de pie de página.
