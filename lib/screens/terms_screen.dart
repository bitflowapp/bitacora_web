import 'package:flutter/material.dart';

import '../ui/ui.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const routeTitle = 'Términos';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.colors.bg,
      appBar: AppBar(
        title: const Text(routeTitle),
        backgroundColor: t.colors.bg,
        surfaceTintColor: t.colors.bg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          SectionHeader(
            title: 'Uso responsable',
            subtitle:
                'Resumen informativo que sirve como base para una versión legal final.',
          ),
          const SizedBox(height: 18),
          const _TermBlock(
            icon: Icons.update_rounded,
            title: 'Disponibilidad',
            body:
                'La aplicación puede actualizarse y algunas funciones pueden variar por plataforma.',
          ),
          const SizedBox(height: 12),
          const _TermBlock(
            icon: Icons.backup_outlined,
            title: 'Respaldo',
            body:
                'Se recomienda exportar respaldos periódicos para mantener continuidad operativa.',
          ),
          const SizedBox(height: 12),
          const _TermBlock(
            icon: Icons.assignment_outlined,
            title: 'Contenido',
            body:
                'El usuario es responsable de la información registrada y compartida desde Bit Flow.',
          ),
        ],
      ),
    );
  }
}

class _TermBlock extends StatelessWidget {
  const _TermBlock({
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
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: t.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(t.radii.sm),
              border: Border.all(color: t.colors.border),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: t.colors.textPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: t.text.bodyMedium?.copyWith(
                    color: t.colors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
