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

## Web movil (iOS/Android): edicion de celdas y teclado

Compatibilidad esperada:
- iOS Safari (incluye PWA agregada a Home Screen)
- Android Chrome

Que se corrige:
- El teclado no debe tapar el editor de celdas.
- El input activo debe quedar visible al entrar en edicion.
- Se evita recorte de media pantalla al abrir/cerrar teclado en web movil.

Pasos de prueba manual:
1. Abrir la app web en iPhone (Safari) y Android (Chrome).
2. Entrar al editor y tocar una celda en filas bajas (cerca del final visible).
3. Verificar que el editor se desplace/acomode y el input quede visible.
4. Escribir texto, presionar `Done` y validar que se guarda y cierra foco.
5. Cambiar entre celdas consecutivas y confirmar que no hay saltos bruscos ni overlay cortado.
6. Probar rotacion (portrait/landscape) y repetir.

Notas cache/SW en debug:
- Hard refresh recomendado: `Ctrl+F5` (Windows) / recarga forzada en Safari.
- Si necesitas desactivar SW para diagnostico, abrir con `?sw=0`.
- Badge de build solo aparece con `?debug=1`.

Build release web:
```bash
flutter build web --release
```

Servir `build/web` localmente:
```bash
cd build/web
python -m http.server 8080
```
Abrir `http://localhost:8080`.
