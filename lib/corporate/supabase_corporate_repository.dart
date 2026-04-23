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

  @override
  Future<RowReview?> getRowReview(
    String projectId,
    String sheetLocalId,
    String rowId,
  ) async {
    if (projectId.trim().isEmpty ||
        sheetLocalId.trim().isEmpty ||
        rowId.trim().isEmpty) {
      return null;
    }
    final row = _asNullableRow(
      await _client
          .from('sheet_row_reviews')
          .select(
            'project_id, sheet_local_id, row_id, status, created_by, updated_by, '
            'approved_by, approved_at, observed_at, corrected_at, created_at, '
            'updated_at',
          )
          .eq('project_id', projectId)
          .eq('sheet_local_id', sheetLocalId)
          .eq('row_id', rowId)
          .maybeSingle(),
    );
    return row == null ? null : RowReview.fromJson(row);
  }

  @override
  Future<List<RowReview>> listSheetRowReviews(
    String projectId,
    String sheetLocalId,
  ) async {
    if (projectId.trim().isEmpty || sheetLocalId.trim().isEmpty) {
      return const <RowReview>[];
    }
    final rows = _asRows(
      await _client
          .from('sheet_row_reviews')
          .select(
            'project_id, sheet_local_id, row_id, status, created_by, updated_by, '
            'approved_by, approved_at, observed_at, corrected_at, created_at, '
            'updated_at',
          )
          .eq('project_id', projectId)
          .eq('sheet_local_id', sheetLocalId)
          .order('updated_at', ascending: false),
    );
    return rows.map(RowReview.fromJson).toList(growable: false);
  }

  @override
  Future<void> upsertRowReview(RowReview review) async {
    if (review.projectId.trim().isEmpty ||
        review.sheetLocalId.trim().isEmpty ||
        review.rowId.trim().isEmpty) {
      return;
    }
    await _client.from('sheet_row_reviews').upsert(
          review.toJson(),
          onConflict: 'project_id,sheet_local_id,row_id',
        );
  }

  @override
  Future<List<RowEvidenceLink>> listRowEvidenceLinks(
    String projectId,
    String sheetLocalId, {
    String? rowId,
  }) async {
    if (projectId.trim().isEmpty || sheetLocalId.trim().isEmpty) {
      return const <RowEvidenceLink>[];
    }
    var query = _client
        .from('sheet_row_evidence_links')
        .select(
          'project_id, sheet_local_id, row_id, evidence_ref, evidence_kind, '
          'evidence_label, evidence_mime, source_cell_key, created_by, created_at',
        )
        .eq('project_id', projectId)
        .eq('sheet_local_id', sheetLocalId);
    if (rowId != null && rowId.trim().isNotEmpty) {
      query = query.eq('row_id', rowId.trim());
    }
    final rows = _asRows(await query.order('created_at', ascending: false));
    return rows.map(RowEvidenceLink.fromJson).toList(growable: false);
  }

  @override
  Future<void> linkRowEvidence(RowEvidenceLink link) async {
    if (link.projectId.trim().isEmpty ||
        link.sheetLocalId.trim().isEmpty ||
        link.rowId.trim().isEmpty ||
        link.evidenceRef.trim().isEmpty) {
      return;
    }
    await _client.from('sheet_row_evidence_links').upsert(
          link.toJson(),
          onConflict: 'project_id,sheet_local_id,row_id,evidence_ref',
        );
  }

  // ── Comentarios por fila ─────────────────────────────────────────────────

  @override
  Future<List<RowComment>> listRowComments(
    String projectId,
    String sheetLocalId,
    String rowId,
  ) async {
    if (projectId.trim().isEmpty ||
        sheetLocalId.trim().isEmpty ||
        rowId.trim().isEmpty) {
      return const <RowComment>[];
    }
    final rows = _asRows(
      await _client
          .from('row_comments')
          .select(
            'id, project_id, sheet_local_id, row_id, parent_id, '
            'author_id, author_label, comment_type, body, created_at, updated_at',
          )
          .eq('project_id', projectId)
          .eq('sheet_local_id', sheetLocalId)
          .eq('row_id', rowId)
          .order('created_at', ascending: true),
    );
    return rows.map(RowComment.fromJson).toList(growable: false);
  }

  @override
  Future<void> addRowComment(RowComment comment) async {
    if (comment.projectId.trim().isEmpty ||
        comment.sheetLocalId.trim().isEmpty ||
        comment.rowId.trim().isEmpty ||
        comment.body.trim().isEmpty) {
      return;
    }
    await _client.from('row_comments').insert(comment.toJson());
  }

  // ── Notificaciones ───────────────────────────────────────────────────────

  @override
  Future<List<UserNotification>> listNotifications({int limit = 60}) async {
    final userId = _userId;
    if (userId == null || userId.trim().isEmpty) {
      return const <UserNotification>[];
    }
    final rows = _asRows(
      await _client
          .from('user_notifications')
          .select(
            'id, user_id, notif_type, project_id, sheet_local_id, row_id, '
            'actor_id, actor_label, body, read_at, created_at',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit),
    );
    return rows.map(UserNotification.fromJson).toList(growable: false);
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    if (notificationId.trim().isEmpty) return;
    await _client.from('user_notifications').update(<String, dynamic>{
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', notificationId).eq('user_id', _userId ?? '');
  }

  @override
  Future<void> createNotification(UserNotification notification) async {
    if (notification.userId.trim().isEmpty) return;
    try {
      await _client.from('user_notifications').insert(notification.toJson());
    } catch (_) {
      // Notificación es fire-and-forget; no propagar errores.
    }
  }

  // ── Panel de pendientes ──────────────────────────────────────────────────

  @override
  Future<List<PendingReviewItem>> listPendingReviews() async {
    final userId = _userId;
    if (userId == null || userId.trim().isEmpty) {
      return const <PendingReviewItem>[];
    }

    // 1. Proyectos del usuario.
    final memberRows = _asRows(
      await _client
          .from('workspace_memberships')
          .select('workspace_id, role')
          .eq('user_id', userId)
          .eq('status', 'active'),
    );
    if (memberRows.isEmpty) return const <PendingReviewItem>[];

    final workspaceIds =
        memberRows.map((r) => r['workspace_id']?.toString() ?? '').toList();

    final projectRows = _asRows(
      await _client
          .from('projects')
          .select('id, name, code, workspace_id, status')
          .inFilter('workspace_id', workspaceIds)
          .neq('status', 'closed'),
    );
    if (projectRows.isEmpty) return const <PendingReviewItem>[];

    final projectById = <String, Map<String, dynamic>>{
      for (final p in projectRows) _str(p['id']): p,
    };
    final projectIds = projectById.keys.toList(growable: false);

    // 2. Revisiones pendientes (excluye aprobadas y sin_revision).
    final reviewRows = _asRows(
      await _client
          .from('sheet_row_reviews')
          .select(
            'project_id, sheet_local_id, row_id, status, '
            'created_by, updated_by, approved_by, '
            'approved_at, observed_at, corrected_at, created_at, updated_at',
          )
          .inFilter('project_id', projectIds)
          .inFilter('status', const <String>['observada', 'corregida'])
          .order('updated_at', ascending: false)
          .limit(200),
    );

    final result = <PendingReviewItem>[];
    for (final row in reviewRows) {
      final pId = _str(row['project_id']);
      final proj = projectById[pId];
      if (proj == null) continue;
      result.add(PendingReviewItem(
        review: RowReview.fromJson(row),
        projectName: _str(proj['name'], fallback: 'Proyecto'),
        projectCode: _strOrNull(proj['code']),
        projectId: pId,
      ));
    }
    return result;
  }

  static String _str(Object? v, {String fallback = ''}) {
    final raw = v?.toString().trim() ?? '';
    return raw.isEmpty ? fallback : raw;
  }

  static String? _strOrNull(Object? v) {
    final raw = v?.toString().trim() ?? '';
    return raw.isEmpty ? null : raw;
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
