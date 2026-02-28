import 'package:flutter/material.dart';

import 'app_button.dart';
import 'app_card.dart';
import 'app_tokens.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    required this.message,
    this.details,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String message;
  final String? details;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasAction = (actionLabel ?? '').trim().isNotEmpty && onAction != null;
    final resolvedMessage = message.trim().isEmpty
        ? 'Ocurrio un problema inesperado. Intenta nuevamente.'
        : message.trim();
    final detailsText = (details ?? '').trim();

    return AppCard(
      padding: EdgeInsets.all(compact ? 16 : 22),
      borderColor: t.colors.dangerFg.withValues(alpha: 0.35),
      color: t.colors.dangerBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 36 : 44,
                height: compact ? 36 : 44,
                decoration: BoxDecoration(
                  color: t.colors.dangerFg.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(t.radii.md),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: t.colors.dangerFg,
                  size: compact ? 20 : 24,
                ),
              ),
              SizedBox(width: t.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.trim().isEmpty ? 'No se pudo completar' : title,
                      style: t.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: t.spacing.xs),
                    Text(
                      resolvedMessage,
                      style: t.text.bodyMedium?.copyWith(
                        color: t.colors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (detailsText.isNotEmpty) ...[
            SizedBox(height: t.spacing.sm),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: t.spacing.md,
                vertical: t.spacing.sm,
              ),
              decoration: BoxDecoration(
                color: t.colors.surface.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(t.radii.sm),
                border: Border.all(color: t.colors.border),
              ),
              child: SelectableText(
                detailsText,
                style: t.text.bodySmall?.copyWith(
                  color: t.colors.textSecondary,
                  height: 1.25,
                ),
              ),
            ),
          ],
          if (hasAction) ...[
            SizedBox(height: t.spacing.md),
            AppButton(
              label: actionLabel!,
              variant: AppButtonVariant.secondary,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
