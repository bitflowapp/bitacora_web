import 'dart:typed_data';

class WebPhotoPickResult {
  WebPhotoPickResult({
    required this.bytes,
    required this.name,
    required this.mime,
  });

  final Uint8List bytes;
  final String name;
  final String mime;
}

Future<WebPhotoPickResult?> pickImageFromWeb({required bool capture}) async {
  return null;
}
