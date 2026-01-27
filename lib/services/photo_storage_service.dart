import 'dart:typed_data';

import 'photo_storage_service_stub.dart'
    if (dart.library.io) 'photo_storage_service_io.dart'
    if (dart.library.html) 'photo_storage_service_web.dart';

class StoredPhoto {
  const StoredPhoto({
    required this.path,
    required this.fileName,
    required this.mime,
    this.dataB64 = '',
  });

  final String path;
  final String fileName;
  final String mime;
  final String dataB64;
}

abstract class PhotoStorageService {
  static PhotoStorageService get I => PhotoStorageServiceImpl();

  Future<StoredPhoto?> savePhoto({
    required String sheetId,
    required Uint8List bytes,
    required String originalName,
    required String mime,
  });

  Future<Uint8List?> readPhotoBytes(String path);

  Future<void> deletePhoto(String path);
}
