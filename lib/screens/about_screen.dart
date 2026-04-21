import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/privacy_screen.dart';
import '../screens/terms_screen.dart';
import '../services/about_diagnostics.dart';
import '../services/app_update_service.dart';
import '../services/build_info.dart';
import '../services/force_update_service.dart';
import '../services/sheet_store.dart';
import '../ui/ui.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  static const routeTitle = 'Acerca de';

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final AppUpdateService _updateService = const AppUpdateService();
  String? _sheetName;
  int? _sheetRows;
  int? _sheetCols;

  AppUpdateSnapshot? _lastCheck;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates(silent: true);
    _loadSheetSnapshot();
  }

  Future<void> _checkForUpdates({bool silent = false}) async {
    if (_checking) return;
    setState(() => _checking = true);

    final result = await _updateService.checkForUpdates();

    if (!mounted) return;
    setState(() {
      _lastCheck = result;
      _checking = false;
    });

    if (!silent) {
      _showSnack(result.message);
    }
  }

  Future<void> _applyUpdate() async {
    final snap = _lastCheck;
    if (snap == null || !snap.updateAvailable) {
      _showSnack('No hay actualizaciones pendientes.');
      return;
    }

    if (kIsWeb) {
      final result = await ForceUpdateService.I.forceUpdate();
      if (!mounted) return;
      _showSnack(result.message);
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final uri = Uri.parse(AppUpdateService.androidLatestApkUrl);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      _showSnack(
        opened
            ? 'Abriendo descarga de Android.'
            : 'No se pudo abrir el enlace de descarga.',
      );
      return;
    }

    _showSnack(
      'En iPhone/iPad usa Safari y selecciona Compartir -> Anadir a inicio.',
    );
  }

  Future<void> _loadSheetSnapshot() async {
    try {
      final list = SheetStore.list();
      if (list.isEmpty) return;
      final first = list.first;
      final parsed = parseSheetSnapshotFromRaw(SheetStore.loadRaw(first.id));
      if (!mounted) return;
      setState(() {
        _sheetName = parsed.name ?? first.title;
        _sheetRows = parsed.rows ?? first.rows;
        _sheetCols = parsed.cols;
      });
    } catch (_) {
      // Keep About responsive even if diagnostics info is unavailable.
    }
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<void> _copyDiagnostics() async {
    final mediaQuery = MediaQuery.maybeOf(context);
    final text = buildAboutDiagnosticsText(
      AboutDiagnosticsPayload(
        version: _lastCheck?.localVersion ?? BuildInfo.stamp,
        build: _lastCheck?.localBuildNumber ?? BuildInfo.buildIdLabel,
        platform: _platformLabel(),
        isWeb: kIsWeb,
        reducedMotion: mediaQuery?.disableAnimations ?? false,
        timestamp: DateTime.now(),
        sheetName: _sheetName,
        rows: _sheetRows,
        cols: _sheetCols,
      ),
    );
    try {
      await Clipboard.setData(ClipboardData(text: text));
      _showSnack('Diagnostico copiado al portapapeles.');
    } catch (_) {
      _showSnack('No se pudo copiar el diagnostico.');
    }
  }

  Future<void> _openIssues() async {
    final opened = await launchUrl(
      Uri.parse('https://github.com/marcoluna-nqn/bitacora_web/issues'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      _showSnack('No se pudo abrir GitHub Issues.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    final text = message.trim();
    if (text.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final localVersion = _lastCheck?.localVersion ?? '...';
    final localBuild = _lastCheck?.localBuildNumber ?? '...';
    final localBuildId = _lastCheck?.localBuildId ?? BuildInfo.buildIdLabel;
    final remoteVersion = _lastCheck?.remoteVersion ?? '';
    final remoteBuildId = _lastCheck?.remoteBuildId ?? '';
    final updateAvailable = _lastCheck?.updateAvailable ?? false;

    return AppShell(
      title: AboutScreen.routeTitle,
      subtitle: 'Version, soporte y diagnostico de Bit Flow.',
      leading: const _BackControl(),
      body: ListView(
        children: [
          AppCard(
            padding: EdgeInsets.all(t.spacing.lg),
            color: t.colors.surfaceElevated,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: t.colors.accentMuted,
                    borderRadius: BorderRadius.circular(t.radii.lg),
                  ),
                  child: Icon(
                    Icons.grid_view_rounded,
                    color: t.colors.accent,
                    size: 24,
                  ),
                ),
                SizedBox(height: t.spacing.md),
                Text(
                  'Bit Flow',
                  style: t.text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: t.spacing.xs),
                Text(
                  'Planillas tecnicas con foco en rapidez, claridad y confiabilidad.',
                  style: t.text.bodyLarge?.copyWith(
                    color: t.colors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: t.spacing.md),
          AppCard(
            padding: EdgeInsets.all(t.spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Version', value: localVersion),
                SizedBox(height: t.spacing.sm),
                _InfoRow(label: 'Build', value: localBuild),
                SizedBox(height: t.spacing.sm),
                _InfoRow(label: 'BuildId', value: localBuildId),
                SizedBox(height: t.spacing.sm),
                _InfoRow(label: 'Stamp', value: BuildInfo.stamp),
                SizedBox(height: t.spacing.sm),
                _InfoRow(
                  label: 'Hoja',
                  value:
                      (_sheetName ?? '').trim().isEmpty ? 'n/a' : _sheetName!,
                ),
                SizedBox(height: t.spacing.sm),
                _InfoRow(
                  label: 'Filas/Cols',
                  value:
                      '${_sheetRows?.toString() ?? 'n/a'} / ${_sheetCols?.toString() ?? 'n/a'}',
                ),
                if (remoteVersion.isNotEmpty || remoteBuildId.isNotEmpty) ...[
                  SizedBox(height: t.spacing.md),
                  Divider(height: 1, color: t.colors.border),
                  SizedBox(height: t.spacing.sm),
                  if (remoteVersion.isNotEmpty)
                    _InfoRow(label: 'Remota', value: remoteVersion),
                  if (remoteVersion.isNotEmpty && remoteBuildId.isNotEmpty)
                    SizedBox(height: t.spacing.sm),
                  if (remoteBuildId.isNotEmpty)
                    _InfoRow(label: 'BuildId remoto', value: remoteBuildId),
                ],
                SizedBox(height: t.spacing.md),
                Wrap(
                  spacing: t.spacing.sm,
                  runSpacing: t.spacing.sm,
                  children: [
                    AppButton(
                      label:
                          _checking ? 'Buscando...' : 'Buscar actualizaciones',
                      icon: Icons.sync_rounded,
                      loading: _checking,
                      variant: AppButtonVariant.secondary,
                      onPressed: _checking ? null : _checkForUpdates,
                    ),
                    AppButton(
                      label: 'Actualizar',
                      icon: Icons.system_update_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: updateAvailable ? _applyUpdate : null,
                    ),
                    AppButton(
                      label: 'Copiar diagnostico',
                      icon: Icons.content_copy_rounded,
                      variant: AppButtonVariant.ghost,
                      onPressed: _copyDiagnostics,
                    ),
                  ],
                ),
                SizedBox(height: t.spacing.sm),
                Text(
                  updateAvailable
                      ? 'Actualizacion disponible.'
                      : 'Sin actualizaciones pendientes.',
                  style: t.text.bodySmall?.copyWith(
                    color: updateAvailable
                        ? t.colors.accent
                        : t.colors.textSecondary,
                    fontWeight:
                        updateAvailable ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: t.spacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacidad'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PrivacyScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: const Text('Terminos'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TermsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('GitHub Issues'),
                  onTap: _openIssues,
                ),
                const Divider(height: 1),
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: _InfoRow(
                    label: 'Contacto',
                    value: 'soporte@bitflow.app',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: t.spacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'BitFlow',
                applicationVersion: BuildInfo.stamp,
              );
            },
            child: const ListTile(
              leading: Icon(Icons.description_outlined),
              title: Text('Licencias'),
              subtitle: Text('Ver licencias de terceros'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 122,
          child: Text(
            label,
            style: t.text.labelLarge?.copyWith(
              color: t.colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: t.text.bodyMedium?.copyWith(
              color: t.colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _BackControl extends StatelessWidget {
  const _BackControl();

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) return const SizedBox.shrink();
    return CupertinoNavigationBarBackButton(
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}
