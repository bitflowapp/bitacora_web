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
      'En iPhone/iPad usa Safari y selecciona Compartir -> Añadir a inicio.',
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
      _showSnack('Diagnóstico copiado al portapapeles.');
    } catch (_) {
      _showSnack('No se pudo copiar el diagnóstico.');
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

  Future<void> _sendFeedbackEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'soporte@bitflow.app',
      queryParameters: const <String, String>{
        'subject': 'Feedback BitFlow',
      },
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _showSnack('No se pudo abrir el correo de soporte.');
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
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final localVersion = _lastCheck?.localVersion ?? '...';
    final localBuild = _lastCheck?.localBuildNumber ?? '...';
    final localBuildId = _lastCheck?.localBuildId ?? BuildInfo.buildIdLabel;
    final remoteVersion = _lastCheck?.remoteVersion ?? '';
    final remoteBuildId = _lastCheck?.remoteBuildId ?? '';
    final updateAvailable = _lastCheck?.updateAvailable ?? false;
    final diagnosticsRows = <_AboutValueRow>[
      _AboutValueRow(label: 'Versión', value: localVersion),
      _AboutValueRow(label: 'Build', value: localBuild),
      _AboutValueRow(label: 'BuildId', value: localBuildId),
      _AboutValueRow(label: 'Stamp', value: BuildInfo.stamp),
      _AboutValueRow(
        label: 'Hoja',
        value: (_sheetName ?? '').trim().isEmpty ? 'n/a' : _sheetName!,
      ),
      _AboutValueRow(
        label: 'Filas/Cols',
        value:
            '${_sheetRows?.toString() ?? 'n/a'} / ${_sheetCols?.toString() ?? 'n/a'}',
      ),
      if (remoteVersion.isNotEmpty)
        _AboutValueRow(label: 'Remota', value: remoteVersion),
      if (remoteBuildId.isNotEmpty)
        _AboutValueRow(label: 'BuildId remoto', value: remoteBuildId),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text(AboutScreen.routeTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Text(
            'BitFlow',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bitácoras técnicas con foco en rapidez, claridad y confiabilidad.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Versión y estado',
                  subtitle: updateAvailable
                      ? 'Hay una actualización lista para instalar.'
                      : 'Aplicación al día.',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: updateAvailable
                          ? tokens.colors.warningBg
                          : tokens.colors.successBg,
                      borderRadius: BorderRadius.circular(tokens.radii.pill),
                      border: Border.all(
                        color: updateAvailable
                            ? tokens.colors.borderStrong
                            : tokens.colors.border,
                      ),
                    ),
                    child: Text(
                      updateAvailable ? 'Actualización disponible' : 'OK',
                      style: tokens.text.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tokens.colors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AppTable<_AboutValueRow>(
                  columns: [
                    AppTableColumn.text(
                      label: 'Dato',
                      minWidth: 180,
                      value: (row) => row.label,
                    ),
                    AppTableColumn.text(
                      label: 'Valor',
                      minWidth: 280,
                      value: (row) => row.value,
                    ),
                  ],
                  rows: diagnosticsRows,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
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
                      variant: AppButtonVariant.primary,
                      onPressed: updateAvailable ? _applyUpdate : null,
                    ),
                    AppButton(
                      label: 'Copiar diagnóstico',
                      icon: Icons.content_copy_rounded,
                      variant: AppButtonVariant.ghost,
                      onPressed: _copyDiagnostics,
                    ),
                    AppButton(
                      label: 'Feedback',
                      icon: Icons.mail_outline_rounded,
                      variant: AppButtonVariant.ghost,
                      onPressed: _sendFeedbackEmail,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
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
                  title: const Text('Términos'),
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
                const ListTile(
                  leading: Icon(Icons.support_agent_outlined),
                  title: Text('Contacto'),
                  subtitle: Text('soporte@bitflow.app'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.description_outlined),
            title: const Text('Licencias'),
            subtitle: const Text('Ver licencias de terceros'),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'BitFlow',
                applicationVersion: BuildInfo.stamp,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AboutValueRow {
  const _AboutValueRow({required this.label, required this.value});
  final String label;
  final String value;
}
