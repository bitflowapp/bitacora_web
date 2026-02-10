import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius,
    this.onTap,
    this.color,
    this.borderColor,
    this.shadows,
  });

  final Widget child;
  final EdgeInsets padding;
  final double? radius;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final List<BoxShadow>? shadows;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cardRadius = widget.radius ?? t.radii.lg;
    final interactive = widget.onTap != null;

    final decorated = MouseRegion(
      onEnter: interactive ? (_) => _setHovered(true) : null,
      onExit: (_) => _setHovered(false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _hovered && interactive ? 1.006 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.color ?? t.colors.surface,
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(
              color: widget.borderColor ?? t.colors.border,
              width: 1,
            ),
            boxShadow: widget.shadows ??
                (_hovered && interactive ? t.shadows.card : t.shadows.soft),
          ),
          child: widget.child,
        ),
      ),
    );

    if (!interactive) return decorated;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        hoverColor: t.colors.hover,
        splashColor: t.colors.pressed,
        child: decorated,
      ),
    );
  }
}
