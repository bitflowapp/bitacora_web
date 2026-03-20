import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

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
  VideoPlayerController? _controller;
  String? _error;
  File? _tempFile;

  @override
  void initState() {
    super.initState();
    _loadController();
  }

  @override
  void didUpdateWidget(covariant AttachmentVideoPreviewImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes) ||
        oldWidget.mime != widget.mime ||
        oldWidget.fileName != widget.fileName) {
      _loadController();
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    final tempFile = _tempFile;
    _controller = null;
    _tempFile = null;
    controller?.dispose();
    if (tempFile != null) {
      Future<void>(() async {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      });
    }
    super.dispose();
  }

  Future<void> _loadController() async {
    final oldController = _controller;
    _controller = null;
    _error = null;
    if (mounted) {
      setState(() {});
    }
    await oldController?.dispose();
    try {
      final dir = await getTemporaryDirectory();
      final ext = _extensionFor(widget.fileName, widget.mime);
      final file = File(
        p.join(
          dir.path,
          'bitflow_preview_${DateTime.now().microsecondsSinceEpoch}$ext',
        ),
      );
      await file.writeAsBytes(widget.bytes, flush: true);
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _tempFile = file;
        _controller = controller;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'No se pudo abrir la vista previa del video en este dispositivo.';
      });
    }
  }

  String _extensionFor(String fileName, String mime) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.webm') || mime.contains('webm')) return '.webm';
    if (lower.endsWith('.mov') || mime.contains('quicktime')) return '.mov';
    if (lower.endsWith('.m4v') || mime.contains('m4v')) return '.m4v';
    if (lower.endsWith('.mpeg') || mime.contains('mpeg')) return '.mpeg';
    return '.mp4';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null) {
      return Container(
        constraints: const BoxConstraints(minHeight: 320),
        alignment: Alignment.center,
        child: Text(
          _error!,
          textAlign: TextAlign.center,
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio <= 0
              ? (16 / 9)
              : controller.value.aspectRatio,
          child: Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: VideoPlayer(controller),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const ValueKey('attachment-video-toggle'),
              onPressed: () async {
                if (controller.value.isPlaying) {
                  await controller.pause();
                } else {
                  await controller.play();
                }
                if (mounted) {
                  setState(() {});
                }
              },
              icon: Icon(
                controller.value.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded,
                size: 36,
              ),
            ),
          ],
        ),
        VideoProgressIndicator(
          controller,
          allowScrubbing: true,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ],
    );
  }
}
