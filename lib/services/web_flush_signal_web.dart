import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

class WebFlushSignalImpl {
  static VoidCallback attach(VoidCallback onFlushRequested) {
    final subscriptions = <StreamSubscription<dynamic>>[];

    void requestFlush() {
      try {
        onFlushRequested();
      } catch (_) {}
    }

    try {
      subscriptions.add(html.document.onVisibilityChange.listen((_) {
        if (html.document.visibilityState == 'hidden') {
          requestFlush();
        }
      }));
    } catch (_) {}

    try {
      subscriptions.add(html.window.onPageHide.listen((_) => requestFlush()));
    } catch (_) {}

    try {
      subscriptions
          .add(html.window.onBeforeUnload.listen((_) => requestFlush()));
    } catch (_) {}

    return () {
      for (final sub in subscriptions) {
        sub.cancel();
      }
    };
  }
}
