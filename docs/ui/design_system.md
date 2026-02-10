# BitFlow UI (Apple-like) — Guía visual

## Principios
- Blanco/negro + grises cálidos, con acento mínimo.
- Bordes redondeados grandes y sombras suaves.
- Tipografía limpia, jerarquía clara, sin ruido visual.
- Estados visibles (hover/focus/disabled) y accesibles.

## Tokens
**Radios**
- xs: 8
- sm: 12
- md: 16
- lg: 20
- xl: 26
- pill: 999

**Spacing**
- xs: 4
- sm: 8
- md: 12
- lg: 16
- xl: 24
- xxl: 32

**Sombras**
- card: sombra limpia, blur 14, offset 0/8 (light)
- soft: sombra sutil, blur 10, offset 0/5 (light)
- floating: blur 20, offset 0/12 (light)

## Componentes base
- `AppButton`: primario/secondary/ghost/destructive, estado loading.
- `AppIconButton`: tamaños sm/md/lg, tooltips consistentes.
- `AppCard`: borde fino + sombra suave, interacción opcional.
- `AppTextField` / `SearchField`: inputs tipo Apple con focus ring suave.
- `AppModal`: diálogo con jerarquía clara y close consistente.
- `AppToast`: snackbar premium, borde sutil.

## Estados y accesibilidad
- Focus ring visible (contraste OK).
- Targets táctiles >= 36px.
- Texto secundario con opacidad controlada.

## Uso rápido
```dart
AppButton(
  label: 'Guardar',
  variant: AppButtonVariant.primary,
  onPressed: onSave,
)
```

```dart
AppTextField(
  label: 'Nombre',
  hint: 'Ingresar nombre',
  onChanged: (v) {},
)
```

## Próximos pasos visuales
- Capturas de pantallas clave (Landing, Editor, Mobile) en `docs/ui/assets/`.
- Guía operativa para adjuntos y exportación: `docs/ui/how_to.md`.
