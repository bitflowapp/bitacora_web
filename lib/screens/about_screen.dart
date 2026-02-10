import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_service.dart';
import '../services/build_info.dart';
import '../services/force_update_service.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  static const routeTitle = 'Acerca de';

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final AppUpdateService _updateService = const AppUpdateService();

  AppUpdateSnapshot? _lastCheck;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates(silent: true);
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
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
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

  void _showSnack(String message) {
    if (!mounted) return;
    final text = message.trim();
    if (text.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localVersion = _lastCheck?.localVersion ?? '...';
    final localBuild = _lastCheck?.localBuildNumber ?? '...';
    final localBuildId = _lastCheck?.localBuildId ?? BuildInfo.buildIdLabel;
    final remoteVersion = _lastCheck?.remoteVersion ?? '';
    final remoteBuildId = _lastCheck?.remoteBuildId ?? '';
    final updateAvailable = _lastCheck?.updateAvailable ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AboutScreen.routeTitle),
      ),
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
            'Bitacoras tecnicas con foco en rapidez, claridad y confiabilidad.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(label: 'Version', value: localVersion),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'Build', value: localBuild),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'BuildId', value: localBuildId),
                  const SizedBox(height: 10),
                  _InfoRow(label: 'Stamp', value: BuildInfo.stamp),
                  if (remoteVersion.isNotEmpty || remoteBuildId.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Divider(
                      height: 1,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.14),
                    ),
                    const SizedBox(height: 12),
                    if (remoteVersion.isNotEmpty)
                      _InfoRow(label: 'Remota', value: remoteVersion),
                    if (remoteVersion.isNotEmpty && remoteBuildId.isNotEmpty)
                      const SizedBox(height: 10),
                    if (remoteBuildId.isNotEmpty)
                      _InfoRow(label: 'BuildId remoto', value: remoteBuildId),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _checking ? null : _checkForUpdates,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.onSurface
                              .withValues(alpha: 0.12),
                          foregroundColor: theme.colorScheme.onSurface,
                        ),
                        icon: _checking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync_rounded),
                        label: Text(
                          _checking ? 'Buscando...' : 'Buscar actualizaciones',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: updateAvailable ? _applyUpdate : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface,
                          side: BorderSide(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.24),
                          ),
                        ),
                        icon: const Icon(Icons.system_update_rounded),
                        label: const Text('Actualizar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    updateAvailable
                        ? 'Actualizacion disponible.'
                        : 'Sin actualizaciones pendientes.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.74),
                      fontWeight:
                          updateAvailable ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: _InfoRow(
                label: 'Contacto',
                value: 'soporte@bitflow.app',
              ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 122,
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
