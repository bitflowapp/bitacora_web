// lib/services/engine_service.dart
//
// BitFlow Engine Service (HTTP)
// - Ping:    GET  /health   (fallback GET /)
// - Compute: POST /engine/compute
// - Export:  POST /export/xlsx/flat            (simple xlsx, sin fotos)
// - Export+: POST /export/xlsx/bitflow_photos  (xlsx con fotos)
//
// Diseño:
// - Timeout configurable
// - API key opcional en header "X-API-Key"
// - Manejo de errores con mensajes claros
// - Compatible Web (no usa dart:io)
//
// Requiere:
//   http: ^1.x
//
// Uso típico:
//   final engine = EngineService(baseUrl: url, apiKey: key);
//   final ping = await engine.ping();
//   final result = await engine.compute(payload);

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class EngineService {
  EngineService({
    required String baseUrl,
    this.apiKey,
    this.timeout = const Duration(seconds: 12),
    http.Client? client,
  })  : baseUrl = normalizeBaseUrl(baseUrl),
        _client = client ?? http.Client();

  /// Ej: http://127.0.0.1:8001  (sin slash final)
  final String baseUrl;

  /// Header opcional. Si tu backend no usa auth, dejalo null/vacío.
  final String? apiKey;

  final Duration timeout;

  final http.Client _client;

  static String normalizeBaseUrl(String v) {
    var s = (v).trim();
    if (s.isEmpty) return s;
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  void close() => _client.close();

  Map<String, String> _headersJson() {
    final h = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json, text/plain, */*',
    };
    final k = (apiKey ?? '').trim();
    if (k.isNotEmpty) h['X-API-Key'] = k;
    return h;
  }

  Map<String, String> _headersBytes() {
    final h = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept':
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/octet-stream, */*',
    };
    final k = (apiKey ?? '').trim();
    if (k.isNotEmpty) h['X-API-Key'] = k;
    return h;
  }

  Uri _u(String path) {
    final b = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    final p = path.trim().startsWith('/') ? path.trim() : '/${path.trim()}';
    return Uri.parse('$b$p');
  }

  String _decodeBody(http.Response res) {
    try {
      return utf8.decode(res.bodyBytes);
    } catch (_) {
      return res.body;
    }
  }

  /// GET /health (fallback GET /)
  Future<EnginePingResult> ping() async {
    if (baseUrl.trim().isEmpty) {
      return EnginePingResult(ok: false, statusCode: null, detail: 'baseUrl vacío');
    }

    // 1) /health
    try {
      final uri = _u('/health');
      final res = await _client.get(uri, headers: _headersJson()).timeout(timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = _decodeBody(res).trim();
        return EnginePingResult(ok: true, statusCode: res.statusCode, detail: body.isEmpty ? 'OK' : body);
      }
    } catch (_) {
      // seguimos a fallback
    }

    // 2) /
    try {
      final uri = _u('/');
      final res = await _client.get(uri, headers: _headersJson()).timeout(timeout);
      final body = _decodeBody(res).trim();
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      return EnginePingResult(ok: ok, statusCode: res.statusCode, detail: body.isEmpty ? 'HTTP ${res.statusCode}' : body);
    } catch (e) {
      return EnginePingResult(ok: false, statusCode: null, detail: e.toString());
    }
  }

  /// POST /engine/compute
  /// Payload libre (tu backend define el schema).
  Future<Map<String, dynamic>> compute(Map<String, dynamic> payload) async {
    final uri = _u('/engine/compute');
    final res = await _client
        .post(uri, headers: _headersJson(), body: jsonEncode(payload))
        .timeout(timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw EngineHttpException(
        statusCode: res.statusCode,
        message: _bestEffortMessage(res),
        path: uri.toString(),
      );
    }

    final body = _decodeBody(res).trim();
    if (body.isEmpty) return <String, dynamic>{};

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;

    return <String, dynamic>{'result': decoded};
  }

  /// POST /export/xlsx/flat
  /// Devuelve bytes de un XLSX.
  Future<Uint8List> exportXlsxFlat(Map<String, dynamic> payload) async {
    final uri = _u('/export/xlsx/flat');
    final res = await _client
        .post(uri, headers: _headersBytes(), body: jsonEncode(payload))
        .timeout(timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw EngineHttpException(
        statusCode: res.statusCode,
        message: _bestEffortMessage(res),
        path: uri.toString(),
      );
    }
    return res.bodyBytes;
  }

  /// POST /export/xlsx/bitflow_photos
  /// Si tu backend exporta fotos embebidas en XLSX.
  Future<Uint8List> exportXlsxWithPhotos(Map<String, dynamic> payload) async {
    final uri = _u('/export/xlsx/bitflow_photos');
    final res = await _client
        .post(uri, headers: _headersBytes(), body: jsonEncode(payload))
        .timeout(timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw EngineHttpException(
        statusCode: res.statusCode,
        message: _bestEffortMessage(res),
        path: uri.toString(),
      );
    }
    return res.bodyBytes;
  }

  String _bestEffortMessage(http.Response res) {
    final b = _decodeBody(res).trim();
    if (b.isEmpty) return 'HTTP ${res.statusCode}';

    // Si el backend devuelve json con detail/message/error
    try {
      final j = jsonDecode(b);
      if (j is Map) {
        final detail = j['detail'] ?? j['message'] ?? j['error'];
        if (detail != null) return '$detail';
      }
    } catch (_) {
      // ignore
    }

    // Fallback a texto plano (cortito)
    if (b.length > 300) return b.substring(0, 300);
    return b;
  }
}

class EnginePingResult {
  EnginePingResult({required this.ok, required this.statusCode, required this.detail});
  final bool ok;
  final int? statusCode;
  final String detail;
}

class EngineHttpException implements Exception {
  EngineHttpException({
    required this.statusCode,
    required this.message,
    required this.path,
  });

  final int statusCode;
  final String message;
  final String path;

  @override
  String toString() => 'EngineHttpException($statusCode) $message @ $path';
}
