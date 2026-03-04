import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

class AppDecorPolicy {
  @visibleForTesting
  static bool? debugDecorativeBackgroundOverride;

  static bool get enableDecorativeBackground {
    final override = debugDecorativeBackgroundOverride;
    if (override != null) return override;
    if (kIsWeb) {
      return const bool.fromEnvironment(
        'ENABLE_DECOR_BG',
        defaultValue: false,
      );
    }
    return true;
  }

  static bool get disableDecorativeBackground => !enableDecorativeBackground;
}
