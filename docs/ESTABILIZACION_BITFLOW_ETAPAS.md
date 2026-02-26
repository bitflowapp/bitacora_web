# Estabilización BitFlow (sin features nuevas)

Fecha: 2026-02-25
Objetivo: confiabilidad y reducción de bugs sin cambios estéticos ni nuevas dependencias.

---

## Etapa 1 — Auditoría funcional (flujo por flujo)

### Flujos principales auditados

1. **Crear planilla**
   - Entrada: Home (`lib/start_page.dart`) → `_createAndOpenSheet`, `_newSheet`, `_newTemplateSheet`
   - Persistencia: `SheetStore` (`lib/services/sheet_store.dart` + impl)

2. **Abrir / listar / renombrar / mover a papelera / restaurar / borrar**
   - Entrada: Home (`lib/start_page.dart`) → `_open`, `_rename`, `_moveToTrash`, `_restoreFromTrash`, `_deleteForever`

3. **Editar celdas en planilla**
   - Entrada: Editor (`lib/features/editor/editor_screen.dart` + `editor_state.dart`)
   - Operaciones: edición de texto, selección, duplicado de filas, pegar inteligente, validación por reglas

4. **Guardar cambios**
   - Entrada: `_saveLocalNow` y guardado automático (Editor)
   - Persistencia segura: staging/backup/snapshot (`editor_state.dart`)

5. **Adjuntos por celda (GPS, foto, audio, archivos)**
   - Entrada: barra acciones + command palette (`editor_actions.dart`)
   - Almacenamiento: `AttachmentStore`, `AudioStorageService`, `WebBlobStore`

6. **Exportar**
   - XLSX / ZIP / Backup ZIP / HTML / PDF
   - Entrada: menú exportación y command palette
   - Archivos clave: `editor_state.dart`, `services/export_*`

7. **Compartir**
   - Entrada: flujo de export + share
   - Servicios: `share_plus`, helpers de exportación

8. **Importar backup ZIP**
   - Entrada: Home → `_importBackupZip`

9. **Diagnósticos y smoke test**
   - Entrada: Home → `_openDiagnostics`, `_createSmokeTestSheet`
   - Cobertura: GPS/Foto/Audio + storage + versión

---

## Etapa 2 — Bugs detectados y correcciones aplicadas

### A. Bug real de texto corrupto (mojibake) en mensajes de geolocalización web
- **Impacto:** mensajes con caracteres corruptos al usuario en errores GPS web.
- **Archivo:** `lib/services/location_web_impl_web.dart`
- **Corrección:** normalización de textos (UTF-8 correcto) + fallback explícito para errores inesperados sin romper los errores específicos existentes.

### B. Manejo de error genérico faltante en geolocalización web
- **Impacto:** excepciones no mapeadas podían llegar crudas o poco claras.
- **Archivo:** `lib/services/location_web_impl_web.dart`
- **Corrección:** `catch` final con mensaje accionable y log en debug (`[web-gps] unexpected error: ...`).

### C. Clasificación de fallback de storage sensible a mayúsculas/espacios
- **Impacto:** reason codes válidos con formato distinto terminaban en fallback genérico.
- **Archivo:** `lib/features/editor/editor_state.dart`
- **Corrección:** normalización con `trim().toLowerCase()` en `classifyEditorStorageFallbackReason`.

### D. Falta de log útil al degradar a almacenamiento temporal
- **Impacto:** difícil diagnóstico cuando adjuntos caían en modo temporal RAM/session-only.
- **Archivo:** `lib/features/editor/editor_state.dart`
- **Corrección:** log debug con tipo, reason original y reason mapeado:
  - `[EditorScreen] storage_fallback kind=... reason=... mapped=...`

### E. Stub XLSX no-web con comportamiento ambiguo
- **Impacto:** en plataformas no-web podía parecer éxito silencioso.
- **Archivo:** `lib/services/export_xlsx_saver_stub.dart`
- **Corrección:** lanza `UnsupportedError` explícito para evitar falsos positivos de exportación.

---

## Etapa 3 — Validación de estabilidad (automatizada)

### Tests agregados/actualizados

1. `test/editor_storage_fallback_reason_test.dart`
   - Nuevo caso: normalización de `reasonCode` con espacios + mayúsculas.

2. `test/storage_diagnostics_test.dart`
   - Nuevo caso: clasificación case-insensitive de errores de cuota.

### Resultado de corrida

- `flutter test test/editor_storage_fallback_reason_test.dart test/storage_diagnostics_test.dart` ✅
- `flutter test` (suite completa) ✅

---

## Checklist manual de estabilización (QA)

### Home / gestión de planillas
- [ ] Crear planilla nueva desde Home.
- [ ] Abrir planilla existente.
- [ ] Renombrar planilla.
- [ ] Mover a papelera, restaurar y borrar definitivo.
- [ ] Importar backup ZIP válido e inválido (ver mensaje claro).

### Edición y guardado
- [ ] Editar 3-5 celdas y guardar manual.
- [ ] Recargar navegador y confirmar persistencia.
- [ ] Probar deshacer/rehacer en cambios simples.

### GPS/foto/audio
- [ ] GPS: permiso denegado (mensaje claro) y permiso concedido.
- [ ] Foto: adjuntar, recargar, verificar miniatura y persistencia.
- [ ] Audio: grabar/reproducir, recargar, verificar persistencia.

### Exportar/compartir
- [ ] Exportar XLSX y abrir en Excel.
- [ ] Exportar ZIP y verificar `manifest.json` + `attachments/`.
- [ ] Exportar Backup ZIP e importar nuevamente.
- [ ] Compartir: cancelar selector (no debe mostrar éxito falso).

### Diagnóstico/storage
- [ ] Abrir Diagnósticos y validar estado de storage.
- [ ] Simular navegador en modo incógnito: verificar aviso de guardado temporal.
- [ ] Revisar logs debug para fallback storage y errores GPS.

---

## Archivos modificados en esta etapa

- `lib/services/location_web_impl_web.dart`
- `lib/features/editor/editor_state.dart`
- `lib/services/export_xlsx_saver_stub.dart`
- `test/editor_storage_fallback_reason_test.dart`
- `test/storage_diagnostics_test.dart`
- `docs/ESTABILIZACION_BITFLOW_ETAPAS.md`
