part of 'editor_screen.dart';

enum EditorSaveState { idle, saving, dirty, saved }

@immutable
class EditorSaveSnapshot {
  const EditorSaveSnapshot({required this.state, this.savedAt});

  final EditorSaveState state;
  final DateTime? savedAt;
}

enum OfflineSyncState {
  offline,
  pending,
  syncing,
  synced,
  failed,
}

@immutable
class OfflineSyncSnapshot {
  const OfflineSyncSnapshot({
    required this.state,
    required this.pendingCount,
    this.updatedAt,
    this.message,
  });

  final OfflineSyncState state;
  final int pendingCount;
  final DateTime? updatedAt;
  final String? message;
}

class _MobileAction {
  const _MobileAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _EngineConfig {
  const _EngineConfig({required this.baseUrl, required this.apiKey});
  final String? baseUrl;
  final String? apiKey;
}

class _EngineErrorDetails {
  const _EngineErrorDetails({
    required this.message,
    this.statusCode,
    this.isCors = false,
    this.isTimeout = false,
  });

  final String message;
  final int? statusCode;
  final bool isCors;
  final bool isTimeout;

  @override
  String toString() =>
      'EngineErrorDetails(message: $message, statusCode: $statusCode, cors: $isCors, timeout: $isTimeout)';
}

class _EngineComputeOutcome {
  const _EngineComputeOutcome({
    required this.ok,
    required this.hadUpdates,
    this.errorDetails,
  });

  final bool ok;
  final bool hadUpdates;
  final _EngineErrorDetails? errorDetails;
}

// ============================== Modelo =====================================

class _ColumnPrefs {
  const _ColumnPrefs({
    required this.type,
    this.hidden = false,
    this.required = false,
    this.enumValues = const <String>[],
  });

  final _ColType type;
  final bool hidden;
  final bool required;
  final List<String> enumValues;

  _ColumnPrefs copyWith({
    _ColType? type,
    bool? hidden,
    bool? required,
    List<String>? enumValues,
  }) {
    return _ColumnPrefs(
      type: type ?? this.type,
      hidden: hidden ?? this.hidden,
      required: required ?? this.required,
      enumValues: enumValues ?? this.enumValues,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'hidden': hidden,
        if (required) 'required': true,
        if (enumValues.isNotEmpty) 'enumValues': enumValues,
      };

  static _ColumnPrefs? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<Object?, Object?>();
    final typeRaw = (map['type'] ?? '').toString();
    final parsedType = _colTypeFromStorageName(typeRaw);
    if (parsedType == null || parsedType == _ColType.photos) return null;
    final hidden = map['hidden'] as bool? ?? false;
    final required = map['required'] as bool? ?? false;
    final enumValues = <String>[];
    final enumRaw = map['enumValues'];
    if (enumRaw is List) {
      for (final item in enumRaw) {
        final value = (item ?? '').toString().trim();
        if (value.isEmpty) continue;
        enumValues.add(value);
      }
    }
    return _ColumnPrefs(
      type: parsedType,
      hidden: hidden,
      required: required,
      enumValues: enumValues,
    );
  }
}

class _SheetModel {
  _SheetModel({
    required this.headers,
    required this.colIds,
    required this.rows,
    this.name,
    this.savedAt,
    this.cellMeta = const <String, CellMeta>{},
    this.columnPrefsById = const <String, _ColumnPrefs>{},
    this.columnOrder = const <String>[],
    this.frozenColId,
  });

  final String? name;
  final DateTime? savedAt;
  final List<String> headers;
  final List<String> colIds;
  final List<_RowModel> rows;
  final Map<String, CellMeta> cellMeta;
  final Map<String, _ColumnPrefs> columnPrefsById;
  final List<String> columnOrder;
  final String? frozenColId;

  Map<String, dynamic> toJson() => {
        'name': name,
        'savedAt': savedAt?.toIso8601String(),
        'headers': headers,
        'colIds': colIds,
        'rows': rows.map((r) => r.toJson()).toList(),
        if (cellMeta.isNotEmpty)
          'cellMeta': cellMeta.map(
            (key, value) => MapEntry(key, value.toJson()),
          ),
        if (columnPrefsById.isNotEmpty)
          'columnPrefs': columnPrefsById.map(
            (key, value) => MapEntry(key, value.toJson()),
          ),
        if (columnOrder.isNotEmpty) 'columnOrder': columnOrder,
        if (frozenColId?.trim().isNotEmpty ?? false) 'frozenColId': frozenColId,
      };

  static _SheetModel fromJson(Map<String, dynamic> map) {
    final name = (map['name'] as String?)?.toString();
    final savedAt = DateTime.tryParse((map['savedAt'] ?? '').toString());

    final headers =
        (map['headers'] as List?)?.map((e) => (e ?? '').toString()).toList() ??
            const <String>[];
    final colIds =
        (map['colIds'] as List?)?.map((e) => (e ?? '').toString()).toList() ??
            const <String>[];

    final rowsRaw = (map['rows'] as List?) ?? const [];
    final rowModels = <_RowModel>[];

    for (final it in rowsRaw) {
      if (it is Map) {
        rowModels.add(_RowModel.fromJson(it.cast<String, dynamic>()));
      } else if (it is List) {
        final cells = it.map((e) => (e ?? '').toString()).toList();
        rowModels.add(_RowModel.fromCells(cells));
      }
    }

    final metaRaw = map['cellMeta'];
    final cellMeta = <String, CellMeta>{};
    if (metaRaw is Map) {
      metaRaw.forEach((key, value) {
        final meta = CellMeta.fromJson(value);
        if (meta != null) {
          cellMeta[key.toString()] = meta;
        }
      });
    }

    final prefsRaw = map['columnPrefs'];
    final columnPrefsById = <String, _ColumnPrefs>{};
    if (prefsRaw is Map) {
      prefsRaw.forEach((key, value) {
        final parsed = _ColumnPrefs.fromJson(value);
        if (parsed != null) {
          columnPrefsById[key.toString()] = parsed;
        }
      });
    }

    final columnOrder = <String>[];
    final orderRaw = map['columnOrder'];
    if (orderRaw is List) {
      for (final item in orderRaw) {
        final value = (item ?? '').toString().trim();
        if (value.isNotEmpty) {
          columnOrder.add(value);
        }
      }
    }

    final frozenRaw = (map['frozenColId'] ?? '').toString().trim();
    final frozenColId = frozenRaw.isEmpty ? null : frozenRaw;

    return _SheetModel(
      name: name,
      savedAt: savedAt,
      headers: headers,
      colIds: colIds,
      rows: rowModels,
      cellMeta: cellMeta,
      columnPrefsById: columnPrefsById,
      columnOrder: columnOrder,
      frozenColId: frozenColId,
    );
  }
}

class _RowModel {
  _RowModel({
    required this.id,
    required this.cells,
    required this.photos,
    this.gpsLat,
    this.gpsLng,
    this.gpsAccuracyM,
    this.gpsTs,
    this.gpsIsLastKnown = false,
  });

  final String id;
  final List<String> cells;
  final List<_RowPhoto> photos;
  final double? gpsLat;
  final double? gpsLng;
  final double? gpsAccuracyM;
  final DateTime? gpsTs;
  final bool gpsIsLastKnown;

  factory _RowModel.empty(int cols, {String id = ''}) => _RowModel(
        id: id,
        cells: List<String>.filled(cols, ''),
        photos: <_RowPhoto>[],
      );

  factory _RowModel.fromCells(List<String> cells, {String id = ''}) =>
      _RowModel(id: id, cells: cells, photos: <_RowPhoto>[]);

  _RowModel copy() => _RowModel(
        id: id,
        cells: List<String>.from(cells),
        photos: photos.map((p) => p.copy()).toList(),
        gpsLat: gpsLat,
        gpsLng: gpsLng,
        gpsAccuracyM: gpsAccuracyM,
        gpsTs: gpsTs,
        gpsIsLastKnown: gpsIsLastKnown,
      );

// ??? Snapshot para Undo/Redo: copia fotos SIN thumbs (liviano).
  _RowModel copyForSnapshot() => _RowModel(
        id: id,
        cells: List<String>.from(cells),
        photos: photos.map((p) => p.copyWithoutThumb()).toList(growable: false),
        gpsLat: gpsLat,
        gpsLng: gpsLng,
        gpsAccuracyM: gpsAccuracyM,
        gpsTs: gpsTs,
        gpsIsLastKnown: gpsIsLastKnown,
      );

  _RowModel copyWithCells(List<String> newCells) => _RowModel(
        id: id,
        cells: List<String>.from(newCells),
        photos: photos.map((p) => p.copy()).toList(),
        gpsLat: gpsLat,
        gpsLng: gpsLng,
        gpsAccuracyM: gpsAccuracyM,
        gpsTs: gpsTs,
        gpsIsLastKnown: gpsIsLastKnown,
      );

  _RowModel copyWithLocation({
    required double lat,
    required double lng,
    required double accuracyM,
    required DateTime ts,
    required bool isLastKnown,
  }) =>
      _RowModel(
        id: id,
        cells: List<String>.from(cells),
        photos: photos.map((p) => p.copy()).toList(),
        gpsLat: lat,
        gpsLng: lng,
        gpsAccuracyM: accuracyM,
        gpsTs: ts,
        gpsIsLastKnown: isLastKnown,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cells': cells,
// ??? Persistencia segura: sin thumbs base64 (evita overflow prefs/localStorage).
        'photos': photos
            .map((p) => p.toJson(persistThumb: _kPersistPhotoThumbs))
            .toList(),
        if (gpsLat != null && gpsLng != null)
          'gps': {
            'lat': gpsLat,
            'lng': gpsLng,
            'accuracyM': gpsAccuracyM,
            'ts': gpsTs?.toIso8601String(),
            'lastKnown': gpsIsLastKnown,
          },
      };

  static _RowModel fromJson(Map<String, dynamic> map) {
    final id = (map['id'] ?? '').toString();
    final cells =
        (map['cells'] as List?)?.map((e) => (e ?? '').toString()).toList() ??
            const <String>[];
    final photosRaw = (map['photos'] as List?) ?? const [];
    final photos = <_RowPhoto>[];
    for (final it in photosRaw) {
      if (it is Map) photos.add(_RowPhoto.fromJson(it.cast<String, dynamic>()));
    }
    final gps = map['gps'];
    if (gps is Map) {
      return _RowModel(
        id: id,
        cells: cells,
        photos: photos,
        gpsLat: (gps['lat'] as num?)?.toDouble(),
        gpsLng: (gps['lng'] as num?)?.toDouble(),
        gpsAccuracyM: (gps['accuracyM'] as num?)?.toDouble(),
        gpsTs: DateTime.tryParse((gps['ts'] ?? '').toString()),
        gpsIsLastKnown: (gps['lastKnown'] as bool?) ?? false,
      );
    }
    return _RowModel(id: id, cells: cells, photos: photos);
  }
}

class _RowPhoto {
  _RowPhoto({
    required this.name,
    required this.mime,
    required this.thumbB64,
    required this.addedAt,
    required this.path,
    this.lat,
    this.lng,
    this.accuracyM,
    this.isLastKnown = false,
    this.dataB64 = '',
  });

  final String name;
  final String mime;
  final String thumbB64;
  final DateTime addedAt;
  final String path;
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final bool isLastKnown;
  final String dataB64;

  _RowPhoto copy() => _RowPhoto(
        name: name,
        mime: mime,
        thumbB64: thumbB64,
        addedAt: addedAt,
        path: path,
        lat: lat,
        lng: lng,
        accuracyM: accuracyM,
        isLastKnown: isLastKnown,
        dataB64: dataB64,
      );

  _RowPhoto copyWithoutThumb() => _RowPhoto(
        name: name,
        mime: mime,
        thumbB64: '',
        addedAt: addedAt,
        path: path,
        lat: lat,
        lng: lng,
        accuracyM: accuracyM,
        isLastKnown: isLastKnown,
        dataB64: dataB64,
      );

  Map<String, dynamic> toJson({required bool persistThumb}) => {
        ...PhotoJson(
          name: name,
          mime: mime,
          thumbB64: thumbB64,
          addedAt: addedAt,
          path: path,
          dataB64: dataB64,
          lat: lat,
          lng: lng,
          accuracyM: accuracyM,
          isLastKnown: isLastKnown,
        ).toJson(persistThumb: persistThumb),
      };

  static _RowPhoto fromJson(Map<String, dynamic> map) {
    final decoded = PhotoJson.fromJson(map);
    return _RowPhoto(
      name: decoded.name,
      mime: decoded.mime,
      thumbB64: decoded.thumbB64,
      addedAt: decoded.addedAt,
      path: decoded.path,
      dataB64: decoded.dataB64,
      lat: decoded.lat,
      lng: decoded.lng,
      accuracyM: decoded.accuracyM,
      isLastKnown: decoded.isLastKnown,
    );
  }
}

class _ZipPhotoItem {
  _ZipPhotoItem({
    required this.cell,
    required this.photo,
    required this.fileName,
    required this.pathInZip,
  });

  final CellKey cell;
  final PhotoAttachment photo;
  final String fileName;
  final String pathInZip;
}

class _ZipAudioItem {
  _ZipAudioItem({
    required this.cell,
    required this.audio,
    required this.fileName,
    required this.pathInZip,
  });

  final CellKey cell;
  final AudioAttachment audio;
  final String fileName;
  final String pathInZip;
}

class _BackupAsset {
  _BackupAsset({
    required this.kind,
    required this.id,
    required this.cellKey,
    required this.fileName,
    required this.path,
    required this.mime,
    required this.size,
    required this.addedAt,
    this.caption,
    this.durationMs,
    this.bytes,
  });

  final String kind;
  final String id;
  final String cellKey;
  final String fileName;
  final String path;
  final String mime;
  final int size;
  final DateTime? addedAt;
  final String? caption;
  final int? durationMs;
  final Uint8List? bytes;
}

class _BackupBundle {
  const _BackupBundle({
    required this.json,
    required this.assets,
  });

  final Map<String, dynamic> json;
  final List<_BackupAsset> assets;
}

enum _PackageImportMode { createNew, replaceCurrent }

class _PackageImportPreview {
  const _PackageImportPreview({
    required this.formatLabel,
    required this.rows,
    required this.attachments,
    required this.photos,
    required this.audios,
    this.exportedAt,
    this.appVersion,
    this.buildId,
  });

  final String formatLabel;
  final int rows;
  final int attachments;
  final int photos;
  final int audios;
  final DateTime? exportedAt;
  final String? appVersion;
  final String? buildId;
}

class _PackageImportBundle {
  const _PackageImportBundle({
    required this.format,
    required this.sheetRaw,
    required this.assets,
    required this.filesByPath,
    required this.preview,
  });

  final String format;
  final Map<String, dynamic> sheetRaw;
  final List<Map<String, dynamic>> assets;
  final Map<String, ArchiveFile> filesByPath;
  final _PackageImportPreview preview;
}

class _ExportPrep {
  const _ExportPrep({
    required this.attachments,
    required this.embeddedPhotos,
    required this.photoItems,
    required this.audioItems,
    required this.manifest,
    required this.packageSheetJson,
  });

  final List<AttachmentRow> attachments;
  final List<EmbeddedPhoto> embeddedPhotos;
  final List<_ZipPhotoItem> photoItems;
  final List<_ZipAudioItem> audioItems;
  final Map<String, dynamic> manifest;
  final Map<String, dynamic> packageSheetJson;
}

class _SheetSnapshot {
  _SheetSnapshot({
    required this.name,
    required this.headers,
    required this.colIds,
    required this.columnPrefsById,
    required this.columnOrder,
    required this.frozenColId,
    required this.rowModels,
    required this.cellMeta,
    required this.selRow,
    required this.selCol,
  });

  final String name;
  final List<String> headers;
  final List<String> colIds;
  final Map<String, _ColumnPrefs> columnPrefsById;
  final List<String> columnOrder;
  final String? frozenColId;
  final List<_RowModel> rowModels;
  final Map<String, CellMeta> cellMeta;
  final int selRow;
  final int selCol;
}

class _ColumnTemplate {
  const _ColumnTemplate({
    required this.name,
    required this.savedAt,
    required this.prefsByLabel,
    required this.orderLabels,
    required this.frozenLabel,
  });

  final String name;
  final DateTime savedAt;
  final Map<String, _ColumnPrefs> prefsByLabel;
  final List<String> orderLabels;
  final String? frozenLabel;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'savedAt': savedAt.toIso8601String(),
      if (prefsByLabel.isNotEmpty)
        'prefsByLabel': prefsByLabel.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      if (orderLabels.isNotEmpty) 'orderLabels': orderLabels,
      if (frozenLabel?.trim().isNotEmpty ?? false) 'frozenLabel': frozenLabel,
    };
  }

  static _ColumnTemplate? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<Object?, Object?>();
    final name = (map['name'] ?? '').toString().trim();
    if (name.isEmpty) return null;
    final savedAt = DateTime.tryParse((map['savedAt'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final prefsByLabel = <String, _ColumnPrefs>{};
    final prefsRaw = map['prefsByLabel'];
    if (prefsRaw is Map) {
      prefsRaw.forEach((key, value) {
        final label = key.toString().trim();
        if (label.isEmpty) return;
        final pref = _ColumnPrefs.fromJson(value);
        if (pref == null) return;
        prefsByLabel[label] = pref;
      });
    }

    final orderLabels = <String>[];
    final orderRaw = map['orderLabels'];
    if (orderRaw is List) {
      for (final item in orderRaw) {
        final label = (item ?? '').toString().trim();
        if (label.isEmpty) continue;
        orderLabels.add(label);
      }
    }

    final frozenRaw = (map['frozenLabel'] ?? '').toString().trim();
    final frozenLabel = frozenRaw.isEmpty ? null : frozenRaw;

    return _ColumnTemplate(
      name: name,
      savedAt: savedAt,
      prefsByLabel: prefsByLabel,
      orderLabels: orderLabels,
      frozenLabel: frozenLabel,
    );
  }
}

class _CellRef {
  const _CellRef(this.r, this.c);
  final int r;
  final int c;

  @override
  bool operator ==(Object other) =>
      other is _CellRef && other.r == r && other.c == c;

  @override
  int get hashCode => Object.hash(r, c);
}

enum _ColType { text, number, date, status, checkbox, photos }

_ColType? _colTypeFromStorageName(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  for (final value in _ColType.values) {
    if (value.name == normalized) return value;
  }
  return null;
}

Uint8List? _tryDecodeB64(String raw) {
  try {
    if (raw.trim().isEmpty) return null;
    return base64Decode(raw);
  } catch (_) {
    return null;
  }
}

class _GpsFix {
  const _GpsFix({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.ts,
    required this.source,
    required this.provider,
  });

  final double lat;
  final double lng;
  final double accuracyM;
  final DateTime ts;
  final String source;
  final String provider;
}

class _GpsOutcome {
  const _GpsOutcome({this.fix, this.error, this.code});
  final _GpsFix? fix;
  final String? error;
  final String? code;

  bool get ok => fix != null;
}

class _QuickCapturePending {
  const _QuickCapturePending({
    required this.sheetId,
    required this.rowId,
    required this.queuedAt,
    this.attempts = 0,
    this.nextRetryAt,
    this.lastError,
  });

  final String sheetId;
  final String rowId;
  final DateTime queuedAt;
  final int attempts;
  final DateTime? nextRetryAt;
  final String? lastError;

  _QuickCapturePending copyWith({
    String? sheetId,
    String? rowId,
    DateTime? queuedAt,
    int? attempts,
    DateTime? nextRetryAt,
    String? lastError,
    bool clearRetry = false,
    bool clearError = false,
  }) {
    return _QuickCapturePending(
      sheetId: sheetId ?? this.sheetId,
      rowId: rowId ?? this.rowId,
      queuedAt: queuedAt ?? this.queuedAt,
      attempts: attempts ?? this.attempts,
      nextRetryAt: clearRetry ? null : (nextRetryAt ?? this.nextRetryAt),
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sheetId': sheetId,
        'rowId': rowId,
        'queuedAt': queuedAt.toIso8601String(),
        'attempts': attempts,
        if (nextRetryAt != null) 'nextRetryAt': nextRetryAt!.toIso8601String(),
        if (lastError != null && lastError!.trim().isNotEmpty)
          'lastError': lastError,
      };

  static _QuickCapturePending? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final sheetId = (raw['sheetId'] ?? '').toString().trim();
    final rowId = (raw['rowId'] ?? '').toString().trim();
    if (sheetId.isEmpty || rowId.isEmpty) return null;
    final queuedAt =
        DateTime.tryParse((raw['queuedAt'] ?? '').toString()) ?? DateTime.now();
    final attempts = (raw['attempts'] as num?)?.toInt() ?? 0;
    final nextRetryAt =
        DateTime.tryParse((raw['nextRetryAt'] ?? '').toString());
    final lastError = (raw['lastError'] ?? '').toString().trim();
    return _QuickCapturePending(
      sheetId: sheetId,
      rowId: rowId,
      queuedAt: queuedAt,
      attempts: attempts < 0 ? 0 : attempts,
      nextRetryAt: nextRetryAt,
      lastError: lastError.isEmpty ? null : lastError,
    );
  }
}

class _EditPending {
  const _EditPending({
    required this.sheetId,
    required this.revision,
    required this.queuedAt,
    this.attempts = 0,
    this.nextRetryAt,
    this.lastError,
  });

  final String sheetId;
  final int revision;
  final DateTime queuedAt;
  final int attempts;
  final DateTime? nextRetryAt;
  final String? lastError;

  _EditPending copyWith({
    String? sheetId,
    int? revision,
    DateTime? queuedAt,
    int? attempts,
    DateTime? nextRetryAt,
    String? lastError,
    bool clearRetry = false,
    bool clearError = false,
  }) {
    return _EditPending(
      sheetId: sheetId ?? this.sheetId,
      revision: revision ?? this.revision,
      queuedAt: queuedAt ?? this.queuedAt,
      attempts: attempts ?? this.attempts,
      nextRetryAt: clearRetry ? null : (nextRetryAt ?? this.nextRetryAt),
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sheetId': sheetId,
        'revision': revision,
        'queuedAt': queuedAt.toIso8601String(),
        'attempts': attempts,
        if (nextRetryAt != null) 'nextRetryAt': nextRetryAt!.toIso8601String(),
        if (lastError != null && lastError!.trim().isNotEmpty)
          'lastError': lastError,
      };

  static _EditPending? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final sheetId = (raw['sheetId'] ?? '').toString().trim();
    if (sheetId.isEmpty) return null;
    final revision = (raw['revision'] as num?)?.toInt() ?? 0;
    final queuedAt =
        DateTime.tryParse((raw['queuedAt'] ?? '').toString()) ?? DateTime.now();
    final attempts = (raw['attempts'] as num?)?.toInt() ?? 0;
    final nextRetryAt =
        DateTime.tryParse((raw['nextRetryAt'] ?? '').toString());
    final lastError = (raw['lastError'] ?? '').toString().trim();
    return _EditPending(
      sheetId: sheetId,
      revision: revision < 0 ? 0 : revision,
      queuedAt: queuedAt,
      attempts: attempts < 0 ? 0 : attempts,
      nextRetryAt: nextRetryAt,
      lastError: lastError.isEmpty ? null : lastError,
    );
  }
}

// ============================== Paleta =====================================

class _SheetPalette {
  _SheetPalette({
    required this.isLight,
    required this.hairline,
    required this.gridBg,
    required this.gridBorder,
    required this.headerText,
    required this.zebraA,
    required this.zebraB,
    required this.cellText,
    required this.cellTextMuted,
    required this.selectionFill,
    required this.selectionBorder,
    required this.focusRing,
    required this.chipBg,
    required this.chipBorder,
    required this.chipText,
    required this.bg,
    required this.fg,
    required this.fgMuted,
    required this.appBarBg,
    required this.headerBg,
    required this.indexBg,
    required this.cellBg,
    required this.blinkBg,
    required this.border,
    required this.borderStrong,
    required this.menuBg,
    required this.editorBg,
    required this.mobileInputBg,
    required this.accent,
    required this.statusBg,
    required this.statusFg,
    required this.hintBg,
    required this.headerCardBg,
    required this.headerCardBorder,
    required this.pillBtnBg,
    required this.pillBtnBorder,
    Color? hoverBg,
    Color? pressedBg,
    Color? zebraBg,
  })  : hoverBg = hoverBg ??
            (isLight
                ? cellText.withValues(alpha: 0.04)
                : cellText.withValues(alpha: 0.08)),
        pressedBg = pressedBg ??
            (isLight
                ? cellText.withValues(alpha: 0.08)
                : cellText.withValues(alpha: 0.14)),
        zebraBg = zebraBg ?? zebraB;

  final bool isLight;
  final double hairline;

  // Spreadsheet tokens (single source of truth).
  final Color gridBg;
  final Color gridBorder;
  final Color headerText;
  final Color zebraA;
  final Color zebraB;
  final Color cellText;
  final Color cellTextMuted;
  final Color selectionFill;
  final Color selectionBorder;
  final Color focusRing;
  final Color chipBg;
  final Color chipBorder;
  final Color chipText;

  final Color bg;
  final Color fg;
  final Color fgMuted;

  final Color appBarBg;
  final Color headerBg;
  final Color indexBg;

  final Color cellBg;
  final Color blinkBg;

  final Color border;
  final Color borderStrong;

  final Color menuBg;
  final Color editorBg;

  final Color mobileInputBg;

  final Color accent;

  final Color statusBg;
  final Color statusFg;

  final Color hintBg;

  final Color headerCardBg;
  final Color headerCardBorder;

  final Color pillBtnBg;
  final Color pillBtnBorder;

  final Color hoverBg;
  final Color pressedBg;
  final Color zebraBg;

  factory _SheetPalette.fromApp(AppThemeData t, {required double hairline}) {
    final c = t.colors;
    final card = c.surfaceElevated;
    final monoInk = c.textPrimary;
    final gridBg = c.surfaceElevated;
    final headerBg = c.surfaceMuted;
    final zebraA = c.surface;
    final zebraB = c.surfaceMuted.withValues(alpha: c.isLight ? 0.34 : 0.16);
    final selectionFill = monoInk.withValues(alpha: c.isLight ? 0.08 : 0.14);
    final selectionBorder = monoInk.withValues(alpha: c.isLight ? 0.38 : 0.52);
    final focusRing = monoInk.withValues(alpha: c.isLight ? 0.42 : 0.62);
    final chipBg = c.surfaceMuted;
    final chipBorder = c.borderStrong;
    final chipText = c.textPrimary;

    return _SheetPalette(
      isLight: c.isLight,
      hairline: hairline,
      gridBg: gridBg,
      gridBorder: c.border,
      headerText: c.textPrimary,
      zebraA: zebraA,
      zebraB: zebraB,
      cellText: c.textPrimary,
      cellTextMuted: c.textSecondary,
      selectionFill: selectionFill,
      selectionBorder: selectionBorder,
      focusRing: focusRing,
      chipBg: chipBg,
      chipBorder: chipBorder,
      chipText: chipText,
      bg: c.bg,
      fg: c.textPrimary,
      fgMuted: c.textSecondary,
      appBarBg: c.bg,
      headerBg: headerBg,
      indexBg: headerBg,
      cellBg: zebraA,
      blinkBg: selectionFill,
      border: c.border,
      borderStrong: c.borderStrong,
      menuBg: c.surfaceElevated,
      editorBg: c.surfaceElevated,
      mobileInputBg:
          c.surfaceElevated.withValues(alpha: c.isLight ? 0.96 : 0.72),
      accent: monoInk,
      statusBg: c.surfaceMuted,
      statusFg: c.textPrimary,
      hintBg: c.surfaceMuted,
      headerCardBg: card.withValues(alpha: c.isLight ? 0.92 : 0.75),
      headerCardBorder: c.border,
      pillBtnBg: c.surface,
      pillBtnBorder: c.borderStrong,
      hoverBg: c.hover,
      pressedBg: c.pressed,
      zebraBg: zebraB,
    );
  }
}

// ============================== Context actions ============================

class _CtxAction {
  _CtxAction(this.label, this.icon, this.run, {this.runOnTap = false});
  final String label;
  final IconData icon;
  final VoidCallback run;
  final bool runOnTap;
}

class _PreparedPhoto {
  const _PreparedPhoto({
    required this.bytes,
    required this.mime,
    required this.fileName,
    required this.caption,
    required this.originalName,
    required this.wasCompressed,
    this.thumbBytes,
    this.webStoredSource,
  });

  final Uint8List bytes;
  final String mime;
  final String fileName;
  final String caption;
  final String originalName;
  final bool wasCompressed;
  final Uint8List? thumbBytes;
  final Object? webStoredSource;
}

class _CompressParams {
  const _CompressParams({
    required this.bytes,
    required this.maxSide,
    required this.quality,
  });

  final Uint8List bytes;
  final int maxSide;
  final int quality;
}

class _CompressResult {
  const _CompressResult({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

_CompressResult _compressImageIsolate(_CompressParams params) {
  try {
    final decoded = img.decodeImage(params.bytes);
    if (decoded == null) {
      return _CompressResult(bytes: params.bytes, width: 0, height: 0);
    }
    final oriented = img.bakeOrientation(decoded);
    final maxSide = params.maxSide;
    img.Image resized = oriented;
    if (oriented.width > maxSide || oriented.height > maxSide) {
      resized = img.copyResize(
        oriented,
        width: oriented.width > oriented.height ? maxSide : null,
        height: oriented.height >= oriented.width ? maxSide : null,
        interpolation: img.Interpolation.average,
      );
    }
    final jpg = img.encodeJpg(resized, quality: params.quality);
    return _CompressResult(
      bytes: Uint8List.fromList(jpg),
      width: resized.width,
      height: resized.height,
    );
  } catch (_) {
    return _CompressResult(bytes: params.bytes, width: 0, height: 0);
  }
}

// ============================== Backdrop / Scroll ==========================
