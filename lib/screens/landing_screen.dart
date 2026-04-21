import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_config.dart';
import '../services/build_info.dart';
import '../ui/ui.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({
    super.key,
    required this.isLight,
    required this.onToggleTheme,
  });

  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppConfig>(
      future: AppConfig.load(),
      builder: (context, snapshot) {
        final config = snapshot.data ?? AppConfig.defaults();
        final tokens = context.tokens;

        return Scaffold(
          backgroundColor: tokens.colors.bg,
          body: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          tokens.colors.bg,
                          tokens.colors.surfaceMuted.withOpacity(0.55),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1160),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 28,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TopNav(
                              brand: config.brandName.isEmpty
                                  ? 'Bit Flow'
                                  : config.brandName,
                              onToggleTheme: onToggleTheme,
                            ),
                            const SizedBox(height: 36),
                            _HeroSection(
                              config: config,
                              onPrimary: () => context.go('/app'),
                              onWhatsApp: () => _launchWhatsApp(config),
                              onEmail: () => _launchEmail(config),
                            ),
                            const SizedBox(height: 56),
                            SectionHeader(
                              title: 'Beneficios claros y medibles',
                              subtitle:
                                  'Operaciones con evidencia en un solo lugar, sin servidores y sin friccion.',
                            ),
                            const SizedBox(height: 18),
                            _BenefitsGrid(),
                            const SizedBox(height: 48),
                            SectionHeader(
                              title: 'Como funciona',
                              subtitle:
                                  'Tres pasos simples para empezar hoy mismo.',
                            ),
                            const SizedBox(height: 18),
                            _HowItWorks(),
                            const SizedBox(height: 48),
                            SectionHeader(
                              title: 'Casos de uso',
                              subtitle:
                                  'Pensado para equipos operativos, auditorias y seguimiento diario.',
                            ),
                            const SizedBox(height: 18),
                            _UseCases(),
                            const SizedBox(height: 52),
                            SectionHeader(
                              title: 'Planes claros, sin servidor',
                              subtitle:
                                  'Licencia local + soporte. No depende de internet para operar.',
                            ),
                            const SizedBox(height: 18),
                            _Pricing(
                              config: config,
                              onPrimary: () => context.go('/app'),
                            ),
                            const SizedBox(height: 52),
                            _CtaBand(
                              showWhatsApp:
                                  config.contactWhatsApp.trim().isNotEmpty,
                              onPrimary: () => context.go('/app'),
                              onWhatsApp: () => _launchWhatsApp(config),
                            ),
                            const SizedBox(height: 52),
                            SectionHeader(
                              title: 'FAQ',
                              subtitle:
                                  'Respuestas rapidas para decidir sin dudas.',
                            ),
                            const SizedBox(height: 18),
                            const _FaqList(),
                            const SizedBox(height: 36),
                            _Footer(config: config),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _launchWhatsApp(AppConfig config) async {
    final raw = config.contactWhatsApp.trim();
    if (raw.isEmpty) return;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    final text = config.whatsappMessage.trim();
    final uri = Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(text.isEmpty ? 'Hola' : text)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> _launchEmail(AppConfig config) async {
    final mail = config.contactEmail.trim();
    if (mail.isEmpty) return;
    final uri = Uri(
      scheme: 'mailto',
      path: mail,
      queryParameters: const <String, String>{
        'subject': 'Consulta Bit Flow',
      },
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _TopNav extends StatelessWidget {
  const _TopNav({
    required this.brand,
    required this.onToggleTheme,
  });

  final String brand;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return AppTopBar(
      title: brand,
      subtitle: 'Planillas de campo offline',
      leading: Icon(
        Icons.grid_view_rounded,
        color: context.tokens.colors.textPrimary,
        size: 20,
      ),
      actions: [
        AppButton(
          label: 'Probar ahora',
          variant: AppButtonVariant.primary,
          onPressed: () => context.go('/app'),
        ),
        AppButton(
          label: 'Modo',
          variant: AppButtonVariant.ghost,
          onPressed: onToggleTheme,
        ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.config,
    required this.onPrimary,
    required this.onWhatsApp,
    required this.onEmail,
  });

  final AppConfig config;
  final VoidCallback onPrimary;
  final VoidCallback onWhatsApp;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final wide = constraints.maxWidth > 880;
        return Flex(
          direction: wide ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: wide ? 6 : 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planillas de campo con evidencias en un solo lugar',
                    style: t.text.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    config.brandTagline.isNotEmpty
                        ? config.brandTagline
                        : 'Registros, fotos, audio y GPS con exportacion inmediata. Todo offline, listo para auditorias.',
                    style: t.text.bodyLarge?.copyWith(
                      color: t.colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      AppButton(
                        label: 'Probar ahora',
                        variant: AppButtonVariant.primary,
                        onPressed: onPrimary,
                      ),
                      if (config.contactWhatsApp.trim().isNotEmpty)
                        AppButton(
                          label: 'WhatsApp',
                          variant: AppButtonVariant.secondary,
                          onPressed: onWhatsApp,
                        ),
                      AppButton(
                        label: 'Email',
                        variant: AppButtonVariant.ghost,
                        onPressed: onEmail,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: const [
                      _Tag('Offline real'),
                      _Tag('Backup ZIP'),
                      _Tag('Reporte imprimible'),
                      _Tag('Sin servidores'),
                    ],
                  ),
                ],
              ),
            ),
            if (wide) const SizedBox(width: 26),
            if (wide)
              Expanded(
                flex: 5,
                child: _PreviewCard(),
              ),
            if (!wide) ...[
              const SizedBox(height: 24),
              const _PreviewCard(),
            ],
          ],
        );
      },
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vista rapida',
            style: t.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: t.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(t.radii.lg),
              border: Border.all(color: t.colors.border),
            ),
            child: Center(
              child: Text(
                'Dashboard + grilla + evidencias',
                style: t.text.bodyMedium?.copyWith(
                  color: t.colors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tu equipo ve la misma informacion, con trazabilidad y exportacion inmediata.',
            style: t.text.bodyMedium?.copyWith(
              color: t.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final wide = constraints.maxWidth > 900;
        final cards = [
          const _BenefitCard(
            title: 'Evidencias por celda',
            desc: 'Fotos, audio y GPS vinculados a cada registro.',
            icon: Icons.photo_camera_back_outlined,
          ),
          const _BenefitCard(
            title: 'Offline real',
            desc: 'Funciona sin internet. Exporta e importa cuando quieras.',
            icon: Icons.offline_bolt_outlined,
          ),
          const _BenefitCard(
            title: 'Reporte listo',
            desc: 'HTML imprimible con evidencias para auditorias.',
            icon: Icons.picture_as_pdf_outlined,
          ),
          const _BenefitCard(
            title: 'Estandar operativo',
            desc: 'Procesos claros, menos errores y mas trazabilidad.',
            icon: Icons.rule_folder_outlined,
          ),
          const _BenefitCard(
            title: 'Sin servidores',
            desc: 'Control total. Datos en tu equipo, sin costos ocultos.',
            icon: Icons.cloud_off_outlined,
          ),
          const _BenefitCard(
            title: 'Escala local',
            desc: 'Multiples proyectos, carpetas y backups confiables.',
            icon: Icons.grid_view_rounded,
          ),
        ];

        if (wide) {
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: cards.map((c) => SizedBox(width: 360, child: c)).toList(),
          );
        }
        return Column(
          children: [
            for (final c in cards) ...[c, const SizedBox(height: 14)],
          ],
        );
      },
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.title,
    required this.desc,
    required this.icon,
  });

  final String title;
  final String desc;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: t.colors.accent),
          const SizedBox(height: 12),
          Text(
            title,
            style: t.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: t.text.bodyMedium?.copyWith(color: t.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final wide = constraints.maxWidth > 900;
        final cards = const [
          _StepCard(
            index: '01',
            title: 'Crea un proyecto',
            desc: 'Define columnas y equipos. Todo queda ordenado.',
          ),
          _StepCard(
            index: '02',
            title: 'Carga y evidencia',
            desc: 'Edita la grilla y adjunta fotos o audio por celda.',
          ),
          _StepCard(
            index: '03',
            title: 'Exporta y entrega',
            desc: 'Backup ZIP y reporte imprimible listo para auditorias.',
          ),
        ];
        if (wide) {
          return Row(
            children: [
              for (final c in cards) ...[
                Expanded(child: c),
                if (c != cards.last) const SizedBox(width: 16),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (final c in cards) ...[c, const SizedBox(height: 14)],
          ],
        );
      },
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.index,
    required this.title,
    required this.desc,
  });

  final String index;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            index,
            style: t.text.labelLarge?.copyWith(
              color: t.colors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: t.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: t.text.bodyMedium?.copyWith(color: t.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _UseCases extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cases = const [
      _UseCaseCard(
        title: 'Municipal y obras',
        desc: 'Inspecciones, avances y evidencias por cuadrilla.',
      ),
      _UseCaseCard(
        title: 'Mantenimiento',
        desc: 'Rutinas, checklists y anexos fotografiados.',
      ),
      _UseCaseCard(
        title: 'Logistica y flota',
        desc: 'Control de entregas, incidencias y trazas.',
      ),
      _UseCaseCard(
        title: 'Salud y seguridad',
        desc: 'Registros diarios con fotos y firmas digitales.',
      ),
    ];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final wide = constraints.maxWidth > 900;
        if (wide) {
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: cases.map((c) => SizedBox(width: 260, child: c)).toList(),
          );
        }
        return Column(
          children: [
            for (final c in cases) ...[c, const SizedBox(height: 14)],
          ],
        );
      },
    );
  }
}

class _UseCaseCard extends StatelessWidget {
  const _UseCaseCard({required this.title, required this.desc});

  final String title;
  final String desc;

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
          const SizedBox(height: 6),
          Text(
            desc,
            style: t.text.bodyMedium?.copyWith(color: t.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Pricing extends StatelessWidget {
  const _Pricing({required this.config, required this.onPrimary});

  final AppConfig config;
  final VoidCallback onPrimary;

  String _pick(String value, String fallback) {
    final v = value.trim();
    return v.isEmpty ? fallback : v;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final wide = constraints.maxWidth > 900;
        final cards = [
          _PriceCard(
            title: 'Basic',
            price: _pick(config.pricingBasic, 'Licencia local'),
            features: const [
              '1 proyecto activo',
              'Adjuntos limitados',
              'Export ZIP manual',
              'Soporte por email',
            ],
          ),
          _PriceCard(
            title: 'Pro',
            price: _pick(config.pricingPro, 'Operaciones completas'),
            features: const [
              'Proyectos ilimitados',
              'Export ZIP + HTML',
              'Plantillas y carpetas',
              'Soporte prioritario',
            ],
            highlight: true,
          ),
          _PriceCard(
            title: 'Enterprise',
            price: _pick(config.pricingEnterprise, 'A medida'),
            features: const [
              'Capacitacion in-company',
              'Branding y templates',
              'Soporte dedicado',
              'SLA y actualizaciones',
            ],
          ),
          const _PriceCard(
            title: 'Soporte',
            price: 'Licencia + soporte',
            features: [
              'Mesa de ayuda dedicada',
              'Actualizaciones planificadas',
              'Buenas practicas operativas',
              'Acompanamiento continuo',
            ],
          ),
        ];

        final list = wide
            ? Wrap(
                spacing: 16,
                runSpacing: 16,
                children:
                    cards.map((c) => SizedBox(width: 260, child: c)).toList(),
              )
            : Column(
                children: [
                  for (final c in cards) ...[c, const SizedBox(height: 14)],
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            list,
            if (config.pricingNote.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                config.pricingNote,
                style: context.tokens.text.bodySmall?.copyWith(
                  color: context.tokens.colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 18),
            AppButton(
              label: 'Probar Bit Flow',
              variant: AppButtonVariant.primary,
              onPressed: onPrimary,
            ),
          ],
        );
      },
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.title,
    required this.price,
    required this.features,
    this.highlight = false,
  });

  final String title;
  final String price;
  final List<String> features;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      padding: const EdgeInsets.all(18),
      borderColor: highlight ? t.colors.accent : t.colors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: t.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            price,
            style: t.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $f',
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

class _CtaBand extends StatelessWidget {
  const _CtaBand({
    required this.showWhatsApp,
    required this.onPrimary,
    required this.onWhatsApp,
  });

  final bool showWhatsApp;
  final VoidCallback onPrimary;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final wide = constraints.maxWidth > 720;
          return Flex(
            direction: wide ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Listo para ordenar tu operacion?',
                      style: t.text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Instalacion local en minutos. Sin servidores, sin friccion.',
                      style: t.text.bodyMedium?.copyWith(
                        color: t.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14, width: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  AppButton(
                    label: 'Probar ahora',
                    variant: AppButtonVariant.primary,
                    onPressed: onPrimary,
                  ),
                  if (showWhatsApp)
                    AppButton(
                      label: 'WhatsApp',
                      variant: AppButtonVariant.secondary,
                      onPressed: onWhatsApp,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FaqList extends StatelessWidget {
  const _FaqList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _FaqItem(
          q: 'Necesito servidor o internet?',
          a: 'No. Funciona local. Solo necesitas internet para enviar o imprimir.',
        ),
        SizedBox(height: 12),
        _FaqItem(
          q: 'Se puede migrar desde Excel?',
          a: 'Si. Copias y pegas columnas o importas planillas existentes.',
        ),
        SizedBox(height: 12),
        _FaqItem(
          q: 'Que pasa si se llena el almacenamiento?',
          a: 'La app avisa y recomienda exportar backup y limpiar adjuntos.',
        ),
      ],
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.q, required this.a});

  final String q;
  final String a;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q,
            style: t.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            a,
            style: t.text.bodyMedium?.copyWith(color: t.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: t.colors.border),
        const SizedBox(height: 16),
        Wrap(
          spacing: 18,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              config.brandName.isEmpty ? 'Bit Flow' : config.brandName,
              style: t.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'Soporte: ${config.contactEmail.isEmpty ? 'soporte@bitflow.app' : config.contactEmail}',
              style: t.text.bodySmall?.copyWith(color: t.colors.textSecondary),
            ),
            Text(
              BuildInfo.stamp,
              style: t.text.bodySmall?.copyWith(color: t.colors.textSecondary),
            ),
            TextButton(
              onPressed: () => context.go('/privacy'),
              child: const Text('Privacidad'),
            ),
            TextButton(
              onPressed: () => context.go('/terms'),
              child: const Text('Terminos'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(t.radii.pill),
        border: Border.all(color: t.colors.border),
      ),
      child: Text(
        label,
        style: t.text.labelLarge?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
