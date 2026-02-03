import 'dart:typed_data';

import 'photo_storage_service.dart';

class PhotoStorageServiceImpl implements PhotoStorageService {
  @override
  Future<StoredPhoto?> savePhoto({
    required String sheetId,
    required String cellKey,
    required String attachmentId,
    required Uint8List bytes,
    required String originalName,
    required String mime,
  }) async {
    return const StoredPhoto(path: '', fileName: '', mime: '');
  }

  @override
  Future<Uint8List?> readPhotoBytes(String path) async {
    return null;
  }

  @override
  Future<void> deletePhoto(String path) async {}
}
