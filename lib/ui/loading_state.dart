import 'package:flutter/material.dart';

import 'app_card.dart';
import 'app_tokens.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.message = 'Cargando...',
    this.compact = false,
    this.onCancel,
    this.cancelLabel = 'Cancelar',
  });

  final String message;
  final bool compact;
  final VoidCallback? onCancel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = Row(
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

    if (compact) return content;

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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
