# Bitácora Web (BitFlow)

Bitácora operativa con evidencias en un solo lugar. Pensado para PyMEs, municipal y equipos de campo. Funciona 100% local, sin servidores.

## Requisitos (usuario final)
- Windows 10/11
- Chrome o Edge

## Uso rápido (release ZIP)
1. Descomprimir el ZIP de entrega.
2. Doble click en `run.bat` (o `run.ps1`).
3. Se abre automáticamente en el navegador.

## Configuración (opcional)
- Edita `web\config.json` para cambiar marca, email, WhatsApp y precios.
- Si usás build desde código, podés editar `assets\config.json` o usar `--dart-define`.

## Desarrollo local
1. Instalar Flutter (estable).
2. `flutter pub get`
3. `flutter run -d chrome`

Para web release con el base-href correcto:
```
flutter build web --release --base-href /bitacora_web/
```

## Deploy a GitHub Pages
El repositorio publica automáticamente a GitHub Pages cuando hay push/merge a `main`.
La base-href de Pages es `/bitacora_web/`, por eso los scripts de release y QA lo fijan.

## Backups y reportes
- En la app: `Exportar -> Backup del proyecto (ZIP)` para resguardar todo.
- `Reporte HTML (imprimible)` para exportar a PDF desde el navegador.
- Importar: `Home -> Opciones -> Importar backup ZIP`.

## Reporte de issues
Cuando reportes un bug, incluí:
- sistema operativo + navegador
- pasos para reproducir
- resultado esperado vs. obtenido
- adjuntos (capturas, ZIP de ejemplo si aplica)

## UI / Design System
Guía visual y tokens en: `docs/ui/design_system.md`.

## Problemas comunes
- Script bloqueado: abrir PowerShell como Admin y ejecutar
  `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
- Puerto en uso: el script intenta otro puerto automáticamente.
- No abre el navegador: copiar el link que aparece en la consola y abrirlo.
- Export/Import: si el ZIP no tiene `backup.json`, el archivo no es válido.
