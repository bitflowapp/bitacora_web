# QA Checklist

## Build Stamp & Version
- Abrir la app y verificar el Build Stamp (esquina inferior izquierda).
- Abrir `/version.json` en el navegador y comprobar que `gitSha` coincide con el último commit.
- En **Diagnósticos**, confirmar `version.json` y `ENGINE_BASE_URL`.

## Forzar Actualización
- En **Diagnósticos** tocar **Forzar actualización**.
- Si iOS Safari sigue mostrando lo viejo: Ajustes → Safari → Avanzado → Datos de sitios web → borrar el dominio.

## Smoke Test (rápido)
- Desde **Más** → **Smoke Test (GPS/Fotos/Audio)**, abrir la planilla y ejecutar los tres pasos.

## GPS Por Celda
- Seleccionar una celda y usar **GPS → Pegar en esta celda**.
- Confirmar texto visible y badge GPS en la celda.
- Probar modos **Elegir celda destino** y **Solo metadata**.
- Recargar la app y validar persistencia.

## Fotos Por Celda
- Adjuntar foto a una celda, confirmar miniatura/badge.
- Abrir galería, renombrar y borrar.
- Recargar y confirmar persistencia.
- Exportar ZIP y verificar `attachments/photos/` + hoja **Attachments**.

## Audio Por Celda
- Grabar audio en una celda y detener.
- Reproducir, renombrar y borrar.
- Recargar y confirmar persistencia.
- En iOS Safari: verificar fallback WAV o mensaje claro si no soporta grabación.
- Exportar ZIP y verificar `attachments/audio/` + hoja **Attachments**.

## Exportar / Compartir
- Exportar XLSX y abrir en Excel sin advertencias de reparación.
- Exportar ZIP: debe contener `Sheet.xlsx`, `manifest.json` y carpeta `attachments/`.
- Compartir: abrir el selector (WhatsApp/Gmail/Outlook según plataforma).

## Diagnósticos
- Verificar `Geolocation disponible`, `Micrófono soportado`, `Storage writable`.
- Verificar `MediaRecorder soportado` en web.
