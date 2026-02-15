import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:bitacora_web/services/keyboard_insets_controller.dart';

class KeyboardAwareRoot extends StatefulWidget {
  const KeyboardAwareRoot({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardAwareRoot> createState() => _KeyboardAwareRootState();
}

class _KeyboardAwareRootState extends State<KeyboardAwareRoot> {
  late final KeyboardInsetsController _controller = KeyboardInsetsController();

  @override
  void initState() {
    super.initState();
    _controller.attach();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _controller.kbInsetDp,
      builder: (context, insetDp, child) {
        final mq = MediaQuery.of(context);
        final isMobileWeb =
            kIsWeb &&
            mq.size.shortestSide < 900 &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.fuchsia);
        if (!isMobileWeb) return child!;
        final focusLabel = FocusManager.instance.primaryFocus?.debugLabel ?? '';
        if (focusLabel.contains('MobileInlineEditorFocus') ||
            focusLabel.contains('CellEditorFocus')) {
          return child!;
        }

        final mqInset = mq.viewInsets.bottom;
        final dpr = mq.devicePixelRatio <= 0 ? 1.0 : mq.devicePixelRatio;
        final visualInsetDp = _controller.keyboardInset.value / dpr;
        _controller.reportMediaQueryInset(mqInset);
        final effectiveInset = math.max(
          mqInset,
          math.max(insetDp, visualInsetDp),
        );
        if (effectiveInset <= 0.0) return child!;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: effectiveInset),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
