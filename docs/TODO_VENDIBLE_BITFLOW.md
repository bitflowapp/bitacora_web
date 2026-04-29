# TODO Vendible Bit Flow

Fecha: 2026-02-24
Objetivo: priorizar tareas para pasar de demo-vendible a MVP cobrable estable.

---

## P0 — Crítico (bloquea calidad comercial seria)

### P0.1 Reducir warnings reales de analyzer en hotspots
- **Tarea:** resolver warnings de lógica/estructura en archivos críticos (no solo deprecaciones cosméticas).
- **Criterio de aceptación:**
  - `flutter analyze` mantiene build estable y reduce warnings reales en:
    - `lib/widgets/gps_map_toolbar.dart`
    - `lib/widgets/mobile_notes_grid.dart`
    - `lib/start_page.dart`
    - `lib/features/editor/editor_state.dart`
  - No se introducen fallos de tests.

### P0.2 Definir entrypoint único de Home
- **Tarea:** dejar explícito cuál `StartPage` es oficial y aislar/eliminar legacy duplicado.
- **Criterio de aceptación:**
  - Un único StartPage referenciado por rutas principales.
  - Documento breve en repo explicando el flujo real.

### P0.3 Hardening de persistencia de adjuntos por cuota
- **Tarea:** detectar y comunicar claramente cuando el navegador entra en límites de storage/fallback.
- **Criterio de aceptación:**
  - Mensaje de usuario accionable cuando hay riesgo de pérdida por cuota.
  - Test de regresión para escenario de fallo de persistencia.

### P0.4 Normalizar errores de guardado/exportación
- **Tarea:** asegurar feedback consistente y no técnico en guardar/exportar/compartir.
- **Criterio de aceptación:**
  - Cada operación core tiene estado de éxito/error/cancelación claro.
  - No quedan mensajes ambiguos tipo “falló” sin acción sugerida.

---

## P1 — Mejora fuerte para vender mejor

### P1.1 Partición progresiva de `editor_state.dart`
- **Tarea:** separar por dominios (save-load, export-share, offline-sync, attachments) sin cambiar comportamiento.
- **Criterio de aceptación:**
  - Compila y tests en verde.
  - Archivo principal reduce tamaño/complejidad visible.

### P1.2 Partición progresiva de `start_page.dart`
- **Tarea:** extraer onboarding, toolbar, empty states y modales en componentes dedicados.
- **Criterio de aceptación:**
  - Navegación y UX actual intactas.
  - Menor acoplamiento entre UI y lógica de negocio.

### P1.3 Baseline de deuda técnica controlada
- **Tarea:** registrar baseline de analyzer (categorías y archivos top) y meta de reducción por sprint.
- **Criterio de aceptación:**
  - Archivo de seguimiento de deuda técnica versionado.
  - Objetivo cuantitativo por sprint (ej. -20% warnings relevantes).

### P1.4 README de demo comercial corto
- **Tarea:** agregar guía de 1 página: cómo correr demo, flujo recomendado de venta, límites actuales.
- **Criterio de aceptación:**
  - Cualquier persona puede levantar demo y ejecutar guion básico en <10 min.

---

## P2 — Nice to have / premium

### P2.1 Unificar strings y naming
- **Tarea:** reducir duplicación entre `core/i18n/app_strings.dart` y `ui/app_strings.dart`.
- **Criterio de aceptación:**
  - Fuente de verdad clara para textos de UI.

### P2.2 Limpieza de legado documental y encoding
- **Tarea:** normalizar archivos con texto mojibake y depurar docs históricas redundantes.
- **Criterio de aceptación:**
  - Textos legibles consistentes (sin caracteres corruptos).
  - Menos ruido para mantenimiento.

### P2.3 Plan de upgrade de dependencias
- **Tarea:** roadmap por lotes para paquetes desactualizados (sin migración masiva de una vez).
- **Criterio de aceptación:**
  - Lista priorizada de upgrades críticos con riesgo/beneficio.

---

## Orden recomendado de ejecución
1. P0.1
2. P0.2
3. P0.3
4. P0.4
5. P1.1
6. P1.2
7. P1.3
8. P1.4
9. P2.*
