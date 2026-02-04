// lib/services/photo_acquire_service.dart
// Servicio unificado para capturar/seleccionar fotos (mobile + web/desktop).

import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'web_image_capture_stub.dart'
    if (dart.library.html) 'web_image_capture.dart';

enum PhotoAcquireStatus { success, cancelled, blocked, error }

class PhotoAcquireResult {
  const PhotoAcquireResult({
    required this.bytes,
    required this.name,
    required this.mime,
  });

  final Uint8List bytes;
  final String name;
  final String mime;
}

class PhotoAcquireOutcome {
  const PhotoAcquireOutcome._({
    required this.status,
    this.result,
    this.error,
  });

  final PhotoAcquireStatus status;
  final PhotoAcquireResult? result;
  final String? error;

  bool get ok => status == PhotoAcquireStatus.success && result != null;
  bool get cancelled => status == PhotoAcquireStatus.cancelled;
  bool get blocked => status == PhotoAcquireStatus.blocked;
  bool get isError => status == PhotoAcquireStatus.error;

  factory PhotoAcquireOutcome.success(PhotoAcquireResult result) =>
      PhotoAcquireOutcome._(status: PhotoAcquireStatus.success, result: result);

  factory PhotoAcquireOutcome.cancelled() =>
      const PhotoAcquireOutcome._(status: PhotoAcquireStatus.cancelled);

  factory PhotoAcquireOutcome.blocked(String message) => PhotoAcquireOutcome._(
        status: PhotoAcquireStatus.blocked,
        error: message.trim().isEmpty ? 'Bloqueado' : message.trim(),
      );

  factory PhotoAcquireOutcome.error(String message) => PhotoAcquireOutcome._(
        status: PhotoAcquireStatus.error,
        error: message.trim().isEmpty ? 'Error desconocido' : message.trim(),
      );
}

class PhotoAcquireService {
  PhotoAcquireService._();

  static final PhotoAcquireService I = PhotoAcquireService._();

  final ImagePicker _picker = ImagePicker();

  static const XTypeGroup _imageTypeGroup = XTypeGroup(
    label: 'Images',
    extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
  );

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  Future<PhotoAcquireOutcome> captureFromCamera() async {
    if (kIsWeb) {
      final web = await captureWebImage(capture: true);
      return _mapWebOutcome(web);
    }

    if (_isMobilePlatform) {
      try {
        final file = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
        );
        if (file == null) return PhotoAcquireOutcome.cancelled();

        final bytes = await file.readAsBytes();
        final name = file.name.isNotEmpty ? file.name : _cameraNameFallback();
        final mime = file.mimeType ?? _guessMime(name);

        return PhotoAcquireOutcome.success(
          PhotoAcquireResult(bytes: bytes, name: name, mime: mime),
        );
      } catch (e) {
        return PhotoAcquireOutcome.error('No se pudo abrir la camara: $e');
      }
    }

    return _pickWithFileSelector();
  }

  Future<PhotoAcquireOutcome> pickFromGallery() async {
    if (kIsWeb) {
      final web = await captureWebImage(capture: false);
      return _mapWebOutcome(web);
    }

    if (_isMobilePlatform) {
      try {
        final file = await _picker.pickImage(source: ImageSource.gallery);
        if (file == null) return PhotoAcquireOutcome.cancelled();

        final bytes = await file.readAsBytes();
        final name = file.name.isNotEmpty ? file.name : _galleryNameFallback();
        final mime = file.mimeType ?? _guessMime(name);

        return PhotoAcquireOutcome.success(
          PhotoAcquireResult(bytes: bytes, name: name, mime: mime),
        );
      } catch (e) {
        return PhotoAcquireOutcome.error('No se pudo abrir la galeria: $e');
      }
    }

    return _pickWithFileSelector();
  }

  Future<PhotoAcquireOutcome> pickFromFilesWeb() async {
    if (kIsWeb) {
      final web = await captureWebImage(capture: false);
      return _mapWebOutcome(web);
    }

    return _pickWithFileSelector();
  }

  Future<PhotoAcquireOutcome> _pickWithFileSelector() async {
    try {
      final xf = await openFile(acceptedTypeGroups: const [_imageTypeGroup]);
      if (xf == null) return PhotoAcquireOutcome.cancelled();

      final bytes = await xf.readAsBytes();
      final mime = xf.mimeType ?? _guessMime(xf.name);
      return PhotoAcquireOutcome.success(
        PhotoAcquireResult(bytes: bytes, name: xf.name, mime: mime),
      );
    } catch (e) {
      return PhotoAcquireOutcome.error('No se pudo abrir el archivo: $e');
    }
  }

  String _cameraNameFallback() {
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    return 'camera_$ts.jpg';
  }

  String _galleryNameFallback() {
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    return 'gallery_$ts.jpg';
  }

  String _guessMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  PhotoAcquireOutcome _mapWebOutcome(WebImageCaptureResult web) {
    switch (web.status) {
      case WebImageCaptureStatus.success:
        return PhotoAcquireOutcome.success(
          PhotoAcquireResult(bytes: web.bytes!, name: web.name, mime: web.mime),
        );
      case WebImageCaptureStatus.cancelled:
        return PhotoAcquireOutcome.cancelled();
      case WebImageCaptureStatus.blocked:
        return PhotoAcquireOutcome.blocked(
          web.error ?? 'Bloqueado por el navegador.',
        );
      case WebImageCaptureStatus.error:
        return PhotoAcquireOutcome.error(web.error ?? 'No se pudo leer la imagen.');
    }
  }
}
