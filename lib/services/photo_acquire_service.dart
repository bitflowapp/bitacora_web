// lib/services/photo_acquire_service.dart
// Servicio unificado para capturar/seleccionar fotos (mobile + web/desktop).

import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'photo_bytes.dart';
import 'photo_mime_sniffer.dart';
import 'package:image_picker/image_picker.dart';

import 'web_camera_capture.dart';
import 'web_image_capture_stub.dart'
    if (dart.library.html) 'web_image_capture.dart';

enum PhotoAcquireStatus { success, cancelled, blocked, error }

class PhotoAcquireResult {
  const PhotoAcquireResult(
    this.photo, {
    this.size,
    this.reportedMime,
    this.webFile,
  });

  final PhotoBytes photo;
  final int? size;
  final String? reportedMime;
  final Object? webFile; // html.File en web

  Uint8List get bytes => photo.bytes;
  String get name => photo.name;
  String get mime => photo.mime;
  int? get width => photo.width;
  int? get height => photo.height;
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

class PhotoAcquireBatchOutcome {
  const PhotoAcquireBatchOutcome._({
    required this.status,
    this.results = const <PhotoAcquireResult>[],
    this.error,
  });

  final PhotoAcquireStatus status;
  final List<PhotoAcquireResult> results;
  final String? error;

  bool get ok => status == PhotoAcquireStatus.success && results.isNotEmpty;
  bool get cancelled => status == PhotoAcquireStatus.cancelled;
  bool get blocked => status == PhotoAcquireStatus.blocked;
  bool get isError => status == PhotoAcquireStatus.error;

  factory PhotoAcquireBatchOutcome.success(List<PhotoAcquireResult> results) =>
      PhotoAcquireBatchOutcome._(
        status: PhotoAcquireStatus.success,
        results: results,
      );

  factory PhotoAcquireBatchOutcome.cancelled() =>
      const PhotoAcquireBatchOutcome._(status: PhotoAcquireStatus.cancelled);

  factory PhotoAcquireBatchOutcome.blocked(String message) =>
      PhotoAcquireBatchOutcome._(
        status: PhotoAcquireStatus.blocked,
        error: message.trim().isEmpty ? 'Bloqueado' : message.trim(),
      );

  factory PhotoAcquireBatchOutcome.error(String message) =>
      PhotoAcquireBatchOutcome._(
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
    extensions: <String>[
      'jpg',
      'jpeg',
      'png',
      'webp',
      'heic',
      'heif',
      'avif',
      'gif'
    ],
  );

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  Future<PhotoAcquireOutcome> captureFromCamera({BuildContext? context}) async {
    if (kIsWeb) {
      if (context == null) {
        return PhotoAcquireOutcome.blocked(
            'Contexto no disponible para cámara web.');
      }
      final web = await captureFromWebCamera(context: context);
      return _mapWebCameraOutcome(web);
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
        final sniffed = sniffMime(bytes, name: name);
        final mime =
            sniffed.isNotEmpty ? sniffed : (file.mimeType ?? _guessMime(name));

        return PhotoAcquireOutcome.success(
          PhotoAcquireResult(
            PhotoBytes(bytes: bytes, name: name, mime: mime),
            size: bytes.length,
            reportedMime: file.mimeType,
          ),
        );
      } catch (e) {
        return PhotoAcquireOutcome.error('No se pudo abrir la cámara: ');
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
        final sniffed = sniffMime(bytes, name: name);
        final mime =
            sniffed.isNotEmpty ? sniffed : (file.mimeType ?? _guessMime(name));

        return PhotoAcquireOutcome.success(
          PhotoAcquireResult(
            PhotoBytes(bytes: bytes, name: name, mime: mime),
            size: bytes.length,
            reportedMime: file.mimeType,
          ),
        );
      } catch (e) {
        return PhotoAcquireOutcome.error('No se pudo abrir la galeria: ');
      }
    }

    return _pickWithFileSelector();
  }

  Future<PhotoAcquireBatchOutcome> pickMultipleFromGallery() async {
    if (_isMobilePlatform && !kIsWeb) {
      try {
        final files = await _picker.pickMultiImage();
        if (files.isEmpty) return PhotoAcquireBatchOutcome.cancelled();
        final results = await _mapXFiles(files);
        return PhotoAcquireBatchOutcome.success(results);
      } catch (e) {
        return PhotoAcquireBatchOutcome.error(
            'No se pudo abrir la galeria: $e');
      }
    }

    return _pickMultipleWithFileSelector();
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
      final sniffed = sniffMime(bytes, name: xf.name);
      final mime =
          sniffed.isNotEmpty ? sniffed : (xf.mimeType ?? _guessMime(xf.name));
      return PhotoAcquireOutcome.success(
        PhotoAcquireResult(
          PhotoBytes(bytes: bytes, name: xf.name, mime: mime),
          size: bytes.length,
          reportedMime: xf.mimeType,
        ),
      );
    } catch (e) {
      return PhotoAcquireOutcome.error('No se pudo abrir el archivo: ');
    }
  }

  Future<PhotoAcquireBatchOutcome> _pickMultipleWithFileSelector() async {
    try {
      final files =
          await openFiles(acceptedTypeGroups: const [_imageTypeGroup]);
      if (files.isEmpty) return PhotoAcquireBatchOutcome.cancelled();
      final results = await _mapXFiles(files);
      return PhotoAcquireBatchOutcome.success(results);
    } catch (e) {
      return PhotoAcquireBatchOutcome.error('No se pudo abrir archivos: $e');
    }
  }

  Future<List<PhotoAcquireResult>> _mapXFiles(List<XFile> files) async {
    final out = <PhotoAcquireResult>[];
    for (final xf in files) {
      final bytes = await xf.readAsBytes();
      final sniffed = sniffMime(bytes, name: xf.name);
      final mime =
          sniffed.isNotEmpty ? sniffed : (xf.mimeType ?? _guessMime(xf.name));
      out.add(
        PhotoAcquireResult(
          PhotoBytes(bytes: bytes, name: xf.name, mime: mime),
          size: bytes.lengthInBytes,
          reportedMime: xf.mimeType,
        ),
      );
    }
    return out;
  }

  String _cameraNameFallback() {
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    return 'camera_.jpg';
  }

  String _galleryNameFallback() {
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    return 'gallery_.jpg';
  }

  String _guessMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    if (lower.endsWith('.avif')) return 'image/avif';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return '';
  }

  PhotoAcquireOutcome _mapWebOutcome(WebImageCaptureResult web) {
    switch (web.status) {
      case WebImageCaptureStatus.success:
        return PhotoAcquireOutcome.success(
          PhotoAcquireResult(
            PhotoBytes(
                bytes: web.bytes ?? Uint8List(0),
                name: web.name,
                mime: web.mime),
            size: web.size ?? web.bytes?.lengthInBytes,
            reportedMime: web.mime,
            webFile: web.file,
          ),
        );
      case WebImageCaptureStatus.cancelled:
        return PhotoAcquireOutcome.cancelled();
      case WebImageCaptureStatus.blocked:
        return PhotoAcquireOutcome.blocked(
          web.error ?? 'Bloqueado por el navegador.',
        );
      case WebImageCaptureStatus.error:
        return PhotoAcquireOutcome.error(
            web.error ?? 'No se pudo obtener la foto.');
    }
  }

  PhotoAcquireOutcome _mapWebCameraOutcome(WebCameraCaptureResult web) {
    switch (web.status) {
      case WebCameraCaptureStatus.success:
        return PhotoAcquireOutcome.success(
          PhotoAcquireResult(
            PhotoBytes(bytes: web.bytes!, name: web.name, mime: web.mime),
            size: web.bytes?.lengthInBytes,
            reportedMime: web.mime,
          ),
        );
      case WebCameraCaptureStatus.cancelled:
        return PhotoAcquireOutcome.cancelled();
      case WebCameraCaptureStatus.blocked:
        return PhotoAcquireOutcome.blocked(
          web.error ?? 'Bloqueado por el navegador.',
        );
      case WebCameraCaptureStatus.error:
        return PhotoAcquireOutcome.error(
            web.error ?? 'No se pudo abrir la cámara.');
    }
  }
}
