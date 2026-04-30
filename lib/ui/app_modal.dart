import 'package:flutter/material.dart';

import 'app_card.dart';
import 'app_motion.dart';
import 'app_tokens.dart';

class AppModal extends StatelessWidget {
  const AppModal({
    super.key,
    this.title,
    required this.child,
    this.actions,
    this.showClose = true,
    this.maxWidth = 620,
  });

  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final bool showClose;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final maxHeight = MediaQuery.sizeOf(context).height - 40;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: AppCard(
          padding: const EdgeInsets.all(20),
          radius: t.radii.xl,
          borderColor: t.colors.borderStrong,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null || showClose)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (title != null)
                      Expanded(
                        child: Text(
                          title!,
                          style: t.text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    if (showClose)
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: IconButton(
                          tooltip: 'Cerrar',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                  ],
                ),
              if (title != null || showClose) const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(child: child),
              ),
              if (actions != null) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: actions!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> showAppModal<T>({
  required BuildContext context,
  String? title,
  required Widget child,
  List<Widget>? actions,
  bool showClose = true,
  double maxWidth = 560,
  bool barrierDismissible = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'app_modal',
    barrierColor: Colors.black.withValues(alpha: 0.22),
    transitionDuration: AppMotion.modal,
    pageBuilder: (_, __, ___) => AppModal(
      title: title,
      actions: actions,
      showClose: showClose,
      maxWidth: maxWidth,
      child: child,
    ),
    transitionBuilder: (ctx, animation, _, modal) {
      return AppMotion.modalTransition(
        context: ctx,
        animation: animation,
        child: modal,
      );
    },
  );
}
