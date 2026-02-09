// lib/services/attachment_store.dart
// Store unificado de adjuntos (fotos) con referencias estables.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/cell_ref.dart';
import 'photo_storage_service.dart';
import 'web_blob_store.dart';

class AttachmentSaveResult {
  const AttachmentSaveResult({
    required this.storedRef,
    required this.storageLabel,
    this.storageKey,
    this.sessionOnly = false,
  });

  final String storedRef;
  final String storageLabel;
  final String? storageKey;
  final bool sessionOnly;
}

class AttachmentStore {
  AttachmentStore._();

  static final AttachmentStore I = AttachmentStore._();

  final PhotoStorageService _photoStore = PhotoStorageService.I;
  final Map<String, Uint8List> _memStore = <String, Uint8List>{};

  Future<AttachmentSaveResult?> saveImage({
    required CellRef cellRef,
    required String attachmentId,
    required Uint8List bytes,
    required String originalName,
    required String mime,
    Object? webFile,
  }) async {
    String storedRef = '';
    String storageLabel = 'unknown';
    String? storageKey;
    var sessionOnly = false;

    if (kIsWeb && webFile != null) {
      try {
        final key = _blobKey(cellRef, attachmentId);
        final rec = await WebBlobStore.I
            .save(
              key: key,
              source: webFile,
              name: originalName,
              mime: mime,
              size: bytes.lengthInBytes,
            )
            .timeout(const Duration(seconds: 4));
        storedRef = 'blob:${rec.key}';
        storageLabel = rec.storageMode;
        storageKey = rec.key;
        sessionOnly = rec.sessionOnly;
      } catch (_) {
        storedRef = '';
      }
    }

    if (storedRef.isEmpty) {
      try {
        final stored = await _photoStore
            .savePhoto(
              sheetId: cellRef.sheetId,
              cellKey: cellRef.compactKey,
              attachmentId: attachmentId,
              bytes: bytes,
              originalName: originalName,
              mime: mime,
            )
            .timeout(const Duration(seconds: 4));
        if (stored != null) {
          storedRef = _normalizeStoredRef(stored.path);
          storageKey = stored.path;
          storageLabel = _labelForStoredRef(storedRef);
          sessionOnly = stored.path.startsWith('mem:');
        }
      } catch (_) {
        storedRef = '';
      }
    }

    if (storedRef.isEmpty) {
      final key = _blobKey(cellRef, attachmentId);
      _memStore[key] = bytes;
      storedRef = 'mem:$key';
      storageLabel = 'ram';
      storageKey = key;
      sessionOnly = true;
    }

    if (storedRef.isEmpty) return null;
    return AttachmentSaveResult(
      storedRef: storedRef,
      storageLabel: storageLabel,
      storageKey: storageKey,
      sessionOnly: sessionOnly,
    );
  }

  Future<Uint8List?> readBytes(String storedRef) async {
    final ref = storedRef.trim();
    if (ref.isEmpty) return null;
    if (ref.startsWith('blob:')) {
      final key = ref.substring(5);
      return WebBlobStore.I.readBytes(key);
    }
    if (ref.startsWith('mem:')) {
      final key = ref.substring(4);
      return _memStore[key];
    }
    final path = _normalizePath(ref);
    return _photoStore.readPhotoBytes(path);
  }

  Future<void> delete(String storedRef) async {
    final ref = storedRef.trim();
    if (ref.isEmpty) return;
    if (ref.startsWith('blob:')) {
      final key = ref.substring(5);
      await WebBlobStore.I.delete(key);
      return;
    }
    if (ref.startsWith('mem:')) {
      _memStore.remove(ref.substring(4));
      return;
    }
    final path = _normalizePath(ref);
    await _photoStore.deletePhoto(path);
  }

  String _normalizeStoredRef(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (t.startsWith('key:') || t.startsWith('mem:') || t.startsWith('blob:')) {
      return t;
    }
    if (t.startsWith('file:')) return t;
    return kIsWeb ? t : 'file:$t';
  }

  String _normalizePath(String storedRef) {
    if (storedRef.startsWith('file:')) return storedRef.substring(5);
    return storedRef;
  }

  String _labelForStoredRef(String storedRef) {
    if (storedRef.startsWith('file:')) return 'file';
    if (storedRef.startsWith('key:')) return 'indexeddb';
    if (storedRef.startsWith('mem:')) return 'ram';
    if (storedRef.startsWith('blob:')) return 'indexeddb';
    return 'unknown';
  }

  String _blobKey(CellRef cellRef, String attachmentId) {
    String safe(String raw) =>
        raw.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    return 'photo:${safe(cellRef.sheetId)}:${safe(cellRef.rowId)}:${safe(cellRef.colId)}:${safe(attachmentId)}';
  }
}
