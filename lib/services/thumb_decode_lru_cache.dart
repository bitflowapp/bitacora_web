import 'dart:convert';
import 'dart:typed_data';

class ThumbDecodeLruCache {
  ThumbDecodeLruCache({
    this.maxEntries = 180,
    this.maxBytes = 16 * 1024 * 1024,
  });

  final int maxEntries;
  final int maxBytes;

  final Map<String, Uint8List?> _decodedByBase64 = <String, Uint8List?>{};
  int _cachedBytes = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _evictions = 0;

  int get entryCount => _decodedByBase64.length;
  int get totalBytes => _cachedBytes;
  int get cacheHits => _cacheHits;
  int get cacheMisses => _cacheMisses;
  int get evictions => _evictions;

  Uint8List? decode(String raw) {
    final key = raw.trim();
    if (key.isEmpty) return null;

    if (_decodedByBase64.containsKey(key)) {
      _cacheHits++;
      final cached = _decodedByBase64.remove(key);
      _decodedByBase64[key] = cached;
      return cached;
    }

    _cacheMisses++;
    final decoded = _tryDecodeB64(key);
    _decodedByBase64[key] = decoded;
    _cachedBytes += decoded?.lengthInBytes ?? 0;
    _evictIfNeeded();
    return decoded;
  }

  void _evictIfNeeded() {
    while (_decodedByBase64.isNotEmpty &&
        (_decodedByBase64.length > maxEntries || _cachedBytes > maxBytes)) {
      final oldestKey = _decodedByBase64.keys.first;
      final removed = _decodedByBase64.remove(oldestKey);
      _cachedBytes -= removed?.lengthInBytes ?? 0;
      if (_cachedBytes < 0) _cachedBytes = 0;
      _evictions++;
    }
  }

  void clear() {
    _decodedByBase64.clear();
    _cachedBytes = 0;
    _cacheHits = 0;
    _cacheMisses = 0;
    _evictions = 0;
  }

  Uint8List? _tryDecodeB64(String raw) {
    try {
      if (raw.trim().isEmpty) return null;
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }
}
