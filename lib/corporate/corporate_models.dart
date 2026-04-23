enum CorporateRole {
  tecnico('tecnico', 'Tecnico'),
  supervisor('supervisor', 'Supervisor'),
  coordinador('coordinador', 'Coordinador'),
  admin('admin', 'Admin');

  const CorporateRole(this.value, this.label);

  final String value;
  final String label;

  static CorporateRole fromValue(Object? value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    return CorporateRole.values.firstWhere(
      (role) => role.value == raw,
      orElse: () => CorporateRole.tecnico,
    );
  }
}

class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.role,
    this.legalName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? legalName;
  final CorporateRole role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Workspace.fromJson(
    Map<String, dynamic> json, {
    CorporateRole role = CorporateRole.tecnico,
  }) {
    return Workspace(
      id: _readString(json['id']),
      name: _readString(json['name'], fallback: 'Workspace'),
      legalName: _readNullableString(json['legal_name']),
      role: role,
      createdAt: _readDate(json['created_at']),
      updatedAt: _readDate(json['updated_at']),
    );
  }
}

class WorkspaceMembership {
  const WorkspaceMembership({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.role,
    this.status = 'active',
  });

  final String id;
  final String workspaceId;
  final String userId;
  final CorporateRole role;
  final String status;

  factory WorkspaceMembership.fromJson(Map<String, dynamic> json) {
    return WorkspaceMembership(
      id: _readString(json['id']),
      workspaceId: _readString(json['workspace_id']),
      userId: _readString(json['user_id']),
      role: CorporateRole.fromValue(json['role']),
      status: _readString(json['status'], fallback: 'active'),
    );
  }
}

class Project {
  const Project({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.status,
    this.code,
    this.description,
    this.fieldScope,
    this.startsOn,
    this.endsOn,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String name;
  final String? code;
  final String? description;
  final String? fieldScope;
  final String status;
  final DateTime? startsOn;
  final DateTime? endsOn;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: _readString(json['id']),
      workspaceId: _readString(json['workspace_id']),
      name: _readString(json['name'], fallback: 'Proyecto tecnico'),
      code: _readNullableString(json['code']),
      description: _readNullableString(json['description']),
      fieldScope: _readNullableString(json['field_scope']),
      status: _readString(json['status'], fallback: 'active'),
      startsOn: _readDate(json['starts_on']),
      endsOn: _readDate(json['ends_on']),
      createdAt: _readDate(json['created_at']),
      updatedAt: _readDate(json['updated_at']),
    );
  }
}

class ProjectMember {
  const ProjectMember({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.role,
  });

  final String id;
  final String projectId;
  final String userId;
  final CorporateRole role;

  factory ProjectMember.fromJson(Map<String, dynamic> json) {
    return ProjectMember(
      id: _readString(json['id']),
      projectId: _readString(json['project_id']),
      userId: _readString(json['user_id']),
      role: CorporateRole.fromValue(json['role']),
    );
  }
}

class ProjectDetail {
  const ProjectDetail({
    required this.project,
    required this.members,
  });

  final Project project;
  final List<ProjectMember> members;
}

class RowReview {
  const RowReview({
    required this.projectId,
    required this.sheetLocalId,
    required this.rowId,
    required this.status,
    this.createdBy,
    this.updatedBy,
    this.approvedBy,
    this.approvedAt,
    this.observedAt,
    this.correctedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String projectId;
  final String sheetLocalId;
  final String rowId;
  final String status;
  final String? createdBy;
  final String? updatedBy;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? observedAt;
  final DateTime? correctedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RowReview.fromJson(Map<String, dynamic> json) {
    return RowReview(
      projectId: _readString(json['project_id']),
      sheetLocalId: _readString(json['sheet_local_id']),
      rowId: _readString(json['row_id']),
      status: _readString(json['status'], fallback: 'sin_revision'),
      createdBy: _readNullableString(json['created_by']),
      updatedBy: _readNullableString(json['updated_by']),
      approvedBy: _readNullableString(json['approved_by']),
      approvedAt: _readDate(json['approved_at']),
      observedAt: _readDate(json['observed_at']),
      correctedAt: _readDate(json['corrected_at']),
      createdAt: _readDate(json['created_at']),
      updatedAt: _readDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'project_id': projectId,
        'sheet_local_id': sheetLocalId,
        'row_id': rowId,
        'status': status,
        if (createdBy?.trim().isNotEmpty ?? false) 'created_by': createdBy,
        if (updatedBy?.trim().isNotEmpty ?? false) 'updated_by': updatedBy,
        if (approvedBy?.trim().isNotEmpty ?? false) 'approved_by': approvedBy,
        if (approvedAt != null) 'approved_at': approvedAt!.toIso8601String(),
        if (observedAt != null) 'observed_at': observedAt!.toIso8601String(),
        if (correctedAt != null) 'corrected_at': correctedAt!.toIso8601String(),
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };
}

class RowEvidenceLink {
  const RowEvidenceLink({
    required this.projectId,
    required this.sheetLocalId,
    required this.rowId,
    required this.evidenceRef,
    this.evidenceKind = 'archivo',
    this.evidenceLabel = '',
    this.evidenceMime = '',
    this.sourceCellKey = '',
    this.createdBy,
    this.createdAt,
  });

  final String projectId;
  final String sheetLocalId;
  final String rowId;
  final String evidenceRef;
  final String evidenceKind;
  final String evidenceLabel;
  final String evidenceMime;
  final String sourceCellKey;
  final String? createdBy;
  final DateTime? createdAt;

  factory RowEvidenceLink.fromJson(Map<String, dynamic> json) {
    return RowEvidenceLink(
      projectId: _readString(json['project_id']),
      sheetLocalId: _readString(json['sheet_local_id']),
      rowId: _readString(json['row_id']),
      evidenceRef: _readString(json['evidence_ref']),
      evidenceKind: _readString(json['evidence_kind'], fallback: 'archivo'),
      evidenceLabel: _readNullableString(json['evidence_label']) ?? '',
      evidenceMime: _readNullableString(json['evidence_mime']) ?? '',
      sourceCellKey: _readNullableString(json['source_cell_key']) ?? '',
      createdBy: _readNullableString(json['created_by']),
      createdAt: _readDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'project_id': projectId,
        'sheet_local_id': sheetLocalId,
        'row_id': rowId,
        'evidence_ref': evidenceRef,
        if (evidenceKind.trim().isNotEmpty) 'evidence_kind': evidenceKind,
        if (evidenceLabel.trim().isNotEmpty) 'evidence_label': evidenceLabel,
        if (evidenceMime.trim().isNotEmpty) 'evidence_mime': evidenceMime,
        if (sourceCellKey.trim().isNotEmpty) 'source_cell_key': sourceCellKey,
        if (createdBy?.trim().isNotEmpty ?? false) 'created_by': createdBy,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

// ── RowComment ───────────────────────────────────────────────────────────────

/// Tipos de comentario permitidos en Fase 1.
enum RowCommentType {
  observacion('observacion', 'Observación'),
  respuesta('respuesta', 'Respuesta'),
  nota('nota', 'Nota'),
  resolucion('resolucion', 'Resolución');

  const RowCommentType(this.value, this.label);

  final String value;
  final String label;

  static RowCommentType fromValue(Object? v) {
    final raw = v?.toString().trim().toLowerCase() ?? '';
    return RowCommentType.values.firstWhere(
      (t) => t.value == raw,
      orElse: () => RowCommentType.nota,
    );
  }
}

class RowComment {
  const RowComment({
    required this.id,
    required this.projectId,
    required this.sheetLocalId,
    required this.rowId,
    required this.body,
    required this.commentType,
    required this.authorLabel,
    this.parentId,
    this.authorId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String sheetLocalId;
  final String rowId;
  final String? parentId;
  final String? authorId;
  final String authorLabel;
  final RowCommentType commentType;
  final String body;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RowComment.fromJson(Map<String, dynamic> json) {
    return RowComment(
      id: _readString(json['id']),
      projectId: _readString(json['project_id']),
      sheetLocalId: _readString(json['sheet_local_id']),
      rowId: _readString(json['row_id']),
      parentId: _readNullableString(json['parent_id']),
      authorId: _readNullableString(json['author_id']),
      authorLabel: _readString(json['author_label'], fallback: 'Usuario'),
      commentType: RowCommentType.fromValue(json['comment_type']),
      body: _readString(json['body']),
      createdAt: _readDate(json['created_at']),
      updatedAt: _readDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'project_id': projectId,
        'sheet_local_id': sheetLocalId,
        'row_id': rowId,
        if (parentId?.trim().isNotEmpty ?? false) 'parent_id': parentId,
        if (authorId?.trim().isNotEmpty ?? false) 'author_id': authorId,
        'author_label': authorLabel,
        'comment_type': commentType.value,
        'body': body,
      };
}

// ── UserNotification ─────────────────────────────────────────────────────────

enum NotifType {
  filaObservada('fila_observada', 'Fila observada'),
  filaCorregida('fila_corregida', 'Fila corregida'),
  filaAprobada('fila_aprobada', 'Fila aprobada'),
  comentarioNuevo('comentario_nuevo', 'Comentario nuevo');

  const NotifType(this.value, this.label);

  final String value;
  final String label;

  static NotifType fromValue(Object? v) {
    final raw = v?.toString().trim().toLowerCase() ?? '';
    return NotifType.values.firstWhere(
      (t) => t.value == raw,
      orElse: () => NotifType.comentarioNuevo,
    );
  }
}

class UserNotification {
  const UserNotification({
    required this.id,
    required this.userId,
    required this.notifType,
    required this.body,
    this.projectId,
    this.sheetLocalId,
    this.rowId,
    this.actorId,
    this.actorLabel,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String userId;
  final NotifType notifType;
  final String? projectId;
  final String? sheetLocalId;
  final String? rowId;
  final String? actorId;
  final String? actorLabel;
  final String body;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isRead => readAt != null;

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    return UserNotification(
      id: _readString(json['id']),
      userId: _readString(json['user_id']),
      notifType: NotifType.fromValue(json['notif_type']),
      projectId: _readNullableString(json['project_id']),
      sheetLocalId: _readNullableString(json['sheet_local_id']),
      rowId: _readNullableString(json['row_id']),
      actorId: _readNullableString(json['actor_id']),
      actorLabel: _readNullableString(json['actor_label']),
      body: _readString(json['body']),
      readAt: _readDate(json['read_at']),
      createdAt: _readDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'user_id': userId,
        'notif_type': notifType.value,
        if (projectId?.trim().isNotEmpty ?? false) 'project_id': projectId,
        if (sheetLocalId?.trim().isNotEmpty ?? false)
          'sheet_local_id': sheetLocalId,
        if (rowId?.trim().isNotEmpty ?? false) 'row_id': rowId,
        if (actorId?.trim().isNotEmpty ?? false) 'actor_id': actorId,
        'actor_label': actorLabel ?? '',
        'body': body,
      };
}

// ── PendingReviewItem ─────────────────────────────────────────────────────────

/// Vista desnormalizada para el panel de pendientes.
/// Se construye en el repositorio combinando RowReview + Project.
class PendingReviewItem {
  const PendingReviewItem({
    required this.review,
    required this.projectName,
    required this.projectCode,
    required this.projectId,
  });

  final RowReview review;
  final String projectName;
  final String? projectCode;
  final String projectId;

  String get displayStatus => switch (review.status) {
        'observada' => 'Observada',
        'corregida' => 'Corregida',
        'aprobada' => 'Aprobada',
        _ => 'Sin revisión',
      };
}

// ─────────────────────────────────────────────────────────────────────────────

String _readString(Object? value, {String fallback = ''}) {
  final raw = value?.toString().trim() ?? '';
  return raw.isEmpty ? fallback : raw;
}

String? _readNullableString(Object? value) {
  final raw = value?.toString().trim() ?? '';
  return raw.isEmpty ? null : raw;
}

DateTime? _readDate(Object? value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
