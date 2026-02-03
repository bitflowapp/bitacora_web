import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'photo_storage_service.dart';

class PhotoStorageServiceImpl implements PhotoStorageService {
  static const String _rootFolder = 'bitflow_photos';

  @override
  Future<StoredPhoto?> savePhoto({
    required String sheetId,
    required String cellKey,
    required String attachmentId,
    required Uint8List bytes,
    required String originalName,
    required String mime,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeSheet = _sanitize(sheetId);
      final folder = Directory(p.join(dir.path, _rootFolder, safeSheet));
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }

      final ext = _extFor(originalName, mime);
      final safeCell = _sanitize(cellKey);
      final safeId = _sanitize(attachmentId);
      final fileName = 'photo_${safeCell}_$safeId$ext';
      final filePath = p.join(folder.path, fileName);

      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      return StoredPhoto(path: filePath, fileName: fileName, mime: mime);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Uint8List?> readPhotoBytes(String path) async {
    try {
      if (path.trim().isEmpty) return null;
      final file = File(path);
      if (!file.existsSync()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deletePhoto(String path) async {
    try {
      if (path.trim().isEmpty) return;
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }

  String _sanitize(String raw) {
    final t = raw.trim().isEmpty ? 'sheet' : raw.trim();
    return t.replaceAll(RegExp(r'[\\/:*?"<>|\\s]'), '_');
  }

  String _extFor(String name, String mime) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.webp')) return '.webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return '.jpg';
    if (mime.contains('png')) return '.png';
    if (mime.contains('webp')) return '.webp';
    return '.jpg';
  }
}
