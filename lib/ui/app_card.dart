import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cardRadius = radius ?? t.radii.lg;

    final decorated = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.colors.surface,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color: borderColor ?? t.colors.border,
          width: 1,
        ),
        boxShadow: shadows ?? t.shadows.soft,
      ),
      child: child,
    );

    if (onTap == null) return decorated;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        hoverColor: t.colors.hover,
        splashColor: t.colors.pressed,
        child: decorated,
      ),
    );
  }
}
