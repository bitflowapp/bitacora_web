# Auditoría UI — Bit Flow (Abril 2026)

> Rama: `codex/professional-report-exports`  
> Scope: Flutter/Dart, sin tocar lógica de negocio.

---

## 1. Estado General

El frontend tiene buenas intenciones (Apple HIG, tokens, tipografía consistente) pero creció con **dos sistemas de diseño paralelos** que nunca se unificaron. El resultado es colisión de nombres, valores de spacing distintos y componentes duplicados. La superficie de riesgo para un rediseño es baja si se sigue el plan por etapas.

---

## 2. Hallazgos Críticos

### 2.1 Dos sistemas de tokens con nombres iguales y valores diferentes

| Clase | Archivo | xs | sm | md | lg | xl |
|---|---|---|---|---|---|---|
| `AppSpacing` (design_system) | `lib/design_system/spacing.dart` | 4 | 8 | 12 | 16 | 24 |
| `AppSpacing` (theme) | `lib/theme/app_theme.dart` | 6 | 10 | 14 | 20 | 28 |
| `AppColors` (design_system) | `lib/design_system/colors.dart` | static helpers por brightness | — | — | — | — |
| `AppColors` (theme) | `lib/theme/app_theme.dart` | instancia rica: bg, surface, dangerFg, successFg… | — | — | — | — |

`lib/theme/app_theme.dart` importa `design_system/colors.dart` con alias `as ds` para evitar colisión. Cualquier dev que importe ambos sin alias entra en conflicto silencioso.

### 2.2 Dos `AppButton` con APIs distintas

| Archivo | Variantes | Uso activo |
|---|---|---|
| `lib/ui/app_button.dart` | `{ primary, secondary, ghost, destructive }` | **Sí** — toda la app |
| `lib/design_system/components/app_button.dart` | `{ filled, outlined, ghost, destructive }` | **No** — no importado en producción |

Las pantallas (`corporate_screens.dart`, `sheets_screen.dart`) importan `lib/ui/ui.dart` → usan el `AppButton` de `lib/ui/`. El del `design_system/` es letra muerta.

### 2.3 LandingScreen con paleta propia (`_LandingPalette`)

`lib/screens/landing_screen.dart:214` define `_LandingPalette` con 13 colores hardcodeados propios, **completamente desconectados** del `AppTheme`. Si cambia el color accent del app, la landing no lo refleja.

Colores hardcodeados en landing (muestra):
```dart
accent: Color(0xFF0066CC),          // light
accent: Color(0xFF5E9BFF),          // dark
success: Color(0xFF157F3E),
warning: Color(0xFF9A6A00),
pageBg: Color(0xFFF5F5F7),
pageBg: Color(0xFF050506),
```

### 2.4 Botones locales en LandingScreen

`_SolidButton` y `_GhostButton` en `landing_screen.dart` son botones completamente custom, no derivados del sistema. Duplican comportamiento del `AppButton`.

### 2.5 `main.dart` con colores hardcodeados en `ErrorWidget` y `_BootSplash`

```dart
color: const Color(0xFF0B0D1A),       // main.dart:97
color: const Color(0xCC0B0D1A),       // main.dart:106
color: const Color(0x22FFFFFF),       // main.dart:107, 676, 739
color: const Color(0x33FFFFFF),       // main.dart:822
color: const Color(0x14000000),       // main.dart:734
color: const Color(0x0A000000),       // main.dart:736
```

### 2.6 `GridnoteTableStyle` con colores hardcodeados

`lib/theme/gridnote_theme.dart:540-567`:
```dart
Color(0xFFFFFFFF), Color(0xFF111827), Color(0xFF374151),
Color(0xFFE5E7EB), Color(0xFF6B7280), Color(0xFF9CA3AF),
Color(0xFF253041), Color(0xFFF9FAFB)
```
Estos colores de tabla no respetan el AppColors del design_system.

### 2.7 Método legacy `_buildLegacy` vivo en producción

`lib/theme/gridnote_theme.dart:74` tiene `_buildLegacy` (prefijado con `_`, ignorado por el linter). Tiene ~200 líneas con su propia paleta completa usando `withAlpha()` (API vieja). Código muerto que aumenta confusión.

### 2.8 `sheets_screen.dart` con widgets privados duplicados

- `_PillButton` (línea 1320): botón pill propio con state de hover y press. Replica `AppPressable` + `AppButton`.
- `_PillIcon` (línea 1377): ícono en contenedor pill. Replica `_IconTile` de corporate_screens.
- `tile()` local en `_pickTemplate()` (línea 333): construye cards con `Ink/InkWell` sin usar `AppCard`.

### 2.9 Valores de radii inconsistentes entre sistemas

`AppRadii` (de `lib/theme/app_theme.dart`): `xs=10, sm=14, md=18, lg=22, xl=28`  
`AppThemeBuilder` (de `lib/design_system/theme_data.dart`): usa `AppSpacing.lg (=16)` para card radius, `AppSpacing.xl (=24)` para dialog radius.

`corporate_screens.dart` usa `t.radii.xl = 28`; `AppThemeBuilder.cardTheme` usa `AppSpacing.lg = 16`. La misma semántica ("radio de card"), dos valores distintos.

### 2.10 Spacing hardcodeado en LandingScreen y BootSplash

LandingScreen usa constantes directas sin tokens: `36, 28, 56, 20, 24, 14, 18, 12, 10, 8, 7, 6`. Ninguna referencia a `AppSpacing`.

---

## 3. Inventario de Componentes

### 3.1 Sistema activo (`lib/ui/`)
Estos son los componentes que la app realmente usa:

| Componente | Archivo | Estado |
|---|---|---|
| `AppButton` | `lib/ui/app_button.dart` | ✅ Bien estructurado, usa tokens |
| `AppCard` | `lib/ui/app_card.dart` | ✅ Usa tokens |
| `AppModal` | `lib/ui/app_modal.dart` | ✅ |
| `AppTextField` | `lib/ui/app_text_field.dart` | ✅ |
| `AppTopBar` | `lib/ui/app_shell.dart` | ✅ |
| `EmptyState` | `lib/ui/empty_state.dart` | ✅ |
| `LoadingState` | `lib/ui/loading_state.dart` | ✅ |
| `SectionHeader` | `lib/ui/section_header.dart` | ✅ |
| `AppToast` | `lib/ui/app_toast.dart` | ✅ |
| `AppTokens` / `context.tokens` | `lib/ui/app_tokens.dart` | ✅ Extensión ergonómica |

### 3.2 Sistema fantasma (`lib/design_system/components/`)
No importado en producción. Letra muerta.

| Componente | Archivo |
|---|---|
| `AppButton` | `lib/design_system/components/app_button.dart` |
| `AppCard` | `lib/design_system/components/app_card.dart` |
| `AppInput` | `lib/design_system/components/app_input.dart` |
| `AppListTile` | `lib/design_system/components/app_list_tile.dart` |
| `AppModal` | `lib/design_system/components/app_modal.dart` |
| `AppText` | `lib/design_system/components/app_text.dart` |
| `AppAppBar` | `lib/design_system/components/app_app_bar.dart` |
| `AppBottomSheet` | `lib/design_system/components/app_bottom_sheet.dart` |

### 3.3 Widgets candidatos a extraer

| Widget local | Dónde vive | Extracción sugerida |
|---|---|---|
| `_IconTile` | `corporate_screens.dart:1458` | `AppIconTile` en `lib/ui/` |
| `_StatusChip` | `corporate_screens.dart:1530` | `AppStatusChip` en `lib/ui/` |
| `_MemberChip` | `corporate_screens.dart:1489` | puede fusionarse con `AppStatusChip` |
| `_BackendBadge` | `corporate_screens.dart:1413` | `AppBadge` genérico |
| `_PillIcon` | `sheets_screen.dart:1377` | fusionar con `AppIconTile` |
| `_PillButton` | `sheets_screen.dart:1320` | usar `AppButton` directamente |
| `_CorporateLoading` | `corporate_screens.dart:1606` | `LoadingState` ya existe |
| `_CorporateError` | `corporate_screens.dart:1635` | `ErrorState` widget (no existe, crear) |
| `_CorporateEmpty` | `corporate_screens.dart:1681` | `EmptyState` ya existe |
| `_NotifBadge` | `corporate_screens.dart:2431` | `AppBadge` wrapping `AppButton` |

---

## 4. Tokens: Propuesta de Estructura Unificada

La idea es que `lib/design_system/` sea **la única fuente de verdad** y que `lib/theme/app_theme.dart` consuma de ahí.

### 4.1 Colores — `lib/design_system/colors.dart` (ampliar)

```dart
abstract final class AppColors {
  // --- Actuales (mantener) ---
  // Background, Labels, Fills, Separators, Accent...

  // --- AGREGAR: semánticos con nombre funcional ---
  // Semantic status colors
  static Color success(Brightness b) => b == Brightness.light ? accentGreen : accentGreenDark;
  static Color warning(Brightness b) => b == Brightness.light ? accentOrange : accentOrangeDark;
  static Color danger(Brightness b) => b == Brightness.light ? accentRed : accentRedDark;

  // Backgrounds semánticos (alpha sobre los colores base)
  static Color successBg(Brightness b) => success(b).withValues(alpha: b == Brightness.light ? 0.10 : 0.18);
  static Color warningBg(Brightness b) => warning(b).withValues(alpha: b == Brightness.light ? 0.12 : 0.18);
  static Color dangerBg(Brightness b)  => danger(b).withValues(alpha: b == Brightness.light ? 0.10 : 0.18);
}
```

Esto elimina la necesidad del `AppColors` de `lib/theme/app_theme.dart` para los semánticos.

### 4.2 Spacing — unificar en `lib/design_system/spacing.dart`

El sistema de `lib/ui/` usa los valores del `AppSpacing` de `lib/theme/app_theme.dart` (xs=6, etc.) vía `AppTokens`. Para no romper nada, la migración es en dos fases:

**Fase intermedia**: hacer que `AppSpacing` de `lib/theme/app_theme.dart` devuelva los valores del design_system:
```dart
// En lib/theme/app_theme.dart
@immutable
class AppSpacing {
  const AppSpacing({
    this.xs = 4,   // era 6
    this.sm = 8,   // era 10
    this.md = 12,  // era 14
    this.lg = 16,  // era 20
    this.xl = 24,  // era 28
    this.xxl = 32, // era 36
  });
  ...
}
```
Esto alinea ambos sistemas. **Cambio destructivo controlado**: solo afecta spacing visual, no lógica.

### 4.3 Radii — `lib/design_system/radii.dart` (nuevo archivo)

```dart
abstract final class AppRadii {
  static const double xs  = 8;
  static const double sm  = 12;
  static const double md  = 16;
  static const double lg  = 20;
  static const double xl  = 24;
  static const double xxl = 32;
  static const double pill = 999;
}
```

Reemplaza `AppRadii` de `lib/theme/app_theme.dart` (xs=10, sm=14, md=18, lg=22, xl=28) con valores que reflejan el uso real en `AppThemeBuilder`.

### 4.4 Sombras — `lib/design_system/shadows.dart` (nuevo archivo)

Extraer `AppShadows` de `lib/theme/app_theme.dart` al design_system.

### 4.5 Typography — mantener `lib/design_system/typography.dart`

Ya es el sistema canónico. Solo necesita que todos consuman `AppTypography.*` directamente, en vez de usar `theme.textTheme.*` con `copyWith` inline.

---

## 5. Inconsistencias Visuales Detectadas

| Elemento | Inconsistencia |
|---|---|
| **Radios de tarjeta** | `AppThemeBuilder.cardTheme` usa `AppSpacing.lg (=16)`, `AppRadii.xl` en tokens = 28, `landing_screen` usa 22, 26, 28 sin sistema |
| **Accent color** | Design system usa `Color(0xFF007AFF)`, landing usa `Color(0xFF0066CC)`. Son distintos azules. |
| **Spacing de separadores internos** | corporate_screens usa `t.spacing.*` ✅; landing_screen usa literales sin tokens (14, 18, 20, 24, 36, 56) |
| **Font weight** | `fontWeight: FontWeight.w900` aparece en >30 lugares como inline override. No hay token `AppTypography.titleDisplay` claro. |
| **Sombras** | `AppShadows.card` en tokens vs `BoxShadow(blurRadius: 28, offset: Offset(0,18))` hardcodeado en landing |
| **Divider thickness** | `AppThemeBuilder` usa 0.5; `gridnote_theme._buildLegacy` usa 0.8; `sheets_screen` usa 0.8 |

---

## 6. Archivos Clave

```
lib/
├── design_system/          ← FUENTE DE VERDAD (ampliar)
│   ├── colors.dart         ← ✅ base sólida, falta semánticos
│   ├── spacing.dart        ← ✅ valores correctos (4pt grid)
│   ├── typography.dart     ← ✅ Apple HIG completo
│   ├── motion.dart         ← ✅ excelente
│   ├── theme_data.dart     ← ✅ canónico
│   └── components/         ← ⚠️ LETRA MUERTA, ignorar o borrar
│
├── theme/
│   ├── app_theme.dart      ← ⚠️ AppColors + AppSpacing duplicados, migrar
│   ├── gridnote_theme.dart ← ⚠️ _buildLegacy = código muerto; GridnoteTableStyle tiene hardcoded colors
│   └── bitflow_colors.dart ← vacío
│
├── ui/                     ← SISTEMA ACTIVO
│   ├── ui.dart             ← barrel de exportación
│   ├── app_tokens.dart     ← ✅ extensión context.tokens
│   ├── app_button.dart     ← ✅ usa tokens, bien
│   ├── app_card.dart       ← ✅
│   ├── app_modal.dart      ← ✅
│   ├── app_text_field.dart ← ✅
│   ├── app_shell.dart      ← ✅ AppTopBar
│   ├── empty_state.dart    ← ✅
│   └── loading_state.dart  ← ✅
│
├── screens/
│   ├── landing_screen.dart ← 🔴 paleta propia, botones propios, spacing hardcoded
│   ├── sheets_screen.dart  ← ⚠️ _PillButton, _PillIcon, tile() locales
│   └── corporate/
│       └── corporate_screens.dart ← ✅ usa tokens bien, chips y badges extraíbles
│
└── main.dart               ← ⚠️ colors hardcodeados en ErrorWidget y _BootSplash
```

---

## 7. Plan de Implementación por Etapas

### Etapa 0 — Limpieza sin riesgo (1-2h)

- [ ] Borrar `lib/design_system/components/` (letra muerta, 0 importaciones en producción)
- [ ] Borrar `lib/theme/bitflow_colors.dart` (vacío)
- [ ] Eliminar `_buildLegacy` de `lib/theme/gridnote_theme.dart`
- [ ] Mover `_buildLegacy` a un archivo de archivo/referencia si se quiere conservar contexto histórico

**Riesgo**: cero.

### Etapa 1 — Consolidar design_system (2-4h)

- [ ] Agregar colores semánticos (`success/warning/danger` + sus `*Bg`) a `lib/design_system/colors.dart`
- [ ] Crear `lib/design_system/radii.dart` con `AppRadii` canónico
- [ ] Crear `lib/design_system/shadows.dart` con `AppShadows` canónico
- [ ] Actualizar `lib/theme/app_theme.dart` para que `AppColors`, `AppSpacing`, `AppRadii`, `AppShadows` deleguen/importen desde `design_system/`
- [ ] Hacer que `AppSpacing` de `lib/theme/app_theme.dart` use los valores del design_system (4pt grid)

**Riesgo**: bajo. Solo cambia valores de spacing visual (4-6pt de diferencia). Revisar visualmente en pantallas clave.

### Etapa 2 — Extraer componentes reutilizables (3-5h)

- [ ] Crear `lib/ui/app_icon_tile.dart` — unificar `_IconTile` (corporate) y `_PillIcon` (sheets)
- [ ] Crear `lib/ui/app_status_chip.dart` — extraer `_StatusChip` con resolución de estado
- [ ] Crear `lib/ui/app_badge.dart` — extraer `_BackendBadge` y `_MemberChip`
- [ ] Reemplazar `_PillButton` de sheets_screen con `AppButton(variant: ghost, size: sm)`
- [ ] Reemplazar `tile()` de template picker con `AppCard` + `InkWell`

**Riesgo**: bajo si los widgets se extraen field-for-field.

### Etapa 3 — Migrar LandingScreen a tokens (4-6h)

- [ ] Reemplazar `_LandingPalette` con `AppTheme.of(context)` / `context.tokens`
- [ ] Reemplazar `_SolidButton` y `_GhostButton` con `AppButton`
- [ ] Reemplazar todos los `const SizedBox(height: X)` con `SizedBox(height: t.spacing.Y)`
- [ ] Actualizar accent de landing para que coincida con design_system (`0xFF007AFF` en light)

**Riesgo**: medio. La landing tiene muchos literales. Hacerlo pantallazo a pantallazo.

### Etapa 4 — Hardcoded colors en main.dart y GridnoteTableStyle (1-2h)

- [ ] Reemplazar colores en `ErrorWidget.builder` y `_BootSplash` de main.dart con tokens del theme
- [ ] Actualizar `GridnoteTableStyle.from()` para usar `AppColors` del design_system

**Riesgo**: bajo.

### Etapa 5 — Unificar tipografía inline (ongoing)

- [ ] Crear alias en `AppTypography` para `displayHero` (el 58/38pt del hero de landing)
- [ ] Reemplazar `text.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.8)` repetido con un estilo nombrado
- [ ] Documentar en `app_text_styles.dart` los overrides comunes (ya existe `titleDisplay`, `titleLarge`, etc.)

**Riesgo**: cero (solo additive).

---

## 8. Widgets a Crear (resumen de Etapa 2)

```dart
// lib/ui/app_icon_tile.dart
class AppIconTile extends StatelessWidget {
  const AppIconTile({ required this.icon, this.size = 42, this.color });
  // Container con accentMuted bg + icon coloreado con accent
}

// lib/ui/app_status_chip.dart
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({ required this.label, this.status = AppChipStatus.neutral });
  // Resuelve colores por status: active/planning/paused/closed/danger/success/warning
}

// lib/ui/app_badge.dart
class AppBadge extends StatelessWidget {
  const AppBadge({ required this.label, this.icon, this.variant = AppBadgeVariant.neutral });
  // Versión simple del _BackendBadge
}
```

---

## 9. Quick Wins Inmediatos (sin rama, sin PR grande)

1. **Borrar `lib/design_system/components/`** — limpieza de código muerto, cero riesgo.
2. **Borrar `_buildLegacy`** — 200 líneas menos de confusión.
3. **Agregar `AppColors.success/warning/danger`** al design_system — pequeño, aditivo, sin romper nada.
4. **Agregar `lib/design_system/radii.dart`** — nuevo archivo, nadie lo usa todavía, no rompe.

---

## 10. Lo que NO tocar

- Lógica de `AppThemeBuilder` (funciona bien, refleja el tema real)
- `AppMotion`, `AppPressable`, `AppMotionReveal` (excelentes, usar más)
- `GridnoteTheme.build()` (wrapper liviano y correcto)
- `context.tokens` / `AppTokens` (ergonómico, bien diseñado)
- Sistema de tipografía de `AppTypography` (Apple HIG, completo)

---

*Generado el 2026-04-23. Rama analizada: `codex/professional-report-exports`.*
