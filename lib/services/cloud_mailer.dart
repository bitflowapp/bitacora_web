// lib/services/cloud_mailer.dart
//
// Cliente HTTP para el microservicio de correo (CloudMailer).
// Usamos UNA sola URL (MAILER_URL), por defecto la Cloud Function.
// Para apuntar a otro backend en debug, podés pasar:
//   --dart-define=MAILER_URL=http://localhost:4000/send-xlsx

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudMailer {
  CloudMailer._(this._client);

  final http.Client _client;

  static final CloudMailer I = CloudMailer._(http.Client());

  // URL única configurable por --dart-define.
  static const String _baseUrl = String.fromEnvironment(
    'MAILER_URL',
    defaultValue:
    'https://southamerica-east1-bitacora-28be4.cloudfunctions.net/sendXlsxMail',
  );

  static Uri get _endpoint => Uri.parse(_baseUrl);

  Future<void> sendXlsx({
    required String to,
    required String fileName,
    required Uint8List bytes,
    String? subject,
    String? text,
    String? html,
  }) async {
    final b64 = base64Encode(bytes);

    final body = <String, dynamic>{
      'to': to,
      'fileName': fileName,
      'xlsxBase64': b64,
      'fileBase64': b64,
    };
    if (subject != null) body['subject'] = subject;
    if (text != null) body['text'] = text;
    if (html != null) body['html'] = html;

    final uri = _endpoint;
    debugPrint('[CloudMailer] POST $uri');

    final res = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint('[CloudMailer] HTTP ${res.statusCode}: ${res.body}');
      throw Exception('CloudMailer HTTP ${res.statusCode}: ${res.body}');
    }

    debugPrint('[CloudMailer] OK ${res.statusCode}');
  }
}
