import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EngineConfig {
  static const _kPrefsKey = 'engine_base_url';
  static const _kDefaultLocal = 'http://127.0.0.1:8001';

  static String normalize(String url) {
    var u = url.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  /// Orden de prioridad:
  /// 1) Web: query param ?engine=...
  /// 2) SharedPreferences (persistido)
  /// 3) Default local (127.0.0.1)
  static Future<String> resolveBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();

    // 1) Web: ?engine=
    if (kIsWeb) {
      final qp = Uri.base.queryParameters['engine'];
      if (qp != null && qp.trim().isNotEmpty) {
        final base = normalize(qp);
        await prefs.setString(_kPrefsKey, base);
        return base;
      }
    }

    // 2) Persistido
    final saved = prefs.getString(_kPrefsKey);
    if (saved != null && saved.trim().isNotEmpty) {
      return normalize(saved);
    }

    // 3) Default
    return _kDefaultLocal;
  }

  static Future<void> setBaseUrl(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, normalize(baseUrl));
  }
}
