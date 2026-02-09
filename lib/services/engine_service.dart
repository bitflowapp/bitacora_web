// lib/services/engine_service.dart
//
// BitFlow Engine Service (HTTP)
// - Ping:    GET  /healthz  (fallback GET /readyz, luego GET /)
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
//   final engine = EngineService(baseUrl: EngineService.defaultBaseUrl);
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

  /// Default según tu server real (logs): 127.0.0.1:8001
  static const String defaultBaseUrl = 'http://127.0.0.1:8001';

  /// Ej: http://127.0.0.1:8001  (sin slash final)
  final String baseUrl;

  /// Header opcional. Si tu backend no usa auth, dejalo null/vacío.
  final String? apiKey;

  final Duration timeout;

  final http.Client _client;

  /// Normaliza:
  /// - agrega scheme http:// si falta
  /// - quita slashes finales
  static String normalizeBaseUrl(String v) {
    var s = v.trim();
    if (s.isEmpty) return s;

    // Si viene "127.0.0.1:8001" => "http://127.0.0.1:8001"
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }

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

  Uri _u(String path, {bool cacheBust = true}) {
    final b = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    final p = path.trim().startsWith('/') ? path.trim() : '/${path.trim()}';

    var uri = Uri.parse('$b$p');
    if (!cacheBust) return uri;

    final qp = Map<String, String>.from(uri.queryParameters);
    qp['x'] = DateTime.now().millisecondsSinceEpoch.toString();
    uri = uri.replace(queryParameters: qp);
    return uri;
  }

  String _decodeBody(http.Response res) {
    try {
      return utf8.decode(res.bodyBytes);
    } catch (_) {
      return res.body;
    }
  }

  /// PING REAL (según tu backend):
  /// 1) GET /healthz
  /// 2) GET /readyz
  /// 3) GET /
  Future<EnginePingResult> ping() async {
    if (baseUrl.trim().isEmpty) {
      return EnginePingResult(
          ok: false, statusCode: null, detail: 'baseUrl vacío');
    }

    // 1) /healthz
    final r1 = await _tryGet('/healthz');
    if (r1.ok) return r1;

    // 2) /readyz
    final r2 = await _tryGet('/readyz');
    if (r2.ok) return r2;

    // 3) /
    final r3 = await _tryGet('/');
    return r3;
  }

  Future<EnginePingResult> _tryGet(String path) async {
    try {
      final uri = _u(path);
      final res =
          await _client.get(uri, headers: _headersJson()).timeout(timeout);
      final body = _decodeBody(res).trim();
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      return EnginePingResult(
        ok: ok,
        statusCode: res.statusCode,
        detail: body.isEmpty ? 'HTTP ${res.statusCode}' : body,
      );
    } catch (e) {
      return EnginePingResult(
          ok: false, statusCode: null, detail: e.toString());
    }
  }

  /// POST /engine/compute
  /// Payload libre (tu backend define el schema).
  ///
  /// Nota: si falta sheet_id te va a devolver 422 (como viste en logs).
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

    // Si el backend devuelve lista/valor, lo envolvemos.
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
  /// XLSX con fotos embebidas.
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
    if (b.length > 400) return b.substring(0, 400);
    return b;
  }
}

class EnginePingResult {
  EnginePingResult(
      {required this.ok, required this.statusCode, required this.detail});
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
