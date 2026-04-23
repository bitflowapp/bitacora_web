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
    if (workspaceId.trim().isEmpty) return null;
    final workspaceRow = _asNullableRow(
      await _client
          .from('workspaces')
          .select('id, name, legal_name, created_at, updated_at')
          .eq('id', workspaceId)
          .maybeSingle(),
    );
    if (workspaceRow == null) return null;

    CorporateRole role = CorporateRole.tecnico;
    final userId = _userId;
    if (userId != null && userId.trim().isNotEmpty) {
      final membershipRow = _asNullableRow(
        await _client
            .from('workspace_memberships')
            .select('role')
            .eq('workspace_id', workspaceId)
            .eq('user_id', userId)
            .maybeSingle(),
      );
      role = CorporateRole.fromValue(membershipRow?['role']);
    }

    return Workspace.fromJson(workspaceRow, role: role);
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

  @override
  Future<List<String>> listProjectSheetIds(String projectId) async {
    if (projectId.trim().isEmpty) return const <String>[];
    final rows = _asRows(
      await _client
          .from('project_sheet_refs')
          .select('sheet_local_id')
          .eq('project_id', projectId)
          .order('created_at', ascending: false),
    );
    return rows
        .map((row) => row['sheet_local_id']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> linkSheetToProject(
    String projectId,
    String sheetLocalId,
  ) async {
    if (projectId.trim().isEmpty || sheetLocalId.trim().isEmpty) return;
    await _client.from('project_sheet_refs').insert(<String, dynamic>{
      'project_id': projectId,
      'sheet_local_id': sheetLocalId.trim(),
      'created_by': _userId,
    });
  }

  @override
  Future<void> unlinkSheetFromProject(
    String projectId,
    String sheetLocalId,
  ) async {
    if (projectId.trim().isEmpty || sheetLocalId.trim().isEmpty) return;
    await _client
        .from('project_sheet_refs')
        .delete()
        .eq('project_id', projectId)
        .eq('sheet_local_id', sheetLocalId.trim());
  }

  List<Map<String, dynamic>> _asRows(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
  }

  Map<String, dynamic>? _asNullableRow(Object? value) {
    if (value == null || value is! Map) return null;
    return value.map((key, value) => MapEntry('$key', value));
  }
}
