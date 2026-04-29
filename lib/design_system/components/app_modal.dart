import 'package:flutter/material.dart';

import '../colors.dart';
import '../spacing.dart';
import '../typography.dart';

/// Apple-style modal dialog. For full-screen overlays, prefer [showAppBottomSheet].
Future<T?> showAppModal<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  List<AppModalAction>? actions,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AppModalDialog(
      title: title,
      content: content,
      actions: actions,
    ),
  );
}

class AppModalAction {
  const AppModalAction({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
    this.isDefault = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;
  final bool isDefault;
}

class AppModalDialog extends StatelessWidget {
  const AppModalDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
  });

  final String title;
  final Widget content;
  final List<AppModalAction>? actions;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = AppColors.secondaryBg(brightness);
    final label = AppColors.label(brightness);
    final secondaryLabel = AppColors.secondaryLabel(brightness);
    final divider = AppColors.divider(brightness);
    final accent = AppColors.accent(brightness);
    final red = brightness == Brightness.light
        ? AppColors.accentRed
        : AppColors.accentRedDark;

    return Dialog(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.xl),
        side: BorderSide(color: divider.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: AppTypography.headline.copyWith(color: label),
            ),
            const SizedBox(height: AppSpacing.sm),
            DefaultTextStyle(
              style: AppTypography.body.copyWith(color: secondaryLabel),
              child: content,
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              ...actions!.map((action) {
                final color = action.isDestructive ? red : accent;
                return TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    action.onPressed();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    minimumSize:
                        const Size(double.infinity, AppSpacing.touchTarget),
                    textStyle: action.isDefault
                        ? AppTypography.headline
                        : AppTypography.body,
                  ),
                  child: Text(action.label),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
