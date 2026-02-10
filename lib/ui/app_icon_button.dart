import 'package:flutter/material.dart';

import 'app_tokens.dart';

enum AppIconButtonSize { sm, md, lg }

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = AppIconButtonSize.md,
    this.variant = AppIconButtonVariant.tonal,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final AppIconButtonSize size;
  final AppIconButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onPressed != null;

    final baseSize = switch (size) {
      AppIconButtonSize.sm => 30.0,
      AppIconButtonSize.md => 36.0,
      AppIconButtonSize.lg => 42.0,
    };

    final iconSize = switch (size) {
      AppIconButtonSize.sm => 16.0,
      AppIconButtonSize.md => 18.0,
      AppIconButtonSize.lg => 20.0,
    };

    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case AppIconButtonVariant.filled:
        bg = t.colors.isLight ? const Color(0xFF0B0B0C) : Colors.white;
        fg = t.colors.isLight ? Colors.white : const Color(0xFF0B0B0C);
        border = bg;
        break;
      case AppIconButtonVariant.ghost:
        bg = Colors.transparent;
        fg = t.colors.textPrimary;
        border = t.colors.border;
        break;
      case AppIconButtonVariant.tonal:
        bg = t.colors.surfaceMuted;
        fg = t.colors.textPrimary;
        border = t.colors.border;
        break;
    }

    if (!enabled) {
      fg = t.colors.textSecondary.withOpacity(0.5);
      bg = bg.withOpacity(0.4);
    }

    final button = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(t.radii.pill),
      hoverColor: enabled ? t.colors.hover : Colors.transparent,
      splashColor: enabled ? t.colors.pressed : Colors.transparent,
      child: Container(
        width: baseSize,
        height: baseSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(t.radii.pill),
          border: Border.all(color: border, width: 0.8),
        ),
        child: Icon(icon, size: iconSize, color: fg),
      ),
    );

    if (tooltip == null || tooltip!.trim().isEmpty) return button;
    return Tooltip(message: tooltip!.trim(), child: button);
  }
}

enum AppIconButtonVariant { filled, tonal, ghost }
