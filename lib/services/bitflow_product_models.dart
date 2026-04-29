import 'dart:convert';

enum BitFlowTier { free, pro }

enum BitFlowFeature {
  basicFormulas,
  advancedFormulas,
  exportXlsx,
  templates,
  automationTools,
  sharing,
}

enum BitFlowSharePermission { view, edit }

enum BitFlowPaymentProvider { stripe, mercadoPago }

enum BitFlowPaymentPlan { proMonthly, proAnnual }

class BitFlowWorkspace {
  const BitFlowWorkspace({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDefault;

  BitFlowWorkspace copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDefault,
  }) {
    return BitFlowWorkspace(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'isDefault': isDefault,
      };

  factory BitFlowWorkspace.fromJson(Map<String, dynamic> json) {
    return BitFlowWorkspace(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now().toUtc(),
      isDefault: json['isDefault'] == true,
    );
  }
}

class BitFlowSheetRecord {
  const BitFlowSheetRecord({
    required this.sheetId,
    required this.title,
    required this.rawJson,
    required this.updatedAt,
    required this.rows,
    required this.workspaceId,
    this.ownerUserId,
    this.origin = 'local',
  });

  final String sheetId;
  final String title;
  final String rawJson;
  final DateTime updatedAt;
  final int rows;
  final String workspaceId;
  final String? ownerUserId;
  final String origin;

  Map<String, dynamic> decodedModel() {
    final decoded = jsonDecode(rawJson);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  }

  BitFlowSheetRecord copyWith({
    String? sheetId,
    String? title,
    String? rawJson,
    DateTime? updatedAt,
    int? rows,
    String? workspaceId,
    String? ownerUserId,
    String? origin,
  }) {
    return BitFlowSheetRecord(
      sheetId: sheetId ?? this.sheetId,
      title: title ?? this.title,
      rawJson: rawJson ?? this.rawJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rows: rows ?? this.rows,
      workspaceId: workspaceId ?? this.workspaceId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      origin: origin ?? this.origin,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sheetId': sheetId,
        'title': title,
        'rawJson': rawJson,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'rows': rows,
        'workspaceId': workspaceId,
        'ownerUserId': ownerUserId,
        'origin': origin,
      };

  factory BitFlowSheetRecord.fromJson(Map<String, dynamic> json) {
    return BitFlowSheetRecord(
      sheetId: (json['sheetId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      rawJson: (json['rawJson'] ?? '{}').toString(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now().toUtc(),
      rows: (json['rows'] as num?)?.toInt() ?? 0,
      workspaceId: (json['workspaceId'] ?? '').toString(),
      ownerUserId: (json['ownerUserId'] ?? '').toString().trim().isEmpty
          ? null
          : (json['ownerUserId'] ?? '').toString(),
      origin: (json['origin'] ?? 'local').toString(),
    );
  }
}

class BitFlowShareLink {
  const BitFlowShareLink({
    required this.id,
    required this.sheetId,
    required this.permission,
    required this.url,
    required this.title,
    required this.snapshotRawJson,
    required this.workspaceId,
    required this.createdAt,
    required this.updatedAt,
    this.ownerUserId,
    this.ownerEmail,
    this.storageLabel = 'local',
  });

  final String id;
  final String sheetId;
  final BitFlowSharePermission permission;
  final String url;
  final String title;
  final String snapshotRawJson;
  final String workspaceId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? ownerUserId;
  final String? ownerEmail;
  final String storageLabel;

  BitFlowShareLink copyWith({
    String? id,
    String? sheetId,
    BitFlowSharePermission? permission,
    String? url,
    String? title,
    String? snapshotRawJson,
    String? workspaceId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? ownerUserId,
    String? ownerEmail,
    String? storageLabel,
  }) {
    return BitFlowShareLink(
      id: id ?? this.id,
      sheetId: sheetId ?? this.sheetId,
      permission: permission ?? this.permission,
      url: url ?? this.url,
      title: title ?? this.title,
      snapshotRawJson: snapshotRawJson ?? this.snapshotRawJson,
      workspaceId: workspaceId ?? this.workspaceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      storageLabel: storageLabel ?? this.storageLabel,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'sheetId': sheetId,
        'permission': permission.name,
        'url': url,
        'title': title,
        'snapshotRawJson': snapshotRawJson,
        'workspaceId': workspaceId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'ownerUserId': ownerUserId,
        'ownerEmail': ownerEmail,
        'storageLabel': storageLabel,
      };

  factory BitFlowShareLink.fromJson(Map<String, dynamic> json) {
    final permissionName = (json['permission'] ?? 'view').toString();
    return BitFlowShareLink(
      id: (json['id'] ?? '').toString(),
      sheetId: (json['sheetId'] ?? '').toString(),
      permission: BitFlowSharePermission.values.firstWhere(
        (value) => value.name == permissionName,
        orElse: () => BitFlowSharePermission.view,
      ),
      url: (json['url'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      snapshotRawJson: (json['snapshotRawJson'] ?? '{}').toString(),
      workspaceId: (json['workspaceId'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now().toUtc(),
      ownerUserId: (json['ownerUserId'] ?? '').toString().trim().isEmpty
          ? null
          : (json['ownerUserId'] ?? '').toString(),
      ownerEmail: (json['ownerEmail'] ?? '').toString().trim().isEmpty
          ? null
          : (json['ownerEmail'] ?? '').toString(),
      storageLabel: (json['storageLabel'] ?? 'local').toString(),
    );
  }
}

class BitFlowEntitlement {
  const BitFlowEntitlement({
    required this.tier,
    required this.maxSheets,
    required this.signedIn,
    required this.isPremiumActive,
    required this.source,
    this.trialEndsAt,
    this.provider,
    this.features = const <BitFlowFeature>{
      BitFlowFeature.basicFormulas,
      BitFlowFeature.exportXlsx,
    },
  });

  final BitFlowTier tier;
  final int? maxSheets;
  final bool signedIn;
  final bool isPremiumActive;
  final String source;
  final DateTime? trialEndsAt;
  final BitFlowPaymentProvider? provider;
  final Set<BitFlowFeature> features;

  bool get isFree => tier == BitFlowTier.free;
  bool get isPro => tier == BitFlowTier.pro;

  bool has(BitFlowFeature feature) => features.contains(feature);

  BitFlowEntitlement copyWith({
    BitFlowTier? tier,
    int? maxSheets,
    bool? signedIn,
    bool? isPremiumActive,
    String? source,
    DateTime? trialEndsAt,
    BitFlowPaymentProvider? provider,
    Set<BitFlowFeature>? features,
  }) {
    return BitFlowEntitlement(
      tier: tier ?? this.tier,
      maxSheets: maxSheets ?? this.maxSheets,
      signedIn: signedIn ?? this.signedIn,
      isPremiumActive: isPremiumActive ?? this.isPremiumActive,
      source: source ?? this.source,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      provider: provider ?? this.provider,
      features: features ?? this.features,
    );
  }

  static const BitFlowEntitlement free = BitFlowEntitlement(
    tier: BitFlowTier.free,
    maxSheets: 5,
    signedIn: false,
    isPremiumActive: false,
    source: 'free',
    features: <BitFlowFeature>{
      BitFlowFeature.basicFormulas,
      BitFlowFeature.exportXlsx,
    },
  );

  static const BitFlowEntitlement pro = BitFlowEntitlement(
    tier: BitFlowTier.pro,
    maxSheets: null,
    signedIn: true,
    isPremiumActive: true,
    source: 'pro',
    features: <BitFlowFeature>{
      BitFlowFeature.basicFormulas,
      BitFlowFeature.advancedFormulas,
      BitFlowFeature.exportXlsx,
      BitFlowFeature.templates,
      BitFlowFeature.automationTools,
      BitFlowFeature.sharing,
    },
  );
}
