import 'corporate_models.dart';
import 'corporate_repository.dart';

class LocalCorporateRepository implements CorporateRepository {
  const LocalCorporateRepository();

  static const String _workspaceId = 'local_workspace_operaciones';

  static const Workspace _workspace = Workspace(
    id: _workspaceId,
    name: 'Operaciones Tecnicas',
    legalName: 'Workspace local',
    role: CorporateRole.admin,
  );

  static const List<Project> _projects = <Project>[
    Project(
      id: 'local_project_pc_gasoducto',
      workspaceId: _workspaceId,
      code: 'PC-001',
      name: 'Proteccion catodica - Gasoducto Norte',
      status: 'active',
      fieldScope: 'Proteccion catodica',
      description:
          'Relevamiento ON/OFF, IR drop, cupones y evidencia fotografica.',
    ),
    Project(
      id: 'local_project_pat',
      workspaceId: _workspaceId,
      code: 'PAT-002',
      name: 'Puesta a tierra - Subestacion',
      status: 'active',
      fieldScope: 'Puesta a tierra',
      description:
          'Mediciones de continuidad, resistencia y evidencia por punto.',
    ),
    Project(
      id: 'local_project_inspeccion',
      workspaceId: _workspaceId,
      code: 'INSP-003',
      name: 'Inspeccion tecnica - Tramo Oeste',
      status: 'planning',
      fieldScope: 'Inspeccion con evidencia',
      description:
          'Checklist tecnico, fotos, ubicacion y observaciones exportables.',
    ),
  ];

  static const List<ProjectMember> _members = <ProjectMember>[
    ProjectMember(
      id: 'local_member_admin',
      projectId: 'local_project_pc_gasoducto',
      userId: 'local',
      role: CorporateRole.admin,
    ),
    ProjectMember(
      id: 'local_member_supervisor',
      projectId: 'local_project_pc_gasoducto',
      userId: 'supervisor-local',
      role: CorporateRole.supervisor,
    ),
    ProjectMember(
      id: 'local_member_tecnico',
      projectId: 'local_project_pc_gasoducto',
      userId: 'tecnico-local',
      role: CorporateRole.tecnico,
    ),
  ];

  @override
  bool get usesRemoteBackend => false;

  @override
  String get backendLabel => 'Modo local';

  @override
  Future<List<Workspace>> listWorkspaces() async {
    return const <Workspace>[_workspace];
  }

  @override
  Future<Workspace?> getWorkspace(String workspaceId) async {
    if (workspaceId == _workspace.id) return _workspace;
    return null;
  }

  @override
  Future<List<Project>> listProjects(String workspaceId) async {
    if (workspaceId != _workspace.id) return const <Project>[];
    return _projects;
  }

  @override
  Future<ProjectDetail?> getProjectDetail(String projectId) async {
    final matches = _projects.where((project) => project.id == projectId);
    if (matches.isEmpty) return null;
    return ProjectDetail(
      project: matches.first,
      members: _members
          .where((member) => member.projectId == projectId)
          .toList(growable: false),
    );
  }

  @override
  Future<List<String>> listProjectSheetIds(String projectId) async {
    if (projectId == 'local_project_pc_gasoducto') {
      return const <String>['local_sheet_default'];
    }
    return const <String>[];
  }

  @override
  Future<void> linkSheetToProject(String projectId, String sheetLocalId) async {
    return;
  }

  @override
  Future<void> unlinkSheetFromProject(
    String projectId,
    String sheetLocalId,
  ) async {
    return;
  }
}
