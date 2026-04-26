import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

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
        'subject': 'Demo Bit Flow para relevamientos tecnicos',
        'body':
            'Hola! Quiero evaluar Bit Flow para relevamientos tecnicos, evidencias y exportaciones.',
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
    final width = media.size.width;
    final isWide = width >= 980;
    final isCompact = width < 640;
    final palette = _LandingPalette.from(AppTheme.of(context));
    final salesChannelLabel = _hasWhatsApp ? 'WhatsApp ventas' : 'Email ventas';
    void openPcDemo() => context.go('/?template=proteccion-catodica');

    return Scaffold(
      backgroundColor: palette.pageBg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isWide ? 48 : 20,
                isCompact ? 18 : 28,
                isWide ? 48 : 20,
                24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: SizedBox(
                    width: double.infinity,
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
                          onOpenApp: () => context.go('/sheets'),
                          onContact: _openSalesContact,
                        ),
                        const SizedBox(height: 28),
                        _QuickStart(
                          palette: palette,
                          isWide: isWide,
                          onOpenDemo: openPcDemo,
                          onOpenApp: () => context.go('/sheets'),
                          onContact: _openSalesContact,
                          salesChannelLabel: salesChannelLabel,
                        ),
                        const SizedBox(height: 56),
                        _VerticalStrip(
                          palette: palette,
                          isWide: isWide,
                          onOpenDemo: openPcDemo,
                          onOpenApp: () => context.go('/sheets'),
                        ),
                        const SizedBox(height: 56),
                        _Benefits(palette: palette, isWide: isWide),
                        const SizedBox(height: 56),
                        _Workflow(palette: palette, isWide: isWide),
                        const SizedBox(height: 56),
                        _ComparisonTable(palette: palette, isWide: isWide),
                        const SizedBox(height: 56),
                        _Pricing(
                          palette: palette,
                          isWide: isWide,
                          onContact: _openSalesContact,
                          onOpenDemo: openPcDemo,
                        ),
                        const SizedBox(height: 56),
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
      ),
    );
  }
}

class _LandingPalette {
  const _LandingPalette({
    required this.pageBg,
    required this.cardBg,
    required this.elevatedBg,
    required this.chromeBg,
    required this.ghostButtonBg,
    required this.cardBorder,
    required this.cardBorderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.accentOutline,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.accentContrast,
    required this.featureBg,
    required this.featureFg,
    required this.featureFgMuted,
    required this.featureIconBg,
    required this.divider,
    required this.shadow,
  });

  final Color pageBg;
  final Color cardBg;
  final Color elevatedBg;
  final Color chromeBg;
  final Color ghostButtonBg;
  final Color cardBorder;
  final Color cardBorderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentSoft;
  final Color accentOutline;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color accentContrast;
  final Color featureBg;
  final Color featureFg;
  final Color featureFgMuted;
  final Color featureIconBg;
  final Color divider;
  final Color shadow;

  factory _LandingPalette.from(AppThemeData theme) {
    final colors = theme.colors;
    final onAccent = theme.material.colorScheme.onPrimary;
    return _LandingPalette(
      pageBg: colors.surfaceMuted,
      cardBg: colors.surface,
      elevatedBg: colors.surfaceElevated,
      chromeBg: colors.surface.withValues(alpha: colors.isLight ? 0.82 : 0.76),
      ghostButtonBg: colors.surfaceElevated
          .withValues(alpha: colors.isLight ? 0.88 : 0.82),
      cardBorder: colors.border,
      cardBorderStrong: colors.borderStrong.withValues(
        alpha: colors.isLight ? 0.72 : 0.66,
      ),
      textPrimary: colors.textPrimary,
      textSecondary: colors.textSecondary,
      textMuted: colors.textSecondary.withValues(
        alpha: colors.isLight ? 0.58 : 0.74,
      ),
      accent: colors.accent,
      accentSoft: colors.accentMuted,
      accentOutline: colors.accent.withValues(
        alpha: colors.isLight ? 0.16 : 0.28,
      ),
      success: colors.successFg,
      successSoft: colors.successBg,
      warning: colors.warningFg,
      warningSoft: colors.warningBg,
      accentContrast: onAccent,
      featureBg: colors.accent,
      featureFg: onAccent,
      featureFgMuted: onAccent.withValues(alpha: 0.82),
      featureIconBg: onAccent.withValues(alpha: colors.isLight ? 0.16 : 0.20),
      divider: colors.border,
      shadow: theme.shadows.floating.first.color,
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
          label: 'Contactar ventas',
          palette: palette,
          onPressed: onContact,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return _TopBarShell(
            palette: palette,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BrandMark(palette: palette),
                const SizedBox(height: 14),
                actions,
              ],
            ),
          );
        }
        return _TopBarShell(
          palette: palette,
          child: Row(
            children: [
              _BrandMark(palette: palette),
              const Spacer(),
              actions,
            ],
          ),
        );
      },
    );
  }
}

class _TopBarShell extends StatelessWidget {
  const _TopBarShell({required this.palette, required this.child});

  final _LandingPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.chromeBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorderStrong),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
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
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.grid_view_rounded,
            color: palette.accentContrast,
            size: 22,
          ),
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
        _Eyebrow(
          palette: palette,
          icon: Icons.engineering_rounded,
          label: 'Planillas operativas para campo, inspección y mantenimiento',
        ),
        const SizedBox(height: 18),
        Text(
          'Relevamientos tecnicos con evidencias, listos para entregar.',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: isWide ? 58 : 38,
            height: 0.98,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Bit Flow convierte datos de campo y oficina en planillas tecnicas '
          'claras. Registra mediciones, fotos, GPS, notas y responsables; '
          'despues exporta XLSX, PDF o backup ZIP sin rehacer el trabajo.',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: isWide ? 18 : 15.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SolidButton(
              label: 'Abrir Bit Flow',
              palette: palette,
              onPressed: onOpenApp,
              icon: Icons.arrow_forward_rounded,
              large: true,
            ),
            _GhostButton(
              label: 'Abrir demo técnica',
              palette: palette,
              onPressed: onOpenDemo,
              icon: Icons.play_arrow_rounded,
              large: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _TrustChip(palette: palette, label: 'Inspección técnica'),
            _TrustChip(palette: palette, label: 'Mantenimiento'),
            _TrustChip(palette: palette, label: 'Evidencias + GPS'),
            _TrustChip(palette: palette, label: 'Exportacion profesional'),
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

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({
    required this.palette,
    required this.icon,
    required this.label,
  });

  final _LandingPalette palette;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.elevatedBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: palette.accent),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.palette, required this.label});

  final _LandingPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.accentOutline),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
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
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 38,
            offset: const Offset(0, 26),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    color: palette.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inspección técnica — Planta Norte',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '4 mediciones listas para revisar',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.successSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'sincronizado',
                    style: TextStyle(
                      color: palette.success,
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
            Row(
              children: [
                Expanded(
                  child: _MetricPill(
                    palette: palette,
                    label: 'Estado',
                    value: '3 OK / 1 Obs',
                    icon: Icons.rule_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricPill(
                    palette: palette,
                    label: 'Evidencia',
                    value: 'Fotos + GPS',
                    icon: Icons.photo_camera_rounded,
                  ),
                ),
              ],
            ),
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
                Expanded(
                  child: Text(
                    'Exportar Excel con fotos - PDF firmado - ZIP backup',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
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

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.palette,
    required this.label,
    required this.value,
    required this.icon,
  });

  final _LandingPalette palette;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.elevatedBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: palette.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isObs = estado.toLowerCase() != 'ok';
        final showEvidenceIcons = hasPhoto && constraints.maxWidth >= 390;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: palette.elevatedBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: palette.cardBorder.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            children: [
              _PreviewCell(
                  label: 'Prog', value: progresiva, palette: palette, flex: 3),
              _PreviewCell(label: 'ON', value: on, palette: palette, flex: 2),
              _PreviewCell(label: 'OFF', value: off, palette: palette, flex: 2),
              _PreviewCell(
                  label: 'Cupon', value: cupon, palette: palette, flex: 3),
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (showEvidenceIcons) ...[
                      Icon(
                        Icons.photo_camera_rounded,
                        size: 14,
                        color: palette.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.place_rounded,
                        size: 14,
                        color: palette.textSecondary,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isObs ? palette.warningSoft : palette.successSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        estado,
                        style: TextStyle(
                          color: isObs ? palette.warning : palette.success,
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
      },
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

class _QuickStart extends StatelessWidget {
  const _QuickStart({
    required this.palette,
    required this.isWide,
    required this.onOpenDemo,
    required this.onOpenApp,
    required this.onContact,
    required this.salesChannelLabel,
  });

  final _LandingPalette palette;
  final bool isWide;
  final VoidCallback onOpenDemo;
  final VoidCallback onOpenApp;
  final VoidCallback onContact;
  final String salesChannelLabel;

  @override
  Widget build(BuildContext context) {
    final items = <_QuickStartAction>[
      _QuickStartAction(
        icon: Icons.bolt_rounded,
        title: 'Protección catódica',
        subtitle: 'Demo completa: ON/OFF, IR drop, cupón y evidencia.',
        cta: 'Abrir demo técnica',
        onTap: onOpenDemo,
        featured: true,
      ),
      _QuickStartAction(
        icon: Icons.add_chart_rounded,
        title: 'Nueva hoja',
        subtitle: 'Empezar un relevamiento desde cero.',
        cta: 'Crear ahora',
        onTap: onOpenApp,
      ),
      _QuickStartAction(
        icon: Icons.history_rounded,
        title: 'Seguir donde quedé',
        subtitle: 'Tus hojas recientes y favoritas.',
        cta: 'Abrir Bit Flow',
        onTap: onOpenApp,
      ),
      _QuickStartAction(
        icon: salesChannelLabel.startsWith('WhatsApp')
            ? Icons.chat_rounded
            : Icons.mail_outline_rounded,
        title: 'Contactar ventas',
        subtitle: 'Evaluamos si Bit Flow encaja con tu flujo técnico.',
        cta: salesChannelLabel,
        onTap: onContact,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(isWide ? 18 : 14),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = isWide ? 4 : (constraints.maxWidth < 620 ? 1 : 2);
          final gap = 12.0;
          final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final item in items)
                SizedBox(
                  width: width,
                  child: _QuickStartCard(
                    palette: palette,
                    action: item,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickStartAction {
  const _QuickStartAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
    this.featured = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onTap;
  final bool featured;
}

class _QuickStartCard extends StatefulWidget {
  const _QuickStartCard({required this.palette, required this.action});

  final _LandingPalette palette;
  final _QuickStartAction action;

  @override
  State<_QuickStartCard> createState() => _QuickStartCardState();
}

class _QuickStartCardState extends State<_QuickStartCard> {
  bool _hover = false;
  bool _press = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final action = widget.action;
    final featuredFg = palette.featureFg;
    final fg = action.featured ? featuredFg : palette.textPrimary;
    final secondary =
        action.featured ? palette.featureFgMuted : palette.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _press = false;
      }),
      child: GestureDetector(
        onTap: action.onTap,
        onTapDown: (_) => setState(() => _press = true),
        onTapCancel: () => setState(() => _press = false),
        onTapUp: (_) => setState(() => _press = false),
        child: AnimatedScale(
          scale: _press ? 0.985 : (_hover ? 1.01 : 1),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: action.featured ? palette.featureBg : palette.elevatedBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: action.featured
                    ? Colors.transparent
                    : palette.cardBorder.withValues(alpha: _hover ? 1 : 0.72),
              ),
              boxShadow: [
                if (_hover)
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: 22,
                    offset: const Offset(0, 14),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: action.featured
                            ? palette.featureIconBg
                            : palette.accentSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        action.icon,
                        color: action.featured ? featuredFg : palette.accent,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  action.title,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  action.subtitle,
                  style: TextStyle(
                    color: secondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  action.cta,
                  style: TextStyle(
                    color: action.featured ? featuredFg : palette.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerticalStrip extends StatelessWidget {
  const _VerticalStrip({
    required this.palette,
    required this.isWide,
    required this.onOpenDemo,
    required this.onOpenApp,
  });

  final _LandingPalette palette;
  final bool isWide;
  final VoidCallback onOpenDemo;
  final VoidCallback onOpenApp;

  @override
  Widget build(BuildContext context) {
    final items = <_UseCase>[
      _UseCase(
        Icons.bolt_rounded,
        'Proteccion catodica',
        'ON/OFF, IR drop, cupon, estado y evidencia por progresiva.',
        'Abrir demo',
        onOpenDemo,
        featured: true,
      ),
      _UseCase(
        Icons.electrical_services_rounded,
        'Puesta a tierra',
        'Resistividad Wenner/Schlumberger, continuidad y malla.',
        'Nueva hoja',
        onOpenApp,
      ),
      _UseCase(
        Icons.settings_input_antenna_rounded,
        'Inspección técnica',
        'Gasoducto, oleoducto, subestación y activos con evidencia fotográfica.',
        'Nueva hoja',
        onOpenApp,
      ),
      _UseCase(
        Icons.engineering_rounded,
        'Mediciones técnicas',
        'Continuidad, interferencias, puntos críticos y evidencia con GPS.',
        'Nueva hoja',
        onOpenApp,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          palette: palette,
          eyebrow: 'Templates y casos de uso',
          title: 'Arranca con estructura tecnica, no con una planilla vacia.',
        ),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final cols = isWide ? 4 : (constraints.maxWidth < 520 ? 1 : 2);
          final gap = 14.0;
          final cellWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final item in items)
                SizedBox(
                  width: cellWidth,
                  child: _VerticalCard(
                    palette: palette,
                    item: item,
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _UseCase {
  const _UseCase(
    this.icon,
    this.title,
    this.subtitle,
    this.cta,
    this.onTap, {
    this.featured = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onTap;
  final bool featured;
}

class _VerticalCard extends StatelessWidget {
  const _VerticalCard({
    required this.palette,
    required this.item,
  });

  final _LandingPalette palette;
  final _UseCase item;

  @override
  Widget build(BuildContext context) {
    final featuredFg = palette.featureFg;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: item.featured ? palette.featureBg : palette.cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: item.featured ? Colors.transparent : palette.cardBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: item.featured ? 30 : 18,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: item.featured
                      ? palette.featureIconBg
                      : palette.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icon,
                  color: item.featured ? featuredFg : palette.accent,
                  size: 21,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                item.title,
                style: TextStyle(
                  color: item.featured ? featuredFg : palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                item.subtitle,
                style: TextStyle(
                  color: item.featured
                      ? palette.featureFgMuted
                      : palette.textSecondary,
                  fontSize: 13,
                  height: 1.42,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    item.cta,
                    style: TextStyle(
                      color: item.featured ? featuredFg : palette.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: item.featured ? featuredFg : palette.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
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
        Icons.timer_rounded,
        'Menos carga duplicada',
        'El tecnico registra una vez y exporta el informe sin transcribir.',
      ),
      (
        Icons.photo_camera_back_rounded,
        'Evidencia ubicada',
        'Fotos, audio y GPS quedan asociados al dato que justifican.',
      ),
      (
        Icons.rule_rounded,
        'Registros consistentes',
        'Columnas de numero, fecha y estado reducen errores de captura.',
      ),
      (
        Icons.file_download_done_rounded,
        'Salida entregable',
        'XLSX con fotos, PDF y ZIP de respaldo para auditoria o envio.',
      ),
      (
        Icons.cloud_off_rounded,
        'Trabajo local',
        'Pensado para campo: carga local y exportacion cuando el equipo vuelve.',
      ),
      (
        Icons.people_alt_rounded,
        'Equipo alineado',
        'Contratistas, inspeccion y mantenimiento usan la misma estructura.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          palette: palette,
          eyebrow: 'Ahorro real',
          title: 'Menos caos operativo entre campo, oficina y entrega.',
        ),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final cols = isWide ? 3 : (constraints.maxWidth < 520 ? 1 : 2);
          final gap = 14.0;
          final cellWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
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

class _Workflow extends StatelessWidget {
  const _Workflow({required this.palette, required this.isWide});

  final _LandingPalette palette;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final steps = const <(String, String, IconData)>[
      (
        '1. Elegir template',
        'Inspección, mantenimiento, relevamiento o planilla propia.',
        Icons.dashboard_customize_rounded,
      ),
      (
        '2. Medir y evidenciar',
        'Carga valores, fotos, audio, observaciones y posicion GPS.',
        Icons.add_location_alt_rounded,
      ),
      (
        '3. Revisar estado',
        'Detecta observaciones y mantiene el registro legible para supervisar.',
        Icons.fact_check_rounded,
      ),
      (
        '4. Exportar',
        'Entrega XLSX, PDF o ZIP sin reconstruir el informe desde cero.',
        Icons.file_download_done_rounded,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(isWide ? 24 : 18),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            palette: palette,
            eyebrow: 'Flujo de trabajo',
            title: 'De la medicion al entregable en cuatro pasos claros.',
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = isWide ? 4 : (constraints.maxWidth < 620 ? 1 : 2);
              final gap = 12.0;
              final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final step in steps)
                    SizedBox(
                      width: width,
                      child: _WorkflowStep(
                        palette: palette,
                        title: step.$1,
                        body: step.$2,
                        icon: step.$3,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({
    required this.palette,
    required this.title,
    required this.body,
    required this.icon,
  });

  final _LandingPalette palette;
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.elevatedBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: palette.accent, size: 22),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12.5,
              height: 1.42,
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
      ('Medicion + evidencia en el mismo registro', false, false, true),
      ('Plantillas tecnicas reutilizables', false, true, true),
      ('Estados y columnas consistentes', false, true, true),
      ('XLSX/PDF/ZIP para entregar o respaldar', false, false, true),
      ('Continuar trabajos recientes', false, false, true),
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
            eyebrow: 'Donde se gana tiempo',
            title: 'Lo importante queda junto: medicion, evidencia y salida.',
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
          Expanded(
            flex: 2,
            child: Center(child: _CheckMark(on: excel, palette: palette)),
          ),
          Expanded(
            flex: 2,
            child: Center(child: _CheckMark(on: forms, palette: palette)),
          ),
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
    required this.palette,
    this.strong = false,
  });

  final bool on;
  final bool strong;
  final _LandingPalette palette;

  @override
  Widget build(BuildContext context) {
    if (!on) {
      return Text(
        '-',
        style: TextStyle(
          color: palette.textMuted,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    final c = strong ? palette.accent : palette.success;
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
          eyebrow: 'Implementacion',
          title: 'Empeza acotado y escala cuando el flujo ya esta validado.',
        ),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final cols = isWide ? 3 : (constraints.maxWidth < 560 ? 1 : 2);
          final gap = 14.0;
          final cellWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
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
                      'Un proyecto tecnico para probar Bit Flow con un entregable real.',
                  ctaLabel: 'Agendar piloto',
                  onCta: onContact,
                  bullets: const [
                    'Template PC y ajustes iniciales',
                    'Export XLSX/PDF/ZIP validado',
                    'Revision del flujo con el equipo',
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
                      'Uso continuo para cuadrillas, inspeccion y supervisores.',
                  ctaLabel: 'Ver demo',
                  onCta: onOpenDemo,
                  highlight: true,
                  bullets: const [
                    'Templates tecnicas reutilizables',
                    'Recientes, favoritos y fijados',
                    'Soporte de implementacion',
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
                      'Para empresas que necesitan plantillas o entregables propios.',
                  ctaLabel: 'Hablar con ventas',
                  onCta: onContact,
                  bullets: const [
                    'Templates exclusivas por cliente',
                    'Formato de informe alineado al cliente',
                    'Capacitacion y soporte acordado',
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
                  color: palette.accentOutline,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          'Mostralo con un caso real.',
          style: TextStyle(
            color: palette.accentContrast,
            fontSize: isWide ? 26 : 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pasame un flujo de inspección, mantenimiento, relevamiento u obra, y vemos si Bit Flow lo puede ordenar sin agregar burocracia.',
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
            backgroundColor: palette.accentContrast,
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
            backgroundColor: palette.accentContrast.withValues(alpha: 0.18),
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
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1.08,
            letterSpacing: -0.6,
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
        disabledBackgroundColor: palette.textMuted,
        padding: EdgeInsets.symmetric(
          horizontal: large ? 24 : 17,
          vertical: large ? 17 : 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        elevation: 0,
        shadowColor: palette.shadow,
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
        side: BorderSide(color: palette.cardBorderStrong),
        backgroundColor: palette.ghostButtonBg,
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
