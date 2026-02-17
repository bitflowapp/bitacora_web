import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const routeTitle = 'Privacidad';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(routeTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Text(
            'Resumen',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'BitFlow prioriza el uso local y pide permisos solo cuando son necesarios para las funciones de cámara, audio o ubicación.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          const _SectionBlock(
            title: 'Datos guardados',
            body:
                'Las planillas y adjuntos se almacenan en el dispositivo o navegador, segun plataforma.',
          ),
          const _SectionBlock(
            title: 'Permisos',
            body:
                'Cámara, micrófono y ubicación se solicitan al usar acciones que los requieren.',
          ),
          const _SectionBlock(
            title: 'Control del usuario',
            body:
                'Puedes eliminar planillas, exportar respaldos y revocar permisos desde el sistema.',
          ),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(body, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
