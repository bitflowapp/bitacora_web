// lib/services/photo_acquire_service.dart
// Servicio unificado para capturar/seleccionar fotos (mobile + web/desktop).

import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

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

  Future<PhotoAcquireResult?> captureFromCamera() async {
    if (kIsWeb) return _pickWithFileSelector();

    if (_isMobilePlatform) {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null) return null;

      final bytes = await file.readAsBytes();
      final name = file.name.isNotEmpty ? file.name : _cameraNameFallback();
      final mime = file.mimeType ?? _guessMime(name);

      return PhotoAcquireResult(bytes: bytes, name: name, mime: mime);
    }

    return _pickWithFileSelector();
  }

  Future<PhotoAcquireResult?> pickFromGallery() async {
    if (kIsWeb) return _pickWithFileSelector();

    if (_isMobilePlatform) {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return null;

      final bytes = await file.readAsBytes();
      final name = file.name.isNotEmpty ? file.name : _galleryNameFallback();
      final mime = file.mimeType ?? _guessMime(name);

      return PhotoAcquireResult(bytes: bytes, name: name, mime: mime);
    }

    return _pickWithFileSelector();
  }

  Future<PhotoAcquireResult?> pickFromFilesWeb() async {
    return _pickWithFileSelector();
  }

  Future<PhotoAcquireResult?> _pickWithFileSelector() async {
    final xf = await openFile(acceptedTypeGroups: const [_imageTypeGroup]);
    if (xf == null) return null;

    final bytes = await xf.readAsBytes();
    final mime = xf.mimeType ?? _guessMime(xf.name);
    return PhotoAcquireResult(bytes: bytes, name: xf.name, mime: mime);
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
}