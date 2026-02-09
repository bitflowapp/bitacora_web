import 'package:flutter/foundation.dart';

/// Stub (no-web): siempre 0.
class VisualViewportInsetsController {
  final ValueNotifier<double> bottomInset = ValueNotifier<double>(0);

  VisualViewportInsetsController();

  void recalcNow() {}

  void dispose() {
    bottomInset.dispose();
  }
}
