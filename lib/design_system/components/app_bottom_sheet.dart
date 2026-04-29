import 'package:flutter/material.dart';

import '../colors.dart';
import '../spacing.dart';
import '../typography.dart';

/// Shows an Apple-style bottom sheet with drag handle, title and content.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  bool isDismissible = true,
  bool showHandle = true,
  bool isScrollControlled = true,
  double initialChildSize = 0.5,
  double minChildSize = 0.25,
  double maxChildSize = 0.92,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AppBottomSheetContainer(
      title: title,
      showHandle: showHandle,
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      child: child,
    ),
  );
}

class _AppBottomSheetContainer extends StatelessWidget {
  const _AppBottomSheetContainer({
    required this.child,
    this.title,
    this.showHandle = true,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.25,
    this.maxChildSize = 0.92,
  });

  final Widget child;
  final String? title;
  final bool showHandle;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = AppColors.bg(brightness);
    final label = AppColors.label(brightness);
    final divider = AppColors.divider(brightness);

    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHandle) ...[
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: divider,
                    borderRadius: BorderRadius.circular(AppSpacing.xs / 2),
                  ),
                ),
              ),
            ],
            if (title != null) ...[
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  title!,
                  style: AppTypography.headline.copyWith(color: label),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Divider(height: 1, thickness: 0.5, color: divider),
            ] else
              const SizedBox(height: AppSpacing.xs),
            Flexible(
              child: SingleChildScrollView(
                controller: scrollController,
                child: child,
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
