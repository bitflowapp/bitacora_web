class PremiumConfig {
  static const int trialDays = int.fromEnvironment(
    'TRIAL_DAYS',
    defaultValue: 7,
  );

  static const String mpProMonthlyUrl = String.fromEnvironment(
    'MP_PRO_MONTHLY_URL',
    defaultValue: '',
  );
  static const String mpTeamsMonthlyUrl = String.fromEnvironment(
    'MP_TEAMS_MONTHLY_URL',
    defaultValue: '',
  );
  static const String mpProAnnualUrl = String.fromEnvironment(
    'MP_PRO_ANNUAL_URL',
    defaultValue: '',
  );
  static const String mpTeamsAnnualUrl = String.fromEnvironment(
    'MP_TEAMS_ANNUAL_URL',
    defaultValue: '',
  );
  static const String mpTransferCbu = String.fromEnvironment(
    'MP_TRANSFER_CBU',
    defaultValue: '',
  );

  static String get proMonthlyUrl => mpProMonthlyUrl.trim();
  static String get teamsMonthlyUrl => mpTeamsMonthlyUrl.trim();
  static String get proAnnualUrl => mpProAnnualUrl.trim();
  static String get teamsAnnualUrl => mpTeamsAnnualUrl.trim();
  static String get transferCbu => mpTransferCbu.trim();
  static bool get hasTransferCbu => transferCbu.isNotEmpty;
}
