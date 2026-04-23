import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../corporate/corporate_models.dart';
import '../../corporate/corporate_repository.dart';
import '../../corporate/corporate_repository_factory.dart';
import '../../services/auth_service.dart';
import '../../services/sheet_store.dart';
import '../../services/supabase_service.dart';
import '../../ui/ui.dart';

class WorkspaceListScreen extends StatefulWidget {
  const WorkspaceListScreen({
    super.key,
    required this.isLight,
    required this.onToggleTheme,
  });

  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<WorkspaceListScreen> createState() => _WorkspaceListScreenState();
}

class _WorkspaceListScreenState extends State<WorkspaceListScreen> {
  late CorporateRepository _repository;
  late Future<List<Workspace>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _repository = createCorporateRepository();
    _future = _repository.listWorkspaces();
  }

  Future<void> _signIn() async {
    final ok = await showCorporateSignInDialog(context);
    if (!mounted || !ok) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _CorporateShell(
      isLight: widget.isLight,
      onToggleTheme: widget.onToggleTheme,
      title: 'Empresa',
      subtitle: 'Workspaces, proyectos y acceso operativo de campo.',
      backendLabel: _repository.backendLabel,
      usesRemoteBackend: _repository.usesRemoteBackend,
      actions: [
        AppButton(
          label: 'Pendientes',
          icon: Icons.task_alt_rounded,
          variant: AppButtonVariant.secondary,
          onPressed: () => context.go('/pending'),
        ),
        _NotifBadge(onTap: () => context.go('/notifications')),
        AppButton(
          label: 'Planillas',
          icon: Icons.table_chart_rounded,
          variant: AppButtonVariant.ghost,
          onPressed: () => context.go('/sheets'),
        ),
        AppButton(
          label: 'Actualizar',
          icon: Icons.refresh_rounded,
          variant: AppButtonVariant.ghost,
          onPressed: () => setState(_reload),
        ),
      ],
      child: FutureBuilder<List<Workspace>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CorporateLoading();
          }
          if (snapshot.hasError) {
            return _CorporateError(
              message: 'No se pudieron cargar los workspaces.',
              detail: '${snapshot.error}',
              onRetry: () => setState(_reload),
            );
          }
          final workspaces = snapshot.data ?? const <Workspace>[];
          final remoteConfigured = AuthService.I.isRemoteBackendConfigured;
          final remoteSignedIn = AuthService.I.isRemoteAuthenticated;
          if (workspaces.isEmpty) {
            return _CorporateEmpty(
              icon: Icons.business_rounded,
              title: remoteConfigured && !remoteSignedIn
                  ? 'Inicia sesion para ver tus workspaces'
                  : 'No hay workspaces disponibles',
              message: remoteConfigured && !remoteSignedIn
                  ? 'Supabase esta configurado, pero todavia no hay una sesion corporativa activa.'
                  : 'Cuando conectes Supabase o crees membresias, la empresa aparecera aca.',
              action: remoteConfigured && !remoteSignedIn
                  ? AppButton(
                      label: 'Iniciar sesion',
                      icon: Icons.login_rounded,
                      onPressed: _signIn,
                    )
                  : null,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RemoteStatusBanner(
                repository: _repository,
                onSignIn: remoteConfigured && !remoteSignedIn ? _signIn : null,
              ),
              SizedBox(height: t.spacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 920 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: t.spacing.lg,
                      crossAxisSpacing: t.spacing.lg,
                      childAspectRatio: columns == 1 ? 2.85 : 2.6,
                    ),
                    itemCount: workspaces.length,
                    itemBuilder: (context, index) {
                      final workspace = workspaces[index];
                      return _WorkspaceCard(workspace: workspace);
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({
    super.key,
    required this.workspaceId,
    required this.isLight,
    required this.onToggleTheme,
  });

  final String workspaceId;
  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  late CorporateRepository _repository;
  late Future<_ProjectListData> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(ProjectListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId) {
      _reload();
    }
  }

  void _reload() {
    _repository = createCorporateRepository();
    _future = _load();
  }

  Future<_ProjectListData> _load() async {
    final workspace = await _repository.getWorkspace(widget.workspaceId);
    final projects = await _repository.listProjects(widget.workspaceId);
    return _ProjectListData(workspace: workspace, projects: projects);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _CorporateShell(
      isLight: widget.isLight,
      onToggleTheme: widget.onToggleTheme,
      title: 'Proyectos',
      subtitle: 'Relevamientos tecnicos agrupados por empresa y alcance.',
      backendLabel: _repository.backendLabel,
      usesRemoteBackend: _repository.usesRemoteBackend,
      actions: [
        AppButton(
          label: 'Empresa',
          icon: Icons.business_rounded,
          variant: AppButtonVariant.secondary,
          onPressed: () => context.go('/app'),
        ),
        AppButton(
          label: 'Planillas',
          icon: Icons.table_chart_rounded,
          variant: AppButtonVariant.ghost,
          onPressed: () => context.go('/sheets'),
        ),
      ],
      child: FutureBuilder<_ProjectListData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CorporateLoading();
          }
          if (snapshot.hasError) {
            return _CorporateError(
              message: 'No se pudieron cargar los proyectos.',
              detail: '${snapshot.error}',
              onRetry: () => setState(_reload),
            );
          }
          final data = snapshot.data;
          if (data == null || data.workspace == null) {
            return _CorporateEmpty(
              icon: Icons.business_rounded,
              title: 'Workspace no disponible',
              message: 'La sesion actual no tiene acceso a este workspace.',
              action: AppButton(
                label: 'Volver a empresa',
                icon: Icons.arrow_back_rounded,
                onPressed: () => context.go('/app'),
              ),
            );
          }
          if (data.projects.isEmpty) {
            return _CorporateEmpty(
              icon: Icons.folder_open_rounded,
              title: 'No hay proyectos activos',
              message:
                  'La base corporativa ya esta lista para mostrar proyectos cuando existan en Supabase.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WorkspaceSummary(workspace: data.workspace!),
              SizedBox(height: t.spacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 980 ? 3 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: t.spacing.lg,
                      crossAxisSpacing: t.spacing.lg,
                      childAspectRatio: columns == 1 ? 2.45 : 1.25,
                    ),
                    itemCount: data.projects.length,
                    itemBuilder: (context, index) {
                      return _ProjectCard(project: data.projects[index]);
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.isLight,
    required this.onToggleTheme,
  });

  final String projectId;
  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late CorporateRepository _repository;
  late Future<ProjectDetail?> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(ProjectDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _reload();
    }
  }

  void _reload() {
    _repository = createCorporateRepository();
    _future = _repository.getProjectDetail(widget.projectId);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _CorporateShell(
      isLight: widget.isLight,
      onToggleTheme: widget.onToggleTheme,
      title: 'Detalle de proyecto',
      subtitle: 'Base minima: alcance, estado y miembros asignados.',
      backendLabel: _repository.backendLabel,
      usesRemoteBackend: _repository.usesRemoteBackend,
      actions: [
        AppButton(
          label: 'Empresa',
          icon: Icons.business_rounded,
          variant: AppButtonVariant.secondary,
          onPressed: () => context.go('/app'),
        ),
        AppButton(
          label: 'Planillas',
          icon: Icons.table_chart_rounded,
          variant: AppButtonVariant.ghost,
          onPressed: () => context.go('/sheets'),
        ),
      ],
      child: FutureBuilder<ProjectDetail?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CorporateLoading();
          }
          if (snapshot.hasError) {
            return _CorporateError(
              message: 'No se pudo cargar el proyecto.',
              detail: '${snapshot.error}',
              onRetry: () => setState(_reload),
            );
          }
          final detail = snapshot.data;
          if (detail == null) {
            return _CorporateEmpty(
              icon: Icons.folder_off_rounded,
              title: 'Proyecto no disponible',
              message: 'La sesion actual no tiene acceso a este proyecto.',
              action: AppButton(
                label: 'Volver a empresa',
                icon: Icons.arrow_back_rounded,
                onPressed: () => context.go('/app'),
              ),
            );
          }

          final project = detail.project;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                padding: EdgeInsets.all(t.spacing.xl),
                radius: t.radii.xl,
                color: t.colors.surface,
                borderColor: t.colors.borderStrong,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: t.spacing.sm,
                      runSpacing: t.spacing.sm,
                      children: [
                        _StatusChip(label: project.status),
                        if ((project.fieldScope ?? '').isNotEmpty)
                          _StatusChip(label: project.fieldScope!),
                        if ((project.code ?? '').isNotEmpty)
                          _StatusChip(label: project.code!),
                      ],
                    ),
                    SizedBox(height: t.spacing.lg),
                    Text(
                      project.name,
                      style: t.text.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    if ((project.description ?? '').isNotEmpty) ...[
                      SizedBox(height: t.spacing.sm),
                      Text(
                        project.description!,
                        style: t.text.bodyLarge?.copyWith(
                          color: t.colors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                    SizedBox(height: t.spacing.xl),
                    Wrap(
                      spacing: t.spacing.sm,
                      runSpacing: t.spacing.sm,
                      children: [
                        AppButton(
                          label: 'Abrir planillas tecnicas',
                          icon: Icons.table_chart_rounded,
                          onPressed: () =>
                              context.go('/projects/${project.id}/sheets'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: t.spacing.lg),
              _MembersPanel(members: detail.members),
            ],
          );
        },
      ),
    );
  }
}

class ProjectSheetsScreen extends StatefulWidget {
  const ProjectSheetsScreen({
    super.key,
    required this.projectId,
    required this.isLight,
    required this.onToggleTheme,
  });

  final String projectId;
  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<ProjectSheetsScreen> createState() => _ProjectSheetsScreenState();
}

class _ProjectSheetsScreenState extends State<ProjectSheetsScreen> {
  late CorporateRepository _repository;
  late Future<_ProjectSheetsData> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(ProjectSheetsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _reload();
    }
  }

  void _reload() {
    _repository = createCorporateRepository();
    _future = _load();
  }

  Future<_ProjectSheetsData> _load() async {
    final results = await Future.wait<Object?>([
      _repository.getProjectDetail(widget.projectId),
      _repository.listProjectSheetIds(widget.projectId),
    ]);
    return _ProjectSheetsData(
      detail: results[0] as ProjectDetail?,
      sheetIds: (results[1] as List<String>? ?? const <String>[]),
    );
  }

  bool _canManage(ProjectDetail detail) {
    final userId = AuthService.I.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) return false;
    return detail.members.any((member) {
      if (member.userId != userId) return false;
      return member.role == CorporateRole.coordinador ||
          member.role == CorporateRole.admin;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _sheetRoute(String sheetId) {
    return Uri(
      path: '/sheets',
      queryParameters: <String, String>{
        'sheetId': sheetId,
        'projectId': widget.projectId,
      },
    ).toString();
  }

  Future<void> _createAndLink(ProjectDetail detail) async {
    if (_busy) return;
    if (!_canManage(detail)) {
      _showMessage('Solo coordinadores o admins pueden vincular planillas.');
      return;
    }
    setState(() => _busy = true);
    try {
      final sheetId = SheetStore.createNew();
      await _repository.linkSheetToProject(detail.project.id, sheetId);
      if (!mounted) return;
      context.go(_sheetRoute(sheetId));
    } catch (e) {
      _showMessage('No se pudo crear y vincular la planilla: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _linkExisting(
    ProjectDetail detail,
    List<String> linkedSheetIds,
  ) async {
    if (_busy) return;
    if (!_canManage(detail)) {
      _showMessage('Solo coordinadores o admins pueden vincular planillas.');
      return;
    }

    final linked = linkedSheetIds.toSet();
    final sheets = SheetStore.list()
        .where((sheet) => !linked.contains(sheet.id))
        .toList(growable: false);
    if (sheets.isEmpty) {
      _showMessage('No hay planillas locales disponibles para vincular.');
      return;
    }

    final selected = await showDialog<SheetMeta>(
      context: context,
      builder: (context) => _ExistingSheetDialog(sheets: sheets),
    );
    if (selected == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await _repository.linkSheetToProject(detail.project.id, selected.id);
      if (!mounted) return;
      setState(_reload);
      _showMessage('Planilla vinculada al proyecto.');
    } catch (e) {
      _showMessage('No se pudo vincular la planilla: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlink(
    ProjectDetail detail,
    String sheetId,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repository.unlinkSheetFromProject(detail.project.id, sheetId);
      if (!mounted) return;
      setState(_reload);
      _showMessage('Planilla desvinculada.');
    } catch (e) {
      _showMessage('No se pudo desvincular la planilla: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProjectSheetsData>(
      future: _future,
      builder: (context, snapshot) {
        final detail = snapshot.data?.detail;
        final canManage = detail != null && _canManage(detail);
        return _CorporateShell(
          isLight: widget.isLight,
          onToggleTheme: widget.onToggleTheme,
          title: 'Planillas del proyecto',
          subtitle: detail?.project.name ??
              'Planillas locales vinculadas a un proyecto corporativo.',
          backendLabel: _repository.backendLabel,
          usesRemoteBackend: _repository.usesRemoteBackend,
          actions: [
            AppButton(
              label: 'Proyecto',
              icon: Icons.folder_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => context.go('/projects/${widget.projectId}'),
            ),
            AppButton(
              label: 'Nueva planilla',
              icon: Icons.add_rounded,
              loading: _busy,
              onPressed: detail == null
                  ? null
                  : () => unawaited(_createAndLink(detail)),
            ),
          ],
          child: _buildBody(context, snapshot, canManage),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<_ProjectSheetsData> snapshot,
    bool canManage,
  ) {
    final t = context.tokens;
    if (snapshot.connectionState != ConnectionState.done) {
      return const _CorporateLoading();
    }
    if (snapshot.hasError) {
      return _CorporateError(
        message: 'No se pudieron cargar las planillas del proyecto.',
        detail: '${snapshot.error}',
        onRetry: () => setState(_reload),
      );
    }

    final data = snapshot.data;
    final detail = data?.detail;
    if (data == null || detail == null) {
      return _CorporateEmpty(
        icon: Icons.folder_off_rounded,
        title: 'Proyecto no disponible',
        message: 'La sesion actual no tiene acceso a este proyecto.',
        action: AppButton(
          label: 'Volver a empresa',
          icon: Icons.arrow_back_rounded,
          onPressed: () => context.go('/app'),
        ),
      );
    }

    final project = detail.project;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: EdgeInsets.all(t.spacing.xl),
          radius: t.radii.xl,
          color: t.colors.surface,
          borderColor: t.colors.borderStrong,
          child: Row(
            children: [
              _IconTile(icon: Icons.folder_rounded),
              SizedBox(width: t.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: t.spacing.sm,
                      runSpacing: t.spacing.xs,
                      children: [
                        _StatusChip(label: project.status),
                        if ((project.code ?? '').isNotEmpty)
                          _StatusChip(label: project.code!),
                      ],
                    ),
                    SizedBox(height: t.spacing.sm),
                    Text(
                      project.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: t.spacing.lg),
        if (data.sheetIds.isEmpty)
          _CorporateEmpty(
            icon: Icons.table_chart_rounded,
            title: 'No hay planillas vinculadas a este proyecto.',
            message:
                'Crea una planilla nueva o vincula una existente para trabajar con contexto de proyecto.',
            action: AppButton(
              label: 'Vincular planilla existente',
              icon: Icons.link_rounded,
              variant: AppButtonVariant.secondary,
              loading: _busy,
              onPressed: () => unawaited(_linkExisting(detail, data.sheetIds)),
            ),
          )
        else
          Column(
            children: [
              for (final sheetId in data.sheetIds) ...[
                _ProjectSheetCard(
                  sheetId: sheetId,
                  canManage: canManage,
                  onOpen: () => context.go(_sheetRoute(sheetId)),
                  onUnlink: () => unawaited(_unlink(detail, sheetId)),
                ),
                SizedBox(height: t.spacing.md),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  label: 'Vincular planilla existente',
                  icon: Icons.link_rounded,
                  variant: AppButtonVariant.secondary,
                  loading: _busy,
                  onPressed: () =>
                      unawaited(_linkExisting(detail, data.sheetIds)),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ProjectSheetCard extends StatelessWidget {
  const _ProjectSheetCard({
    required this.sheetId,
    required this.canManage,
    required this.onOpen,
    required this.onUnlink,
  });

  final String sheetId;
  final bool canManage;
  final VoidCallback onOpen;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      color: t.colors.surface,
      borderColor: t.colors.borderStrong.withValues(
        alpha: t.colors.isLight ? 0.50 : 0.70,
      ),
      radius: t.radii.xl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final title = Row(
            children: [
              _IconTile(icon: Icons.table_chart_rounded),
              SizedBox(width: t.spacing.md),
              Expanded(
                child: Text(
                  sheetId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: t.spacing.sm,
            runSpacing: t.spacing.sm,
            children: [
              AppButton(
                label: 'Abrir',
                icon: Icons.open_in_new_rounded,
                size: AppButtonSize.sm,
                onPressed: onOpen,
              ),
              if (canManage)
                AppButton(
                  label: 'Desvincular',
                  icon: Icons.link_off_rounded,
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.ghost,
                  onPressed: onUnlink,
                ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                SizedBox(height: t.spacing.md),
                actions,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              SizedBox(width: t.spacing.md),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ExistingSheetDialog extends StatelessWidget {
  const _ExistingSheetDialog({required this.sheets});

  final List<SheetMeta> sheets;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AlertDialog(
      backgroundColor: t.colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radii.xl),
      ),
      title: const Text('Vincular planilla existente'),
      content: SizedBox(
        width: 460,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: ListView.separated(
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final sheet = sheets[index];
              final title = sheet.title.trim().isEmpty ? sheet.id : sheet.title;
              return ListTile(
                leading: const Icon(Icons.table_chart_rounded),
                title: Text(title),
                subtitle: Text(sheet.id),
                onTap: () => Navigator.of(context).pop(sheet),
              );
            },
            separatorBuilder: (_, __) => Divider(color: t.colors.border),
            itemCount: sheets.length,
          ),
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancelar',
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

Future<bool> showCorporateSignInDialog(BuildContext context) async {
  if (!SupabaseService.I.isConfigured) return false;
  final email = TextEditingController();
  final password = TextEditingController();
  var loading = false;
  var error = '';

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: !loading,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final t = context.tokens;
          Future<void> submit() async {
            setDialogState(() {
              loading = true;
              error = '';
            });
            try {
              await AuthService.I.signInWithPassword(
                email: email.text,
                password: password.text,
              );
              if (context.mounted) Navigator.of(context).pop(true);
            } catch (e) {
              setDialogState(() {
                loading = false;
                error = '$e';
              });
            }
          }

          return AlertDialog(
            backgroundColor: t.colors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radii.xl),
            ),
            title: const Text('Iniciar sesion corporativa'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Usa un usuario existente de Supabase Auth para cargar workspaces y proyectos reales.',
                    style: t.text.bodyMedium?.copyWith(
                      color: t.colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: t.spacing.lg),
                  AppTextField(
                    controller: email,
                    label: 'Email',
                    hint: 'tecnico@empresa.com',
                    keyboardType: TextInputType.emailAddress,
                    enabled: !loading,
                  ),
                  SizedBox(height: t.spacing.sm),
                  AppTextField(
                    controller: password,
                    label: 'Password',
                    obscureText: true,
                    enabled: !loading,
                    onSubmitted: (_) => unawaited(submit()),
                  ),
                  if (error.isNotEmpty) ...[
                    SizedBox(height: t.spacing.sm),
                    Text(
                      error,
                      style: t.text.bodySmall?.copyWith(
                        color: t.colors.dangerFg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              AppButton(
                label: 'Cancelar',
                variant: AppButtonVariant.ghost,
                onPressed: loading ? null : () => Navigator.of(context).pop(),
              ),
              AppButton(
                label: 'Entrar',
                icon: Icons.login_rounded,
                loading: loading,
                onPressed: loading ? null : () => unawaited(submit()),
              ),
            ],
          );
        },
      );
    },
  );

  email.dispose();
  password.dispose();
  return result ?? false;
}

class _CorporateShell extends StatelessWidget {
  const _CorporateShell({
    required this.isLight,
    required this.onToggleTheme,
    required this.title,
    required this.subtitle,
    required this.backendLabel,
    required this.usesRemoteBackend,
    required this.child,
    this.actions = const <Widget>[],
  });

  final bool isLight;
  final VoidCallback onToggleTheme;
  final String title;
  final String subtitle;
  final String backendLabel;
  final bool usesRemoteBackend;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: _horizontalPadding(context),
            vertical: t.spacing.lg,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    padding: EdgeInsets.all(t.spacing.lg),
                    radius: t.radii.xl,
                    color: t.colors.surface,
                    borderColor: t.colors.borderStrong,
                    shadows: t.shadows.card,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 760;
                        final header = Row(
                          children: [
                            _IconTile(
                              icon: Icons.business_center_rounded,
                              size: 48,
                              iconSize: 22,
                              filled: true,
                            ),
                            SizedBox(width: t.spacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: t.text.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  Text(
                                    subtitle,
                                    style: t.text.bodyMedium?.copyWith(
                                      color: t.colors.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                        final controls = Wrap(
                          spacing: t.spacing.sm,
                          runSpacing: t.spacing.sm,
                          alignment: WrapAlignment.end,
                          children: [
                            _BackendBadge(
                              label: backendLabel,
                              remote: usesRemoteBackend,
                            ),
                            AppButton(
                              label: isLight ? 'Dia' : 'Noche',
                              icon: isLight
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                              variant: AppButtonVariant.ghost,
                              onPressed: onToggleTheme,
                            ),
                            ...actions,
                          ],
                        );

                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              header,
                              SizedBox(height: t.spacing.md),
                              controls,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: header),
                            SizedBox(width: t.spacing.lg),
                            controls,
                          ],
                        );
                      },
                    ),
                  ),
                  SizedBox(height: t.spacing.xl),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 980) return 42;
    if (width >= 620) return 28;
    return 18;
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      onTap: () => context.go('/workspaces/${workspace.id}/projects'),
      color: t.colors.surface,
      borderColor: t.colors.borderStrong.withValues(
        alpha: t.colors.isLight ? 0.52 : 0.72,
      ),
      radius: t.radii.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconTile(icon: Icons.apartment_rounded),
              const Spacer(),
              _RoleChip(role: workspace.role),
            ],
          ),
          const Spacer(),
          Text(
            workspace.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: t.spacing.xs),
          Text(
            workspace.legalName ?? 'Workspace corporativo',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.text.bodyMedium?.copyWith(color: t.colors.textSecondary),
          ),
          SizedBox(height: t.spacing.md),
          const _ActionHint(label: 'Ver proyectos'),
        ],
      ),
    );
  }
}

class _WorkspaceSummary extends StatelessWidget {
  const _WorkspaceSummary({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      color: t.colors.surface,
      borderColor: t.colors.borderStrong,
      radius: t.radii.xl,
      child: Row(
        children: [
          _IconTile(icon: Icons.apartment_rounded),
          SizedBox(width: t.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workspace.name,
                  style: t.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  workspace.legalName ?? 'Workspace corporativo',
                  style: t.text.bodyMedium?.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _RoleChip(role: workspace.role),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      onTap: () => context.go('/projects/${project.id}'),
      radius: t.radii.xl,
      color: t.colors.surface,
      borderColor: t.colors.borderStrong.withValues(
        alpha: t.colors.isLight ? 0.52 : 0.72,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconTile(icon: _projectIcon(project.fieldScope)),
              const Spacer(),
              _StatusChip(label: project.status),
            ],
          ),
          const Spacer(),
          if ((project.code ?? '').isNotEmpty)
            Text(
              project.code!,
              style: t.text.bodySmall?.copyWith(
                color: t.colors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          Text(
            project.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.12,
            ),
          ),
          SizedBox(height: t.spacing.sm),
          Text(
            project.description ?? project.fieldScope ?? 'Proyecto tecnico',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.text.bodySmall?.copyWith(
              color: t.colors.textSecondary,
              height: 1.35,
            ),
          ),
          SizedBox(height: t.spacing.md),
          const _ActionHint(label: 'Entrar al proyecto'),
        ],
      ),
    );
  }

  IconData _projectIcon(String? scope) {
    final raw = (scope ?? '').toLowerCase();
    if (raw.contains('catod')) return Icons.bolt_rounded;
    if (raw.contains('tierra')) return Icons.settings_input_antenna_rounded;
    if (raw.contains('inspe')) return Icons.fact_check_rounded;
    return Icons.folder_rounded;
  }
}

class _MembersPanel extends StatelessWidget {
  const _MembersPanel({required this.members});

  final List<ProjectMember> members;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      color: t.colors.surfaceElevated,
      radius: t.radii.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Miembros del proyecto',
            style: t.text.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: t.spacing.sm),
          if (members.isEmpty)
            Text(
              'Todavia no hay miembros asignados.',
              style: t.text.bodyMedium?.copyWith(
                color: t.colors.textSecondary,
              ),
            )
          else
            Wrap(
              spacing: t.spacing.sm,
              runSpacing: t.spacing.sm,
              children: [
                for (final member in members)
                  _MemberChip(
                    userId: member.userId,
                    role: member.role,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RemoteStatusBanner extends StatelessWidget {
  const _RemoteStatusBanner({
    required this.repository,
    this.onSignIn,
  });

  final CorporateRepository repository;
  final Future<void> Function()? onSignIn;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final signedIn = AuthService.I.isRemoteAuthenticated;
    final text = repository.usesRemoteBackend
        ? (signedIn
            ? 'Backend corporativo conectado con Supabase Auth.'
            : 'Supabase configurado. Inicia sesion para aplicar RLS y ver datos reales.')
        : 'Modo local operativo. Configura Supabase para usar workspaces reales.';
    return AppCard(
      color: t.colors.surface,
      borderColor: repository.usesRemoteBackend
          ? (signedIn
              ? t.colors.successFg.withValues(alpha: 0.20)
              : t.colors.accent.withValues(alpha: 0.18))
          : t.colors.borderStrong.withValues(
              alpha: t.colors.isLight ? 0.40 : 0.60,
            ),
      radius: t.radii.lg,
      shadows: const <BoxShadow>[],
      child: Row(
        children: [
          _IconTile(
            icon: repository.usesRemoteBackend
                ? Icons.cloud_done_rounded
                : Icons.computer_rounded,
            backgroundColor: repository.usesRemoteBackend
                ? (signedIn ? t.colors.successBg : t.colors.accentMuted)
                : t.colors.surfaceMuted,
            foregroundColor: repository.usesRemoteBackend
                ? (signedIn ? t.colors.successFg : t.colors.accent)
                : t.colors.textSecondary,
            borderColor: repository.usesRemoteBackend
                ? (signedIn
                    ? t.colors.successFg.withValues(alpha: 0.18)
                    : t.colors.accent.withValues(alpha: 0.16))
                : t.colors.border,
          ),
          SizedBox(width: t.spacing.md),
          Expanded(
            child: Text(
              text,
              style: t.text.bodyMedium?.copyWith(
                color: t.colors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
          if (onSignIn != null) ...[
            SizedBox(width: t.spacing.md),
            AppButton(
              label: 'Iniciar sesion',
              icon: Icons.login_rounded,
              size: AppButtonSize.sm,
              onPressed: () => unawaited(onSignIn!()),
            ),
          ],
        ],
      ),
    );
  }
}

class _BackendBadge extends StatelessWidget {
  const _BackendBadge({required this.label, required this.remote});

  final String label;
  final bool remote;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _PillFrame(
      background: remote ? t.colors.successBg : t.colors.surfaceMuted,
      borderColor:
          remote ? t.colors.successFg.withValues(alpha: 0.22) : t.colors.border,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            remote ? Icons.cloud_done_rounded : Icons.computer_rounded,
            size: 16,
            color: remote ? t.colors.successFg : t.colors.textSecondary,
          ),
          SizedBox(width: t.spacing.xs),
          Text(
            label,
            style: t.text.bodySmall?.copyWith(
              color: remote ? t.colors.successFg : t.colors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    this.size = 42,
    this.iconSize = 20,
    this.filled = false,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final bool filled;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final bg =
        backgroundColor ?? (filled ? t.colors.accent : t.colors.accentMuted);
    final fg = foregroundColor ?? (filled ? onPrimary : t.colors.accent);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(t.radii.md),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Icon(icon, size: iconSize, color: fg),
    );
  }
}

class _PillFrame extends StatelessWidget {
  const _PillFrame({
    required this.child,
    required this.background,
    this.borderColor,
    this.padding,
  });

  final Widget child;
  final Color background;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: t.spacing.md,
            vertical: t.spacing.xs,
          ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(t.radii.pill),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: child,
    );
  }
}

class _ActionHint extends StatelessWidget {
  const _ActionHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: t.text.bodySmall?.copyWith(
            color: t.colors.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(width: t.spacing.xs),
        Icon(
          Icons.arrow_forward_rounded,
          size: 16,
          color: t.colors.accent,
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final CorporateRole role;

  @override
  Widget build(BuildContext context) {
    return _StatusChip(label: role.label);
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.userId, required this.role});

  final String userId;
  final CorporateRole role;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _PillFrame(
      background: t.colors.surfaceMuted,
      borderColor: t.colors.border,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_rounded, size: 16, color: t.colors.textSecondary),
          SizedBox(width: t.spacing.xs),
          Text(
            userId,
            style: t.text.bodySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(width: t.spacing.xs),
          Text(
            role.label,
            style: t.text.bodySmall?.copyWith(
              color: t.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final status = _resolveStatus(t, label);
    return _PillFrame(
      background: status.background,
      borderColor: status.border,
      child: Text(
        status.label,
        style: t.text.bodySmall?.copyWith(
          color: status.foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  _ResolvedStatus _resolveStatus(AppTokens t, String rawLabel) {
    switch (rawLabel.trim().toLowerCase()) {
      case 'active':
        return _ResolvedStatus(
          label: 'Activo',
          background: t.colors.successBg,
          foreground: t.colors.successFg,
          border: t.colors.successFg.withValues(alpha: 0.18),
        );
      case 'planning':
        return _ResolvedStatus(
          label: 'Planificación',
          background: t.colors.accentMuted,
          foreground: t.colors.accent,
          border: t.colors.accent.withValues(alpha: 0.16),
        );
      case 'paused':
        return _ResolvedStatus(
          label: 'Pausado',
          background: t.colors.warningBg,
          foreground: t.colors.warningFg,
          border: t.colors.warningFg.withValues(alpha: 0.16),
        );
      case 'closed':
        return _ResolvedStatus(
          label: 'Cerrado',
          background: t.colors.surfaceMuted,
          foreground: t.colors.textSecondary,
          border: t.colors.border,
        );
      default:
        return _ResolvedStatus(
          label: rawLabel,
          background: t.colors.statusBg,
          foreground: t.colors.statusFg,
          border: t.colors.statusFg.withValues(alpha: 0.14),
        );
    }
  }
}

class _ResolvedStatus {
  const _ResolvedStatus({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color border;
}

class _CorporateLoading extends StatelessWidget {
  const _CorporateLoading();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      color: t.colors.surface,
      borderColor: t.colors.borderStrong,
      radius: t.radii.xl,
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: t.colors.accent,
            ),
          ),
          SizedBox(width: t.spacing.md),
          Text(
            'Cargando base corporativa...',
            style: t.text.bodyMedium?.copyWith(
              color: t.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CorporateError extends StatelessWidget {
  const _CorporateError({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      color: t.colors.surface,
      borderColor: t.colors.dangerFg.withValues(alpha: 0.18),
      radius: t.radii.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconTile(
            icon: Icons.error_outline_rounded,
            backgroundColor: t.colors.dangerBg,
            foregroundColor: t.colors.dangerFg,
            borderColor: t.colors.dangerFg.withValues(alpha: 0.18),
          ),
          SizedBox(height: t.spacing.md),
          Text(
            message,
            style: t.text.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: t.spacing.xs),
          Text(
            detail,
            style: t.text.bodySmall?.copyWith(
              color: t.colors.textSecondary,
              height: 1.35,
            ),
          ),
          SizedBox(height: t.spacing.lg),
          AppButton(
            label: 'Reintentar',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _CorporateEmpty extends StatelessWidget {
  const _CorporateEmpty({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      color: t.colors.surface,
      borderColor: t.colors.borderStrong,
      radius: t.radii.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconTile(icon: icon),
          SizedBox(height: t.spacing.lg),
          Text(
            title,
            style: t.text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: t.spacing.xs),
          Text(
            message,
            style: t.text.bodyMedium?.copyWith(
              color: t.colors.textSecondary,
              height: 1.35,
            ),
          ),
          if (action != null) ...[
            SizedBox(height: t.spacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

class _ProjectListData {
  const _ProjectListData({
    required this.workspace,
    required this.projects,
  });

  final Workspace? workspace;
  final List<Project> projects;
}

class _ProjectSheetsData {
  const _ProjectSheetsData({
    required this.detail,
    required this.sheetIds,
  });

  final ProjectDetail? detail;
  final List<String> sheetIds;
}

// ══════════════════════════════════════════════════════════════════════════════
// PANEL DE PENDIENTES
// ══════════════════════════════════════════════════════════════════════════════

class PendingPanelScreen extends StatefulWidget {
  const PendingPanelScreen({
    super.key,
    required this.isLight,
    required this.onToggleTheme,
  });

  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<PendingPanelScreen> createState() => _PendingPanelScreenState();
}

class _PendingPanelScreenState extends State<PendingPanelScreen> {
  late CorporateRepository _repository;
  late Future<List<PendingReviewItem>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _repository = createCorporateRepository();
    _future = _repository.listPendingReviews();
  }

  @override
  Widget build(BuildContext context) {
    return _CorporateShell(
      isLight: widget.isLight,
      onToggleTheme: widget.onToggleTheme,
      title: 'Pendientes',
      subtitle: 'Filas que requieren tu atención ahora.',
      backendLabel: _repository.backendLabel,
      usesRemoteBackend: _repository.usesRemoteBackend,
      actions: [
        AppButton(
          label: 'Empresa',
          icon: Icons.business_rounded,
          variant: AppButtonVariant.secondary,
          onPressed: () => context.go('/app'),
        ),
        AppButton(
          label: 'Actualizar',
          icon: Icons.refresh_rounded,
          variant: AppButtonVariant.ghost,
          onPressed: () => setState(_reload),
        ),
      ],
      child: FutureBuilder<List<PendingReviewItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CorporateLoading();
          }
          if (snapshot.hasError) {
            return _CorporateError(
              message: 'No se pudieron cargar los pendientes.',
              detail: '${snapshot.error}',
              onRetry: () => setState(_reload),
            );
          }
          final items = snapshot.data ?? const <PendingReviewItem>[];
          if (!_repository.usesRemoteBackend) {
            return _CorporateEmpty(
              icon: Icons.task_alt_rounded,
              title: 'Panel de pendientes',
              message:
                  'Conectá Supabase e iniciá sesión para ver filas pendientes '
                  'de todos tus proyectos.',
            );
          }
          if (items.isEmpty) {
            return _CorporateEmpty(
              icon: Icons.task_alt_rounded,
              title: 'Al día en todos los proyectos',
              message:
                  'No hay filas observadas ni corregidas pendientes de acción.',
            );
          }
          final projectCount = items.map((i) => i.projectId).toSet().length;
          final rowWord = items.length == 1 ? 'fila' : 'filas';
          final projWord = projectCount == 1 ? 'proyecto' : 'proyectos';
          final t = context.tokens;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${items.length} $rowWord en $projectCount $projWord',
                style:
                    t.text.labelSmall?.copyWith(color: t.colors.textSecondary),
              ),
              SizedBox(height: t.spacing.md),
              _PendingList(items: items),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: t.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              SizedBox(width: t.spacing.xs),
              Text(
                label,
                style: t.text.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: t.spacing.xs),
          Divider(height: 1, color: t.colors.border),
        ],
      ),
    );
  }
}

class _PendingList extends StatelessWidget {
  const _PendingList({required this.items});

  final List<PendingReviewItem> items;

  Widget _groupedSection(
    BuildContext context,
    List<PendingReviewItem> sectionItems,
  ) {
    final t = context.tokens;
    final grouped = <String, List<PendingReviewItem>>{};
    for (final item in sectionItems) {
      grouped.putIfAbsent(item.projectId, () => []).add(item);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in grouped.entries) ...[
          _PendingGroupHeader(
            projectName: entry.value.first.projectName,
            projectCode: entry.value.first.projectCode,
            count: entry.value.length,
          ),
          SizedBox(height: t.spacing.sm),
          for (final item in entry.value) _PendingItemCard(item: item),
          SizedBox(height: t.spacing.lg),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final toCorrect =
        items.where((i) => i.review.status == 'observada').toList();
    final toReview =
        items.where((i) => i.review.status == 'corregida').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (toCorrect.isNotEmpty) ...[
          _SectionHeader(
            label: 'Para corregir',
            icon: Icons.flag_rounded,
            color: t.colors.dangerFg,
          ),
          _groupedSection(context, toCorrect),
        ],
        if (toReview.isNotEmpty) ...[
          _SectionHeader(
            label: 'Para revisar',
            icon: Icons.build_circle_rounded,
            color: t.colors.successFg,
          ),
          _groupedSection(context, toReview),
        ],
      ],
    );
  }
}

class _PendingGroupHeader extends StatelessWidget {
  const _PendingGroupHeader({
    required this.projectName,
    required this.count,
    this.projectCode,
  });

  final String projectName;
  final String? projectCode;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        if (projectCode != null)
          _PillFrame(
            background: t.colors.accentMuted,
            borderColor: t.colors.accent.withValues(alpha: 0.16),
            padding: EdgeInsets.symmetric(
              horizontal: t.spacing.sm,
              vertical: 2,
            ),
            child: Text(
              projectCode!,
              style: t.text.labelSmall?.copyWith(
                color: t.colors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        if (projectCode != null) SizedBox(width: t.spacing.sm),
        Expanded(
          child: Text(
            projectName,
            style: t.text.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _PillFrame(
          background: t.colors.statusBg,
          borderColor: t.colors.statusFg.withValues(alpha: 0.14),
          padding: EdgeInsets.symmetric(
            horizontal: t.spacing.sm,
            vertical: 2,
          ),
          child: Text(
            '$count',
            style: t.text.labelSmall?.copyWith(
              color: t.colors.statusFg,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingItemCard extends StatelessWidget {
  const _PendingItemCard({required this.item});

  final PendingReviewItem item;

  Color _statusColor(BuildContext ctx) {
    final t = ctx.tokens;
    return switch (item.review.status) {
      'observada' => t.colors.dangerFg,
      'corregida' => t.colors.successFg,
      _ => t.colors.textSecondary,
    };
  }

  IconData _statusIcon() => switch (item.review.status) {
        'observada' => Icons.flag_rounded,
        'corregida' => Icons.build_circle_rounded,
        _ => Icons.radio_button_unchecked_rounded,
      };

  String _lastActionLabel() {
    final review = item.review;
    if (review.status == 'observada' && review.observedAt != null) {
      return 'Observada ${_relTime(review.observedAt)}';
    }
    if (review.status == 'corregida' && review.correctedAt != null) {
      return 'Corregida ${_relTime(review.correctedAt)}';
    }
    if (review.updatedAt != null) {
      return 'Actualizada ${_relTime(review.updatedAt)}';
    }
    return '';
  }

  String _relTime(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inHours < 1) return 'hace ${diff.inMinutes}m';
    if (diff.inDays < 1) return 'hace ${diff.inHours}h';
    return 'hace ${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final statusColor = _statusColor(context);

    return AppCard(
      onTap: () {
        // Navegar a la planilla correspondiente con el sheetId.
        final sheetId = item.review.sheetLocalId;
        context.go('/sheets?sheetId=$sheetId');
      },
      color: t.colors.surface,
      borderColor: statusColor.withValues(alpha: 0.18),
      radius: t.radii.lg,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(t.radii.md),
            ),
            child: Icon(_statusIcon(), color: statusColor, size: 20),
          ),
          SizedBox(width: t.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _PillFrame(
                      background: statusColor.withValues(alpha: 0.10),
                      borderColor: statusColor.withValues(alpha: 0.18),
                      padding: EdgeInsets.symmetric(
                        horizontal: t.spacing.xs,
                        vertical: 2,
                      ),
                      child: Text(
                        item.displayStatus,
                        style: t.text.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: t.spacing.xs),
                    Expanded(
                      child: Text(
                        'Fila ${_shortRowId(item.review.rowId)}',
                        style: t.text.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  _lastActionLabel(),
                  style: t.text.labelSmall?.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: t.colors.textSecondary),
        ],
      ),
    );
  }

  String _shortRowId(String rowId) {
    if (rowId.length <= 10) return rowId;
    return '…${rowId.substring(rowId.length - 8)}';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// NOTIFICACIONES
// ══════════════════════════════════════════════════════════════════════════════

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.isLight,
    required this.onToggleTheme,
  });

  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late CorporateRepository _repository;
  late Future<List<UserNotification>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _repository = createCorporateRepository();
    _future = _repository.listNotifications();
  }

  Future<void> _markRead(UserNotification notif) async {
    if (notif.isRead) return;
    try {
      await _repository.markNotificationRead(notif.id);
      setState(_reload);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return _CorporateShell(
      isLight: widget.isLight,
      onToggleTheme: widget.onToggleTheme,
      title: 'Notificaciones',
      subtitle: 'Actividad relevante en tus proyectos.',
      backendLabel: _repository.backendLabel,
      usesRemoteBackend: _repository.usesRemoteBackend,
      actions: [
        AppButton(
          label: 'Empresa',
          icon: Icons.business_rounded,
          variant: AppButtonVariant.secondary,
          onPressed: () => context.go('/app'),
        ),
        AppButton(
          label: 'Actualizar',
          icon: Icons.refresh_rounded,
          variant: AppButtonVariant.ghost,
          onPressed: () => setState(_reload),
        ),
      ],
      child: FutureBuilder<List<UserNotification>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CorporateLoading();
          }
          if (snapshot.hasError) {
            return _CorporateError(
              message: 'No se pudieron cargar las notificaciones.',
              detail: '${snapshot.error}',
              onRetry: () => setState(_reload),
            );
          }
          final notifs = snapshot.data ?? const <UserNotification>[];
          if (!_repository.usesRemoteBackend) {
            return _CorporateEmpty(
              icon: Icons.notifications_none_rounded,
              title: 'Notificaciones corporativas',
              message:
                  'Conectá Supabase e iniciá sesión para recibir notificaciones '
                  'sobre revisiones y comentarios de tus proyectos.',
            );
          }
          if (notifs.isEmpty) {
            return _CorporateEmpty(
              icon: Icons.notifications_none_rounded,
              title: 'Sin notificaciones',
              message: 'Cuando alguien observe o apruebe una fila, '
                  'aparecerá aquí.',
            );
          }
          return _NotificationsList(
            notifs: notifs,
            onMarkRead: _markRead,
          );
        },
      ),
    );
  }
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList({
    required this.notifs,
    required this.onMarkRead,
  });

  final List<UserNotification> notifs;
  final Future<void> Function(UserNotification) onMarkRead;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unread = notifs.where((n) => !n.isRead).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (unread > 0) ...[
          _PillFrame(
            background: t.colors.accentMuted,
            borderColor: t.colors.accent.withValues(alpha: 0.16),
            padding: EdgeInsets.symmetric(
              horizontal: t.spacing.sm,
              vertical: t.spacing.xs,
            ),
            child: Text(
              '$unread sin leer',
              style: t.text.labelSmall?.copyWith(
                color: t.colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: t.spacing.sm),
        ],
        for (final notif in notifs) _NotifCard(notif: notif, onTap: onMarkRead),
      ],
    );
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.notif, required this.onTap});

  final UserNotification notif;
  final Future<void> Function(UserNotification) onTap;

  IconData _icon() => switch (notif.notifType) {
        NotifType.filaObservada => Icons.flag_rounded,
        NotifType.filaCorregida => Icons.build_circle_rounded,
        NotifType.filaAprobada => Icons.check_circle_rounded,
        NotifType.comentarioNuevo => Icons.edit_note_rounded,
      };

  Color _color(BuildContext ctx) {
    final t = ctx.tokens;
    return switch (notif.notifType) {
      NotifType.filaObservada => t.colors.dangerFg,
      NotifType.filaAprobada => t.colors.successFg,
      NotifType.filaCorregida => t.colors.accent,
      NotifType.comentarioNuevo => t.colors.accent,
    };
  }

  String _timeLabel() {
    final dt = notif.createdAt;
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inHours < 1) return 'hace ${diff.inMinutes}m';
    if (diff.inDays < 1) return 'hace ${diff.inHours}h';
    return 'hace ${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = _color(context);

    final actorPart = notif.actorLabel?.trim() ?? '';
    final titleText = actorPart.isNotEmpty
        ? '$actorPart · ${notif.notifType.label}'
        : notif.notifType.label;

    final card = AppCard(
      onTap: () {
        unawaited(onTap(notif));
        if (notif.sheetLocalId?.isNotEmpty ?? false) {
          context.go('/sheets?sheetId=${notif.sheetLocalId}');
        }
      },
      radius: t.radii.lg,
      color: t.colors.surface,
      borderColor:
          notif.isRead ? t.colors.border : color.withValues(alpha: 0.18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            margin: EdgeInsets.only(right: t.spacing.md),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(t.radii.md),
            ),
            child: Icon(_icon(), color: color, size: 18),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        titleText,
                        style: t.text.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      _timeLabel(),
                      style: t.text.labelSmall?.copyWith(
                        color: t.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (notif.body.trim().isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    notif.body,
                    style: t.text.bodySmall?.copyWith(
                      color: t.colors.textSecondary,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (!notif.isRead)
            Container(
              width: 6,
              height: 6,
              margin: EdgeInsets.only(left: t.spacing.sm, top: 6),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );

    if (notif.isRead) return card;
    return Stack(
      children: [
        card,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(t.radii.lg),
              child: Row(
                children: [
                  Container(width: 3, color: t.colors.accent),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Badge de notificaciones no leidas para el shell.
class _NotifBadge extends StatefulWidget {
  const _NotifBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_NotifBadge> createState() => _NotifBadgeState();
}

class _NotifBadgeState extends State<_NotifBadge> {
  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    // Poll cada 90s sin tiempo real.
    _timer = Timer.periodic(const Duration(seconds: 90), (_) {
      if (mounted) unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final repo = createCorporateRepository();
      if (!repo.usesRemoteBackend) return;
      final notifs = await repo.listNotifications(limit: 60);
      final unread = notifs.where((n) => !n.isRead).length;
      if (!mounted) return;
      setState(() => _unread = unread);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppButton(
          icon: Icons.notifications_none_rounded,
          label: 'Alertas',
          variant: AppButtonVariant.ghost,
          onPressed: widget.onTap,
        ),
        if (_unread > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: t.colors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: t.colors.surface, width: 1.5),
              ),
              child: Center(
                child: Text(
                  _unread > 9 ? '9+' : '$_unread',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
