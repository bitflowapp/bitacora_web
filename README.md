# Bitacora Pro (Windows)

Bitacora operativa con evidencias en 1 lugar. Pensado para PyMEs, municipal y equipos de campo. Funciona 100% local, sin servidores.

Requisitos
- Windows 10/11
- Chrome o Edge

Como usar en 3 pasos
1. Descomprimir el ZIP de entrega.
2. Doble click en `run.bat` (o `run.ps1`).
3. Se abre automaticamente en el navegador.

Configuracion (opcional)
- Edita `web\config.json` para cambiar marca, email, WhatsApp y precios.
- Si usas build desde codigo, podes editar `assets\config.json` o usar `--dart-define`.

Backup y reportes
- En la app: `Exportar -> Backup del proyecto (ZIP)` para resguardar todo.
- `Reporte HTML (imprimible)` para exportar a PDF desde el navegador.
- Importar: `Home -> Opciones -> Importar backup ZIP`.

Problemas comunes
- Script bloqueado: abrir PowerShell como Admin y ejecutar
  `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
- Puerto en uso: el script intenta otro puerto automaticamente.
- No abre el navegador: copiar el link que aparece en la consola y abrirlo.
- Export/Import: si el ZIP no tiene `backup.json`, el archivo no es valido.
