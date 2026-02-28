import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'package:bitacora_web/web/html_compat.dart' as html;import 'dart:math' as math;
import 'dart:typed_data';

import 'web_image_normalizer.dart';

class WebImageNormalizerImpl implements WebImageNormalizer {
  @override
  Future<WebImageNormalizationResult?> normalize(
    WebImageNormalizationRequest request,
  ) async {
    final blob = _toBlob(request.source, request.bytes, request.mimeType);
    if (blob == null) return null;

    final decoded = await _decodeBlob(blob);
    if (decoded == null) {
      throw const WebImageNormalizationException(
        code: 'decode_unsupported',
        message: 'Browser decoder failed.',
      );
    }

    try {
      final normalizedBlob = await _drawJpeg(
        decoded,
        maxSide: request.maxSide,
        quality: request.jpegQuality,
      );
      if (normalizedBlob == null) {
        throw const WebImageNormalizationException(
          code: 'decode_unsupported',
          message: 'Canvas toBlob failed for normalized image.',
        );
      }
      final normalizedBytes = await _blobToBytes(normalizedBlob);
      if (normalizedBytes == null || normalizedBytes.isEmpty) {
        throw const WebImageNormalizationException(
          code: 'decode_unsupported',
          message: 'Normalized image bytes are empty.',
        );
      }

      Uint8List? thumbBytes;
      try {
        final thumbBlob = await _drawJpeg(
          decoded,
          maxSide: request.thumbMaxSide,
          quality: request.thumbJpegQuality,
        );
        if (thumbBlob != null) {
          thumbBytes = await _blobToBytes(thumbBlob);
        }
      } catch (_) {}

      return WebImageNormalizationResult(
        bytes: normalizedBytes,
        mimeType: 'image/jpeg',
        fileName: _jpgFileName(request.fileName),
        thumbBytes: thumbBytes,
      );
    } finally {
      decoded.dispose?.call();
    }
  }

  html.Blob? _toBlob(Object? source, Uint8List bytes, String mimeType) {
    if (source is html.Blob) {
      return source;
    }
    if (bytes.isEmpty && source == null) {
      return null;
    }
    final mime =
        mimeType.trim().isEmpty ? 'application/octet-stream' : mimeType;
    return html.Blob([bytes], mime);
  }

  Future<_DecodedImage?> _decodeBlob(html.Blob blob) async {
    final bitmapDecoded = await _decodeBlobViaImageBitmap(blob);
    if (bitmapDecoded != null) return bitmapDecoded;
    return _decodeBlobViaImageElement(blob);
  }

  Future<_DecodedImage?> _decodeBlobViaImageBitmap(html.Blob blob) async {
    try {
      final dynamic win = html.window;
      final dynamic createImageBitmap = win.createImageBitmap;
      if (createImageBitmap == null) return null;

      final dynamic imageBitmap = await createImageBitmap(blob);
      final width = (imageBitmap.width as num?)?.toInt() ?? 0;
      final height = (imageBitmap.height as num?)?.toInt() ?? 0;
      if (width <= 0 || height <= 0) return null;

      return _DecodedImage(
        image: imageBitmap,
        width: width,
        height: height,
        dispose: () {
          try {
            imageBitmap.close();
          } catch (_) {}
        },
      );
    } catch (_) {
      return null;
    }
  }

  Future<_DecodedImage?> _decodeBlobViaImageElement(html.Blob blob) async {
    final url = html.Url.createObjectUrlFromBlob(blob);
    final image = html.ImageElement();
    final completer = Completer<_DecodedImage?>();
    late final StreamSubscription<html.Event> loadSub;
    late final StreamSubscription<html.Event> errorSub;

    void complete(_DecodedImage? value) {
      if (!completer.isCompleted) completer.complete(value);
    }

    loadSub = image.onLoad.listen((_) {
      final width =
          image.naturalWidth > 0 ? image.naturalWidth : (image.width ?? 0);
      final height =
          image.naturalHeight > 0 ? image.naturalHeight : (image.height ?? 0);
      if (width <= 0 || height <= 0) {
        complete(null);
        return;
      }
      complete(_DecodedImage(image: image, width: width, height: height));
    });
    errorSub = image.onError.listen((_) => complete(null));

    image.src = url;
    try {
      return await completer.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => null,
      );
    } finally {
      await loadSub.cancel();
      await errorSub.cancel();
      html.Url.revokeObjectUrl(url);
    }
  }

  Future<html.Blob?> _drawJpeg(
    _DecodedImage decoded, {
    required int maxSide,
    required double quality,
  }) async {
    final srcW = decoded.width.toDouble();
    final srcH = decoded.height.toDouble();
    if (srcW <= 0 || srcH <= 0) return null;
    final maxSrc = math.max(srcW, srcH);
    final scale = maxSrc > maxSide ? (maxSide / maxSrc) : 1.0;
    final outW = math.max(1, (srcW * scale).round());
    final outH = math.max(1, (srcH * scale).round());

    final canvas = html.CanvasElement(width: outW, height: outH);
    final ctx = canvas.context2D;
    ctx
      ..imageSmoothingEnabled = true
      ..imageSmoothingQuality = 'high'
      ..drawImageScaled(
        decoded.image as dynamic,
        0,
        0,
        outW.toDouble(),
        outH.toDouble(),
      );

    return _canvasToBlob(canvas, quality: quality);
  }

  Future<html.Blob?> _canvasToBlob(
    html.CanvasElement canvas, {
    required double quality,
  }) async {
    try {
      return await canvas
          .toBlob('image/jpeg', quality.clamp(0.0, 1.0))
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _blobToBytes(html.Blob blob) async {
    final reader = html.FileReader();
    final completer = Completer<Uint8List?>();
    reader.onError.first.then((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
    reader.onLoadEnd.first.then((_) {
      if (completer.isCompleted) return;
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(Uint8List.view(result));
      } else {
        completer.complete(null);
      }
    });
    reader.readAsArrayBuffer(blob);
    return completer.future;
  }

  String _jpgFileName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'foto.jpg';
    final dot = trimmed.lastIndexOf('.');
    final base = dot > 0 ? trimmed.substring(0, dot) : trimmed;
    return '$base.jpg';
  }
}

class _DecodedImage {
  const _DecodedImage({
    required this.image,
    required this.width,
    required this.height,
    this.dispose,
  });

  final Object image;
  final int width;
  final int height;
  final void Function()? dispose;
}
