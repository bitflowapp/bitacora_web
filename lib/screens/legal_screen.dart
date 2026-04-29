import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/ui.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen.privacy({super.key})
      : title = 'Politica de privacidad',
        sections = const [
          LegalSection(
            title: 'Datos locales',
            body:
                'La aplicacion funciona sin servidores. La informacion se guarda localmente en el navegador o equipo del usuario.',
          ),
          LegalSection(
            title: 'Control del usuario',
            body:
                'Cada equipo decide que exporta, comparte o elimina. No recolectamos ni enviamos informacion automaticamente.',
          ),
          LegalSection(
            title: 'Respaldo',
            body:
                'Se recomienda exportar respaldos ZIP de forma periodica para resguardar evidencias.',
          ),
        ];

  const LegalScreen.terms({super.key})
      : title = 'Terminos de uso',
        sections = const [
          LegalSection(
            title: 'Uso permitido',
            body:
                'La licencia permite operar la aplicacion de manera local para registrar actividades y evidencias.',
          ),
          LegalSection(
            title: 'Responsabilidad',
            body:
                'El usuario es responsable de la calidad y seguridad de los datos exportados y compartidos.',
          ),
          LegalSection(
            title: 'Soporte',
            body:
                'El soporte se brinda segun el plan contratado. No incluye hosting ni almacenamiento remoto.',
          ),
        ];

  final String title;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppShell(
      title: title,
      leading: IconButton(
        tooltip: 'Volver',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: title,
                      subtitle: 'Documento breve para operacion local.',
                      trailing: AppButton(
                        label: 'Ir al inicio',
                        variant: AppButtonVariant.ghost,
                        onPressed: () => context.go('/'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final section in sections) ...[
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: t.text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              section.body,
                              style: t.text.bodyMedium?.copyWith(
                                color: t.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LegalSection {
  const LegalSection({required this.title, required this.body});

  final String title;
  final String body;
}
