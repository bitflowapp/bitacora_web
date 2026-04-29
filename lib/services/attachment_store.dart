// lib/services/attachment_store.dart
// Store unificado de adjuntos (fotos) con referencias estables.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

class AttachmentUploadInfo {
  const AttachmentUploadInfo({
    required this.attachmentId,
    required this.sheetId,
    required this.cellKey,
    required this.storedRef,
    required this.uploadStatus,
    required this.updatedAt,
    this.remotePath,
    this.remoteUrl,
    this.lastError,
  });

  final String attachmentId;
  final String sheetId;
  final String cellKey;
  final String storedRef;
  final String uploadStatus;
  final String? remotePath;
  final String? remoteUrl;
  final String? lastError;
  final DateTime updatedAt;

  bool get isUploaded {
    return uploadStatus == AttachmentStore.uploadStatusUploaded ||
        (remotePath?.trim().isNotEmpty ?? false) ||
        (remoteUrl?.trim().isNotEmpty ?? false);
  }

  AttachmentUploadInfo copyWith({
    String? attachmentId,
    String? sheetId,
    String? cellKey,
    String? storedRef,
    String? uploadStatus,
    String? remotePath,
    String? remoteUrl,
    String? lastError,
    DateTime? updatedAt,
    bool clearRemotePath = false,
    bool clearRemoteUrl = false,
    bool clearLastError = false,
  }) {
    return AttachmentUploadInfo(
      attachmentId: attachmentId ?? this.attachmentId,
      sheetId: sheetId ?? this.sheetId,
      cellKey: cellKey ?? this.cellKey,
      storedRef: storedRef ?? this.storedRef,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      remotePath: clearRemotePath ? null : (remotePath ?? this.remotePath),
      remoteUrl: clearRemoteUrl ? null : (remoteUrl ?? this.remoteUrl),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      updatedAt: (updatedAt ?? this.updatedAt).toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'attachmentId': attachmentId,
      'sheetId': sheetId,
      'cellKey': cellKey,
      'storedRef': storedRef,
      'uploadStatus': uploadStatus,
      'remotePath': remotePath,
      'remoteUrl': remoteUrl,
      'lastError': lastError,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  static AttachmentUploadInfo fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['uploadStatus'] ?? '').toString().trim();
    final status = AttachmentStore.normalizeUploadStatus(rawStatus);
    return AttachmentUploadInfo(
      attachmentId: (json['attachmentId'] ?? '').toString().trim(),
      sheetId: (json['sheetId'] ?? '').toString().trim(),
      cellKey: (json['cellKey'] ?? '').toString().trim(),
      storedRef: (json['storedRef'] ?? '').toString().trim(),
      uploadStatus: status,
      remotePath: (json['remotePath'] ?? '').toString().trim().isEmpty
          ? null
          : (json['remotePath'] ?? '').toString().trim(),
      remoteUrl: (json['remoteUrl'] ?? '').toString().trim().isEmpty
          ? null
          : (json['remoteUrl'] ?? '').toString().trim(),
      lastError: (json['lastError'] ?? '').toString().trim().isEmpty
          ? null
          : (json['lastError'] ?? '').toString().trim(),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString())?.toUtc() ??
              DateTime.now().toUtc(),
    );
  }
}

class AttachmentStore {
  AttachmentStore._();

  static final AttachmentStore I = AttachmentStore._();

  static const String uploadStatusLocal = 'local';
  static const String uploadStatusQueued = 'queued';
  static const String uploadStatusUploading = 'uploading';
  static const String uploadStatusUploaded = 'uploaded';
  static const String uploadStatusError = 'error';

  static const String _uploadMetaBoxName = 'attachment_upload_meta_v1';

  final PhotoStorageService _photoStore = PhotoStorageService.I;
  final Map<String, Uint8List> _memStore = <String, Uint8List>{};

  Box<String>? _uploadMetaBox;

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

  Future<void> registerLocalAttachment({
    required String attachmentId,
    required String sheetId,
    required String cellKey,
    required String storedRef,
  }) async {
    final id = attachmentId.trim();
    if (id.isEmpty) return;

    final existing = await getUploadInfo(id);
    final next = AttachmentUploadInfo(
      attachmentId: id,
      sheetId: sheetId.trim(),
      cellKey: cellKey.trim(),
      storedRef: storedRef.trim(),
      uploadStatus: existing?.isUploaded == true
          ? uploadStatusUploaded
          : uploadStatusLocal,
      remotePath: existing?.remotePath,
      remoteUrl: existing?.remoteUrl,
      lastError: null,
      updatedAt: DateTime.now().toUtc(),
    );
    await _saveUploadInfo(next);
  }

  Future<AttachmentUploadInfo?> getUploadInfo(String attachmentId) async {
    final id = attachmentId.trim();
    if (id.isEmpty) return null;

    final box = await _ensureUploadMetaBox();
    final raw = box.get(id);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = decoded.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
      final info = AttachmentUploadInfo.fromJson(map);
      if (info.attachmentId.trim().isEmpty) {
        return info.copyWith(attachmentId: id);
      }
      return info;
    } catch (_) {
      return null;
    }
  }

  Future<void> markUploadQueued(
    String attachmentId, {
    String? sheetId,
    String? cellKey,
    String? storedRef,
  }) async {
    await _upsertUploadInfo(
      attachmentId,
      (current) => current.copyWith(
        sheetId: (sheetId ?? current.sheetId).trim(),
        cellKey: (cellKey ?? current.cellKey).trim(),
        storedRef: (storedRef ?? current.storedRef).trim(),
        uploadStatus: uploadStatusQueued,
        clearLastError: true,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> markUploadUploading(String attachmentId) async {
    await _upsertUploadInfo(
      attachmentId,
      (current) => current.copyWith(
        uploadStatus: uploadStatusUploading,
        clearLastError: true,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> markUploadUploaded(
    String attachmentId, {
    String? remotePath,
    String? remoteUrl,
  }) async {
    await _upsertUploadInfo(
      attachmentId,
      (current) => current.copyWith(
        uploadStatus: uploadStatusUploaded,
        remotePath: (remotePath ?? current.remotePath)?.trim(),
        remoteUrl: (remoteUrl ?? current.remoteUrl)?.trim(),
        clearLastError: true,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> markUploadError(String attachmentId, String error) async {
    final message = error.trim().isEmpty ? 'error' : error.trim();
    await _upsertUploadInfo(
      attachmentId,
      (current) => current.copyWith(
        uploadStatus: uploadStatusError,
        lastError: message,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  static String normalizeUploadStatus(String raw) {
    switch (raw) {
      case uploadStatusLocal:
      case uploadStatusQueued:
      case uploadStatusUploading:
      case uploadStatusUploaded:
      case uploadStatusError:
        return raw;
      default:
        return uploadStatusLocal;
    }
  }

  Future<void> _upsertUploadInfo(
    String attachmentId,
    AttachmentUploadInfo Function(AttachmentUploadInfo current) update,
  ) async {
    final id = attachmentId.trim();
    if (id.isEmpty) return;

    final current = await getUploadInfo(id) ??
        AttachmentUploadInfo(
          attachmentId: id,
          sheetId: '',
          cellKey: '',
          storedRef: '',
          uploadStatus: uploadStatusLocal,
          updatedAt: DateTime.now().toUtc(),
        );

    final candidate = update(current);
    final next = candidate.copyWith(
      attachmentId: id,
      uploadStatus: normalizeUploadStatus(candidate.uploadStatus),
      updatedAt: DateTime.now().toUtc(),
    );
    await _saveUploadInfo(next);
  }

  Future<void> _saveUploadInfo(AttachmentUploadInfo info) async {
    final id = info.attachmentId.trim();
    if (id.isEmpty) return;
    final box = await _ensureUploadMetaBox();
    await box.put(id, jsonEncode(info.toJson()));
  }

  Future<Box<String>> _ensureUploadMetaBox() async {
    if (_uploadMetaBox != null && _uploadMetaBox!.isOpen) {
      return _uploadMetaBox!;
    }

    try {
      await Hive.initFlutter();
    } catch (_) {}

    if (Hive.isBoxOpen(_uploadMetaBoxName)) {
      _uploadMetaBox = Hive.box<String>(_uploadMetaBoxName);
      return _uploadMetaBox!;
    }

    _uploadMetaBox = await Hive.openBox<String>(_uploadMetaBoxName);
    return _uploadMetaBox!;
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
