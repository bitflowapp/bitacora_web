# BitFlow User Guide (P12)

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
