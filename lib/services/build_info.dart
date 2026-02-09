import 'dart:convert';

class BuildInfo {
  static const String gitSha =
      String.fromEnvironment('GIT_SHA', defaultValue: 'dev');
  static const String buildTime =
      String.fromEnvironment('BUILD_TIME', defaultValue: '');
  static const String engineBaseUrl =
      String.fromEnvironment('ENGINE_BASE_URL', defaultValue: '');

  static String get shortSha {
    final s = gitSha.trim();
    if (s.isEmpty || s == 'dev') return 'dev';
    return s.length <= 7 ? s : s.substring(0, 7);
  }

  static String get stamp {
    final ts = buildTime.trim();
    if (ts.isEmpty) return 'Build: $shortSha';
    return 'Build: $shortSha • $ts';
  }

  static Map<String, dynamic> toJson() => {
        'gitSha': gitSha.trim().isEmpty ? 'dev' : gitSha.trim(),
        'buildTime': buildTime.trim(),
        'engineBaseUrl': engineBaseUrl.trim(),
      };

  static String toJsonString() => jsonEncode(toJson());
}
