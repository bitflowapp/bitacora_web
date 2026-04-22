// lib/models/cell_meta.dart
// Modelos de metadata por celda (GPS / fotos / audios) + claves estables.

class CellKey {
  const CellKey(this.row, this.col);

  final int row; // 0-based
  final int col; // 0-based

  String get a1 => '${_colToLetters(col)}${row + 1}';

  String toKey() => '$row:$col';

  static CellKey? fromKey(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (s.contains(':')) {
      final parts = s.split(':');
      if (parts.length != 2) return null;
      final r = int.tryParse(parts[0]);
      final c = int.tryParse(parts[1]);
      if (r == null || c == null) return null;
      return CellKey(r, c);
    }
    return fromA1(s);
  }

  static CellKey? fromA1(String raw) {
    final s = raw.trim().toUpperCase();
    if (s.isEmpty) return null;
    final m = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(s);
    if (m == null) return null;
    final letters = m.group(1) ?? '';
    final numbers = m.group(2) ?? '';
    final col = _lettersToCol(letters);
    final row = int.tryParse(numbers);
    if (row == null || row <= 0) return null;
    return CellKey(row - 1, col);
  }

  static String _colToLetters(int col) {
    var n = col + 1;
    if (n <= 0) return 'A';
    final buffer = StringBuffer();
    while (n > 0) {
      final rem = (n - 1) % 26;
      buffer.writeCharCode(65 + rem);
      n = (n - 1) ~/ 26;
    }
    return buffer.toString().split('').reversed.join();
  }

  static int _lettersToCol(String letters) {
    var out = 0;
    for (int i = 0; i < letters.length; i++) {
      final code = letters.codeUnitAt(i);
      if (code < 65 || code > 90) continue;
      out = out * 26 + (code - 64);
    }
    return (out - 1).clamp(0, 1 << 30);
  }
}

class GpsMeta {
  const GpsMeta({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.timestamp,
    required this.source,
    required this.provider,
  });

  final double lat;
  final double lng;
  final double accuracyM;
  final DateTime timestamp;
  final String source;
  final String provider;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'acc': accuracyM,
        'ts': timestamp.toIso8601String(),
        'source': source,
        'provider': provider,
      };

  static GpsMeta? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final lat = (raw['lat'] as num?)?.toDouble();
    final lng = (raw['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return GpsMeta(
      lat: lat,
      lng: lng,
      accuracyM: (raw['acc'] as num?)?.toDouble() ?? 0,
      timestamp:
          DateTime.tryParse((raw['ts'] ?? '').toString()) ?? DateTime.now(),
      source: (raw['source'] ?? '').toString(),
      provider: (raw['provider'] ?? '').toString(),
    );
  }

  GpsMeta copy() => GpsMeta(
        lat: lat,
        lng: lng,
        accuracyM: accuracyM,
        timestamp: timestamp,
        source: source,
        provider: provider,
      );
}

class AttachmentRef {
  const AttachmentRef({
    required this.id,
    required this.filename,
    required this.mime,
    required this.size,
    required this.storedRef,
    required this.thumbRef,
    required this.addedAt,
    this.caption = '',
    this.lat,
    this.lon,
    this.accuracyM,
    this.isLastKnown = false,
  });

  final String id;
  final String filename;
  final String caption;
  final String mime;
  final int size;
  final String storedRef;
  final String thumbRef;
  final DateTime addedAt;
  final double? lat;
  final double? lon;
  final double? accuracyM;
  final bool isLastKnown;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': filename,
        if (caption.trim().isNotEmpty) 'caption': caption.trim(),
        'mime': mime,
        'size': size,
        'storedRef': storedRef,
        'thumbRef': thumbRef,
        'addedAt': addedAt.toIso8601String(),
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        if (accuracyM != null) 'acc': accuracyM,
        'lastKnown': isLastKnown,
      };

  static AttachmentRef? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return AttachmentRef(
      id: (raw['id'] ?? '').toString(),
      filename: (raw['name'] ?? '').toString(),
      caption: (raw['caption'] ?? '').toString(),
      mime: (raw['mime'] ?? 'image/jpeg').toString(),
      size: (raw['size'] as num?)?.toInt() ?? 0,
      storedRef: (raw['storedRef'] ?? '').toString(),
      thumbRef: (raw['thumbRef'] ?? '').toString(),
      addedAt: DateTime.tryParse((raw['addedAt'] ?? '').toString()) ??
          DateTime.now(),
      lat: (raw['lat'] as num?)?.toDouble(),
      lon: (raw['lon'] as num?)?.toDouble(),
      accuracyM: (raw['acc'] as num?)?.toDouble(),
      isLastKnown: (raw['lastKnown'] as bool?) ?? false,
    );
  }

  AttachmentRef copy() => AttachmentRef(
        id: id,
        filename: filename,
        caption: caption,
        mime: mime,
        size: size,
        storedRef: storedRef,
        thumbRef: thumbRef,
        addedAt: addedAt,
        lat: lat,
        lon: lon,
        accuracyM: accuracyM,
        isLastKnown: isLastKnown,
      );

  AttachmentRef copyWith({
    String? filename,
    String? caption,
    String? mime,
    int? size,
    String? storedRef,
    String? thumbRef,
    DateTime? addedAt,
    double? lat,
    double? lon,
    double? accuracyM,
    bool? isLastKnown,
  }) =>
      AttachmentRef(
        id: id,
        filename: filename ?? this.filename,
        caption: caption ?? this.caption,
        mime: mime ?? this.mime,
        size: size ?? this.size,
        storedRef: storedRef ?? this.storedRef,
        thumbRef: thumbRef ?? this.thumbRef,
        addedAt: addedAt ?? this.addedAt,
        lat: lat ?? this.lat,
        lon: lon ?? this.lon,
        accuracyM: accuracyM ?? this.accuracyM,
        isLastKnown: isLastKnown ?? this.isLastKnown,
      );
}

typedef PhotoAttachment = AttachmentRef;

class AudioAttachment {
  const AudioAttachment({
    required this.id,
    required this.filename,
    required this.mime,
    required this.size,
    required this.durationMs,
    required this.storedRef,
    required this.addedAt,
    this.transcript = '',
  });

  final String id;
  final String filename;
  final String mime;
  final int size;
  final int durationMs;
  final String storedRef;
  final DateTime addedAt;
  final String transcript;

  Map<String, dynamic> toJson() {
    final cleanTranscript = transcript.trim();
    return {
      'id': id,
      'name': filename,
      'mime': mime,
      'size': size,
      'durationMs': durationMs,
      'storedRef': storedRef,
      'addedAt': addedAt.toIso8601String(),
      if (cleanTranscript.isNotEmpty) 'transcript': cleanTranscript,
    };
  }

  static AudioAttachment? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return AudioAttachment(
      id: (raw['id'] ?? '').toString(),
      filename: (raw['name'] ?? '').toString(),
      mime: (raw['mime'] ?? 'audio/m4a').toString(),
      size: (raw['size'] as num?)?.toInt() ?? 0,
      durationMs: (raw['durationMs'] as num?)?.toInt() ?? 0,
      storedRef: (raw['storedRef'] ?? '').toString(),
      addedAt: DateTime.tryParse((raw['addedAt'] ?? '').toString()) ??
          DateTime.now(),
      transcript: (raw['transcript'] ?? '').toString(),
    );
  }

  AudioAttachment copy() => AudioAttachment(
        id: id,
        filename: filename,
        mime: mime,
        size: size,
        durationMs: durationMs,
        storedRef: storedRef,
        addedAt: addedAt,
        transcript: transcript,
      );

  AudioAttachment copyWith({
    String? filename,
    String? mime,
    int? size,
    int? durationMs,
    String? storedRef,
    DateTime? addedAt,
    String? transcript,
  }) =>
      AudioAttachment(
        id: id,
        filename: filename ?? this.filename,
        mime: mime ?? this.mime,
        size: size ?? this.size,
        durationMs: durationMs ?? this.durationMs,
        storedRef: storedRef ?? this.storedRef,
        addedAt: addedAt ?? this.addedAt,
        transcript: transcript ?? this.transcript,
      );
}

class CellMeta {
  const CellMeta({
    this.gps,
    this.photos = const <PhotoAttachment>[],
    this.audios = const <AudioAttachment>[],
  });

  final GpsMeta? gps;
  final List<PhotoAttachment> photos;
  final List<AudioAttachment> audios;

  bool get hasGps => gps != null;
  bool get hasPhotos => photos.isNotEmpty;
  bool get hasAudios => audios.isNotEmpty;
  bool get isEmpty => gps == null && photos.isEmpty && audios.isEmpty;

  CellMeta copy() => CellMeta(
        gps: gps?.copy(),
        photos: photos.map((p) => p.copy()).toList(growable: false),
        audios: audios.map((a) => a.copy()).toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        if (gps != null) 'gps': gps!.toJson(),
        if (photos.isNotEmpty)
          'photos': photos.map((p) => p.toJson()).toList(growable: false),
        if (audios.isNotEmpty)
          'audios': audios.map((a) => a.toJson()).toList(growable: false),
      };

  static CellMeta? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final gps = GpsMeta.fromJson(raw['gps']);
    final photosRaw = raw['photos'];
    final audiosRaw = raw['audios'];
    final photos = <PhotoAttachment>[];
    if (photosRaw is List) {
      for (final p in photosRaw) {
        final item = AttachmentRef.fromJson(p);
        if (item != null) photos.add(item);
      }
    }
    final audios = <AudioAttachment>[];
    if (audiosRaw is List) {
      for (final a in audiosRaw) {
        final item = AudioAttachment.fromJson(a);
        if (item != null) audios.add(item);
      }
    }
    final meta = CellMeta(
      gps: gps,
      photos: photos,
      audios: audios,
    );
    return meta.isEmpty ? null : meta;
  }
}
