# QA Checklist

## Build
- flutter analyze (0 errors)
- flutter test
- flutter build web --release --base-href "/bitacora_web/"
- flutter build apk --release
- iOS: build and run, permisos correctos (GPS/microfono/camara/fotos)

## Funcionalidad critica
- Guardar / cargar planillas
- Exportar XLSX y abrir en Excel sin reparaciones
- Exportar ZIP (XLSX + attachments + manifest.json)
- Share: XLSX y ZIP via share sheet
- GPS:
  - Permisos denegados -> dialogo claro
  - Insertar texto en celda
  - Guardar metadata solamente
  - Elegir celda destino
- Fotos:
  - Adjuntar / ver / renombrar / borrar
  - Export: primera foto embebida por celda
- Audio:
  - Grabar / reproducir / renombrar / borrar (Android/iOS)
  - Web: grabacion habilitada si el navegador lo soporta
- Calculadora: expresiones offline (+-*/%^, par√©ntesis)
- Atajos desktop/web:
  - Ctrl+S guardar
  - Ctrl+E exportar XLSX
  - Ctrl+Shift+E exportar ZIP
  - Ctrl+G GPS en celda
  - Ctrl+Shift+A audio en celda
  - Ctrl+P fotos en celda

## Known limitations
- Audio no reproduce dentro de Excel (solo se exporta como archivo adjunto en ZIP).
- Grabacion web puede estar limitada por el navegador (Safari/iOS web).

## Build stamp
- Verificar que se vea "Build: <sha> ï <YYYY-MM-DD HH:mm>" en pantalla principal.

## Cache / actualizacion
- Chrome: DevTools ? Application ? Service Workers ? Unregister + Clear site data + hard reload.
- iOS Safari: Ajustes ? Safari ? Avanzado ? Datos de sitios web ? borrar para el dominio.
