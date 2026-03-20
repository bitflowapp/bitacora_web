import 'dart:typed_data';
import 'dart:ui_web' as ui;

import 'package:bitacora_web/web/html_compat.dart' as html;
import 'package:flutter/material.dart';

class AttachmentVideoPreviewImpl extends StatefulWidget {
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
  State<AttachmentVideoPreviewImpl> createState() =>
      _AttachmentVideoPreviewImplState();
}

class _AttachmentVideoPreviewImplState
    extends State<AttachmentVideoPreviewImpl> {
  static int _counter = 0;

  late final String _viewType;
  late final html.VideoElement _video;
  String? _url;

  @override
  void initState() {
    super.initState();
    _viewType = 'attachment-video-${_counter++}';
    _video = html.VideoElement()
      ..controls = true
      ..autoplay = false
      ..muted = false
      ..preload = 'metadata'
      ..style.width = '100%'
      ..style.maxWidth = '100%'
      ..style.maxHeight = '70vh'
      ..style.backgroundColor = '#111111'
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true');
    _applyBytes();
    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _video,
    );
  }

  @override
  void didUpdateWidget(covariant AttachmentVideoPreviewImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes) ||
        oldWidget.mime != widget.mime) {
      _applyBytes();
    }
  }

  @override
  void dispose() {
    _revokeUrl();
    super.dispose();
  }

  void _revokeUrl() {
    final url = _url;
    if (url == null) return;
    _url = null;
    try {
      html.Url.revokeObjectUrl(url);
    } catch (_) {}
  }

  void _applyBytes() {
    _revokeUrl();
    final mime = widget.mime.trim().isEmpty ? 'video/mp4' : widget.mime.trim();
    final blob = html.Blob(<dynamic>[widget.bytes], mime);
    _url = html.Url.createObjectUrlFromBlob(blob);
    _video.src = _url!;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 320),
      color: Colors.black,
      alignment: Alignment.center,
      child: HtmlElementView(
        key: const ValueKey('attachment-video-preview'),
        viewType: _viewType,
      ),
    );
  }
}
