# Export Pro Audit & Fixes (BitFlow)

Fecha: 2026-03-12
Objetivo: mejorar calidad de entregables exportados (XLSX/PDF/ZIP) para uso real en campo.

## Top 15 fricciones detectadas

### P1
1. ZIP con naming poco comercial/consistente.
- Síntoma: nombres de archivo difíciles de presentar.
- Causa: convención histórica heterogénea.
- Archivo: `lib/services/export_filename.dart`
- Fix: convención `BitFlow_<planilla>_<yyyy-mm-dd_hh-mm>.zip`.

2. XLSX interno del paquete con nombre genérico.
- Síntoma: dentro del ZIP no queda claro qué planilla es.
- Causa: nombre técnico por defecto.
- Archivo: `lib/services/export_filename.dart`
- Fix: `BitFlow_<planilla>.xlsx`.

3. Hoja de evidencias incompleta para trazabilidad de campo.
- Síntoma: faltan columnas de contexto (hoja/fila/fecha/ruta útil).
- Causa: modelo de adjuntos limitado.
- Archivo: `lib/services/export_xlsx_with_photos.dart`
- Fix: hoja `Evidencias` con columnas ampliadas y orden profesional.

4. Relación evidencia↔celda poco clara en archivos multimedia.
- Síntoma: fotos/videos con nombres ambiguos.
- Causa: naming sin referencia consistente.
- Archivo: `lib/features/editor/editor_state.dart`
- Fix: naming con tipo+planilla+referencia+timestamp.

5. Share de ZIP sin subject/text orientado a negocio.
- Síntoma: mensaje de compartido ambiguo.
- Causa: fallback genérico.
- Archivo: `lib/features/editor/actions/editor_export_share_helpers.dart`
- Fix: `BitFlow | <planilla>` + texto claro.

6. UX del selector de export no explica valor de cada formato.
- Síntoma: usuario no entiende cuándo elegir ZIP/PDF/XLSX.
- Causa: copy técnica.
- Archivo: `lib/features/editor/dialogs/export_dialogs.dart`
- Fix: labels orientados a resultado.

### P2
7. Mensajes de éxito/error de ZIP poco comerciales.
- Archivo: `lib/features/editor/editor_state.dart`
- Fix: feedback “Paquete completo listo …”.

8. Caso sin evidencias no explicitado.
- Archivo: `lib/features/editor/editor_state.dart`
- Fix: mensaje dedicado cuando no hay multimedia.

9. ZIP sin README orientado a receptor final.
- Archivo: `lib/features/editor/editor_state.dart`
- Fix: `README.txt` con estructura y recomendaciones de uso.

10. Manifest con poca guía sobre estructura del paquete.
- Archivo: `lib/features/editor/editor_state.dart`
- Fix: bloque `package` y rutas de evidencias.

11. Copy de opción ZIP antigua (`.bitflow.zip`) confusa.
- Archivo: `lib/ui/app_strings.dart`
- Fix: “Paquete completo (.zip)”.

### P3
12. Falta de consistencia terminológica en “Adjuntos/Evidencias”.
- Fix: estandarizar en “Evidencias”.

13. Rutas de evidencias mezclando carpetas antiguas.
- Fix: `evidencias/fotos|videos|audio`.

14. Pruebas de naming insuficientes para convención comercial.
- Fix: tests unitarios adicionales.

15. Tests del diálogo de export con expectativas viejas.
- Fix: smoke test actualizado a nuevos labels/copy.

---

## Resumen de mejoras aplicadas
- Naming profesional para ZIP/XLSX/evidencias.
- Hoja `Evidencias` mejorada en XLSX con contexto operativo.
- ZIP más completo y presentable: XLSX + manifest + sheet.json + README + carpetas de evidencias.
- Copy de export/share más claro para usuarios no técnicos.
- Cobertura de tests reforzada en naming, diálogo y hoja de evidencias.
