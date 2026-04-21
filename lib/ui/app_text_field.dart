import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.textInputAction,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _ownFocusNode;
  bool _focused = false;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _ownFocusNode!;

  @override
  void initState() {
    super.initState();
    _ownFocusNode = widget.focusNode == null ? FocusNode() : null;
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    oldWidget.focusNode?.removeListener(_handleFocusChange);
    if (oldWidget.focusNode == null) {
      _ownFocusNode?.removeListener(_handleFocusChange);
      _ownFocusNode?.dispose();
      _ownFocusNode = null;
    }
    _ownFocusNode = widget.focusNode == null ? FocusNode() : null;
    _effectiveFocusNode.addListener(_handleFocusChange);
    _focused = _effectiveFocusNode.hasFocus;
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    final value = _effectiveFocusNode.hasFocus;
    if (_focused == value) return;
    setState(() => _focused = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasError = (widget.errorText ?? '').trim().isNotEmpty;
    final borderColor = hasError
        ? t.colors.dangerFg
        : (_focused ? t.colors.focusRing : t.colors.border);

    final radius = BorderRadius.circular(t.radii.md + 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: t.text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: t.spacing.xs),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: t.colors.surface,
            borderRadius: radius,
            border: Border.all(
              color: borderColor,
              width: _focused ? 1.2 : 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: t.colors.focusRing
                          .withValues(alpha: t.colors.isLight ? 0.18 : 0.26),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _effectiveFocusNode,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            maxLines: widget.maxLines,
            textInputAction: widget.textInputAction,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            decoration: InputDecoration(
              hintText: widget.hint,
              isDense: true,
              border: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.symmetric(
                horizontal: t.spacing.lg,
                vertical: t.spacing.sm,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: t.spacing.xs),
          Text(
            widget.errorText!,
            style: t.text.bodySmall?.copyWith(color: t.colors.dangerFg),
          ),
        ],
      ],
    );
  }
}
