import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EngineBaseUrl {
  EngineBaseUrl._();

  static const prefsKey = 'bitflow_engine_base_url';

  /// Importante: en iPhone/Web tu app (https) NO puede pegarle a http://127.0.0.1
  /// Así que el default “real” debe ser vacío y forzarte a setear tunnel.
  static const String defaultBaseUrl = '';

  /// Lee desde prefs. Si está vacío, devuelve defaultBaseUrl.
  static Future<String> get() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(prefsKey);
    final clean = (v ?? '').trim().replaceAll(RegExp(r'\/+$'), '');
    return clean.isEmpty ? defaultBaseUrl : clean;
  }

  /// Guarda base url limpia.
  static Future<void> set(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'\/+$'), '');
    if (clean.isEmpty) {
      throw ArgumentError('URL inválida.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, clean);
  }

  /// Web only: permite setear el engine desde la URL:
  /// https://tuapp/?engine=https://xxxxx.trycloudflare.com
  static Future<void> bootstrapFromQueryParam() async {
    if (!kIsWeb) return;

    final engine = Uri.base.queryParameters['engine']?.trim();
    if (engine == null || engine.isEmpty) return;

    final clean = engine.replaceAll(RegExp(r'\/+$'), '');
    // Aceptamos solo http/https
    final u = Uri.tryParse(clean);
    if (u == null || (u.scheme != 'https' && u.scheme != 'http')) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, clean);
  }
}
