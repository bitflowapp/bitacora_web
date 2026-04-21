import 'package:flutter/material.dart';

import '../colors.dart';
import '../spacing.dart';
import '../typography.dart';

enum AppButtonVariant { filled, outlined, ghost, destructive }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.icon,
    this.loading = false,
    this.small = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? icon;
  final bool loading;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = AppColors.accent(brightness);

    final minHeight = small ? 36.0 : AppSpacing.touchTarget;
    final hPad = small ? AppSpacing.md : AppSpacing.lg;
    final textStyle = small ? AppTypography.subheadline : AppTypography.headline;

    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _fgColor(brightness),
            ),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconTheme(
                    data: IconThemeData(color: _fgColor(brightness), size: 18),
                    child: icon!,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(label, style: textStyle.copyWith(color: _fgColor(brightness))),
                ],
              )
            : Text(label, style: textStyle.copyWith(color: _fgColor(brightness)));

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.xl),
    );

    switch (variant) {
      case AppButtonVariant.filled:
        return FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            minimumSize: Size(AppSpacing.touchTarget, minHeight),
            padding: EdgeInsets.symmetric(horizontal: hPad),
            shape: shape,
          ),
          child: child,
        );

      case AppButtonVariant.outlined:
        return OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(color: accent.withValues(alpha: 0.6)),
            minimumSize: Size(AppSpacing.touchTarget, minHeight),
            padding: EdgeInsets.symmetric(horizontal: hPad),
            shape: shape,
          ),
          child: child,
        );

      case AppButtonVariant.ghost:
        return TextButton(
          onPressed: loading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: accent,
            minimumSize: Size(AppSpacing.touchTarget, minHeight),
            padding: EdgeInsets.symmetric(horizontal: hPad),
            shape: shape,
          ),
          child: child,
        );

      case AppButtonVariant.destructive:
        final red = brightness == Brightness.light
            ? AppColors.accentRed
            : AppColors.accentRedDark;
        return FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: red,
            foregroundColor: Colors.white,
            minimumSize: Size(AppSpacing.touchTarget, minHeight),
            padding: EdgeInsets.symmetric(horizontal: hPad),
            shape: shape,
          ),
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : child,
        );
    }
  }

  Color _fgColor(Brightness brightness) {
    switch (variant) {
      case AppButtonVariant.filled:
      case AppButtonVariant.destructive:
        return Colors.white;
      case AppButtonVariant.outlined:
      case AppButtonVariant.ghost:
        return AppColors.accent(brightness);
    }
  }
}
