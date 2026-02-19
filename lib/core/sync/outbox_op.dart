import 'dart:math';

class OutboxOp {
  const OutboxOp({
    required this.id,
    required this.createdAt,
    required this.kind,
    required this.payload,
    required this.attempts,
    required this.status,
    required this.clientMutationId,
    this.nextAttemptAt,
    this.lastError,
  });

  static const String statusQueued = 'queued';
  static const String statusInFlight = 'in_flight';
  static const String statusDone = 'done';
  static const String statusError = 'error';

  final String id;
  final DateTime createdAt;
  final String kind;
  final Map<String, dynamic> payload;
  final int attempts;
  final DateTime? nextAttemptAt;
  final String status;
  final String? lastError;
  final String clientMutationId;

  factory OutboxOp.create({
    required String kind,
    required Map<String, dynamic> payload,
    DateTime? createdAt,
  }) {
    final now = (createdAt ?? DateTime.now()).toUtc();
    final id = generateId();
    return OutboxOp(
      id: id,
      createdAt: now,
      kind: kind,
      payload: Map<String, dynamic>.from(payload),
      attempts: 0,
      status: statusQueued,
      clientMutationId: id,
    );
  }

  OutboxOp copyWith({
    String? id,
    DateTime? createdAt,
    String? kind,
    Map<String, dynamic>? payload,
    int? attempts,
    DateTime? nextAttemptAt,
    String? status,
    String? lastError,
    String? clientMutationId,
    bool clearNextAttemptAt = false,
    bool clearLastError = false,
  }) {
    return OutboxOp(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      attempts: attempts ?? this.attempts,
      nextAttemptAt:
          clearNextAttemptAt ? null : (nextAttemptAt ?? this.nextAttemptAt),
      status: status ?? this.status,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      clientMutationId: clientMutationId ?? this.clientMutationId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'kind': kind,
      'payload': payload,
      'attempts': attempts,
      'nextAttemptAt': nextAttemptAt?.toUtc().toIso8601String(),
      'status': status,
      'lastError': lastError,
      'clientMutationId': clientMutationId,
    };
  }

  static OutboxOp fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString().trim();
    final createdAtRaw = (json['createdAt'] ?? '').toString();
    final createdAt =
        DateTime.tryParse(createdAtRaw)?.toUtc() ?? DateTime.now().toUtc();
    final kind = (json['kind'] ?? '').toString().trim();

    final payloadRaw = json['payload'];
    final payload = payloadRaw is Map
        ? payloadRaw.map(
            (key, value) => MapEntry(key.toString(), value),
          )
        : <String, dynamic>{};

    final attempts = (json['attempts'] as num?)?.toInt() ?? 0;
    final nextAttemptAt =
        DateTime.tryParse((json['nextAttemptAt'] ?? '').toString())?.toUtc();
    final status = (json['status'] ?? '').toString().trim();
    final lastError = (json['lastError'] ?? '').toString().trim();
    final clientMutationId = (json['clientMutationId'] ?? '').toString().trim();

    final safeId = id.isEmpty ? generateId() : id;

    return OutboxOp(
      id: safeId,
      createdAt: createdAt,
      kind: kind,
      payload: payload,
      attempts: attempts < 0 ? 0 : attempts,
      nextAttemptAt: nextAttemptAt,
      status: _normalizeStatus(status),
      lastError: lastError.isEmpty ? null : lastError,
      clientMutationId: clientMutationId.isEmpty ? safeId : clientMutationId,
    );
  }

  static String generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = _rng.nextInt(1 << 32);
    return '$now-$random';
  }

  static String _normalizeStatus(String raw) {
    if (raw == statusQueued ||
        raw == statusInFlight ||
        raw == statusDone ||
        raw == statusError) {
      return raw;
    }
    return statusQueued;
  }

  static final Random _rng = Random();
}
