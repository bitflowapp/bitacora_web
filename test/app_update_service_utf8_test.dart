import 'dart:convert';

import 'package:bitacora_web/services/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('decodes version json using utf8 body bytes', () async {
    final payload = <String, String>{
      'appVersion': '1.3.1',
      'buildId': 'build-versión-ñ',
    };
    final client = _FakeClient(
      handler: (request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode(payload)),
          200,
          headers: const <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      },
    );

    final service = AppUpdateService(client: client);
    final snapshot = await service.checkForUpdates(
      sourceUrl: 'https://example.test/version.json',
    );

    expect(snapshot.requestOk, isTrue);
    expect(snapshot.remoteBuildId, 'build-versión-ñ');
  });
}

class _FakeClient extends http.BaseClient {
  _FakeClient({required this.handler});

  final Future<http.Response> Function(http.Request request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = http.Request(request.method, request.url)
      ..headers.addAll(request.headers);
    final response = await handler(req);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}
