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

## Deploy a GitHub Pages

Este repo tiene un workflow automático en `.github/workflows/deploy_gh_pages.yml` que publica la app web en **GitHub Pages (project pages)** usando la rama `gh-pages`.

### Configuración en GitHub

1. Ir a **Settings → Pages** del repositorio.
2. En **Source**, seleccionar **Deploy from a branch**.
3. Elegir **Branch: `gh-pages`** y **Folder: `/ (root)`**.
4. Guardar los cambios.

La URL esperada queda como:
- `https://<user>.github.io/bitacora_web/`

### Base href requerido

El build se genera con:

```bash
flutter build web --release --base-href "/bitacora_web/"
```

Ese `base-href` es obligatorio para que los assets y rutas funcionen correctamente en project pages.

### Cómo se dispara el deploy

- Automático: cada `push` a `main`.
- Manual: desde **Actions → Deploy to gh-pages → Run workflow** (`workflow_dispatch`).

### Verificar estado del deploy

- Ir a la pestaña **Actions** y abrir el workflow **Deploy to gh-pages**.
- Confirmar que los pasos `Build Flutter Web for GitHub Pages` y `Deploy build/web to gh-pages branch` finalicen en verde.
- Luego validar que el último commit exista en la rama `gh-pages` y que el sitio cargue en la URL final.

### Checklist rápido

- [ ] Workflow `Deploy to gh-pages` ejecutado sin errores.
- [ ] Rama `gh-pages` actualizada con el contenido de `build/web`.
- [ ] Settings → Pages apuntando a `gh-pages` / root.
- [ ] Sitio publicado en `https://<user>.github.io/bitacora_web/`.
