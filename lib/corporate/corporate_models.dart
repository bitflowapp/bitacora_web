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
