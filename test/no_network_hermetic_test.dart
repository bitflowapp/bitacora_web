import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('outbound HTTP is blocked in tests by default', () async {
    final client = HttpClient();
    expect(
      () => client.getUrl(Uri.parse('https://example.com')),
      throwsA(
        isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          contains('Outbound HTTP is blocked in widget/unit tests.'),
        ),
      ),
    );
  });
}
