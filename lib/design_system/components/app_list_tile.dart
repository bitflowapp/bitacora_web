import 'package:flutter/material.dart';

import '../colors.dart';
import '../spacing.dart';
import '../typography.dart';

class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final label = AppColors.label(brightness);
    final secondaryLabel = AppColors.secondaryLabel(brightness);
    final accent = AppColors.accent(brightness);
    final red = brightness == Brightness.light
        ? AppColors.accentRed
        : AppColors.accentRedDark;

    final titleColor = destructive ? red : label;

    Widget? trailingWidget = trailing;
    if (showChevron && trailing == null) {
      trailingWidget = Icon(
        Icons.chevron_right,
        size: 20,
        color: secondaryLabel,
      );
    }

    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      child: Padding(
        padding: AppSpacing.listTilePadding,
        child: Row(
          children: [
            if (leading != null) ...[
              IconTheme(
                data: IconThemeData(color: accent, size: 22),
                child: leading!,
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.body.copyWith(color: titleColor),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.footnote.copyWith(color: secondaryLabel),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingWidget != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailingWidget,
            ],
          ],
        ),
      ),
    );
  }
}
