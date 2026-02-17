# Bug Sweep

## Objetivo
`bug_sweep.ps1` ejecuta una revisión repetible para detectar:
- Mojibake frecuente en `lib/` (`Ã`, `Â`, `â€¦`, `â€™`, `â€“`, `â€”`).
- Strings de UI en inglés sospechosas en `lib/` (`Jump`, `Maps`, `Photos`, `Quick actions`, `Attachments`).

También imprime contexto del repo al inicio (`git status -sb` y `git diff --stat`).

## Cómo correrlo
Desde la raíz del repo:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bug_sweep.ps1
```

## Códigos de salida
- `0`: no se encontraron hallazgos.
- `2`: se encontraron hallazgos (sirve para usarlo como gate en CI).
- `1`: error de ejecución (por ejemplo, `git` no disponible o falla inesperada de `git grep`).

Nota: `git grep` con código `1` por "sin matches" se considera normal y **no** falla el script.

## Qué hacer si hay hallazgos
1. Revisar las entradas reportadas (`[categoria] [patrón] archivo:línea`).
2. Abrir el archivo y validar si el texto es un error real o un falso positivo.
3. Si es mojibake, corregir el literal al texto esperado en UTF-8.
4. Si es string en inglés no deseada, moverla al copy correcto en español o a la capa de strings centralizada del proyecto.
5. Volver a correr el sweep:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bug_sweep.ps1
```

6. Antes de merge/release, ejecutar verificación rápida:

```powershell
powershell -ExecutionPolicy Bypass -File .\verify.ps1 -Fast
```
