import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../corporate/corporate_models.dart';
import '../../corporate/corporate_repository.dart';
import '../../corporate/corporate_repository_factory.dart';
import '../../services/auth_service.dart';
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
          label: 'Planillas',
          icon: Icons.table_chart_rounded,
          variant: AppButtonVariant.secondary,
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
                color: t.colors.surfaceElevated,
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
                          onPressed: () => context.go('/sheets'),
                        ),
                        AppButton(
                          label: 'Demo proteccion catodica',
                          icon: Icons.bolt_rounded,
                          variant: AppButtonVariant.secondary,
                          onPressed: () =>
                              context.go('/?template=proteccion-catodica'),
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
                    color: t.colors.surfaceElevated.withValues(alpha: 0.92),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 760;
                        final header = Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: t.colors.textPrimary,
                                borderRadius: BorderRadius.circular(t.radii.md),
                              ),
                              child: Icon(
                                Icons.business_center_rounded,
                                color: t.colors.bg,
                              ),
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
                                      height: 1.3,
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
      color: t.colors.surfaceElevated,
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
          Row(
            children: [
              Text(
                'Ver proyectos',
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
          ),
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
      color: t.colors.surfaceElevated,
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
      color: t.colors.surfaceElevated,
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
          Row(
            children: [
              Text(
                'Entrar al proyecto',
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
          ),
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
    final configured = AuthService.I.isRemoteBackendConfigured;
    final signedIn = AuthService.I.isRemoteAuthenticated;
    final text = repository.usesRemoteBackend
        ? (signedIn
            ? 'Backend corporativo conectado con Supabase Auth.'
            : 'Supabase configurado. Inicia sesion para aplicar RLS y ver datos reales.')
        : 'Modo local operativo. Configura Supabase para usar workspaces reales.';
    return AppCard(
      color: t.colors.surfaceMuted,
      radius: t.radii.lg,
      shadows: const <BoxShadow>[],
      child: Row(
        children: [
          Icon(
            repository.usesRemoteBackend
                ? Icons.cloud_done_rounded
                : Icons.computer_rounded,
            color: configured ? t.colors.successFg : t.colors.textSecondary,
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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: remote ? t.colors.successBg : t.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(t.radii.pill),
        border: Border.all(
          color: remote
              ? t.colors.successFg.withValues(alpha: 0.22)
              : t.colors.border,
        ),
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
  const _IconTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: t.colors.accentMuted,
        borderRadius: BorderRadius.circular(t.radii.md),
      ),
      child: Icon(icon, color: t.colors.accent),
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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: t.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(t.radii.pill),
        border: Border.all(color: t.colors.border),
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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: t.colors.statusBg,
        borderRadius: BorderRadius.circular(t.radii.pill),
      ),
      child: Text(
        label,
        style: t.text.bodySmall?.copyWith(
          color: t.colors.statusFg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CorporateLoading extends StatelessWidget {
  const _CorporateLoading();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      color: t.colors.surfaceElevated,
      radius: t.radii.xl,
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
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
      color: t.colors.surfaceElevated,
      radius: t.radii.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: t.colors.dangerFg),
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
      color: t.colors.surfaceElevated,
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
