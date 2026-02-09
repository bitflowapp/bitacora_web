import 'dart:typed_data';

class PhotoBytes {
  const PhotoBytes({
    required this.bytes,
    required this.mime,
    required this.name,
    this.width,
    this.height,
  });

  final Uint8List bytes;
  final String mime;
  final String name;
  final int? width;
  final int? height;
}
