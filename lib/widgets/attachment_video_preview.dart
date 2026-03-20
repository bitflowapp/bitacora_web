import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'attachment_video_preview_stub.dart'
    if (dart.library.io) 'attachment_video_preview_io.dart'
    if (dart.library.html) 'attachment_video_preview_web.dart';

class AttachmentVideoPreview extends StatelessWidget {
  const AttachmentVideoPreview({
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
    return AttachmentVideoPreviewImpl(
      bytes: bytes,
      mime: mime,
      fileName: fileName,
    );
  }
}
