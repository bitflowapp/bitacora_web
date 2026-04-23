import 'corporate_models.dart';

abstract class CorporateRepository {
  Future<List<Workspace>> listWorkspaces();
  Future<Workspace?> getWorkspace(String workspaceId);
  Future<List<Project>> listProjects(String workspaceId);
  Future<ProjectDetail?> getProjectDetail(String projectId);
  Future<List<String>> listProjectSheetIds(String projectId);
  Future<void> linkSheetToProject(String projectId, String sheetLocalId);
  Future<void> unlinkSheetFromProject(String projectId, String sheetLocalId);

  bool get usesRemoteBackend;
  String get backendLabel;
}
