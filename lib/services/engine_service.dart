// lib/services/engine_service.dart
//
// BitFlow Engine Service (HTTP)
// - Compute: POST /engine/compute
// - Export:  POST /export/xlsx/flat  (simple xlsx, sin fotos)
// - Export+: POST /export/xlsx/bitflow_photos (xlsx con fotos, si tu backend lo soporta)
//
// Diseño:
// - Timeout configurable
// - API key opcional en header "X-API-Key"
// - Manejo de errores con mensajes claros
//
// Requiere:
//   http: ^1.x
//
// Uso típico:
//   final engine = EngineService(baseUrl: prefsUrl, apiKey: prefsKey);
//   final result = await engine.compute(payload);

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class EngineService {
  EngineService({
    required this.baseUrl,
    this.apiKey,
    this.timeout = const Duration(seconds: 12),
  });

  /// Ej: http://127.0.0.1:8001  (sin slash final)
  final String baseUrl;

  /// Header opcional. Si tu backend no usa auth, dejalo null/vacío.
  final String? apiKey;

  final Duration timeout;

  Map<String, String> _headersJson() {
    final h = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
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

  /// POST /engine/compute
  /// Payload libre (tu backend define el schema).
  Future<Map<String, dynamic>> compute(Map<String, dynamic> payload) async {
    final uri = _u('/engine/compute');
    final res = await http
        .post(uri, headers: _headersJson(), body: jsonEncode(payload))
        .timeout(timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw EngineHttpException(
        statusCode: res.statusCode,
        message: _bestEffortMessage(res),
        path: uri.toString(),
      );
    }

    final body = res.body.trim();
    if (body.isEmpty) return <String, dynamic>{};

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;

    return <String, dynamic>{'result': decoded};
  }

  /// POST /export/xlsx/flat
  /// Devuelve bytes de un XLSX.
  Future<Uint8List> exportXlsxFlat(Map<String, dynamic> payload) async {
    final uri = _u('/export/xlsx/flat');
    final res = await http
        .post(uri, headers: _headersJson(), body: jsonEncode(payload))
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
    final res = await http
        .post(uri, headers: _headersJson(), body: jsonEncode(payload))
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
    final b = res.body.trim();
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
