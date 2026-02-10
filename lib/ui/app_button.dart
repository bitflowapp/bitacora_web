import 'package:flutter/material.dart';

import 'app_tokens.dart';

enum AppButtonVariant { primary, secondary, ghost, destructive }

enum AppButtonSize { sm, md, lg }

class AppButton extends StatefulWidget {
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
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = _resolveColors(t);
    final disabled = widget.loading || widget.onPressed == null;

    final minHeight = switch (widget.size) {
      AppButtonSize.sm => 36.0,
      AppButtonSize.md => 42.0,
      AppButtonSize.lg => 48.0,
    };

    final padding = switch (widget.size) {
      AppButtonSize.sm =>
        EdgeInsets.symmetric(horizontal: t.spacing.md, vertical: t.spacing.xs),
      AppButtonSize.md =>
        EdgeInsets.symmetric(horizontal: t.spacing.lg, vertical: t.spacing.sm),
      AppButtonSize.lg =>
        EdgeInsets.symmetric(horizontal: t.spacing.xl, vertical: t.spacing.sm),
    };

    final fontSize = switch (widget.size) {
      AppButtonSize.sm => 12.0,
      AppButtonSize.md => 13.0,
      AppButtonSize.lg => 14.0,
    };

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(Size(0, minHeight)),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(padding),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radii.pill),
        ),
      ),
      side: WidgetStateProperty.resolveWith<BorderSide>((states) {
        final focused = states.contains(WidgetState.focused);
        return BorderSide(
          color: focused ? t.colors.focusRing : c.border,
          width: focused ? 1.2 : 1,
        );
      }),
      elevation: const WidgetStatePropertyAll<double>(0),
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) {
          return c.bg.withValues(alpha: 0.50);
        }
        return c.bg;
      }),
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) {
          return c.fg.withValues(alpha: 0.50);
        }
        return c.fg;
      }),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.pressed)) return t.colors.pressed;
        if (states.contains(WidgetState.hovered)) return t.colors.hover;
        if (states.contains(WidgetState.focused)) {
          return t.colors.focusRing.withValues(alpha: 0.20);
        }
        return null;
      }),
      textStyle: WidgetStatePropertyAll<TextStyle>(
        TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          letterSpacing: 0.1,
        ),
      ),
    );

    final child = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: fontSize + 2,
            height: fontSize + 2,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(c.fg),
            ),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: fontSize + 6),
        if (widget.icon != null || widget.loading)
          SizedBox(width: t.spacing.sm),
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final button = TextButton(
      onPressed: widget.loading ? null : widget.onPressed,
      style: style,
      child: child,
    );

    final wrapped = widget.fullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
    final shadowColor =
        t.colors.textPrimary.withValues(alpha: t.colors.isLight ? 0.10 : 0.30);
    final interactive = MouseRegion(
      onEnter: disabled ? null : (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _hovered && !disabled ? 1.01 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            boxShadow: _hovered &&
                    !disabled &&
                    widget.variant == AppButtonVariant.primary
                ? [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
            borderRadius: BorderRadius.circular(t.radii.pill),
          ),
          child: wrapped,
        ),
      ),
    );

    final tip = widget.tooltip?.trim() ?? '';
    if (tip.isEmpty) return interactive;
    return Tooltip(message: tip, child: interactive);
  }

  _ResolvedButtonColors _resolveColors(AppTokens t) {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return _ResolvedButtonColors(
          bg: t.colors.accent,
          fg: t.colors.isLight ? Colors.white : const Color(0xFF0D0D0F),
          border: t.colors.accent,
        );
      case AppButtonVariant.secondary:
        return _ResolvedButtonColors(
          bg: t.colors.surface,
          fg: t.colors.textPrimary,
          border: t.colors.border,
        );
      case AppButtonVariant.ghost:
        return _ResolvedButtonColors(
          bg: Colors.transparent,
          fg: t.colors.textPrimary,
          border: t.colors.border,
        );
      case AppButtonVariant.destructive:
        return _ResolvedButtonColors(
          bg: t.colors.dangerFg,
          fg: t.colors.isLight ? Colors.white : const Color(0xFF0D0D0F),
          border: t.colors.dangerFg,
        );
    }
  }
}

class _ResolvedButtonColors {
  const _ResolvedButtonColors({
    required this.bg,
    required this.fg,
    required this.border,
  });

  final Color bg;
  final Color fg;
  final Color border;
}
