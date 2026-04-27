import 'dart:typed_data';

import 'package:flutter/material.dart';

class WebBlobVideo extends StatelessWidget {
  const WebBlobVideo({
    super.key,
    required this.bytes,
    this.mime = '',
  });

  final Uint8List bytes;
  final String mime;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Video adjunto, pero no se pudo previsualizar en este dispositivo.',
        textAlign: TextAlign.center,
      ),
    );
  }
}
