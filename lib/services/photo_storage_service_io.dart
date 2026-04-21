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
      if (!await folder.exists()) {
        await folder.create(recursive: true);
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
      if (!await file.exists()) return null;
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
      if (await file.exists()) {
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
    if (lower.endsWith('.mp4')) return '.mp4';
    if (lower.endsWith('.mov')) return '.mov';
    if (lower.endsWith('.webm')) return '.webm';
    if (lower.endsWith('.m4v')) return '.m4v';
    if (lower.endsWith('.mpeg') || lower.endsWith('.mpg')) return '.mpeg';
    if (lower.endsWith('.pdf')) return '.pdf';
    if (lower.endsWith('.txt')) return '.txt';
    if (lower.endsWith('.csv')) return '.csv';
    if (lower.endsWith('.zip')) return '.zip';
    if (mime.contains('png')) return '.png';
    if (mime.contains('webp')) return '.webp';
    if (mime.contains('mp4')) return '.mp4';
    if (mime.contains('quicktime')) return '.mov';
    if (mime.contains('webm')) return '.webm';
    if (mime.contains('mpeg')) return '.mpeg';
    if (mime.contains('pdf')) return '.pdf';
    if (mime.contains('text/plain')) return '.txt';
    if (mime.contains('csv')) return '.csv';
    if (mime.contains('zip')) return '.zip';
    return '.jpg';
  }
}
