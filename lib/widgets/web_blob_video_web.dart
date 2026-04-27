// ignore_for_file: deprecated_member_use

import 'dart:html' as html; // ignore: avoid_web_libraries_in_flutter
import 'dart:typed_data';
import 'dart:ui_web' as ui;

import 'package:flutter/widgets.dart';

class WebBlobVideo extends StatefulWidget {
  const WebBlobVideo({
    super.key,
    required this.bytes,
    this.mime = '',
  });

  final Uint8List bytes;
  final String mime;

  @override
  State<WebBlobVideo> createState() => _WebBlobVideoState();
}

class _WebBlobVideoState extends State<WebBlobVideo> {
  static int _counter = 0;
  late final String _viewType;
  late final html.VideoElement _video;
  String? _url;

  @override
  void initState() {
    super.initState();
    _viewType = 'blob-video-${_counter++}';
    _video = html.VideoElement()
      ..controls = true
      ..autoplay = false
      ..muted = false
      ..preload = 'metadata'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..style.backgroundColor = '#000'
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true');

    _applyBytes();

    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _video,
    );
  }

  @override
  void didUpdateWidget(WebBlobVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes) ||
        oldWidget.mime != widget.mime) {
      _applyBytes();
    }
  }

  @override
  void dispose() {
    try {
      _video.pause();
      _video.removeAttribute('src');
      _video.load();
    } catch (_) {}
    _revoke();
    super.dispose();
  }

  void _revoke() {
    final url = _url;
    if (url == null) return;
    _url = null;
    try {
      html.Url.revokeObjectUrl(url);
    } catch (_) {}
  }

  void _applyBytes() {
    _revoke();
    final mime = widget.mime.trim().isEmpty ? 'video/mp4' : widget.mime.trim();
    final blob = html.Blob(<dynamic>[widget.bytes], mime);
    _url = html.Url.createObjectUrlFromBlob(blob);
    _video.src = _url!;
    try {
      _video.load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
