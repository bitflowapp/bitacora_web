import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../ui/ui.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const routeTitle = 'Terminos';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppShell(
      title: routeTitle,
      subtitle: 'Condiciones simples para operar con continuidad.',
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
                  Icons.verified_user_outlined,
                  color: t.colors.accent,
                  size: 28,
                ),
                SizedBox(height: t.spacing.sm),
                Text(
                  'Uso responsable',
                  style: t.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: t.spacing.xs),
                Text(
                  'Este resumen es informativo y funciona como base para una version legal final por cliente o empresa.',
                  style: t.text.bodyMedium?.copyWith(
                    color: t.colors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: t.spacing.md),
          const _TermItem(
            icon: Icons.cloud_off_outlined,
            title: 'Disponibilidad',
            body:
                'La aplicacion funciona localmente. Algunas funciones pueden variar por plataforma, navegador o permisos del dispositivo.',
          ),
          const _TermItem(
            icon: Icons.ios_share_rounded,
            title: 'Respaldo',
            body:
                'Se recomienda exportar respaldos periodicos para mantener continuidad operativa y facilitar auditorias.',
          ),
          const _TermItem(
            icon: Icons.fact_check_outlined,
            title: 'Contenido',
            body:
                'El usuario es responsable de la informacion registrada, exportada y compartida desde Bit Flow.',
          ),
        ],
      ),
    );
  }
}

class _TermItem extends StatelessWidget {
  const _TermItem({
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
