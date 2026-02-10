part of 'editor_screen.dart';

enum EditorSaveState { idle, saving, dirty, saved }

@immutable
class EditorSaveSnapshot {
  const EditorSaveSnapshot({required this.state, this.savedAt});

  final EditorSaveState state;
  final DateTime? savedAt;
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

class _SheetModel {
  _SheetModel({
    required this.headers,
    required this.colIds,
    required this.rows,
    this.name,
    this.savedAt,
    this.cellMeta = const <String, CellMeta>{},
  });

  final String? name;
  final DateTime? savedAt;
  final List<String> headers;
  final List<String> colIds;
  final List<_RowModel> rows;
  final Map<String, CellMeta> cellMeta;

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

    return _SheetModel(
      name: name,
      savedAt: savedAt,
      headers: headers,
      colIds: colIds,
      rows: rowModels,
      cellMeta: cellMeta,
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

class _ExportPrep {
  const _ExportPrep({
    required this.attachments,
    required this.embeddedPhotos,
    required this.photoItems,
    required this.audioItems,
    required this.manifest,
    required this.portableSheetJson,
  });

  final List<AttachmentRow> attachments;
  final List<EmbeddedPhoto> embeddedPhotos;
  final List<_ZipPhotoItem> photoItems;
  final List<_ZipAudioItem> audioItems;
  final Map<String, dynamic> manifest;
  final Map<String, dynamic> portableSheetJson;
}

class _SheetSnapshot {
  _SheetSnapshot({
    required this.name,
    required this.headers,
    required this.colIds,
    required this.rowModels,
    required this.cellMeta,
    required this.selRow,
    required this.selCol,
  });

  final String name;
  final List<String> headers;
  final List<String> colIds;
  final List<_RowModel> rowModels;
  final Map<String, CellMeta> cellMeta;
  final int selRow;
  final int selCol;
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

enum _ColType { text, number, date, status, photos }

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
  });

  final String sheetId;
  final String rowId;
  final DateTime queuedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sheetId': sheetId,
        'rowId': rowId,
        'queuedAt': queuedAt.toIso8601String(),
      };

  static _QuickCapturePending? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final sheetId = (raw['sheetId'] ?? '').toString().trim();
    final rowId = (raw['rowId'] ?? '').toString().trim();
    if (sheetId.isEmpty || rowId.isEmpty) return null;
    final queuedAt =
        DateTime.tryParse((raw['queuedAt'] ?? '').toString()) ?? DateTime.now();
    return _QuickCapturePending(
      sheetId: sheetId,
      rowId: rowId,
      queuedAt: queuedAt,
    );
  }
}

// ============================== Paleta =====================================

class _SheetPalette {
  _SheetPalette({
    required this.isLight,
    required this.hairline,
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
                ? Colors.black.withOpacity(0.04)
                : Colors.white.withOpacity(0.08)),
        pressedBg = pressedBg ??
            (isLight
                ? Colors.black.withOpacity(0.08)
                : Colors.white.withOpacity(0.14)),
        zebraBg = zebraBg ??
            (isLight
                ? const Color(0xFFF9F9FB)
                : Colors.white.withOpacity(0.02));

  final bool isLight;
  final double hairline;

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

    return _SheetPalette(
      isLight: c.isLight,
      hairline: hairline,
      bg: c.bg,
      fg: c.textPrimary,
      fgMuted: c.textSecondary,
      appBarBg: c.bg,
      headerBg: card,
      indexBg: card,
      cellBg: c.surface,
      blinkBg: c.accentMuted,
      border: c.border,
      borderStrong: c.borderStrong,
      menuBg: c.surfaceElevated,
      editorBg: c.surfaceElevated,
      mobileInputBg: c.surfaceElevated.withOpacity(c.isLight ? 0.96 : 0.72),
      accent: c.accent,
      statusBg: c.statusBg,
      statusFg: c.statusFg,
      hintBg: c.surfaceMuted,
      headerCardBg: c.surfaceElevated.withOpacity(c.isLight ? 0.9 : 0.65),
      headerCardBorder: c.border,
      pillBtnBg: c.surfaceMuted,
      pillBtnBorder: c.border,
      hoverBg: c.hover,
      pressedBg: c.pressed,
      zebraBg: c.surfaceMuted.withOpacity(c.isLight ? 0.6 : 0.12),
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
