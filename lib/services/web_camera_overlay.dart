import 'dart:async';
import 'dart:convert';
import 'dart:html' as html; // ignore: avoid_web_libraries_in_flutter
import 'dart:typed_data';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

import 'diagnostics_log.dart';
import 'web_camera_capture_types.dart';

class WebCameraOverlay extends StatefulWidget {
  const WebCameraOverlay({super.key, this.jpegQuality = 0.9});

  final double jpegQuality;

  @override
  State<WebCameraOverlay> createState() => _WebCameraOverlayState();
}

class _WebCameraOverlayState extends State<WebCameraOverlay> {
  late final html.VideoElement _video;
  late final String _viewType;
  html.MediaStream? _stream;
  Uint8List? _captured;
  bool _starting = true;
  bool _capturing = false;
  String? _error;
  WebCameraCaptureStatus? _errorStatus;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'webcam--';
    _video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';

    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _video,
    );

    unawaited(_startCamera());
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  void _log(String msg, {bool ok = true}) {
    DiagnosticsLog.I.record(
      type: DiagnosticActionType.photo,
      ok: ok,
      message: msg,
    );
  }

  String _describeError(Object e) {
    if (e is html.DomException) {
      return ' '.trim();
    }
    return e.toString();
  }

  WebCameraCaptureStatus _mapErrorStatus(Object e) {
    if (e is html.DomException) {
      final name = e.name.toLowerCase();
      if (name.contains('notallowed') ||
          name.contains('security') ||
          name.contains('notreadable')) {
        return WebCameraCaptureStatus.blocked;
      }
    }
    return WebCameraCaptureStatus.error;
  }

  Future<void> _startCamera() async {
    setState(() {
      _starting = true;
      _error = null;
      _errorStatus = null;
    });
    _log('photo:webcam start');

    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw Exception('NotSupportedError: mediaDevices unavailable');
      }
      final constraints = <String, dynamic>{
        'video': <String, dynamic>{
          'facingMode': <String, dynamic>{'ideal': 'environment'},
        },
        'audio': false,
      };
      final stream = await mediaDevices.getUserMedia(constraints);
      _stream = stream;
      _video.srcObject = stream;
      await _video.play();
      if (!mounted) return;
      setState(() => _starting = false);
      _log('photo:webcam ready');
    } catch (e) {
      final details = _describeError(e);
      final status = _mapErrorStatus(e);
      _log('photo:webcam error ', ok: false);
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = details;
        _errorStatus = status;
      });
    }
  }

  void _stopStream() {
    final stream = _stream;
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      try {
        track.stop();
      } catch (_) {}
    }
    _stream = null;
  }

  Future<Uint8List?> _blobToBytes(html.Blob blob) async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoadEnd.first;
    final result = reader.result;
    if (result is! ByteBuffer) return null;
    return Uint8List.view(result);
  }

  Uint8List? _dataUrlToBytes(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma < 0 || comma >= dataUrl.length - 1) return null;
    final b64 = dataUrl.substring(comma + 1);
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  Future<void> _captureFrame() async {
    if (_capturing) return;
    if (_stream == null) return;

    setState(() => _capturing = true);
    try {
      final width = _video.videoWidth;
      final height = _video.videoHeight;
      if (width == 0 || height == 0) {
        throw Exception('video size invalid');
      }

      final canvas = html.CanvasElement(width: width, height: height);
      final ctx = canvas.context2D;
      ctx.drawImageScaled(_video, 0, 0, width, height);

      Uint8List? bytes;
      final blob = await canvas.toBlob('image/jpeg', widget.jpegQuality);
      if (blob != null) {
        bytes = await _blobToBytes(blob);
      }

      bytes ??= _dataUrlToBytes(canvas.toDataUrl('image/jpeg', widget.jpegQuality));

      if (bytes == null || bytes.isEmpty) {
        throw Exception('empty bytes');
      }

      _video.pause();
      if (!mounted) return;
      setState(() => _captured = bytes);
      _log('photo:webcam captured bytes=');
    } catch (e) {
      final details = _describeError(e);
      _log('photo:webcam capture_error ', ok: false);
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo capturar la foto: ';
        _errorStatus = WebCameraCaptureStatus.error;
      });
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _retake() {
    setState(() => _captured = null);
    try {
      _video.play();
    } catch (_) {}
  }

  void _finish(WebCameraCaptureResult result) {
    if (_finished) return;
    _finished = true;
    _stopStream();
    Navigator.of(context).pop(result);
  }

  void _cancel() {
    _finish(WebCameraCaptureResult.cancelled());
  }

  void _confirm() {
    final bytes = _captured;
    if (bytes == null || bytes.isEmpty) return;
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    _finish(WebCameraCaptureResult.success(
      bytes: bytes,
      name: 'camera_.jpg',
      mime: 'image/jpeg',
    ));
  }

  void _closeWithError() {
    final msg = _error ?? 'Error desconocido';
    final status = _errorStatus ?? WebCameraCaptureStatus.error;
    if (status == WebCameraCaptureStatus.blocked) {
      _finish(WebCameraCaptureResult.blocked(msg));
      return;
    }
    _finish(WebCameraCaptureResult.error(msg));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.black.withOpacity(0.88),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _cancel,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Camara',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  if (_captured != null)
                    TextButton(
                      onPressed: _retake,
                      child: const Text(
                        'Repetir',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_captured == null)
                          HtmlElementView(viewType: _viewType)
                        else
                          Image.memory(
                            _captured!,
                            fit: BoxFit.contain,
                          ),
                        if (_starting)
                          const Center(child: CircularProgressIndicator()),
                        if (_error != null)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              margin: const EdgeInsets.all(12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      color: Colors.orangeAccent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _closeWithError,
                                    child: const Text('Cerrar',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _captured == null ? _captureFrame : _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(_captured == null ? 'Capturar' : 'Usar foto'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_captured == null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    )
                  else
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _retake,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: const Text('Repetir'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
