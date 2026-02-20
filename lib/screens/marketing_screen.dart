import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_config.dart';
import '../services/build_info.dart';
import '../ui/ui.dart';

enum _MarketingPageKind { contact, changelog }

class MarketingScreen extends StatelessWidget {
  const MarketingScreen.contact({super.key})
      : kind = _MarketingPageKind.contact;

  const MarketingScreen.changelog({super.key})
      : kind = _MarketingPageKind.changelog;

  final _MarketingPageKind kind;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case _MarketingPageKind.contact:
        return _ContactPage();
      case _MarketingPageKind.changelog:
        return const _ChangelogPage();
    }
  }
}

class _ContactPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppConfig>(
      future: AppConfig.load(),
      builder: (context, snapshot) {
        final config = snapshot.data ?? AppConfig.defaults();
        final email = config.contactEmail.trim();
        final whatsapp = config.contactWhatsApp.trim();

        return AppShell(
          title: 'Contacto',
          subtitle: 'Canales directos para demo, pricing y soporte comercial.',
          leading: IconButton(
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Hablemos de tu operación',
                  subtitle:
                      'Cuéntanos volumen, equipo y flujo. Te devolvemos una propuesta concreta.',
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Canales disponibles',
                        style: context.tokens.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        email.isEmpty
                            ? 'Email: soporte@bitflow.local'
                            : 'Email: $email',
                        style: context.tokens.text.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        whatsapp.isEmpty
                            ? 'WhatsApp: no configurado'
                            : 'WhatsApp: $whatsapp',
                        style: context.tokens.text.bodyMedium,
                      ),
                      const SizedBox(height: 14),
                      AppButton(
                        label: 'Enviar email',
                        icon: Icons.mail_outline,
                        variant: AppButtonVariant.primary,
                        size: AppButtonSize.lg,
                        fullWidth: true,
                        onPressed:
                            email.isEmpty ? null : () => _openEmail(email),
                      ),
                      const SizedBox(height: 10),
                      AppButton(
                        label: 'Abrir WhatsApp',
                        icon: Icons.open_in_new_rounded,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.lg,
                        fullWidth: true,
                        onPressed: whatsapp.isEmpty
                            ? null
                            : () => _openWhatsApp(whatsapp),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compromiso de respuesta',
                        style: context.tokens.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'BitFlow es local-first: no requiere backend para operar. El acompañamiento comercial incluye setup, adopción y mejoras por release.',
                        style: context.tokens.text.bodyMedium?.copyWith(
                          color: context.tokens.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: <String, String>{
        'subject': 'Consulta comercial BitFlow',
      },
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openWhatsApp(String rawPhone) async {
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent('Hola, quiero una demo comercial de BitFlow.')}', // ignore: lines_longer_than_80_chars
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _ChangelogPage extends StatelessWidget {
  const _ChangelogPage();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppShell(
      title: 'Changelog',
      subtitle: 'Registro corto de cambios orientados a producto y release.',
      leading: IconButton(
        tooltip: 'Volver',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Versión activa',
              subtitle: BuildInfo.stamp,
              trailing: AppButton(
                label: 'Ir al inicio',
                variant: AppButtonVariant.ghost,
                onPressed: () => context.go('/'),
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Build ID: ${BuildInfo.buildIdLabel}',
                    style: t.text.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Git SHA: ${BuildInfo.shortSha}',
                    style: t.text.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    BuildInfo.buildTime.trim().isEmpty
                        ? 'Build time: no disponible'
                        : 'Build time: ${BuildInfo.buildTime.trim()} UTC',
                    style: t.text.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _ReleaseNoteCard(
              title: 'P10 Premium Sellable Sweep',
              bullets: [
                'Tokens visuales unificados en landing, premium y app shell.',
                'A11y mejorada: focus visible, semantics y smoke tests con textScale.',
                'Estabilidad reforzada en navegación, errores globales y safe areas.',
                'Páginas legales/comerciales listas para venta en web.',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleaseNoteCard extends StatelessWidget {
  const _ReleaseNoteCard({
    required this.title,
    required this.bullets,
  });

  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: t.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final bullet in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '- $bullet',
                style: t.text.bodyMedium?.copyWith(
                  color: t.colors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
