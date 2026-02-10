import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppleButtonVariant { filled, tonal, ghost }

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      appBar: appBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: backgroundColor ?? t.colors.bg,
      body: body,
    );
  }
}

class AppleCard extends StatelessWidget {
  const AppleCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius,
    this.color,
    this.borderColor,
    this.shadows,
  });

  final Widget child;
  final EdgeInsets padding;
  final double? radius;
  final Color? color;
  final Color? borderColor;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final r = radius ?? t.radii.lg;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.colors.surface,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(
          color: borderColor ?? t.colors.border,
          width: 0.8,
        ),
        boxShadow: shadows ?? t.shadows.soft,
      ),
      child: child,
    );
  }
}

class AppleButton extends StatelessWidget {
  const AppleButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.enabled,
    this.variant = AppleButtonVariant.tonal,
    this.dense = false,
    this.tooltip,
    this.shortcut,
    this.iconColor,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool? enabled;
  final AppleButtonVariant variant;
  final bool dense;
  final String? tooltip;
  final String? shortcut;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final effectiveEnabled = enabled ?? onPressed != null;

    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case AppleButtonVariant.filled:
        bg = t.colors.textPrimary;
        fg = t.colors.surfaceElevated;
        border = bg;
        break;
      case AppleButtonVariant.ghost:
        bg = Colors.transparent;
        fg = t.colors.textPrimary;
        border = t.colors.border;
        break;
      case AppleButtonVariant.tonal:
        bg = t.colors.surfaceMuted;
        fg = t.colors.textPrimary;
        border = t.colors.border;
        break;
    }

    if (!effectiveEnabled) {
      fg = t.colors.textSecondary.withOpacity(0.5);
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(
            icon,
            size: dense ? 18 : 20,
            color: iconColor ?? fg,
          ),
        if (label != null) ...[
          if (icon != null) const SizedBox(width: 8),
          Text(
            label!,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: dense ? 12 : 13,
              height: 1.05,
            ),
          ),
        ],
      ],
    );

    final padding = EdgeInsets.symmetric(
      horizontal: dense ? 12 : 16,
      vertical: dense ? 8 : 12,
    );

    final button = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(t.radii.pill),
      mouseCursor: effectiveEnabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      hoverColor: effectiveEnabled ? t.colors.hover : Colors.transparent,
      splashColor: effectiveEnabled ? t.colors.pressed : Colors.transparent,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(t.radii.pill),
          border: Border.all(color: border, width: 0.8),
        ),
        child: content,
      ),
    );

    if ((tooltip ?? '').isEmpty && (shortcut ?? '').isEmpty) return button;

    final tip = [
      if (tooltip != null && tooltip!.trim().isNotEmpty) tooltip!.trim(),
      if (shortcut != null && shortcut!.trim().isNotEmpty) '($shortcut)',
    ].join(' ');

    return Tooltip(message: tip, child: button);
  }
}

class AppleToolbarItem {
  AppleToolbarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onDisabledTap,
    this.shortcut,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onDisabledTap;
  final String? shortcut;
  final bool enabled;
}

class AppleToolbar extends StatelessWidget {
  const AppleToolbar({
    super.key,
    required this.items,
    this.dense = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.backgroundColor,
  });

  final List<AppleToolbarItem> items;
  final bool dense;
  final EdgeInsets padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final bg = backgroundColor ??
        (t.colors.isLight
            ? t.colors.surfaceElevated.withOpacity(0.9)
            : t.colors.surfaceElevated.withOpacity(0.75));

    return AppleCard(
      padding: padding,
      radius: t.radii.xl,
      color: bg,
      borderColor: t.colors.border,
      shadows: t.shadows.soft,
      child: Wrap(
        spacing: dense ? 8 : 12,
        runSpacing: dense ? 8 : 10,
        children: [
          for (final item in items)
            AppleButton(
              icon: item.icon,
              label: item.label,
              dense: dense,
              variant: AppleButtonVariant.tonal,
              onPressed: item.enabled ? item.onTap : item.onDisabledTap,
              enabled: item.enabled,
              tooltip: item.label,
              shortcut: item.shortcut,
              iconColor: t.colors.accent,
            ),
        ],
      ),
    );
  }
}

class AppleToast {
  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (message.trim().isEmpty) return;
    final t = AppTheme.of(context);
    final bg = isError ? t.colors.dangerBg : t.colors.statusBg;
    final fg = isError ? t.colors.dangerFg : t.colors.statusFg;
    final iconData = icon ??
        (isError
            ? Icons.error_outline_rounded
            : Icons.check_circle_outline_rounded);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radii.md),
        ),
        content: Row(
          children: [
            Icon(iconData, size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        action: (actionLabel ?? '').trim().isNotEmpty && onAction != null
            ? SnackBarAction(
                label: actionLabel!.trim(),
                onPressed: onAction,
                textColor: fg,
              )
            : null,
      ),
    );
  }
}
