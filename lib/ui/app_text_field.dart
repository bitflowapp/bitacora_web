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
    final fill = t.colors.surfaceMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: t.text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
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
            fillColor: fill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(t.radii.md),
              borderSide: BorderSide(color: borderColor, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(t.radii.md),
              borderSide: BorderSide(color: t.colors.focusRing, width: 1.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(t.radii.md),
              borderSide: BorderSide(color: t.colors.dangerFg, width: 0.9),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(t.radii.md),
              borderSide: BorderSide(
                color: t.colors.border.withOpacity(0.5),
                width: 0.8,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: t.text.bodySmall?.copyWith(color: t.colors.dangerFg),
          ),
        ],
      ],
    );
  }
}
