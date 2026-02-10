# BitFlow Premium Plan (P7)

## Objetivo
Entregar una experiencia premium tipo Apple/Microsoft en BitFlow, manteniendo compatibilidad con Android offline y Web/PWA (incluyendo iOS Safari dentro de sus limites), sin romper Pages ni features previas (P2/P3/P6).

## Reglas de ejecucion
- Cambios quirurgicos sobre arquitectura existente.
- Commits separados por fase.
- En cada fase: format + analyze + test; build web cuando haya cambios web/UI.
- No subir APK ni artefactos.

## Riesgos y limitaciones por plataforma
- Web/iOS Safari:
  - Service Worker y cache pueden retener version vieja; usar ForceUpdateService y cache busting.
  - Compartir archivos es mas limitado que Android; fallback a descarga.
  - Safari puede matar pestañas en background; minimizar perdida con flush por lifecycle/visibility/pagehide.
- Android:
  - Permisos (camara, gps, microfono, almacenamiento) pueden bloquear flujos de adjuntos.
  - Compartir depende de apps instaladas y providers del sistema.
- Desktop/Web general:
  - Atajos pueden colisionar con browser/OS; mantener defaults conocidos y comportamiento predecible.

## Fases

### F1 - Design System v2 (monocromo premium)
Checklist:
- [x] Unificar tokens de color/radio/sombra/espaciado en monocromo.
- [x] Pulir botones, inputs, chips y modales con focus/hover/pressed consistentes.
- [x] Mejorar microcopy de estados vacios y mensajes base.
Done:
- [x] No hay acentos de color fuera de escala de grises en componentes core.
- [x] Controles base se sienten consistentes en desktop y mobile.

### F2 - Editor Premium pass (UX, bugs, performance)
Checklist:
- [x] Pulir topbar/toolbar/chips con jerarquia visual clara.
- [x] Mejorar feedback de seleccion y estado de grilla.
- [x] Ajustar shortcuts y command palette para acciones de alto uso.
- [x] Resolver bugs visibles de overlays/focus/scroll y reducir rebuilds innecesarios.
Done:
- [x] Flujo guardar/buscar/exportar/adjuntar en 1-2 interacciones.
- [x] Navegacion por teclado y cierre con ESC consistente.

### F3 - Offline + Share hardening
Checklist:
- [x] Reforzar estado de cola offline y retry/backoff con feedback claro.
- [x] Mejorar experiencia export/share (Android share sheet, Web fallback).
- [x] Pulir helper iOS/PWA + update/cache coherente con ForceUpdateService.
Done:
- [x] Offline no rompe edicion y usuario entiende estado/siguiente paso.
- [x] Export y share tienen resultado claro o fallback explicitado.

### F4 - Productividad (ahorro de tiempo)
Checklist:
- [x] Mejorar acciones por lote mas usadas.
- [x] Potenciar autocomplete/defaults reutilizando logica actual.
- [x] Pulir galeria de templates y validaciones rapidas.
Done:
- [x] Operaciones repetitivas requieren menos taps/clicks y menos errores.

### F5 - Docs + QA comercial
Checklist:
- [x] Actualizar release checklist con smoke tests reales de P7.
- [x] Barrido de mojibake en `lib/` y `docs/`.
- [x] Verificar builds y dejar evidencia de despliegue.
Done:
- [x] Checklist utilizable por QA/manual release sin pasos ambiguos.

## Comandos de validacion por fase
- `dart format --set-exit-if-changed .`
- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter test`
- `flutter build web --release --base-href "/bitacora_web/"` (si hay cambios web/UI)
