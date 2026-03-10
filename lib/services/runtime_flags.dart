import 'package:flutter/foundation.dart' show visibleForTesting;

class RuntimeFlags {
  RuntimeFlags._();

  /// Demo mode keeps the app accessible without authentication.
  ///
  /// Enabled by default for this branch so the app opens directly for demos.
  static const bool demoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: true,
  );

  /// Explicit auth switch for future reactivation.
  ///
  /// When [demoMode] is true, auth is always bypassed even if this is true.
  static const bool authEnabled = bool.fromEnvironment(
    'AUTH_ENABLED',
    defaultValue: false,
  );

  /// Monetization master switch.
  ///
  /// Default is free-only mode so product testing has zero Pro friction.
  static bool _monetizationEnabled = bool.fromEnvironment(
    'MONETIZATION_ENABLED',
    defaultValue: false,
  );

  static bool get monetizationEnabled => _monetizationEnabled;

  @visibleForTesting
  static void setMonetizationEnabledForTest(bool value) {
    _monetizationEnabled = value;
  }

  @visibleForTesting
  static void resetMonetizationFlagForTest() {
    _monetizationEnabled = bool.fromEnvironment(
      'MONETIZATION_ENABLED',
      defaultValue: false,
    );
  }

  static const bool isAuthRequired = authEnabled && !demoMode;

  static const bool openHomeDirectly = demoMode;
}
