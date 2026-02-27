# Demo Script 90s (BitFlow P0)

Objetivo: demo corta (60-90s) para mostrar confiabilidad real.

## Setup (previo)

- Ejecutar web demo con:
  - `flutter build web --dart-define=DEMO_MODE=true --dart-define=AUTH_ENABLED=false`
- Tener una planilla de ejemplo o crearla en vivo.

## Guion cronometrado

1) 0s-10s | Home
- Abrir BitFlow.
- Mensaje: "Hoy mostramos estabilidad P0: menos errores falsos y flujos confiables".

2) 10s-25s | Nueva planilla
- Click en "Nueva planilla".
- Abrir editor y cargar 1-2 celdas rapido.

3) 25s-40s | Editar + adjuntar
- Editar una celda.
- Adjuntar foto/audio (si se puede) y mostrar que queda en la celda.

4) 40s-55s | Cancelacion correcta
- Abrir picker de adjunto o export y cancelar.
- Mensaje en demo: "Cancelar ya no se interpreta como error ni como exito".

5) 55s-75s | Exportar / compartir / guardar
- Exportar PDF o ZIP.
- Si hay fallback, explicar: "Se abre compartir/guardar sin falso success".

6) 75s-90s | Importar backup
- Volver a Inicio y ejecutar import de backup ZIP (o mostrar entrypoint).
- Cierre: "P0 lista para RC: test/build verdes y semantica robusta".

## Frases de apoyo (breves)

- "Cancelado != error != exito."
- "El usuario recibe feedback real, no humo."
- "RC validada con test/build web y auditoria P0."
