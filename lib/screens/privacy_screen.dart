import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../ui/ui.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const routeTitle = 'Privacidad';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppShell(
      title: routeTitle,
      subtitle: 'Datos locales, permisos claros y control del usuario.',
      leading: const _BackControl(),
      body: ListView(
        children: [
          AppCard(
            padding: EdgeInsets.all(t.spacing.lg),
            color: t.colors.surfaceElevated,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: t.colors.accent,
                  size: 28,
                ),
                SizedBox(height: t.spacing.sm),
                Text(
                  'Bit Flow prioriza el uso local.',
                  style: t.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: t.spacing.xs),
                Text(
                  'Los permisos se piden solo cuando usas cámara, audio o ubicación. Las planillas quedan en este dispositivo o navegador, según plataforma.',
                  style: t.text.bodyMedium?.copyWith(
                    color: t.colors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: t.spacing.md),
          const _SectionBlock(
            icon: Icons.folder_copy_outlined,
            title: 'Datos guardados',
            body:
                'Las planillas y adjuntos se almacenan localmente. Puedes exportar respaldos cuando necesites mover o resguardar informacion.',
          ),
          const _SectionBlock(
            icon: Icons.privacy_tip_outlined,
            title: 'Permisos',
            body:
                'Cámara, micrófono y ubicación se solicitan al usar acciones que los requieren. Si no los usas, no se piden.',
          ),
          const _SectionBlock(
            icon: Icons.tune_rounded,
            title: 'Control del usuario',
            body:
                'Puedes eliminar planillas, exportar respaldos y revocar permisos desde la configuración del sistema.',
          ),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: t.spacing.sm),
      child: AppCard(
        padding: EdgeInsets.all(t.spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: t.colors.accentMuted,
                borderRadius: BorderRadius.circular(t.radii.sm),
              ),
              child: Icon(icon, color: t.colors.accent, size: 19),
            ),
            SizedBox(width: t.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: t.spacing.xs),
                  Text(
                    body,
                    style: t.text.bodyMedium?.copyWith(
                      color: t.colors.textSecondary,
                      height: 1.32,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
