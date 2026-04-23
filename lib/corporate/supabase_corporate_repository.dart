import 'package:supabase_flutter/supabase_flutter.dart';

import 'corporate_models.dart';
import 'corporate_repository.dart';

class SupabaseCorporateRepository implements CorporateRepository {
  const SupabaseCorporateRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  bool get usesRemoteBackend => true;

  @override
  String get backendLabel => 'Supabase';

  @override
  Future<List<Workspace>> listWorkspaces() async {
    final userId = _userId;
    if (userId == null || userId.trim().isEmpty) return const <Workspace>[];

    final membershipRows = _asRows(
      await _client
          .from('workspace_memberships')
          .select('workspace_id, role, status')
          .eq('user_id', userId)
          .eq('status', 'active'),
    );
    if (membershipRows.isEmpty) return const <Workspace>[];

    final roleByWorkspace = <String, CorporateRole>{};
    for (final row in membershipRows) {
      final workspaceId = row['workspace_id']?.toString() ?? '';
      if (workspaceId.isEmpty) continue;
      roleByWorkspace[workspaceId] = CorporateRole.fromValue(row['role']);
    }

    final workspaceIds = roleByWorkspace.keys.toList(growable: false);
    final workspaceRows = _asRows(
      await _client
          .from('workspaces')
          .select('id, name, legal_name, created_at, updated_at')
          .inFilter('id', workspaceIds)
          .order('updated_at', ascending: false),
    );

    return workspaceRows
        .map(
          (row) => Workspace.fromJson(
            row,
            role:
                roleByWorkspace[row['id']?.toString()] ?? CorporateRole.tecnico,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<Workspace?> getWorkspace(String workspaceId) async {
    final workspaces = await listWorkspaces();
    for (final workspace in workspaces) {
      if (workspace.id == workspaceId) return workspace;
    }
    return null;
  }

  @override
  Future<List<Project>> listProjects(String workspaceId) async {
    if (workspaceId.trim().isEmpty) return const <Project>[];
    final rows = _asRows(
      await _client
          .from('projects')
          .select(
            'id, workspace_id, name, code, description, field_scope, '
            'status, starts_on, ends_on, created_at, updated_at',
          )
          .eq('workspace_id', workspaceId)
          .order('updated_at', ascending: false),
    );
    return rows.map(Project.fromJson).toList(growable: false);
  }

  @override
  Future<ProjectDetail?> getProjectDetail(String projectId) async {
    if (projectId.trim().isEmpty) return null;
    final projectRows = _asRows(
      await _client
          .from('projects')
          .select(
            'id, workspace_id, name, code, description, field_scope, '
            'status, starts_on, ends_on, created_at, updated_at',
          )
          .eq('id', projectId)
          .limit(1),
    );
    if (projectRows.isEmpty) return null;

    final memberRows = _asRows(
      await _client
          .from('project_members')
          .select('id, project_id, user_id, role')
          .eq('project_id', projectId),
    );

    return ProjectDetail(
      project: Project.fromJson(projectRows.first),
      members: memberRows.map(ProjectMember.fromJson).toList(growable: false),
    );
  }

  List<Map<String, dynamic>> _asRows(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
  }
}
