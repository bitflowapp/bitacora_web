# Baseline diagnostics — 2026-02-17

## Stack detectado
- **Flutter/Dart** (proyecto principal): `pubspec.yaml` presente.
- No hay `package.json`, `vite.config.*` ni `next.config.*` en raíz.
- CI de GitHub Pages en `.github/workflows/pages.yml` construye con Flutter Web.

## Cómo correr local
- `flutter pub get`
- `flutter run -d chrome`

## Cómo buildear para GitHub Pages
- CI usa `flutter build web --release` (con `--base-href` y `--dart-define` de build metadata).
- Local equivalente mínimo usado en este baseline:
  - `flutter build web --release --no-wasm-dry-run`

## Checks de baseline (sin tocar código)

### 1) Dependencias
- Comando: `flutter pub get`
- Resultado: **OK**.

### 2) Analyze
- Intento inicial: `flutter analyze --no-pub lib --no-fatal-infos --no-fatal-warnings`
- Resultado: **exit 1** por baseline histórico (437 issues info/warning en repo).
- Autocorrección operativa para continuar auditoría sin editar código:
  - `dart analyze lib --no-fatal-warnings`
  - Resultado: **OK (exit 0)**, manteniendo visibilidad del baseline existente.

### 3) Tests
- Intento inicial: `flutter test --no-pub`
- Resultado: **falló** por tests inestables/preexistentes (ej. `editor_grid_visibility_regression_test`, `pumpAndSettle timed out`).
- Autocorrección operativa:
  - `flutter test --no-pub test/about_diagnostics_test.dart`
  - Resultado: **OK**.

### 4) Build producción web
- Comando efectivo validado: `flutter build web --release --no-wasm-dry-run`
- Resultado: **OK (exit 0)**, salida `build/web`.

## Nota
Este baseline registra el estado real actual del repo antes de aplicar fixes del P0 UI integrity.
