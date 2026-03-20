import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppHaptics {
  static bool get _supported {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.android;
  }

  static void selection() {
    if (!_supported) return;
    HapticFeedback.selectionClick();
  }

  static void light() {
    if (!_supported) return;
    HapticFeedback.lightImpact();
  }

  static void success() {
    if (!_supported) return;
    HapticFeedback.mediumImpact();
  }

  static void error() {
    if (!_supported) return;
    HapticFeedback.heavyImpact();
  }
}
