import 'package:flutter/material.dart';

import 'app_card.dart';
import 'app_tokens.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.title,
    this.message = 'Cargando...',
    this.detail,
    this.compact = false,
    this.onCancel,
    this.cancelLabel = 'Cancelar',
  });

  final String? title;
  final String message;
  final String? detail;
  final bool compact;
  final VoidCallback? onCancel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cleanTitle = title?.trim();
    final cleanDetail = detail?.trim();
    final hasTitle = cleanTitle != null && cleanTitle.isNotEmpty;
    final hasDetail = cleanDetail != null && cleanDetail.isNotEmpty;
    final titleText = cleanTitle ?? '';
    final detailText = cleanDetail ?? '';

    final Widget content = hasTitle
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      titleText,
                      style: t.text.titleMedium?.copyWith(
                        color: t.colors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: t.text.bodyMedium?.copyWith(
                  color: t.colors.textSecondary,
                  height: 1.35,
                ),
              ),
              if (hasDetail) ...[
                const SizedBox(height: 6),
                Text(
                  detailText,
                  style: t.text.bodySmall?.copyWith(
                    color: t.colors.textSecondary.withValues(alpha: 0.78),
                    height: 1.35,
                  ),
                ),
              ],
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  style: t.text.bodyMedium?.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
              ),
            ],
          );

    if (compact) {
      return hasTitle
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    titleText,
                    style: t.text.bodyMedium?.copyWith(
                      color: t.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            )
          : content;
    }

    final action = onCancel == null
        ? null
        : Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onCancel,
              child: Text(cancelLabel),
            ),
          );

    return AppCard(
      padding: EdgeInsets.symmetric(
        horizontal: hasTitle ? 20 : 18,
        vertical: hasTitle ? 18 : 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          content,
          if (action != null) ...[
            const SizedBox(height: 10),
            action,
          ],
        ],
      ),
    );
  }
}
