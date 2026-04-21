// lib/services/engine_config.dart
//
// EngineConfig: runtime settings for BitFlow Engine base URL.
// - Stores mode (auto/manual), manual_base_url, last_resolved_base_url.
// - Web: supports ?engine=https://... override (highest priority).
// - Fallback: --dart-define=ENGINE_URL=... when no prefs.
// - Defaults: LAN + Tunnel provided here.
//
// No dart:io. Web/Mobile/Desktop compatible.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EngineConfig {
  EngineConfig._();

  static final EngineConfig instance = EngineConfig._();

  static const String modeAuto = 'auto';
  static const String modeManual = 'manual';

  static const String webQueryParam = 'engine';

  static const String defaultTunnelBaseUrl =
      'https://dock-stranger-crossing-breeding.trycloudflare.com';
  static const String defaultLanBaseUrl = 'http://192.168.1.37:8001';

  static const String _kModeKey = 'engine_mode';
  static const String _kManualBaseKey = 'engine_manual_base_url';
  static const String _kLastResolvedKey = 'engine_last_resolved_base_url';

  /// Normalizes: trim + drop trailing slash + adds scheme if missing.
  static String normalize(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;

    final hasScheme = u.contains('://');
    if (!hasScheme) {
      u = 'https://$u';
    }

    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  // ── Allowlist ─────────────────────────────────────────────────────────────
  // Exact hostnames or suffix patterns (prefix '.') allowed for ?engine= override.
  // In debug mode all URLs pass with a warning; in release only listed hosts are accepted.
  static const List<String> _allowedHostPatterns = [
    'localhost',
    '127.0.0.1',
    '0.0.0.0',
    '.trycloudflare.com',   // Cloudflare tunnels
    '.ngrok-free.app',      // ngrok free-tier tunnels
    '.ngrok.io',
    '.loca.lt',             // localtunnel
  ];

  /// Returns true if [url]'s host is on the allowlist.
  /// In debug mode always returns true (with a log), so developers can use any server.
  static bool isAllowedEngineHost(String url) {
    final host = Uri.tryParse(normalize(url))?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;

    for (final pattern in _allowedHostPatterns) {
      if (pattern.startsWith('.')) {
        if (host.endsWith(pattern)) return true;
      } else {
        if (host == pattern) return true;
      }
    }

    if (kDebugMode) {
      debugPrint('[EngineConfig] Host "$host" not in allowlist — '
          'allowed in debug mode only');
      return true;
    }

    return false;
  }

  static bool isValidBaseUrl(String url) {
    final u = normalize(url);
    if (u.isEmpty) return false;

    final uri = Uri.tryParse(u);
    if (uri == null) return false;
    if (uri.host.isEmpty) return false;
    if (kIsWeb && uri.scheme != 'https') return false;
    if (!kIsWeb && uri.scheme != 'http' && uri.scheme != 'https') {
      return false;
    }
    if (uri.host.trim().isEmpty) return false;
    return true;
  }

  Future<String> get mode async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_kModeKey) ?? modeAuto).trim().toLowerCase();
    return raw == modeManual ? modeManual : modeAuto;
  }

  Future<String?> get manualBaseUrl async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_kManualBaseKey) ?? '').trim();
    if (raw.isEmpty || !isValidBaseUrl(raw)) return null;
    return normalize(raw);
  }

  Future<String?> get lastResolvedBaseUrl async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_kLastResolvedKey) ?? '').trim();
    if (raw.isEmpty || !isValidBaseUrl(raw)) return null;
    return normalize(raw);
  }

  Future<void> setMode(String nextMode) async {
    final v = nextMode.trim().toLowerCase();
    final normalized = v == modeManual ? modeManual : modeAuto;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModeKey, normalized);
  }

  Future<void> setManualBaseUrl(String url) async {
    final normalized = normalize(url);
    if (!isValidBaseUrl(normalized)) {
      throw ArgumentError('Engine manual_base_url invalida: $url');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kManualBaseKey, normalized);
  }

  Future<void> setLastResolved(String url) async {
    final normalized = normalize(url);
    final prefs = await SharedPreferences.getInstance();
    if (normalized.isEmpty || !isValidBaseUrl(normalized)) {
      await prefs.remove(_kLastResolvedKey);
      return;
    }
    await prefs.setString(_kLastResolvedKey, normalized);
  }

  /// Returns preferred base URL if user provided one (query/env/manual).
  /// If null, caller should use auto resolution (LAN -> Tunnel).
  Future<String?> resolvePreferredBaseUrl() async {
    if (kIsWeb) {
      final qp = Uri.base.queryParameters[webQueryParam];
      if (qp != null && qp.trim().isNotEmpty && isValidBaseUrl(qp)) {
        final normalized = normalize(qp);
        await setManualBaseUrl(normalized);
        await setMode(modeManual);
        await setLastResolved(normalized);
        return normalized;
      }
    }

    const envUrl = String.fromEnvironment('ENGINE_BASE_URL', defaultValue: '');
    if (envUrl.trim().isNotEmpty && isValidBaseUrl(envUrl)) {
      return normalize(envUrl);
    }

    final currentMode = await mode;
    if (currentMode == modeManual) {
      final manual = await manualBaseUrl;
      if (manual != null) return manual;
    }

    return null;
  }
}
