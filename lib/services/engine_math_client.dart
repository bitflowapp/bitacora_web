// lib/services/engine_math_client.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EngineMathClient {
  static const _prefsKey = 'bitflow_engine_base_url';
  static const _defaultBaseUrl = 'http://127.0.0.1:8001';

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_prefsKey);
    return (v == null || v.trim().isEmpty) ? _defaultBaseUrl : v.trim();
  }

  Future<void> setBaseUrl(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'\/+$'), '');
    if (clean.isEmpty) {
      throw ArgumentError('URL inválida.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, clean);
  }

  Future<EngineMathResult> runMath({
    required String expr,
    String task = 'eval',
    Map<String, String>? vars,
    String? variable, // <- NO usar "var" (keyword)
    String? to,
    int precision = 50,
    int order = 6,
    String output = 'both', // string|latex|both
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final baseUrl = await getBaseUrl();
    final uri = Uri.parse('$baseUrl/engine/math');

    final payload = <String, dynamic>{
      'task': task,
      'expr': expr,
      'vars': vars ?? <String, String>{},
      'var': variable,
      'to': to,
      'precision': precision,
      'order': order,
      'output': output,
    }..removeWhere((k, v) => v == null);

    final rid = DateTime.now().millisecondsSinceEpoch.toString();

    http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json; charset=utf-8',
              'x-request-id': rid,
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout);
    } catch (e) {
      throw EngineMathException(
        'No se pudo conectar al engine ($baseUrl). Detalle: $e',
      );
    }

    final bodyText = utf8.decode(res.bodyBytes);
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(bodyText);
      if (decoded is! Map) {
        throw const FormatException('JSON no es objeto');
      }
      data = Map<String, dynamic>.from(decoded as Map);
    } catch (_) {
      throw EngineMathException(
        'Respuesta inválida del engine (HTTP ${res.statusCode}).',
      );
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final detail =
          (data['detail'] ?? data['message'] ?? 'Error desconocido').toString();
      throw EngineMathException(
          'Engine error (HTTP ${res.statusCode}): $detail');
    }

    if (data['ok'] != true) {
      throw EngineMathException('Engine respondió ok=false.');
    }

    final meta = (data['meta'] is Map)
        ? Map<String, dynamic>.from(data['meta'] as Map)
        : <String, dynamic>{};

    return EngineMathResult(
      task: (data['task'] ?? task).toString(),
      inputExpr: (data['input_expr'] ?? expr).toString(),
      result: (data['result'] ?? '').toString(),
      latex: data['latex']?.toString(),
      meta: meta,
      requestId: (data['request_id'] ?? rid).toString(),
    );
  }
}

class EngineMathResult {
  final String task;
  final String inputExpr;
  final String result;
  final String? latex;
  final Map<String, dynamic> meta;
  final String requestId;

  EngineMathResult({
    required this.task,
    required this.inputExpr,
    required this.result,
    required this.latex,
    required this.meta,
    required this.requestId,
  });
}

class EngineMathException implements Exception {
  final String message;
  EngineMathException(this.message);

  @override
  String toString() => message;
}
