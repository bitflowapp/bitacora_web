import 'package:bitacora_web/web/html_compat.dart' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui;

import 'package:flutter/widgets.dart';

class WebBlobImage extends StatefulWidget {
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
  State<WebBlobImage> createState() => _WebBlobImageState();
}

class _WebBlobImageState extends State<WebBlobImage> {
  static int _counter = 0;
  late final String _viewType;
  late final html.ImageElement _img;
  String? _url;

  @override
  void initState() {
    super.initState();
    _viewType = 'blob-img-${_counter++}';
    _img = html.ImageElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = _fitToCss(widget.fit)
      ..setAttribute('draggable', 'false');

    _applyBytes();

    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _img,
    );
  }

  @override
  void didUpdateWidget(WebBlobImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes) ||
        oldWidget.mime != widget.mime ||
        oldWidget.fit != widget.fit) {
      _img.style.objectFit = _fitToCss(widget.fit);
      _applyBytes();
    }
  }

  @override
  void dispose() {
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
    final mime = widget.mime.trim().isEmpty
        ? 'application/octet-stream'
        : widget.mime.trim();
    final blob = html.Blob(<dynamic>[widget.bytes], mime);
    _url = html.Url.createObjectUrlFromBlob(blob);
    _img.src = _url!;
  }

  String _fitToCss(BoxFit fit) {
    switch (fit) {
      case BoxFit.cover:
        return 'cover';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.contain:
        return 'contain';
      case BoxFit.fitHeight:
        return 'contain';
      case BoxFit.fitWidth:
        return 'contain';
      case BoxFit.none:
        return 'none';
      case BoxFit.scaleDown:
        return 'scale-down';
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
