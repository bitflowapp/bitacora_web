import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (message.trim().isEmpty) return;
    final t = context.tokens;
    final bg = isError ? t.colors.dangerBg : t.colors.statusBg;
    final fg = isError ? t.colors.dangerFg : t.colors.statusFg;
    final iconData = icon ??
        (isError
            ? Icons.error_outline_rounded
            : Icons.check_circle_outline_rounded);
    final border = isError ? t.colors.dangerFg : t.colors.accent;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radii.md),
          side: BorderSide(color: border.withOpacity(0.45), width: 0.8),
        ),
        elevation: 6,
        margin: const EdgeInsets.all(12),
        content: Row(
          children: [
            Icon(iconData, size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
