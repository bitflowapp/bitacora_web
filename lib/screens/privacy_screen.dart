import 'package:flutter/material.dart';

import '../ui/ui.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const routeTitle = 'Privacidad';

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
            title: 'Resumen',
            subtitle:
                'Bit Flow prioriza el uso local y pide permisos sólo cuando son necesarios.',
          ),
          const SizedBox(height: 18),
          const _Block(
            icon: Icons.shield_outlined,
            title: 'Datos guardados',
            body:
                'Las planillas y adjuntos se almacenan en el dispositivo o navegador, según plataforma.',
          ),
          const SizedBox(height: 12),
          const _Block(
            icon: Icons.lock_outline,
            title: 'Permisos',
            body:
                'Cámara, micrófono y ubicación se solicitan al usar acciones que los requieren.',
          ),
          const SizedBox(height: 12),
          const _Block(
            icon: Icons.tune_rounded,
            title: 'Control del usuario',
            body:
                'Podés eliminar planillas, exportar respaldos y revocar permisos desde el sistema.',
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
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
