import 'corporate_models.dart';

abstract class CorporateRepository {
  Future<List<Workspace>> listWorkspaces();
  Future<Workspace?> getWorkspace(String workspaceId);
  Future<List<Project>> listProjects(String workspaceId);
  Future<ProjectDetail?> getProjectDetail(String projectId);

  bool get usesRemoteBackend;
  String get backendLabel;
}
