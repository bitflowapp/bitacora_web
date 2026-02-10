import 'package:flutter/foundation.dart';

import 'web_flush_signal_stub.dart'
    if (dart.library.html) 'web_flush_signal_web.dart';

class WebFlushSignal {
  static VoidCallback attach(VoidCallback onFlushRequested) {
    return WebFlushSignalImpl.attach(onFlushRequested);
  }
}
