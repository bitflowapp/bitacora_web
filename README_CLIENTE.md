# Bitacora Web (Guia para cliente)

## Que es
Bitacora Web es una app local para registrar actividades, evidencias (fotos/audio/GPS) y generar respaldos o reportes sin servidor.

## Requisitos
- Windows 10/11
- Google Chrome o Microsoft Edge

## Como usar en 3 pasos
1. Descomprimir el ZIP en una carpeta (por ejemplo `C:\BitacoraWeb`).
2. Doble click en `run.bat` (o `run.ps1`).
3. Se abre el navegador en `http://localhost:8787`.

## Configuracion rapida (opcional)
Antes de abrir la app, edita:
- `dist_release\web\config.json`

Campos comunes:
- `brandName`
- `brandTagline`
- `contactEmail`
- `contactWhatsApp`

## Exportar e importar
- Exportar backup ZIP: dentro del Editor (menu Exportar).
- Importar backup ZIP: en Inicio > Opciones > Importar backup ZIP.
- Reporte HTML: dentro del Editor (Exportar Reporte HTML).

## Problemas comunes
- **El script esta bloqueado**
  - Abrir PowerShell y ejecutar:
    `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser`
- **Puerto en uso**
  - `run.ps1` prueba 8787-8799 automaticamente.
- **No se abre el navegador**
  - Abrir manualmente `http://localhost:8787`.
- **No veo cambios de config**
  - Cerrar y volver a abrir `run.bat`.
- **Se lleno el almacenamiento**
  - Exportar un backup ZIP y limpiar adjuntos antiguos.

## Soporte
- Email: el definido en `config.json`.

