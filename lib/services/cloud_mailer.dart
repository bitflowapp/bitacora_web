// lib/services/cloud_mailer.dart
//
// Cliente HTTP para CloudMailer (Node + Resend).
// Endpoint esperado: POST {BASE_URL}/send-xlsx
// Envío: multipart/form-data con fields (to, subject, text, html) + file (xlsx)
//
// Funciona en Android/iOS/Desktop/Web.
// Importante en Web: tu server debe habilitar CORS.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class CloudMailerException implements Exception {
  final String message;
  final Uri? uri;
  final int? statusCode;
  final String? bodySnippet;
  final Object? cause;

  const CloudMailerException(
    this.message, {
    this.uri,
    this.statusCode,
    this.bodySnippet,
    this.cause,
  });

  @override
  String toString() {
    final parts = <String>['CloudMailerException: $message'];
    if (statusCode != null) parts.add('status=$statusCode');
    if (uri != null) parts.add('uri=$uri');
    if (bodySnippet != null && bodySnippet!.isNotEmpty) {
      parts.add('body=${bodySnippet!.replaceAll("\n", " ")}');
    }
    if (cause != null) parts.add('cause=$cause');
    return parts.join(' | ');
  }
}

@immutable
class CloudMailerConfig {
  final String baseUrl;
  final String? apiKey;

  const CloudMailerConfig({
    required this.baseUrl,
    this.apiKey,
  });
}

class CloudMailer {
  CloudMailer._();

  static final CloudMailer I = CloudMailer._();

  static const String _kBaseUrlKey = 'cloud_mailer_base_url';
  static const String _kApiKeyKey = 'cloud_mailer_api_key';

  // Timeouts razonables para mobile/web.
  static const Duration _connectTimeout = Duration(seconds: 12);
  static const Duration _sendTimeout = Duration(seconds: 35);

  CloudMailerConfig? _cached;

  Future<void> setConfig({
    required String baseUrl,
    String? apiKey,
  }) async {
    final normalized = _normalizeBaseUrl(baseUrl);

    if (kIsWeb && !normalized.startsWith('https://')) {
      throw const CloudMailerException(
        'En Web (iPhone/Safari incluido) el baseUrl debe ser HTTPS.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrlKey, normalized);
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      await prefs.setString(_kApiKeyKey, apiKey.trim());
    } else {
      await prefs.remove(_kApiKeyKey);
    }
    _cached = CloudMailerConfig(baseUrl: normalized, apiKey: apiKey?.trim());
  }

  Future<CloudMailerConfig> getConfig() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(_kBaseUrlKey)?.trim() ?? '';
    final apiKey = prefs.getString(_kApiKeyKey)?.trim();

    if (baseUrl.isEmpty) {
      throw const CloudMailerException(
        'CloudMailer no está configurado: falta baseUrl.',
      );
    }

    final normalized = _normalizeBaseUrl(baseUrl);
    final cfg = CloudMailerConfig(baseUrl: normalized, apiKey: apiKey);
    _cached = cfg;
    return cfg;
  }

  /// Envía un XLSX por mail a través del microservicio CloudMailer.
  Future<void> sendXlsx({
    required String to,
    required String fileName,
    required Uint8List bytes,
    String? subject,
    String? text,
    String? html,
  }) async {
    final trimmedTo = to.trim();
    if (trimmedTo.isEmpty || !trimmedTo.contains('@')) {
      throw const CloudMailerException('Parámetro "to" inválido.');
    }
    if (bytes.isEmpty) {
      throw const CloudMailerException('El XLSX está vacío (bytes == 0).');
    }

    final cfg = await getConfig();
    final uri = Uri.parse('${cfg.baseUrl}/send-xlsx');

    final req = http.MultipartRequest('POST', uri);

    // Campos simples.
    req.fields['to'] = trimmedTo;
    if (subject != null && subject.trim().isNotEmpty) {
      req.fields['subject'] = subject.trim();
    }
    if (text != null && text.trim().isNotEmpty) {
      req.fields['text'] = text;
    }
    if (html != null && html.trim().isNotEmpty) {
      req.fields['html'] = html;
    }

    // Archivo XLSX.
    final safeFileName =
        fileName.trim().isEmpty ? 'Gridnote.xlsx' : fileName.trim();
    req.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: safeFileName,
    ));

    // Headers (compatibles).
    req.headers['Accept'] = 'application/json';

    final apiKey = cfg.apiKey;
    if (apiKey != null && apiKey.isNotEmpty) {
      final bearer = apiKey.toLowerCase().startsWith('bearer ')
          ? apiKey
          : 'Bearer $apiKey';
      req.headers['Authorization'] = bearer;
      // Muchos servicios usan X-API-Key; si no lo usan, lo ignoran.
      req.headers['X-API-Key'] = apiKey;
    }

    final client = http.Client();
    try {
      http.StreamedResponse streamed;
      try {
        streamed = await client.send(req).timeout(_connectTimeout);
      } on TimeoutException catch (e) {
        throw CloudMailerException(
          'Timeout conectando a CloudMailer.',
          uri: uri,
          cause: e,
        );
      }

      final resp =
          await http.Response.fromStream(streamed).timeout(_sendTimeout);
      final status = resp.statusCode;
      final body = _decodeUtf8Body(resp);

      if (status < 200 || status >= 300) {
        throw CloudMailerException(
          'CloudMailer respondió error HTTP.',
          uri: uri,
          statusCode: status,
          bodySnippet: _snip(body),
        );
      }

      // Si devuelve JSON con ok=false o error, lo respetamos.
      if (body.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            final ok = decoded['ok'];
            if (ok is bool && !ok) {
              throw CloudMailerException(
                'CloudMailer respondió ok=false.',
                uri: uri,
                statusCode: status,
                bodySnippet: _snip(body),
              );
            }
          }
        } catch (_) {
          // Si no es JSON, no pasa nada.
        }
      }
    } on CloudMailerException {
      rethrow;
    } catch (e) {
      throw CloudMailerException(
        'Fallo enviando XLSX por CloudMailer.',
        uri: uri,
        cause: e,
      );
    } finally {
      client.close();
    }
  }

  static String _decodeUtf8Body(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      return response.body;
    }
  }

  static String _normalizeBaseUrl(String input) {
    var u = input.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  static String _snip(String s) {
    final t = s.trim();
    if (t.length <= 500) return t;
    return '${t.substring(0, 500)}…';
  }
}
