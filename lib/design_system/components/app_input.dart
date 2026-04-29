import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../spacing.dart';
import '../typography.dart';

class AppInput extends StatelessWidget {
  const AppInput({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.obscureText = false,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool autofocus;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final fill = AppColors.fill(brightness);
    final divider = AppColors.divider(brightness);
    final label_ = AppColors.label(brightness);
    final secondaryLabel = AppColors.secondaryLabel(brightness);
    final accent = AppColors.accent(brightness);

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.md),
      borderSide: BorderSide(
        color: divider.withValues(alpha: 0.8),
        width: 0.9,
      ),
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      autofocus: autofocus,
      enabled: enabled,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      style: AppTypography.body.copyWith(color: label_),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.body.copyWith(color: secondaryLabel),
        hintText: hint,
        hintStyle: AppTypography.body.copyWith(color: secondaryLabel),
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: fill.withValues(alpha: 0.5),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          borderSide: BorderSide(
            color: divider.withValues(alpha: 0.4),
            width: 0.9,
          ),
        ),
        counterText: '',
      ),
    );
  }
}
