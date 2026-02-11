# BitFlow User Guide (P14)

## 1) Flujo recomendado (ahorro de tiempo real)
1. Crea/abre planilla y captura con `+ Registro` (quick capture).
2. Completa datos clave desde `Formulario`.
3. Configura `Columnas` (tipos, validacion, visibilidad, orden, fijadas).
4. Guarda una `Vista` para tu contexto (`Campo`, `Revision`, `Urgentes`).
5. Usa `Marcar revisado` al cerrar cada fila.
6. Exporta `PDF`, `XLSX` o `ZIP`.

## 2) Centro de calidad (validacion premium)
- Reglas por columna:
  - `required`
  - `number` con `min/max` opcional
  - `date` (parse robusto)
  - `enum/dropdown`
  - `regex` opcional
- UX:
  - celda invalida con resaltado monocromo sutil
  - hint inline al editar
  - panel `Errores` con salto directo a celda
  - indicador de errores en header
- Export gating:
  - si hay errores, modal:
    - `Exportar igual`
    - `Ir a errores`

## 3) Vistas guardadas
- Acceso:
  - chips de `Vista` en la barra superior
  - `Guardar vista`
  - `Gestionar vistas`
- Cada vista puede guardar:
  - filtros (`Estado`, `Fecha`, `Texto contiene`)
  - orden
  - columnas visibles/fijas/ordenadas
- Persistencia:
  - por planilla
  - web refresh, Android restart y iOS PWA standalone

## 4) Workflow revision/firmado
- Metadata por fila:
  - `Revisado` (si/no)
  - `RevisadoPor`
  - `RevisadoEn`
- Acciones:
  - `Marcar revisado` (toolbar, menu, command palette)
  - `Marcar pendiente`
  - vista `Pendientes de revision`
- PDF:
  - incluye columnas de revision cuando hay metadatos presentes

## 5) Acciones rapidas de productividad
- Command palette (`Ctrl/Cmd+K`) con:
  - `Ir a errores`
  - `Vista Urgentes`
  - `Marcar revisado`
  - `Duplicar ultima fila`
  - `Auto-ID`
  - `Usar ultimo valor`
- Smart paste:
  - pegado en chunks para no congelar UI
- Historial por columna:
  - sugerencias instantaneas
  - reaplicar ultimo valor de columna

## 6) Exportar y compartir
- Android:
  - comparte archivo real (`XLSX`, `PDF`, `ZIP`) en WhatsApp/correo
- Web/iOS:
  - usa share nativo cuando existe
  - fallback a descarga local

## 7) Recomendaciones operativas
- Antes de emitir reporte final:
  - abrir `Errores`
  - resolver validaciones bloqueantes
  - marcar filas revisadas
- Mantener vistas por rol:
  - `Campo` (captura)
  - `Revision` (control)
  - `Urgentes` (prioridad)

## 8) Historial y auditoria (P13)
- Abrir `Historial` desde toolbar o `Ctrl/Cmd+K`.
- Se registran eventos clave:
  - edicion de celda
  - insertar/eliminar fila
  - batch/paste/quick capture
  - revision/firmado
  - import/merge de paquetes
- Filtros:
  - `Hoy`
  - `Semana`
  - `Tipo`
- Cada evento permite `Ir a celda`.
- Retencion:
  - rolling log (limite por cantidad y ventana de dias).

## 9) Busqueda global (P13)
- `Ctrl/Cmd+F`: busqueda inline en planilla actual.
- `Ctrl/Cmd+Shift+F`: busqueda global.
- Query soportada:
  - texto libre (`urgente`)
  - `col:valor` (`Estado:Urgente`)
  - alias comunes (`status`, `fecha`).
- En resultados:
  - agrupado por planilla
  - click/tap para saltar a celda (incluye cambio de planilla con foco en destino).

## 10) Colaboracion asincronica por paquetes (P13)
- Abrir `Colaborar` desde toolbar o palette.
- Flujo:
  - exportar paquete (snapshot completo + metadata colaborativa)
  - compartir paquete
  - importar paquete
- Import con merge:
  - detecta planilla origen
  - merge automatico si cambian celdas distintas
  - conflicto si misma celda cambia distinto:
    - `Mantener local`
    - `Usar importado`
- Todo merge/import queda registrado en `Historial`.

## 11) Template Packs premium (P13)
- En `Nueva plantilla`, usar galeria `Template Packs`.
- Packs incluidos (3x3):
  - `Campo/Inspeccion`
  - `Obra/Avance`
  - `Relevamiento/GPS`
- Cada template incluye:
  - columnas + tipos + validaciones + defaults
  - vistas guardadas iniciales (`Campo`, `Revision`, `Urgentes`)
  - workflow de revision cuando aplica
- Antes de crear:
  - preview de columnas, reglas, vistas y tags del template.

## 12) Editor premium fluido + previews inline (P14)
- Escritura ultra fluida:
  - el editor evita rebuild global al tipear en una celda.
  - input/scroll y foco se mantienen estables en grillas grandes.
- Previews inline de adjuntos:
  - si una celda tiene adjuntos, muestra mini preview sin click.
  - imagenes usan thumbnail comprimido (no full-res) y badge `+N`.
  - PDF/doc muestran icono monocromo + nombre + tamano cuando no hay thumbnail.
- Toggle de performance:
  - `Preferencias de editor > Previews en celdas` (ON por defecto).
  - desactivar si priorizas menor uso de memoria en grillas muy grandes.
- Motion iOS-style:
  - micro-animaciones cortas (120-180ms) en barras/acciones del editor.
  - comportamiento visual monocromo consistente (sin acentos azules).
