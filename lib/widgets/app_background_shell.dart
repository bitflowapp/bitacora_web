import 'package:flutter/material.dart';

class AppBackgroundShell extends StatelessWidget {
  const AppBackgroundShell({
    super.key,
    required this.child,
    required this.disableDecorativeBackground,
    required this.backgroundColor,
    required this.debugLayerName,
  });

  final Widget child;
  final bool disableDecorativeBackground;
  final Color backgroundColor;
  final String debugLayerName;

  @override
  Widget build(BuildContext context) {
    final opaqueBackground = backgroundColor.withValues(alpha: 1);
    assert(() {
      debugPrint(
        '[bg-layer] $debugLayerName => solid scaffold only '
        '(decorDisabled=$disableDecorativeBackground)',
      );
      return true;
    }());
    return Scaffold(
      backgroundColor: opaqueBackground,
      body: child,
    );
  }
}
