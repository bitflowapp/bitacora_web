# UI Copy EN Backlog (Top-20 files)

## Alcance y criterio
- Fuente: `logs/bug_sweep_report.json` (752 english findings) y revisión manual de los 20 archivos con más matches.
- Incluye solo texto probablemente visible para usuario final (labels, menús, mensajes, subject de share, nombres/headers de exportación).
- Excluye identificadores técnicos, nombres de clases/variables, keys internas, rutas, imports y comentarios de implementación.

## Backlog priorizado (EN -> ES sugerido)
1. **P0**
Archivo: `lib/features/editor/editor_state.dart:11347`
Original: `Done`
Sugerido: `Listo`

2. **P0**
Archivo: `lib/features/editor/attachments/attachments_controller.dart:3467`
Original: `Smoke Test (GPS/Foto/Audio)`
Sugerido: `Prueba rápida (GPS/Foto/Audio)`

3. **P0**
Archivo: `lib/start_page.dart:3178`
Original: `Smoke Test (GPS/Fotos/Audio)…`
Sugerido: `Prueba rápida (GPS/Fotos/Audio)…`

4. **P0**
Archivo: `lib/start_page.dart:1666`
Original: `Smoke Test`
Sugerido: `Prueba rápida`

5. **P0**
Archivo: `lib/services/export_xlsx_with_photos.dart:561`
Original: `Attachments` (nombre de hoja XLSX)
Sugerido: `Adjuntos`

6. **P0**
Archivo: `lib/services/export_xlsx_with_photos.dart:564`
Original: `CellRef`
Sugerido: `Referencia de celda`

7. **P0**
Archivo: `lib/services/export_xlsx_with_photos.dart:564`
Original: `Type`
Sugerido: `Tipo`

8. **P0**
Archivo: `lib/services/export_xlsx_with_photos.dart:564`
Original: `FileName`
Sugerido: `Nombre de archivo`

9. **P0**
Archivo: `lib/services/export_xlsx_with_photos.dart:564`
Original: `Notes`
Sugerido: `Notas`

10. **P0**
Archivo: `lib/services/export_xlsx_with_photos.dart:564`
Original: `Path`
Sugerido: `Ruta`

11. **P1**
Archivo: `lib/features/editor/editor_state.dart:19843`
Original: `Web Share no soportado. Archivo descargado.`
Sugerido: `Compartir web no compatible. Archivo descargado.`

12. **P1**
Archivo: `lib/features/editor/editor_state.dart:19872`
Original: `BitFlow Export` (subject de compartir)
Sugerido: `Exportación de Bit Flow`

13. **P1**
Archivo: `lib/features/editor/editor_state.dart:19898`
Original: `BitFlow Export` (subject de compartir)
Sugerido: `Exportación de Bit Flow`

14. **P1**
Archivo: `lib/features/editor/editor_state.dart:19885`
Original: `Export` (label de tipo para guardar)
Sugerido: `Exportar`

15. **P1**
Archivo: `lib/features/editor/editor_state.dart:20290`
Original: `Engine CHECK...`
Sugerido: `Chequeo del motor...`

16. **P1**
Archivo: `lib/start_page.dart:2971`
Original: `Engine error HTTP ...`
Sugerido: `Error HTTP del motor ...`

17. **P1**
Archivo: `lib/features/editor/editor_state.dart:20278`
Original: `Failed to fetch`
Sugerido: `No se pudo obtener respuesta`

18. **P1**
Archivo: `lib/start_page.dart:2975`
Original: `Failed to fetch`
Sugerido: `No se pudo obtener respuesta`

19. **P2**
Archivo: `lib/start_page.dart:2728`
Original: `Modo AUTO usa ... pasa a MANUAL ...`
Sugerido: `Modo Automático usa ... pasa a Manual ...`

20. **P2**
Archivo: `lib/start_page.dart:2729`
Original: `Modo AUTO intenta ... en MANUAL.`
Sugerido: `Modo Automático intenta ... en Manual.`

21. **P2**
Archivo: `lib/start_page.dart:2736`
Original: `AUTO`
Sugerido: `Automático`

22. **P2**
Archivo: `lib/start_page.dart:2737`
Original: `MANUAL`
Sugerido: `Manual`

## Notas de descarte (no UI o baja prioridad)
- Se descartaron ocurrencias en `editor_state.dart`, `attachments_controller.dart`, `grid_host.dart`, `mobile_notes_grid.dart`, `editor_models.dart`, `sheet_store_*.dart`, `attachment_store.dart`, `sync_coordinator.dart` y similares por ser:
  - nombres de funciones/campos (`openAttachments`, `jumpTo`, `uploadStatus...`),
  - claves internas (`attachments`, `upload_attachment...`),
  - tipos/modelos (`AttachmentUploadInfo`, `EmbeddedPhoto`),
  - comentarios técnicos o código de infraestructura.
- También se dejaron fuera términos de marca/proveedor (`Google Maps`, `FastAPI`, `XLSX`, `PDF`) salvo cuando forman parte de copy directamente mejorable.
