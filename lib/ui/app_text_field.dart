import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 1,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasError = (errorText ?? '').trim().isNotEmpty;
    final borderColor = hasError ? t.colors.dangerFg : t.colors.border;

    final radius = BorderRadius.circular(t.radii.md);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: t.text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: t.spacing.xs),
        ],
        TextField(
          controller: controller,
          onChanged: onChanged,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            filled: true,
            fillColor: t.colors.surface,
            contentPadding: EdgeInsets.symmetric(
              horizontal: t.spacing.lg,
              vertical: t.spacing.sm,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: t.colors.focusRing, width: 1.2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: t.colors.dangerFg, width: 1),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(
                color: t.colors.border.withOpacity(0.6),
                width: 1,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: t.spacing.xs),
          Text(
            errorText!,
            style: t.text.bodySmall?.copyWith(color: t.colors.dangerFg),
          ),
        ],
      ],
    );
  }
}
