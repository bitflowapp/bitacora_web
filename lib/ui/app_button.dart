import 'package:flutter/material.dart';

import 'app_tokens.dart';

enum AppButtonVariant { primary, secondary, ghost, destructive }

enum AppButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.loading = false,
    this.fullWidth = false,
    this.tooltip,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool loading;
  final bool fullWidth;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final colors = t.colors;

    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case AppButtonVariant.primary:
        bg = colors.isLight ? const Color(0xFF0B0B0C) : Colors.white;
        fg = colors.isLight ? Colors.white : const Color(0xFF0B0B0C);
        border = bg;
        break;
      case AppButtonVariant.secondary:
        bg = colors.surfaceMuted;
        fg = colors.textPrimary;
        border = colors.border;
        break;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = colors.textPrimary;
        border = colors.border;
        break;
      case AppButtonVariant.destructive:
        bg = colors.dangerFg;
        fg = colors.isLight ? Colors.white : const Color(0xFF0B0B0C);
        border = colors.dangerFg;
        break;
    }

    final padding = switch (size) {
      AppButtonSize.sm =>
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      AppButtonSize.md =>
        const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      AppButtonSize.lg =>
        const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    };

    final fontSize = switch (size) {
      AppButtonSize.sm => 12.0,
      AppButtonSize.md => 13.0,
      AppButtonSize.lg => 14.0,
    };

    final style = ButtonStyle(
      padding: WidgetStateProperty.all(padding),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return bg.withOpacity(0.4);
        }
        return bg;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return fg.withOpacity(0.45);
        }
        return fg;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return colors.pressed;
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return colors.hover;
        }
        return null;
      }),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radii.pill),
        ),
      ),
      side: WidgetStateProperty.resolveWith((states) {
        final focus = states.contains(WidgetState.focused);
        return BorderSide(
          color: focus ? colors.focusRing : border,
          width: 0.9,
        );
      }),
      textStyle: WidgetStateProperty.all(
        TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          letterSpacing: 0.1,
        ),
      ),
      elevation: WidgetStateProperty.all(0),
    );

    final child = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment:
          fullWidth ? MainAxisAlignment.center : MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: fontSize + 2,
            height: fontSize + 2,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        else if (icon != null)
          Icon(icon, size: fontSize + 6),
        if (icon != null || loading) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final button = TextButton(
      onPressed: loading ? null : onPressed,
      style: style,
      child: child,
    );

    if (tooltip == null || tooltip!.trim().isEmpty) {
      return fullWidth
          ? SizedBox(width: double.infinity, child: button)
          : button;
    }
    return Tooltip(message: tooltip!.trim(), child: button);
  }
}
