# Motion System

## Objetivo
Usar animacion micro y funcional para mejorar jerarquia visual y feedback, sin ruido ni "carnaval".

## Fuente
- `lib/ui/app_motion.dart`

## Tokens
- `AppMotion.micro` (120 ms)
  - feedback de chips, hover/press, transiciones de estado puntuales.
- `AppMotion.quick` (160 ms)
  - barras contextuales, cambios de bloque livianos.
- `AppMotion.medium` (220 ms)
  - aparicion de banners/contextos secundarios.
- `AppMotion.modal` (280 ms)
  - apertura/cierre de command palette y modales.

Curvas:
- `AppMotion.standardOut`
- `AppMotion.standardIn`
- `AppMotion.springOut`

## Helpers
- `fadeSlide(...)`
- `fadeScale(...)`
- `modalTransition(...)`
- `openSpring(...)`

## Reglas de uso
- Si:
  - transicion comunica estado (guardar/sync/resultado)
  - entrada/salida mejora foco (quick actions, search bar, palette)
  - accion confirmable en mobile puede sumar haptics suaves
- No:
  - animar todo al mismo tiempo
  - offsets grandes o duraciones largas
  - animaciones que bloqueen tipeo/scroll

## Donde aplicar (P9)
- Onboarding banner: aparicion suave y cierre rapido.
- Quick actions/search: `AnimatedSwitcher` + `fadeSlide`.
- Save/sync chips: cross-fade + scale corto.
- Command palette y modales: `modalTransition`.
- Tooltips y botones: micro feedback, sin rebotes exagerados.

## Aplicacion P10
- Command palette y barras contextuales:
  - entrada: `fadeSlide` con `AppMotion.springOut`.
  - salida: `standardIn` rapido.
- Form mode:
  - apertura como bottom-sheet con duracion `medium`.
  - controles de estado (chips/status/adjuntos) con micro transicion.
- Grid feedback:
  - seleccion/focus: cambios de opacidad y borde, sin transforms agresivos.
  - chips de guardado/sync: cross-fade corto + haptics en mobile.
## Guardrails
- Mantener offsets pequenos (`<= 0.08`).
- Preferir 120-220 ms para interacciones frecuentes.
- Priorizar fluidez de edicion y scroll sobre decoracion visual.
