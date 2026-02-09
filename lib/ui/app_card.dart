import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
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
    final r = radius ?? t.radii.lg;
    final body = Container(
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

    if (onTap == null) return body;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        hoverColor: t.colors.hover,
        splashColor: t.colors.pressed,
        child: body,
      ),
    );
  }
}
