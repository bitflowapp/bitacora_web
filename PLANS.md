# BitFlow Premium Plan (P9)

## Objetivo
Entregar un editor premium que ahorre tiempo real, con onboarding claro, defaults inteligentes, resiliencia offline/PWA y accesibilidad consistente, sin romper Pages ni flujos existentes (P2/P3/P6/P7/P8).

## Riesgos y limitaciones por plataforma
- Web/iOS Safari:
  - Safari puede matar pestanas en background; se prioriza flush rapido y rutas de recuperacion.
  - Instalacion PWA depende de UX nativa del navegador (no hay prompt universal).
  - Compartir archivos sigue limitado frente a Android.
- Android:
  - Permisos (camara/GPS/microfono/archivos) pueden bloquear acciones; UI debe informar causa y fallback.
  - Cola offline debe mantenerse util aun sin red prolongada.
- Desktop/Web:
  - Atajos pueden colisionar con navegador/SO; mantener combinaciones previsibles.

## Fases (F1..F5)

### F1 - Onboarding premium
Checklist:
- [x] First-run tour en editor (dismissible + persistencia).
- [x] Cheat sheet de atajos accesible desde Command Palette.
- [x] Tooltips contextuales en acciones criticas.
Done criteria:
- [x] Usuario nuevo entiende flujo principal en < 30 segundos.
- [x] El tour puede ocultarse y no reaparece si se desactiva.

### F2 - Productividad del editor
Checklist:
- [x] Defaults inteligentes por columna (Fecha, Estado, ID/Progresiva).
- [x] Preferencias de defaults editables desde settings del editor.
- [x] Historial de autocompletado por columna (persistente, liviano).
- [x] Smart paste robusto para TSV/CSV/texto simple.
Done criteria:
- [x] Alta de fila requiere menos taps/clicks.
- [x] Pegado masivo respeta seleccion y tipos de columna.

### F3 - Resiliencia offline/PWA
Checklist:
- [x] Recovery banner para sesion previa incompleta (restore).
- [x] Cola offline con retry por item + retry all + export diagnostico.
- [x] Install helper Android/Chrome no invasivo.
Done criteria:
- [x] Usuario puede recuperar estado local y entender fallos de sync.
- [x] Cola offline tiene acciones operables sin depender de consola.

### F4 - Accesibilidad y UX hardening
Checklist:
- [x] Semantics en controles clave del editor.
- [x] Focus order consistente en topbar/toolbar/grilla.
- [x] Text scale alto con layout estable.
Done criteria:
- [x] Navegacion por teclado coherente en desktop.
- [x] Sin overflow visible en chrome principal con escala de texto elevada.

### F5 - Documentacion comercial y QA
Checklist:
- [x] Actualizar arquitectura del editor con nuevos modulos P9.
- [x] Actualizar Motion System con reglas de uso/no uso.
- [x] Actualizar release checklist con smoke tests P9.
Done criteria:
- [x] QA puede validar P9 sin pasos ambiguos.
- [x] Docs reflejan puntos de extension sin romper arquitectura actual.

## Validacion por fase
- `dart format --set-exit-if-changed .`
- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter test`
- `flutter build web --release --base-href "/bitacora_web/"` (si hubo cambios web/UI)
