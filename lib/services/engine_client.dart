// lib/services/engine_client.dart
//
// BitFlow Engine Client (FastAPI) — Web/Mobile compatible (sin dart:io)
// - Lee engine_url dinámico desde version.json (misma origin) + cache en SharedPreferences
// - Endpoints: healthz, smart_edit_cell, compute
//
// Requiere pubspec:
//   http: ^1.2.2
//   shared_preferences: ^2.3.2
//
// Uso recomendado:
//   await EngineConfig.instance.init();
//   final api = EngineClient();
//   await api.healthz();

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EngineConfig {
  EngineConfig._();

  static final EngineConfig instance = EngineConfig._();

  static const _prefsKey = 'bitflow_engine_url';
  static const _prefsOverrideKey = 'bitflow_engine_url_override';

  Uri _baseUri = Uri.parse('http://127.0.0.1:8011');
  Uri get baseUri => _baseUri;

  /// Inicializa la URL del engine:
  /// 1) override manual guardado (si existe)
  /// 2) version.json (misma origin) si tiene engine_url
  /// 3) --dart-define=ENGINE_URL
  /// 4) fallback local
  Future<void> init({
    Duration timeout = const Duration(seconds: 6),
    String versionJsonPath = 'version.json',
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final override = prefs.getString(_prefsOverrideKey);
    if (_isValidHttpUrl(override)) {
      _baseUri = Uri.parse(override!);
      return;
    }

    // 1) Intentar leer version.json desde misma origin (web) o desde el bundle-served root (mobile/web).
    final fromVersion = await _tryLoadEngineUrlFromVersionJson(
      prefs: prefs,
      timeout: timeout,
      versionJsonPath: versionJsonPath,
    );
    if (_isValidHttpUrl(fromVersion)) {
      _baseUri = Uri.parse(fromVersion!);
      await prefs.setString(_prefsKey, fromVersion);
      return;
    }

    // 2) Si falla, usar cache previa (si existe)
    final cached = prefs.getString(_prefsKey);
    if (_isValidHttpUrl(cached)) {
      _baseUri = Uri.parse(cached!);
      return;
    }

    // 3) Si no hay nada, usar dart-define (si lo pasaste en build/run)
    const envUrl = String.fromEnvironment('ENGINE_URL', defaultValue: '');
    if (_isValidHttpUrl(envUrl)) {
      _baseUri = Uri.parse(envUrl);
      await prefs.setString(_prefsKey, envUrl);
      return;
    }

    // 4) Fallback local
    _baseUri = Uri.parse('http://127.0.0.1:8011');
  }

  Future<void> setOverride(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(_prefsOverrideKey);
      return;
    }
    if (!_isValidHttpUrl(url)) {
      throw ArgumentError('engine_url inválida: $url');
    }
    await prefs.setString(_prefsOverrideKey, url.trim());
    _baseUri = Uri.parse(url.trim());
  }

  Future<String?> _tryLoadEngineUrlFromVersionJson({
    required SharedPreferences prefs,
    required Duration timeout,
    required String versionJsonPath,
  }) async {
    try {
      final cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();

      // Uri.base funciona en web; en mobile también existe pero apunta a "file:///" en algunos casos.
      // Resolvemos relativo: si falla, no pasa nada (se captura).
      final versionUri = Uri.base.resolve('$versionJsonPath?x=$cacheBuster');

      final resp = await http
          .get(versionUri, headers: const {'Cache-Control': 'no-store'})
          .timeout(timeout);

      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;

      final map = jsonDecode(resp.body);
      if (map is! Map) return null;

      final engineUrl = map['engine_url'];
      if (engineUrl is String && _isValidHttpUrl(engineUrl)) {
        return engineUrl.trim();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _isValidHttpUrl(String? s) {
    if (s == null) return false;
    final v = s.trim();
    if (v.isEmpty) return false;
    final uri = Uri.tryParse(v);
    if (uri == null) return false;
    if (!(uri.scheme == 'http' || uri.scheme == 'https')) return false;
    if (uri.host.isEmpty) return false;
    return true;
  }
}

class EngineClient {
  EngineClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Duration timeout = const Duration(seconds: 12);

  Uri _u(String path, [Map<String, String>? q]) {
    final base = EngineConfig.instance.baseUri;
    final p = path.startsWith('/') ? path : '/$path';
    return base.replace(
      path: _joinPaths(base.path, p),
      queryParameters: q,
    );
  }

  static String _joinPaths(String a, String b) {
    final aa = a.endsWith('/') ? a.substring(0, a.length - 1) : a;
    final bb = b.startsWith('/') ? b : '/$b';
    return '$aa$bb';
  }

  Future<Map<String, dynamic>> healthz() async {
    return _getJson('/healthz');
  }

  Future<Map<String, dynamic>> readyz() async {
    return _getJson('/readyz');
  }

  /// Normaliza y asiste edición de una celda
  Future<Map<String, dynamic>> smartEditCell({
    String? sheetId,
    String? columnName,
    int? rowIndex,
    required String rawValue,
    String? previousValue,
    Map<String, dynamic>? neighborValues,
    Map<String, dynamic>? options,
  }) async {
    final body = <String, dynamic>{
      'sheet_id': sheetId,
      'column_name': columnName,
      'row_index': rowIndex,
      'raw_value': rawValue,
      'previous_value': previousValue,
      'neighbor_values': neighborValues,
      'options': options,
    };
    return _postJson('/editor/cell/smart_edit', body);
  }

  /// Ejecuta motor de cálculo sobre la planilla
  Future<Map<String, dynamic>> compute({
    required String sheetId,
    required List<String> headers,
    required List<List<String>> rows,
    String operation = 'calc',
    int? focusRow,
    int? focusCol,
    Map<String, dynamic>? options,
  }) async {
    final body = <String, dynamic>{
      'sheet_id': sheetId,
      'headers': headers,
      'rows': rows,
      'operation': operation,
      'focus_row': focusRow,
      'focus_col': focusCol,
      'options': options,
    };
    return _postJson('/engine/compute', body);
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final uri = _u(path, {'x': DateTime.now().millisecondsSinceEpoch.toString()});
    final resp = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(timeout);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw EngineHttpException(resp.statusCode, resp.body);
    }
    final data = jsonDecode(resp.body);
    if (data is Map<String, dynamic>) return data;
    throw const EngineProtocolException('Respuesta JSON inválida (no es objeto).');
  }

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body) async {
    final uri = _u(path, {'x': DateTime.now().millisecondsSinceEpoch.toString()});
    final resp = await _client
        .post(
      uri,
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode(_stripNulls(body)),
    )
        .timeout(timeout);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw EngineHttpException(resp.statusCode, resp.body);
    }
    final data = jsonDecode(resp.body);
    if (data is Map<String, dynamic>) return data;
    throw const EngineProtocolException('Respuesta JSON inválida (no es objeto).');
  }

  static Map<String, dynamic> _stripNulls(Map<String, dynamic> m) {
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      if (v == null) return;
      out[k] = v;
    });
    return out;
  }

  void dispose() => _client.close();
}

class EngineHttpException implements Exception {
  EngineHttpException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() => 'EngineHttpException(status=$statusCode, body=$body)';
}

class EngineProtocolException implements Exception {
  const EngineProtocolException(this.message);
  final String message;

  @override
  String toString() => 'EngineProtocolException($message)';
}
