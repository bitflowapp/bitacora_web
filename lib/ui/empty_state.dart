import 'package:flutter/material.dart';

import 'app_button.dart';
import 'app_card.dart';
import 'app_tokens.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: t.colors.accent),
          const SizedBox(height: 12),
          Text(
            title,
            style: t.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: t.text.bodyMedium?.copyWith(color: t.colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            AppButton(
              label: actionLabel!,
              variant: AppButtonVariant.primary,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
