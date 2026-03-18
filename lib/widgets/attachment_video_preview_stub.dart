import 'dart:typed_data';

import 'package:flutter/material.dart';

class AttachmentVideoPreviewImpl extends StatelessWidget {
  const AttachmentVideoPreviewImpl({
    super.key,
    required this.bytes,
    required this.mime,
    required this.fileName,
  });

  final Uint8List bytes;
  final String mime;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 320),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off_rounded, size: 40),
          SizedBox(height: 10),
          Text(
            'La vista previa de video no esta disponible en este dispositivo.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
