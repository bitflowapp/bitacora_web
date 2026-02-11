# Motion System

## Objetivo
Mantener animaciones micro, consistentes y monocromas para que BitFlow se sienta fluido y premium sin ruido visual.

## Archivo fuente
- `lib/ui/app_motion.dart`

## Tokens de motion
- `AppMotion.micro` (120 ms): feedback de chips y cambios de estado cortos.
- `AppMotion.quick` (160 ms): aparicion/desaparicion de barras contextuales.
- `AppMotion.medium` (220 ms): transiciones entre bloques.
- `AppMotion.modal` (280 ms): apertura/cierre de modales y command palette.

Curvas:
- `AppMotion.standardOut`: salida natural para UI general.
- `AppMotion.standardIn`: entrada/salida inversa para cierre limpio.
- `AppMotion.springOut`: rebote leve para elementos contextuales (sin exagerar).

## Helpers
- `AppMotion.fadeSlide(...)`: fade + desplazamiento corto.
- `AppMotion.fadeScale(...)`: fade + escala sutil.
- `AppMotion.modalTransition(...)`: transición modal tipo iOS/macOS cuando aplica; fallback elegante para Android/Web.
- `AppMotion.openSpring(...)`: spring simulation reutilizable para animaciones avanzadas.

## Donde se aplica hoy
- `lib/widgets/command_palette.dart`
  - apertura/cierre con `showGeneralDialog` + `AppMotion.modalTransition`.
  - feedback háptico en navegación de resultados y ejecución.
- `lib/features/editor/editor_state.dart`
  - `Inline Search Bar` y `Selection Quick Actions Bar` con `AnimatedSwitcher` + `AppMotion.fadeSlide`.
  - feedback háptico al abrir/cerrar búsqueda y navegar resultados.
- `lib/features/editor/widgets/save_status_chip.dart`
  - cambios de estado con `AnimatedSwitcher`/`AnimatedContainer` usando tokens de `AppMotion`.
- `lib/ui/app_modal.dart`
  - modales de app con transición consistente vía `AppMotion.modalTransition`.

## Guía de uso
- Preferir micro-animaciones funcionales (estado, foco, jerarquía).
- Evitar animaciones largas o múltiples efectos simultáneos.
- Mantener amplitud de movimiento baja (`Offset` <= 0.08).
- En mobile, combinar motion con `AppHaptics` en acciones confirmables.