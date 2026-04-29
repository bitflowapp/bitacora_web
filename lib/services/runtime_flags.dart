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

  static const bool isAuthRequired = authEnabled && !demoMode;

  static const bool openHomeDirectly = demoMode;
}
