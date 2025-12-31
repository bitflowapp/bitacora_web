import 'package:flutter/foundation.dart';

class VisualViewportInsetsController {
  final ValueNotifier<double> bottomInset = ValueNotifier<double>(0);

  void recalcNow() {}

  void dispose() {
    bottomInset.dispose();
  }
}
