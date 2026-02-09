import 'dart:typed_data';

String sniffMime(Uint8List bytes, {String name = ''}) {
  if (bytes.length >= 12) {
    if (_match(bytes, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return 'image/png';
    }
    if (_match(bytes, [0xFF, 0xD8, 0xFF])) {
      return 'image/jpeg';
    }
    if (_match(bytes, [0x47, 0x49, 0x46, 0x38])) {
      return 'image/gif';
    }
    if (_match(bytes, [0x52, 0x49, 0x46, 0x46]) &&
        _match(bytes, [0x57, 0x45, 0x42, 0x50], offset: 8)) {
      return 'image/webp';
    }
    if (_match(bytes, [0x66, 0x74, 0x79, 0x70], offset: 4)) {
      final brand = _fourcc(bytes, 8);
      if (_heicBrands.contains(brand)) return 'image/heic';
      if (_heifBrands.contains(brand)) return 'image/heif';
      if (_avifBrands.contains(brand)) return 'image/avif';
    }
  }

  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.heif')) return 'image/heif';
  if (lower.endsWith('.avif')) return 'image/avif';

  return '';
}

bool _match(Uint8List bytes, List<int> sig, {int offset = 0}) {
  if (bytes.length < offset + sig.length) return false;
  for (int i = 0; i < sig.length; i++) {
    if (bytes[offset + i] != sig[i]) return false;
  }
  return true;
}

String _fourcc(Uint8List bytes, int offset) {
  if (bytes.length < offset + 4) return '';
  return String.fromCharCodes(bytes.sublist(offset, offset + 4));
}

const Set<String> _heicBrands = {
  'heic',
  'heix',
  'hevc',
  'hevx',
  'mif1',
};

const Set<String> _heifBrands = {
  'heif',
  'heim',
  'msf1',
};

const Set<String> _avifBrands = {
  'avif',
  'avis',
};
