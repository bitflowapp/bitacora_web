import 'dart:typed_data';

import 'package:flutter/widgets.dart';

class WebBlobImage extends StatelessWidget {
  const WebBlobImage({
    super.key,
    required this.bytes,
    this.mime = '',
    this.fit = BoxFit.contain,
  });

  final Uint8List bytes;
  final String mime;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      bytes,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
