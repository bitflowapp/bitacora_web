import 'package:flutter/foundation.dart';

class VisualViewportInsetsController {
  final ValueNotifier<double> bottomInset = ValueNotifier<double>(0);

  /// En no-web, MediaQuery.viewInsets suele ser suficiente.
  void recalcNow() {
    // no-op
  }

  void dispose() {
    bottomInset.dispose();
  }
}
