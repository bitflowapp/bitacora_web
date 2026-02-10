import 'package:flutter/material.dart';

import 'app_tokens.dart';

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.hint = 'Buscar…',
    this.enabled = true,
    this.showClear = true,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hint;
  final bool enabled;
  final bool showClear;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    Widget buildField(bool hasValue) {
      return TextField(
        controller: controller,
        enabled: enabled,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: t.text.bodyMedium?.copyWith(color: t.colors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: showClear && hasValue
              ? IconButton(
                  tooltip: 'Limpiar',
                  onPressed: () {
                    controller?.clear();
                    onChanged?.call('');
                  },
                  icon: const Icon(Icons.close_rounded),
                )
              : null,
          filled: true,
          fillColor: t.colors.surfaceMuted,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(t.radii.pill),
            borderSide: BorderSide(color: t.colors.border, width: 0.9),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(t.radii.pill),
            borderSide: BorderSide(color: t.colors.focusRing, width: 1.1),
          ),
        ),
      );
    }

    if (controller == null) {
      return buildField(false);
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller!,
      builder: (_, value, __) => buildField(value.text.trim().isNotEmpty),
    );
  }
}
