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

## Deploy automático a GitHub Pages (project site)

Este repo publica automáticamente la web en cada push a `main` usando el workflow:

- `.github/workflows/deploy_pages.yml`

El build se ejecuta con base href de proyecto:

- `flutter build web --release --base-href "/bitacora_web/"`

### Activar GitHub Pages

1. Ir a **Settings → Pages** del repositorio.
2. En **Build and deployment**, elegir **Source: Deploy from a branch**.
3. Seleccionar **Branch: `gh-pages`** y **Folder: `/ (root)`**.
4. Guardar cambios.

URL esperada de publicación:

- `https://<user>.github.io/bitacora_web/`

### Forzar redeploy

Opciones para disparar una nueva publicación:

- Hacer un nuevo push a `main`.
- Ir a **Actions → Deploy to GitHub Pages (project)** y usar **Run workflow** (`workflow_dispatch`).
- Re-ejecutar un job previo con **Re-run jobs** desde Actions.
