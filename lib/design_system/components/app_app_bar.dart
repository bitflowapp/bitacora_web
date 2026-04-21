import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../spacing.dart';
import '../typography.dart';

/// Apple-style blurred AppBar. Use as `appBar:` in Scaffold.
///
/// Wraps a SliverAppBar or PreferredSizeWidget depending on [floating].
/// The blur effect uses BackdropFilter so it works on both web and native.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.blurSigma = 20.0,
    this.bottom,
  });

  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final double blurSigma;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = AppColors.bg(brightness);
    final label = AppColors.label(brightness);

    final bgWithAlpha = bg.withValues(alpha: 0.85);

    SystemChrome.setSystemUIOverlayStyle(
      brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          color: bgWithAlpha,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: kToolbarHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        if (leading != null)
                          leading!
                        else if (Navigator.of(context).canPop())
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios_new,
                                size: 18, color: label),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Back',
                          ),
                        if (!centerTitle) ...[
                          const SizedBox(width: AppSpacing.xs),
                          if (title != null)
                            Expanded(
                              child: Text(
                                title!,
                                style: AppTypography.headline.copyWith(color: label),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ] else
                          const Spacer(),
                        if (centerTitle && title != null)
                          Expanded(
                            child: Text(
                              title!,
                              style: AppTypography.headline.copyWith(color: label),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (centerTitle) const Spacer(),
                        if (actions != null) ...actions!,
                      ],
                    ),
                  ),
                ),
                if (bottom != null) bottom!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
