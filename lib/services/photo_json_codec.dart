class PhotoJson {
  PhotoJson({
    required this.name,
    required this.mime,
    required this.thumbB64,
    required this.addedAt,
    required this.path,
    required this.dataB64,
    this.lat,
    this.lng,
    this.accuracyM,
    this.isLastKnown = false,
  });

  final String name;
  final String mime;
  final String thumbB64;
  final DateTime addedAt;
  final String path;
  final String dataB64;
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final bool isLastKnown;

  Map<String, dynamic> toJson({required bool persistThumb}) => {
        'name': name,
        'mime': mime,
        'thumbB64': persistThumb ? thumbB64 : '',
        'addedAt': addedAt.toIso8601String(),
        'path': path,
        if (dataB64.isNotEmpty) 'dataB64': dataB64,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (accuracyM != null) 'accuracyM': accuracyM,
        'lastKnown': isLastKnown,
      };

  static PhotoJson fromJson(Map<String, dynamic> map) {
    return PhotoJson(
      name: (map['name'] ?? '').toString(),
      mime: (map['mime'] ?? 'image/jpeg').toString(),
      thumbB64: (map['thumbB64'] ?? '').toString(),
      addedAt: DateTime.tryParse((map['addedAt'] ?? '').toString()) ??
          DateTime.now(),
      path: (map['path'] ?? '').toString(),
      dataB64: (map['dataB64'] ?? '').toString(),
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      accuracyM: (map['accuracyM'] as num?)?.toDouble(),
      isLastKnown: (map['lastKnown'] as bool?) ?? false,
    );
  }
}
