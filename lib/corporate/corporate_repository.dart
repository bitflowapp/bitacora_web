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

  bool get usesRemoteBackend;
  String get backendLabel;
}
