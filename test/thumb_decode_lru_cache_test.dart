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

  test('tracks cache hits, misses and evictions deterministically', () {
    final cache = ThumbDecodeLruCache(maxEntries: 1, maxBytes: 1024 * 1024);
    final a = base64Encode(Uint8List.fromList(List<int>.filled(8, 1)));
    final b = base64Encode(Uint8List.fromList(List<int>.filled(8, 2)));

    cache.decode(a);
    cache.decode(a); // hit
    cache.decode(b); // miss + eviction

    expect(cache.cacheMisses, 2);
    expect(cache.cacheHits, 1);
    expect(cache.evictions, greaterThanOrEqualTo(1));

    cache.clear();
    expect(cache.cacheMisses, 0);
    expect(cache.cacheHits, 0);
    expect(cache.evictions, 0);
  });
}
