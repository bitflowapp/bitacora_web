import 'package:flutter/material.dart';

import 'animated_video_background.dart';

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
        '[bg-layer] $debugLayerName mobileWebUi=$disableDecorativeBackground',
      );
      return true;
    }());

    if (disableDecorativeBackground) {
      assert(() {
        debugPrint('[bg-layer] $debugLayerName => opaque background only');
        return true;
      }());
      return Scaffold(
        backgroundColor: opaqueBackground,
        body: child,
      );
    }

    assert(() {
      debugPrint('[bg-layer] $debugLayerName => AnimatedVideoBackground ON');
      return true;
    }());
    return AnimatedVideoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: child,
      ),
    );
  }
}
