import 'dart:convert';
import 'dart:typed_data';

import 'package:bitacora_web/services/thumb_decode_lru_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps cache bounded by max entries', () {
    final cache = ThumbDecodeLruCache(maxEntries: 2, maxBytes: 1024 * 1024);

    final a = base64Encode(Uint8List.fromList(List<int>.filled(10, 1)));
    final b = base64Encode(Uint8List.fromList(List<int>.filled(10, 2)));
    final c = base64Encode(Uint8List.fromList(List<int>.filled(10, 3)));

    expect(cache.decode(a), isNotNull);
    expect(cache.decode(b), isNotNull);
    expect(cache.entryCount, 2);

    expect(cache.decode(c), isNotNull);
    expect(cache.entryCount, 2);
    expect(cache.decode(a), isNotNull); // "a" was evicted and decodes again.
  });

  test('evicts when max bytes is exceeded', () {
    final cache = ThumbDecodeLruCache(maxEntries: 10, maxBytes: 30);

    final a = base64Encode(Uint8List.fromList(List<int>.filled(20, 1)));
    final b = base64Encode(Uint8List.fromList(List<int>.filled(20, 2)));

    cache.decode(a);
    expect(cache.totalBytes, lessThanOrEqualTo(30));

    cache.decode(b);
    expect(cache.totalBytes, lessThanOrEqualTo(30));
    expect(cache.entryCount, lessThanOrEqualTo(2));
  });
}
