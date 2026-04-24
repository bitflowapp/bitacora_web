import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_config.dart';
import '../services/build_info.dart';
import '../ui/ui.dart';

const bool _kShowDebugBadge =
    bool.fromEnvironment('SHOW_DEBUG_BADGE', defaultValue: false) ||
        bool.fromEnvironment('SHOW_BUILD_BADGE', defaultValue: false);

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
        final tokens = context.tokens;
        final isLoading = snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData;

        if (isLoading) {
          return Scaffold(
            backgroundColor: tokens.colors.bg,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: const LoadingState(
                      message: 'Iniciando BitFlow...',
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final config = snapshot.data ?? AppConfig.defaults();
        final hasConfigError = snapshot.hasError;
        final hasContactChannels = config.contactEmail.trim().isNotEmpty ||
            config.contactWhatsApp.trim().isNotEmpty;

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
                          tokens.colors.surfaceMuted.withValues(alpha: 0.55),
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
                                  ? 'Bitacora'
                                  : config.brandName,
                              onToggleTheme: onToggleTheme,
                              isLight: isLight,
                            ),
                            if (hasConfigError) ...[
                              const SizedBox(height: 16),
                              AppErrorState(
                                compact: true,
                                title: 'Configuracion comercial incompleta',
                                message:
                                    'Se cargaron valores por defecto para no frenar la demo.',
                                actionLabel: 'Ir a la app',
                                onAction: () => context.go('/app'),
                              ),
                            ],
                            if (!hasContactChannels) ...[
                              const SizedBox(height: 16),
                              EmptyState(
                                title: 'Falta canal de contacto',
                                message:
                                    'Configura email o WhatsApp para recibir consultas desde la landing.',
                                actionLabel: 'Abrir aplicacion',
                                onAction: () => context.go('/app'),
                                icon: Icons.support_agent_outlined,
                              ),
                            ],
                            const SizedBox(height: 36),
                            _HeroSection(
                              config: config,
                              onPrimary: () => context.go('/app'),
                              onWhatsApp: () => _launchWhatsApp(config),
                              onEmail: () => _launchEmail(config),
                            ),
                            const SizedBox(height: 56),
                            SectionHeader(
                              title: 'Por qué equipos técnicos eligen BitFlow',
                              subtitle:
                                  'Control operativo con evidencia, sin servidores y sin fricción.',
                            ),
                            const SizedBox(height: 18),
                            _BenefitsGrid(),
                            const SizedBox(height: 48),
                            SectionHeader(
                              title: 'Cómo funciona',
                              subtitle:
                                  'Tres pasos para empezar a registrar hoy mismo.',
                            ),
                            const SizedBox(height: 18),
                            _HowItWorks(),
                            const SizedBox(height: 48),
                            SectionHeader(
                              title: 'Sectores que ya lo usan',
                              subtitle:
                                  'Diseñado para equipos de campo, inspecciones y control operativo.',
                            ),
                            const SizedBox(height: 18),
                            _UseCases(),
                            const SizedBox(height: 52),
                            SectionHeader(
                              title:
                                  'Licenciamiento simple, sin suscripción mensual',
                              subtitle:
                                  'Licencia local, instalación en minutos, soporte incluido.',
                            ),
                            const SizedBox(height: 18),
                            _Pricing(
                              config: config,
                              onPrimary: () => context.go('/app'),
                            ),
                            const SizedBox(height: 52),
                            _CtaBand(
                              onPrimary: () => context.go('/app'),
                              onWhatsApp: () => _launchWhatsApp(config),
                            ),
                            const SizedBox(height: 52),
                            SectionHeader(
                              title: 'Preguntas frecuentes',
                              subtitle: 'Respuestas rápidas antes de decidir.',
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
        'subject': 'Consulta Bitacora',
      },
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _TopNav extends StatelessWidget {
  const _TopNav({
    required this.brand,
    required this.onToggleTheme,
    required this.isLight,
  });

  final String brand;
  final VoidCallback onToggleTheme;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return AppTopBar(
      title: brand,
      subtitle: 'Bitácora operativa sin conexión',
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
          label: isLight ? 'Oscuro' : 'Claro',
          icon: isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
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
                    'Planillas técnicas con evidencias, offline y exportación inmediata',
                    style: t.text.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    config.brandTagline.isNotEmpty
                        ? config.brandTagline
                        : 'Relevamientos, inspecciones y checklists con fotos, audio y GPS. Sin conexión. Exportación XLSX y HTML lista para auditorías.',
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
                      _Tag('Sin internet'),
                      _Tag('Respaldo ZIP'),
                      _Tag('Informe HTML'),
                      _Tag('Sin servidor'),
                      _Tag('Exporta XLSX'),
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
            'Vista de planilla técnica',
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.table_chart_outlined,
                    size: 40,
                    color: t.colors.accent.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Grilla · Adjuntos · Exportación',
                    style: t.text.bodyMedium?.copyWith(
                      color: t.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Cada fila con fotos, audio y GPS. Exportación XLSX o informe HTML en un tap.',
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
            desc:
                'Fotos, audio y coordenadas GPS vinculadas a cada registro de campo.',
            icon: Icons.photo_camera_back_outlined,
          ),
          const _BenefitCard(
            title: 'Funciona sin internet',
            desc:
                'Opera offline en terreno. Exporta o importa cuando tengas señal.',
            icon: Icons.offline_bolt_outlined,
          ),
          const _BenefitCard(
            title: 'Informe listo para entregar',
            desc:
                'Reporte HTML imprimible con fotos y datos para auditorías o clientes.',
            icon: Icons.picture_as_pdf_outlined,
          ),
          const _BenefitCard(
            title: 'Estándar operativo',
            desc:
                'Procesos repetibles, menos errores humanos y trazabilidad completa.',
            icon: Icons.rule_folder_outlined,
          ),
          const _BenefitCard(
            title: 'Sin servidor, sin costo mensual',
            desc:
                'Todos los datos en tu equipo. Sin nube, sin suscripción, sin sorpresas.',
            icon: Icons.cloud_off_outlined,
          ),
          const _BenefitCard(
            title: 'Exporta XLSX directo',
            desc:
                'Planillas compatibles con Excel y Google Sheets. Sin conversión manual.',
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
            title: 'Elige o crea una plantilla',
            desc:
                'Inspección, relevamiento, checklist o planilla en blanco. Lista en segundos.',
          ),
          _StepCard(
            index: '02',
            title: 'Registra con evidencias',
            desc:
                'Completa la grilla de campo y adjunta fotos, audio o GPS por celda.',
          ),
          _StepCard(
            index: '03',
            title: 'Exporta y entrega',
            desc:
                'XLSX para el cliente y reporte HTML para la auditoría. Un tap, listo.',
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
        title: 'Obras y municipios',
        desc: 'Partes diarios, avance de frente y evidencias por cuadrilla.',
      ),
      _UseCaseCard(
        title: 'Mantenimiento industrial',
        desc: 'OT, checklists, rutinas preventivas y adjuntos fotográficos.',
      ),
      _UseCaseCard(
        title: 'Relevamientos técnicos',
        desc: 'Mediciones, resistividades, GPS y observaciones en terreno.',
      ),
      _UseCaseCard(
        title: 'HSE y calidad',
        desc:
            'Inspecciones de seguridad, registros con foto y trazabilidad de incidentes.',
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
              label: 'Probar Bitacora',
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
                '- $f',
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
    required this.onPrimary,
    required this.onWhatsApp,
  });

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
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Listo para reemplazar las planillas improvisadas?',
                style: t.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Instalación local en minutos. Sin servidores, sin fricción, sin costo mensual.',
                style: t.text.bodyMedium?.copyWith(
                  color: t.colors.textSecondary,
                ),
              ),
            ],
          );
          return Flex(
            direction: wide ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (wide) Expanded(child: intro) else intro,
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
          q: '¿Necesito servidor o conexión a internet?',
          a: 'No. Funciona completamente offline. Solo necesitas internet para enviar el informe o hacer backup.',
        ),
        SizedBox(height: 12),
        _FaqItem(
          q: '¿Se puede migrar desde Excel?',
          a: 'Sí. Podés copiar y pegar columnas o importar planillas existentes en formato CSV o XLSX.',
        ),
        SizedBox(height: 12),
        _FaqItem(
          q: '¿Qué pasa si necesito capacitar a mi equipo?',
          a: 'Ofrecemos capacitación in-company y soporte técnico. Los planes Enterprise incluyen acompañamiento dedicado.',
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
    final showDebugBadge = kDebugMode || _kShowDebugBadge;
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
              config.brandName.isEmpty ? 'Bitacora' : config.brandName,
              style: t.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'Soporte: ${config.contactEmail.isEmpty ? 'soporte@bitacora.local' : config.contactEmail}',
              style: t.text.bodySmall?.copyWith(color: t.colors.textSecondary),
            ),
            if (showDebugBadge)
              Text(
                BuildInfo.stamp,
                style:
                    t.text.bodySmall?.copyWith(color: t.colors.textSecondary),
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
