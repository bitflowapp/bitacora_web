import 'dart:convert';
import 'dart:typed_data';

import 'photo_storage_service.dart';

class PhotoStorageServiceImpl implements PhotoStorageService {
  @override
  Future<StoredPhoto?> savePhoto({
    required String sheetId,
    required Uint8List bytes,
    required String originalName,
    required String mime,
  }) async {
    final b64 = base64Encode(bytes);
    return StoredPhoto(path: '', fileName: originalName, mime: mime, dataB64: b64);
  }

  @override
  Future<Uint8List?> readPhotoBytes(String path) async {
    return null;
  }

  @override
  Future<void> deletePhoto(String path) async {}
}
