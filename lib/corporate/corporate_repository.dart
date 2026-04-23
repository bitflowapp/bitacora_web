import 'corporate_models.dart';

abstract class CorporateRepository {
  Future<List<Workspace>> listWorkspaces();
  Future<Workspace?> getWorkspace(String workspaceId);
  Future<List<Project>> listProjects(String workspaceId);
  Future<ProjectDetail?> getProjectDetail(String projectId);
  Future<List<String>> listProjectSheetIds(String projectId);
  Future<void> linkSheetToProject(String projectId, String sheetLocalId);
  Future<void> unlinkSheetFromProject(String projectId, String sheetLocalId);
  Future<RowReview?> getRowReview(
    String projectId,
    String sheetLocalId,
    String rowId,
  );
  Future<List<RowReview>> listSheetRowReviews(
    String projectId,
    String sheetLocalId,
  );
  Future<void> upsertRowReview(RowReview review);
  Future<List<RowEvidenceLink>> listRowEvidenceLinks(
    String projectId,
    String sheetLocalId, {
    String? rowId,
  });
  Future<void> linkRowEvidence(RowEvidenceLink link);

  // ── Comentarios por fila ─────────────────────────────────────────────────
  Future<List<RowComment>> listRowComments(
    String projectId,
    String sheetLocalId,
    String rowId,
  );
  Future<void> addRowComment(RowComment comment);

  // ── Notificaciones internas ──────────────────────────────────────────────
  Future<List<UserNotification>> listNotifications({int limit = 60});
  Future<void> markNotificationRead(String notificationId);
  Future<void> createNotification(UserNotification notification);

  // ── Panel de pendientes ──────────────────────────────────────────────────
  /// Retorna revisiones pendientes de acción para el usuario activo,
  /// enriquecidas con nombre de proyecto.
  Future<List<PendingReviewItem>> listPendingReviews();

  bool get usesRemoteBackend;
  String get backendLabel;
}
