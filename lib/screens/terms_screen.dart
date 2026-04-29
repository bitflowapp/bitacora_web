import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const routeTitle = 'Terminos';

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
            'Uso responsable',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Este resumen es informativo y se ofrece como base para una version legal final.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          const _TermItem(
            title: 'Disponibilidad',
            body:
                'La aplicacion puede actualizarse y algunas funciones pueden variar por plataforma.',
          ),
          const _TermItem(
            title: 'Respaldo',
            body:
                'Se recomienda exportar respaldos periodicos para mantener continuidad operativa.',
          ),
          const _TermItem(
            title: 'Contenido',
            body:
                'El usuario es responsable de la información registrada y compartida desde BitFlow.',
          ),
        ],
      ),
    );
  }
}

class _TermItem extends StatelessWidget {
  const _TermItem({
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
      child: ListTile(
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(body),
        ),
      ),
    );
  }
}
