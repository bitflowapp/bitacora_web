import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('boot shell and runtime keep BitFlow branding', () {
    final webIndex = File('web/index.html').readAsStringSync();
    final mainDart = File('lib/main.dart').readAsStringSync();

    expect(webIndex, contains('BitFlow'));
    expect(webIndex, isNot(contains('Gridnote')));
    expect(mainDart, contains("_kPublicBrandName = 'BitFlow'"));
    expect(mainDart, isNot(contains('Gridnote - Error')));
    expect(mainDart, isNot(contains("'Gridnote'")));
    expect(mainDart, isNot(contains("'Bitacora Web'")));
  });

  test('public config and manifest stay on BitFlow', () {
    for (final path in <String>[
      'assets/config.json',
      'docs/config.json',
      'web/config.json',
    ]) {
      final decoded =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      expect(decoded['brandName'], 'BitFlow');
    }

    final manifest = jsonDecode(
      File('web/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(manifest['name'], 'BitFlow');
    expect(manifest['short_name'], 'BitFlow');
    expect(manifest['background_color'], '#F5F5F7');
    expect(manifest['theme_color'], '#F5F5F7');
  });
}
