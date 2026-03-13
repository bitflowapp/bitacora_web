# EXPORT PRO Audit + Fixes (XLSX / PDF / ZIP)

Fecha: 2026-03-12  
Alcance: flujo de exportación de planilla con evidencias para uso en campo y envío a terceros.

## Top 15 fricciones detectadas y plan/fix aplicado

| # | Prioridad | Síntoma | Causa raíz | Archivo(s) | Fix aplicado |
|---|---|---|---|---|---|
| 1 | P1 | El ZIP “paquete completo” no traía PDF | El armador ZIP solo adjuntaba XLSX y assets | `lib/features/editor/editor_state.dart` | Se agregó generación de PDF y se incluye en ZIP (`BitFlow_<planilla>_reporte.pdf`). |
| 2 | P1 | Estructura ZIP incompleta para intercambio profesional | No se forzaban carpetas `evidencias/` y subcarpetas | `lib/features/editor/editor_state.dart` | Se agregan entradas explícitas de carpetas: `evidencias/`, `fotos/`, `videos/`, `audio/`. |
| 3 | P1 | Hoja “Evidencias” de XLSX sin lat/lon | Modelo de fila de adjunto sin campos geográficos | `lib/services/export_xlsx_with_photos.dart`, `lib/features/editor/editor_state.dart` | `AttachmentRow` ahora incluye `latitude/longitude`; columnas `Latitud` y `Longitud` en la hoja. |
| 4 | P1 | Nombres de evidencia inconsistentes para fotos no-image MIME | Fallback a tipo `archivo` en vez de prefijo homologado | `lib/features/editor/editor_state.dart` | Se unificó a prefijos requeridos: `foto_`, `video_`, `audio_`. |
| 5 | P1 | XLSX de exportación individual no seguía naming comercial acordado | Se usaba nombre con fecha para todos los formatos | `lib/features/editor/editor_state.dart` | XLSX ahora usa `BitFlow_<planilla>.xlsx` (sin fecha). |
| 6 | P1 | Mensajes de compartir/guardar ambiguos (“archivo”) | Copy genérico sin distinguir formato | `lib/features/editor/actions/editor_export_share_helpers.dart` | Mensajes dinámicos por formato (XLSX/PDF/ZIP/HTML) y fallback más claro al guardar. |
| 7 | P2 | XLSX con lectura básica, poco “pro” visual | Header simple sin tema visual ni zebra striping | `lib/services/export_xlsx_with_photos.dart` | Nuevo estilo profesional: header destacado + filas alternadas + bordes finos. |
| 8 | P2 | Encabezados sin filtros | No se aplicaba `autoFilter` en planilla principal | `lib/services/export_xlsx_with_photos.dart` | Se activa filtro en rango usado. |
| 9 | P2 | Cabecera se pierde al navegar planilla grande | Sin freeze panes | `lib/services/export_xlsx_with_photos.dart` | Se congela la primera fila en planilla principal y hoja Evidencias. |
| 10 | P2 | Fechas/números poco legibles (texto crudo ISO) | Faltaban number formats en celdas parseadas | `lib/services/export_xlsx_with_photos.dart` | Formatos: fecha `yyyy-mm-dd hh:mm`, números y GPS con precisión adecuada. |
| 11 | P2 | PDF correcto pero poco ejecutivo en portada | Título y estructura no optimizados para cliente | `lib/features/editor/editor_state.dart` | Encabezado profesional, planilla/datetime visibles y sección “Tabla principal”. |
| 12 | P2 | Manifest no explicitaba reporte PDF del paquete | Metadata package incompleta | `lib/features/editor/editor_state.dart` | `manifest.json` ahora incluye `package.report`. |
| 13 | P2 | README del paquete incompleto | No listaba PDF ni guía explícita | `lib/features/editor/editor_state.dart` | README incluye XLSX + PDF + evidencias + manifest + sheet.json + README. |
| 14 | P3 | Copys del diálogo de exportación poco claros | Etiquetas cortas y descriptivos genéricos | `lib/features/editor/dialogs/export_dialogs.dart` | Etiquetas claras: “Excel (.xlsx)”, “Reporte PDF (.pdf)”, “Paquete completo (.ZIP)” + descripciones específicas. |
| 15 | P3 | Cobertura de tests insuficiente en ZIP estructural/copy | Faltaban pruebas enfocadas de estructura y UX copy | `test/editor_export_zip_package_test.dart`, `test/editor_export_dialog_smoke_test.dart`, `test/editor_export_feedback_smoke_test.dart`, `test/export_xlsx_with_photos_test.dart`, `test/export_filename_test.dart` | Se añadieron/actualizaron tests para naming, columnas evidencias, estructura ZIP y mensajes de diálogo/feedback. |

## Notas de alcance

- No se reescribió arquitectura de exportación.
- No se incorporaron dependencias nuevas.
- Se trabajó sobre flujo existente de generación y empaquetado.
