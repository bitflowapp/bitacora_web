import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({
    super.key,
    required this.isLight,
    required this.onToggleTheme,
  });

  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  static const String _contactEmail = String.fromEnvironment(
    'CONTACT_EMAIL',
    defaultValue: 'ventas@bitflow.app',
  );
  static const String _contactWhatsApp = String.fromEnvironment(
    'CONTACT_WHATSAPP',
    defaultValue: '',
  );
  static const String _whatsappMessage = String.fromEnvironment(
    'WHATSAPP_MESSAGE',
    defaultValue:
        'Hola! Quiero ver Bit Flow para relevamientos tecnicos de campo.',
  );

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _salesPhone => _contactWhatsApp.replaceAll(RegExp(r'[^0-9]'), '');

  bool get _hasWhatsApp => _salesPhone.isNotEmpty;

  Future<void> _openSalesContact() async {
    final phone = _salesPhone;
    if (phone.isEmpty) {
      await _openEmail();
      return;
    }
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(_whatsappMessage)}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _showSnack('No se pudo abrir WhatsApp. Copie el email al portapapeles.');
      await _copyEmail(showMessage: false);
    }
  }

  Future<void> _openEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      queryParameters: const <String, String>{
        'subject': 'Demo Bit Flow',
        'body':
            'Hola! Quiero ver Bit Flow para relevamientos tecnicos de campo.',
      },
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      await _copyEmail();
    }
  }

  Future<void> _copyEmail({bool showMessage = true}) async {
    await Clipboard.setData(const ClipboardData(text: _contactEmail));
    if (!mounted || !showMessage) return;
    _showSnack('Email de ventas copiado: $_contactEmail');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isWide = media.size.width >= 920;
    final palette = _LandingPalette.from(widget.isLight);
    final salesChannelLabel = _hasWhatsApp ? 'WhatsApp ventas' : 'Email ventas';
    void openPcDemo()     => context.go('/?template=proteccion-catodica');

    return Scaffold(
      backgroundColor: palette.pageBg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 48 : 20,
                vertical: 28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TopBar(
                        palette: palette,
                        isLight: widget.isLight,
                        onToggleTheme: widget.onToggleTheme,
                        onContact: _openSalesContact,
                      ),
                      const SizedBox(height: 36),
                      _Hero(
                        palette: palette,
                        isWide: isWide,
                        salesChannelLabel: salesChannelLabel,
                        onOpenDemo: openPcDemo,
                        onOpenApp: () => context.go('/app'),
                        onContact: _openSalesContact,
                      ),
                      const SizedBox(height: 48),
                      _VerticalStrip(palette: palette, isWide: isWide),
                      const SizedBox(height: 48),
                      _Benefits(palette: palette, isWide: isWide),
                      const SizedBox(height: 48),
                      _ComparisonTable(palette: palette, isWide: isWide),
                      const SizedBox(height: 48),
                      _Pricing(
                        palette: palette,
                        isWide: isWide,
                        onContact: _openSalesContact,
                        onOpenDemo: openPcDemo,
                      ),
                      const SizedBox(height: 48),
                      _FooterCTA(
                        palette: palette,
                        isWide: isWide,
                        salesChannelLabel: salesChannelLabel,
                        onContact: _openSalesContact,
                        onCopyEmail: _copyEmail,
                      ),
                      const SizedBox(height: 24),
                      _Legal(palette: palette),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingPalette {
  const _LandingPalette({
    required this.pageBg,
    required this.cardBg,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentSoft,
    required this.accentContrast,
    required this.divider,
  });

  final Color pageBg;
  final Color cardBg;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color accentSoft;
  final Color accentContrast;
  final Color divider;

  factory _LandingPalette.from(bool isLight) {
    if (isLight) {
      return const _LandingPalette(
        pageBg: Color(0xFFF6F8FB),
        cardBg: Colors.white,
        cardBorder: Color(0xFFE3E7EE),
        textPrimary: Color(0xFF0F172A),
        textSecondary: Color(0xFF4B5563),
        accent: Color(0xFF0B63CE),
        accentSoft: Color(0x140B63CE),
        accentContrast: Colors.white,
        divider: Color(0xFFE5E7EB),
      );
    }
    return const _LandingPalette(
      pageBg: Color(0xFF0B0D1A),
      cardBg: Color(0xFF111528),
      cardBorder: Color(0x22FFFFFF),
      textPrimary: Color(0xFFF5F7FB),
      textSecondary: Color(0xFFAAB2C0),
      accent: Color(0xFF3B82F6),
      accentSoft: Color(0x263B82F6),
      accentContrast: Colors.white,
      divider: Color(0x22FFFFFF),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.palette,
    required this.isLight,
    required this.onToggleTheme,
    required this.onContact,
  });

  final _LandingPalette palette;
  final bool isLight;
  final VoidCallback onToggleTheme;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        _GhostButton(
          label: isLight ? 'Noche' : 'Dia',
          palette: palette,
          onPressed: onToggleTheme,
        ),
        _SolidButton(
          label: 'Hablar con ventas',
          palette: palette,
          onPressed: onContact,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BrandMark(palette: palette),
              const SizedBox(height: 14),
              actions,
            ],
          );
        }
        return Row(
          children: [
            _BrandMark(palette: palette),
            const Spacer(),
            actions,
          ],
        );
      },
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.palette});

  final _LandingPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: palette.accent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: palette.accent.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Text(
          'Bit Flow',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.palette,
    required this.isWide,
    required this.salesChannelLabel,
    required this.onOpenDemo,
    required this.onOpenApp,
    required this.onContact,
  });

  final _LandingPalette palette;
  final bool isWide;
  final String salesChannelLabel;
  final VoidCallback onOpenDemo;
  final VoidCallback onOpenApp;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: palette.accentSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Para equipos de ingenieria en campo',
            style: TextStyle(
              color: palette.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Del campo al informe, sin pasar por la oficina.',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: isWide ? 44 : 32,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Bit Flow es la planilla de relevamientos para proteccion catodica, '
          'puesta a tierra y mediciones tecnicas. Cada celda lleva foto, GPS '
          'y audio firmados. Exporta Excel con fotos embebidas, PDF y ZIP. '
          'Funciona sin conexion y sincroniza solo cuando vuelve la senal.',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: isWide ? 17 : 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SolidButton(
              label: 'Abrir demo',
              palette: palette,
              onPressed: onOpenDemo,
              icon: Icons.play_arrow_rounded,
              large: true,
            ),
            _GhostButton(
              label: 'Entrar a la app',
              palette: palette,
              onPressed: onOpenApp,
              icon: Icons.login_rounded,
              large: true,
            ),
            _GhostButton(
              label: salesChannelLabel,
              palette: palette,
              onPressed: onContact,
              icon: Icons.chat_rounded,
              large: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              Icons.shield_outlined,
              size: 16,
              color: palette.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Offline-first  -  Excel / PDF / ZIP  -  GPS + foto + audio por celda',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    final heroPreview = _HeroPreview(palette: palette);

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          textBlock,
          const SizedBox(height: 24),
          heroPreview,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: textBlock),
        const SizedBox(width: 40),
        Expanded(flex: 5, child: heroPreview),
      ],
    );
  }
}

class _HeroPreview extends StatelessWidget {
  const _HeroPreview({required this.palette});

  final _LandingPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.grid_view_rounded,
                    color: palette.accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Relevamiento PC - Gasoducto Norte',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F7EC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'sincronizado',
                    style: TextStyle(
                      color: Color(0xFF137D3B),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: palette.divider),
            const SizedBox(height: 12),
            _PreviewRow(
              palette: palette,
              progresiva: '12+000',
              on: '-1.12',
              off: '-0.92',
              cupon: 'Polarizado',
              estado: 'OK',
              hasPhoto: true,
            ),
            const SizedBox(height: 8),
            _PreviewRow(
              palette: palette,
              progresiva: '12+025',
              on: '-1.08',
              off: '-0.88',
              cupon: 'Polarizado',
              estado: 'OK',
              hasPhoto: true,
            ),
            const SizedBox(height: 8),
            _PreviewRow(
              palette: palette,
              progresiva: '12+050',
              on: '-0.82',
              off: '-0.61',
              cupon: 'Despolarizado',
              estado: 'Obs',
              hasPhoto: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.download_rounded,
                    size: 16, color: palette.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Exportar Excel con fotos  -  PDF firmado  -  ZIP backup',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.palette,
    required this.progresiva,
    required this.on,
    required this.off,
    required this.cupon,
    required this.estado,
    required this.hasPhoto,
  });

  final _LandingPalette palette;
  final String progresiva;
  final String on;
  final String off;
  final String cupon;
  final String estado;
  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    final isObs = estado.toLowerCase() != 'ok';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: palette.pageBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _PreviewCell(
              label: 'Prog', value: progresiva, palette: palette, flex: 3),
          _PreviewCell(label: 'ON', value: on, palette: palette, flex: 2),
          _PreviewCell(label: 'OFF', value: off, palette: palette, flex: 2),
          _PreviewCell(label: 'Cupon', value: cupon, palette: palette, flex: 3),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasPhoto) ...[
                  Icon(Icons.photo_camera_rounded,
                      size: 14, color: palette.textSecondary),
                  const SizedBox(width: 4),
                  Icon(Icons.place_rounded,
                      size: 14, color: palette.textSecondary),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isObs
                        ? const Color(0xFFFFF1CC)
                        : const Color(0xFFE7F7EC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    estado,
                    style: TextStyle(
                      color: isObs
                          ? const Color(0xFF8A5A00)
                          : const Color(0xFF137D3B),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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

class _PreviewCell extends StatelessWidget {
  const _PreviewCell({
    required this.label,
    required this.value,
    required this.palette,
    required this.flex,
  });

  final String label;
  final String value;
  final _LandingPalette palette;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 10,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalStrip extends StatelessWidget {
  const _VerticalStrip({required this.palette, required this.isWide});

  final _LandingPalette palette;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final items = const <(IconData icon, String title, String subtitle)>[
      (
        Icons.bolt_rounded,
        'Proteccion catodica',
        'ON/OFF, IR drop, cupon polarizado, evidencia por progresiva.',
      ),
      (
        Icons.electrical_services_rounded,
        'Puesta a tierra',
        'Resistividad de suelo Wenner/Schlumberger, continuidad, malla.',
      ),
      (
        Icons.settings_input_antenna_rounded,
        'Inspeccion tecnica',
        'Gasoducto, oleoducto, subestacion. Firma de revisor al cierre.',
      ),
      (
        Icons.engineering_rounded,
        'Mediciones tecnicas',
        'Continuidad, interferencias, puntos criticos y evidencia con GPS.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          palette: palette,
          eyebrow: 'Verticales iniciales',
          title: 'Disenado para relevamientos tecnicos de campo.',
        ),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final cols = isWide ? 4 : (constraints.maxWidth < 520 ? 1 : 2);
          final gap = 14.0;
          final cellWidth =
              (constraints.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final item in items)
                SizedBox(
                  width: cellWidth,
                  child: _VerticalCard(
                    palette: palette,
                    icon: item.$1,
                    title: item.$2,
                    subtitle: item.$3,
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _VerticalCard extends StatelessWidget {
  const _VerticalCard({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final _LandingPalette palette;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: palette.accent, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits({required this.palette, required this.isWide});

  final _LandingPalette palette;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final items = const <(IconData, String, String)>[
      (
        Icons.sensors_rounded,
        'Evidencia pegada al dato',
        'Foto, audio y GPS atados a la celda de la progresiva medida.',
      ),
      (
        Icons.description_rounded,
        'Excel que no se rompe',
        'XLSX con fotos embebidas + hoja Attachments + manifest ZIP.',
      ),
      (
        Icons.cloud_off_rounded,
        'Offline real',
        'IndexedDB + cola de sync. La senal vuelve, el dato se va.',
      ),
      (
        Icons.rule_rounded,
        'Validacion antes de firmar',
        'Reglas por columna: requerido, rango, enum, regex.',
      ),
      (
        Icons.mic_none_rounded,
        'Dicta y ordena',
        'Comandos de voz: "marcar urgente", "autonumerar", "rellenar listo x 3".',
      ),
      (
        Icons.workspace_premium_rounded,
        'Firma de revisor',
        'Metadata RevisadoPor / RevisadoEn en el informe final.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          palette: palette,
          eyebrow: 'Por que Bit Flow',
          title: 'Lo que un tecnico necesita en campo, y un supervisor al cerrar.',
        ),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final cols = isWide ? 3 : (constraints.maxWidth < 520 ? 1 : 2);
          final gap = 14.0;
          final cellWidth =
              (constraints.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final item in items)
                SizedBox(
                  width: cellWidth,
                  child: _BenefitCard(
                    palette: palette,
                    icon: item.$1,
                    title: item.$2,
                    subtitle: item.$3,
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final _LandingPalette palette;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: palette.accent, size: 22),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.palette, required this.isWide});

  final _LandingPalette palette;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final rows = const <(String, bool, bool, bool)>[
      ('Foto + GPS + medicion en un solo registro', false, false, true),
      ('Funciona sin senal', false, false, true),
      ('Validacion por columna (numero, rango, enum)', false, true, true),
      ('XLSX con fotos embebidas', false, false, true),
      ('PDF firmado por revisor', false, false, true),
      ('ZIP backup restaurable', false, false, true),
    ];

    return Container(
      padding: EdgeInsets.all(isWide ? 22 : 16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            palette: palette,
            eyebrow: 'Comparativa honesta',
            title: 'Por que no alcanza con Excel, WhatsApp o Google Forms.',
          ),
          const SizedBox(height: 16),
          _CompareHeader(palette: palette),
          Divider(height: 1, color: palette.divider),
          for (final r in rows) ...[
            _CompareRow(
              palette: palette,
              label: r.$1,
              excel: r.$2,
              forms: r.$3,
              bitflow: r.$4,
            ),
            Divider(height: 1, color: palette.divider),
          ],
        ],
      ),
    );
  }
}

class _CompareHeader extends StatelessWidget {
  const _CompareHeader({required this.palette});

  final _LandingPalette palette;

  @override
  Widget build(BuildContext context) {
    TextStyle style(Color c) => TextStyle(
          color: c,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text('CAPACIDAD', style: style(palette.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text('EXCEL + WA', style: style(palette.textSecondary)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text('G. FORMS', style: style(palette.textSecondary)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text('BIT FLOW', style: style(palette.accent)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.palette,
    required this.label,
    required this.excel,
    required this.forms,
    required this.bitflow,
  });

  final _LandingPalette palette;
  final String label;
  final bool excel;
  final bool forms;
  final bool bitflow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(flex: 2, child: Center(child: _CheckMark(on: excel))),
          Expanded(flex: 2, child: Center(child: _CheckMark(on: forms))),
          Expanded(
            flex: 2,
            child: Center(
              child: _CheckMark(on: bitflow, strong: true, palette: palette),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckMark extends StatelessWidget {
  const _CheckMark({
    required this.on,
    this.strong = false,
    this.palette,
  });

  final bool on;
  final bool strong;
  final _LandingPalette? palette;

  @override
  Widget build(BuildContext context) {
    if (!on) {
      return const Text(
        '-',
        style: TextStyle(
          color: Color(0xFFB0B7C3),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    final c = strong ? (palette?.accent ?? const Color(0xFF0B63CE))
        : const Color(0xFF137D3B);
    return Icon(Icons.check_rounded, color: c, size: 20);
  }
}

class _Pricing extends StatelessWidget {
  const _Pricing({
    required this.palette,
    required this.isWide,
    required this.onContact,
    required this.onOpenDemo,
  });

  final _LandingPalette palette;
  final bool isWide;
  final VoidCallback onContact;
  final VoidCallback onOpenDemo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          palette: palette,
          eyebrow: 'Como se compra',
          title: 'Piloto pago acotado. Licencia por equipo. O a medida.',
        ),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final cols = isWide ? 3 : (constraints.maxWidth < 560 ? 1 : 2);
          final gap = 14.0;
          final cellWidth =
              (constraints.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(
                width: cellWidth,
                child: _PricingCard(
                  palette: palette,
                  title: 'Piloto 30 dias',
                  price: 'Precio cerrado',
                  description:
                      '1 proyecto. Hasta 3 tecnicos. Templates PC + Puesta a tierra. Soporte chat.',
                  ctaLabel: 'Agendar piloto',
                  onCta: onContact,
                  bullets: const [
                    'Setup guiado en 1 taller de 2 hs',
                    'Entregable XLSX + PDF listo',
                    'Devuelvo licencia si no sirve',
                  ],
                ),
              ),
              SizedBox(
                width: cellWidth,
                child: _PricingCard(
                  palette: palette,
                  title: 'Equipo de campo',
                  price: 'Mensual',
                  description:
                      'Usuarios ilimitados dentro de la empresa. Plantillas custom. PDF con logo del cliente.',
                  ctaLabel: 'Ver demo',
                  onCta: onOpenDemo,
                  highlight: true,
                  bullets: const [
                    'Todas las templates tecnicas',
                    'Backup ZIP + restore verificado',
                    'Soporte email 24-48 hs',
                  ],
                ),
              ),
              SizedBox(
                width: cellWidth,
                child: _PricingCard(
                  palette: palette,
                  title: 'A medida',
                  price: 'A cotizar',
                  description:
                      'Integracion con SGI/SharePoint/API. Capacitacion on-site. SLA.',
                  ctaLabel: 'Hablar con ventas',
                  onCta: onContact,
                  bullets: const [
                    'Templates exclusivas por cliente',
                    'API REST para Power BI / SAP',
                    'SLA de respuesta acordado',
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.palette,
    required this.title,
    required this.price,
    required this.description,
    required this.ctaLabel,
    required this.onCta,
    required this.bullets,
    this.highlight = false,
  });

  final _LandingPalette palette;
  final String title;
  final String price;
  final String description;
  final String ctaLabel;
  final VoidCallback onCta;
  final List<String> bullets;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final borderColor = highlight ? palette.accent : palette.cardBorder;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: highlight ? 1.4 : 1,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (highlight) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'mas vendido',
                    style: TextStyle(
                      color: palette.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            price,
            style: TextStyle(
              color: palette.accent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 16, color: palette.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          _SolidButton(
            label: ctaLabel,
            palette: palette,
            onPressed: onCta,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

class _FooterCTA extends StatelessWidget {
  const _FooterCTA({
    required this.palette,
    required this.isWide,
    required this.salesChannelLabel,
    required this.onContact,
    required this.onCopyEmail,
  });

  final _LandingPalette palette;
  final bool isWide;
  final String salesChannelLabel;
  final VoidCallback onContact;
  final VoidCallback onCopyEmail;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hablemos 15 minutos.',
          style: TextStyle(
            color: palette.accentContrast,
            fontSize: isWide ? 26 : 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Contame tu flujo de relevamiento y te muestro Bit Flow con un caso tuyo real.',
          style: TextStyle(
            color: palette.accentContrast.withValues(alpha: 0.92),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        TextButton.icon(
          onPressed: onContact,
          icon: Icon(
            salesChannelLabel.startsWith('WhatsApp')
                ? Icons.chat_rounded
                : Icons.mail_outline_rounded,
          ),
          label: Text(salesChannelLabel),
          style: TextButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: palette.accent,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        TextButton.icon(
          onPressed: onCopyEmail,
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copiar email'),
          style: TextButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            foregroundColor: palette.accentContrast,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color: palette.accentContrast.withValues(alpha: 0.4),
              ),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(isWide ? 28 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.accent,
            palette.accent.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: copy),
                const SizedBox(width: 20),
                actions,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: 18),
                actions,
              ],
            ),
    );
  }
}

class _Legal extends StatelessWidget {
  const _Legal({required this.palette});

  final _LandingPalette palette;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: palette.textSecondary,
      fontSize: 12,
    );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        Text('(c) Bit Flow', style: style),
        InkWell(
          onTap: () => context.go('/privacy'),
          child: Text('Privacidad', style: style),
        ),
        InkWell(
          onTap: () => context.go('/terms'),
          child: Text('Terminos', style: style),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.palette,
    required this.eyebrow,
    required this.title,
  });

  final _LandingPalette palette;
  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            color: palette.accent,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _SolidButton extends StatelessWidget {
  const _SolidButton({
    required this.label,
    required this.palette,
    required this.onPressed,
    this.icon,
    this.large = false,
    this.fullWidth = false,
  });

  final String label;
  final _LandingPalette palette;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool large;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final child = ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon == null
          ? const SizedBox.shrink()
          : Icon(icon, size: large ? 20 : 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: palette.accentContrast,
        padding: EdgeInsets.symmetric(
          horizontal: large ? 22 : 16,
          vertical: large ? 16 : 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        elevation: 0,
        textStyle: TextStyle(
          fontSize: large ? 15 : 14,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.1,
        ),
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: child) : child;
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    required this.palette,
    required this.onPressed,
    this.icon,
    this.large = false,
  });

  final String label;
  final _LandingPalette palette;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null
          ? const SizedBox.shrink()
          : Icon(icon, size: large ? 20 : 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textPrimary,
        side: BorderSide(color: palette.cardBorder),
        padding: EdgeInsets.symmetric(
          horizontal: large ? 20 : 14,
          vertical: large ? 16 : 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        textStyle: TextStyle(
          fontSize: large ? 15 : 14,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}
/*  */
