import 'package:flutter/material.dart';

import '../colors.dart';
import '../spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.borderRadius = AppSpacing.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = AppColors.secondaryBg(brightness);
    final divider = AppColors.divider(brightness);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      side: BorderSide(
        color: divider.withValues(alpha: brightness == Brightness.light ? 0.6 : 0.4),
        width: 0.5,
      ),
    );

    if (onTap == null) {
      return Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: divider.withValues(alpha: brightness == Brightness.light ? 0.6 : 0.4),
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      );
    }

    return Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
