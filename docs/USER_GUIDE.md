# BitFlow User Guide (P11)

## 1. Flujo rapido diario
1. Abre una planilla y toca `+ Registro` para quick capture.
2. Completa campos clave en `Formulario` si necesitas editar fila completa.
3. Usa `Columnas` para ordenar, ocultar, fijar, renombrar y tipar.
4. Exporta en `PDF`, `XLSX` o `ZIP` (paquete completo con adjuntos).

## 2. Column panel (configuracion por planilla)
- Acceso: header `Columnas` o menu contextual de encabezado.
- Acciones:
  - Cambiar tipo (`Texto`, `Numero`, `Fecha`, `Estado`, `Checkbox`).
  - Marcar `Requerido`.
  - Definir `Enum` para columnas `Estado` (lista separada por coma).
  - Ocultar/mostrar columnas.
  - Fijar columna.
  - Reordenar columnas.
  - `Restaurar columnas por defecto`.
  - `Guardar como plantilla`.
  - `Aplicar plantilla`.
- Persistencia:
  - Se guarda por planilla.
  - Sobrevive refresh web, reinicio Android y PWA standalone iOS.

## 3. Validacion premium
- Errores detectados:
  - `required` (campo obligatorio vacio)
  - numero invalido
  - fecha invalida
  - enum invalido (columna Estado)
- UX:
  - Resaltado sutil monocromo en celdas invalidas.
  - Hint inline al editar (desktop y mobile).
  - Panel `Errores` opcional con salto directo a celda.
- Export:
  - Si hay errores, aparece modal:
    - `Exportar igual`
    - `Revisar errores`

## 4. Edicion ultrarrapida
- Navegacion:
  - `Tab` / `Shift+Tab`: siguiente/anterior celda editable.
  - `Enter` / `Shift+Enter`: bajar/subir celda editable.
- Pegado inteligente:
  - Soporta texto simple, TSV y CSV.
  - Pegado multi-celda por chunks para mantener UI fluida.
- Historial por columna:
  - Sugerencias instantaneas de valores recientes.

## 5. Exportar y compartir
- Android:
  - Share con archivo real (XLSX/PDF/ZIP) para WhatsApp o correo.
  - Fallbacks: share sheet, cliente de correo, `mailto`.
- Web/iOS:
  - Usa Web Share si esta disponible.
  - Fallback a descarga local cuando share no esta soportado.

## 6. Tips operativos
- Si trabajas offline, prioriza `ZIP` para respaldo completo con adjuntos.
- Usa `Panel de errores` antes de reportes finales.
- Guarda una plantilla de columnas por tipo de trabajo para arrancar mas rapido.
