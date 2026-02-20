import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/feature_flags.dart';
import '../services/app_config.dart';
import '../services/auth_service.dart';
import '../services/premium_config.dart';
import '../services/premium_service.dart';
import '../ui/ui.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  late final Stream<PremiumState> _premiumStream;

  @override
  void initState() {
    super.initState();
    _premiumStream = kAuthEnabled
        ? PremiumService.I.watchCurrentUserPremium()
        : Stream<PremiumState>.value(PremiumState.signedOut());
  }

  Future<void> _openCheckout(String url) async {
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null) {
      _showMessage('Link de pago no configurado.');
      return;
    }
    final opened =
        await launchUrl(parsed, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage('No se pudo abrir el link de pago.');
    }
  }

  Future<void> _copyCbu(String cbu) async {
    await Clipboard.setData(ClipboardData(text: cbu));
    if (!mounted) return;
    _showMessage('CBU copiado.');
  }

  Future<Uri?> _buildPaymentNoticeUri() async {
    final cfg = await AppConfig.load();
    final email = cfg.contactEmail.trim();
    final whatsapp = cfg.contactWhatsApp.trim();
    if (whatsapp.isNotEmpty) {
      final digits = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        return Uri.parse(
          'https://wa.me/$digits?text=${Uri.encodeComponent('Hola, realicé un pago Premium y quiero reportarlo para acreditación manual.')}',
        );
      }
    }
    if (email.isNotEmpty) {
      return Uri.parse(
        'mailto:$email?subject=${Uri.encodeComponent('Aviso de pago Premium')}&body=${Uri.encodeComponent('Hola, realicé un pago por transferencia y necesito acreditación manual.')}',
      );
    }
    return null;
  }

  Future<void> _openPaymentNotice() async {
    final uri = await _buildPaymentNoticeUri();
    if (uri == null) {
      _showMessage('No hay canal de aviso configurado.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage('No se pudo abrir el canal de aviso de pago.');
    }
  }

  String _formatCbu(String raw) {
    final digits = raw.replaceAll(RegExp(r'\s+'), '');
    if (digits.length == 22) {
      return '${digits.substring(0, 8)} ${digits.substring(8)}';
    }
    return raw;
  }

  void _showMessage(String text) {
    if (!mounted) return;
    AppToast.show(context, message: text);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bt = context.bitflow;
    final spacing = BitflowTokens.spacing;

    return AppShell(
      title: 'BitFlow Premium',
      subtitle: 'Planes claros para operación local sin backend obligatorio.',
      leading: IconButton(
        tooltip: 'Volver',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      body: FocusTraversalGroup(
        child: StreamBuilder<PremiumState>(
          stream: _premiumStream,
          builder: (context, snapshot) {
            final state = snapshot.data ?? PremiumState.signedOut();
            final trialEndsAt = state.trialEndsAt?.toLocal();
            final user = kAuthEnabled ? AuthService.I.currentUser : null;
            final statusText = state.premiumActive
                ? (state.isPremium
                    ? 'Premium activo'
                    : 'Prueba activa: ${state.remainingTrialDays} día(s) restantes')
                : 'Prueba finalizada';

            return ListView(
              padding: EdgeInsets.fromLTRB(
                spacing.s4,
                spacing.s8,
                spacing.s4,
                spacing.s24,
              ),
              children: [
                AppCard(
                  padding: EdgeInsets.all(spacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(statusText, style: bt.typography.title),
                      SizedBox(height: spacing.s8),
                      Text(
                        trialEndsAt == null
                            ? 'No hay fecha de fin de prueba registrada.'
                            : 'Fin de prueba: ${trialEndsAt.day.toString().padLeft(2, '0')}/${trialEndsAt.month.toString().padLeft(2, '0')}/${trialEndsAt.year}',
                        style: bt.typography.body,
                      ),
                      if (user != null) ...[
                        SizedBox(height: spacing.s8),
                        Text(
                          'Usuario: ${user.email ?? user.id}',
                          style: bt.typography.caption,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: spacing.s16),
                AppCard(
                  padding: EdgeInsets.all(spacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Planes y checkout',
                        style: t.text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: spacing.s12),
                      _PlanCard(
                        title: 'Pro mensual',
                        subtitle: 'Operación individual completa',
                        url: PremiumConfig.proMonthlyUrl,
                        onTap: _openCheckout,
                      ),
                      SizedBox(height: spacing.s12),
                      _PlanCard(
                        title: 'Equipos mensual',
                        subtitle: 'Trabajo colaborativo por equipo',
                        url: PremiumConfig.teamsMonthlyUrl,
                        onTap: _openCheckout,
                      ),
                      SizedBox(height: spacing.s12),
                      _PlanCard(
                        title: 'Pro anual',
                        subtitle: 'Mejor costo anual',
                        url: PremiumConfig.proAnnualUrl,
                        onTap: _openCheckout,
                      ),
                      SizedBox(height: spacing.s12),
                      _PlanCard(
                        title: 'Equipos anual',
                        subtitle: 'Escala con soporte continuo',
                        url: PremiumConfig.teamsAnnualUrl,
                        onTap: _openCheckout,
                      ),
                    ],
                  ),
                ),
                if (PremiumConfig.hasTransferCbu) ...[
                  SizedBox(height: spacing.s16),
                  AppCard(
                    padding: EdgeInsets.all(spacing.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transferencia manual',
                          style: t.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: spacing.s8),
                        Text('CBU: ${_formatCbu(PremiumConfig.transferCbu)}'),
                        SizedBox(height: spacing.s12),
                        AppButton(
                          label: 'Copiar CBU',
                          icon: Icons.copy_rounded,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.lg,
                          fullWidth: true,
                          onPressed: () => _copyCbu(PremiumConfig.transferCbu),
                        ),
                        SizedBox(height: spacing.s8),
                        Text(
                          'Acreditación manual (no automática).',
                          style: bt.typography.caption,
                        ),
                        SizedBox(height: spacing.s12),
                        AppButton(
                          label: 'Avisar pago',
                          icon: Icons.mark_email_unread_outlined,
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.lg,
                          fullWidth: true,
                          onPressed: _openPaymentNotice,
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: spacing.s16),
                AppCard(
                  padding: EdgeInsets.all(spacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Qué incluye',
                        style: t.text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: spacing.s12),
                      const _BenefitLine(
                        icon: Icons.offline_bolt_outlined,
                        text:
                            'Flujo local-first para operar sin depender de red.',
                      ),
                      const _BenefitLine(
                        icon: Icons.inventory_2_outlined,
                        text:
                            'Plantillas, evidencias y exportación lista para clientes.',
                      ),
                      const _BenefitLine(
                        icon: Icons.support_agent_outlined,
                        text:
                            'Soporte comercial y mejoras continuas por release.',
                      ),
                    ],
                  ),
                ),
                if (kAuthEnabled && user != null) ...[
                  SizedBox(height: spacing.s16),
                  AppButton(
                    label: 'Cerrar sesión',
                    icon: Icons.logout_rounded,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    onPressed: () async {
                      await AuthService.I.signOut();
                      if (!mounted) return;
                      Navigator.of(context).maybePop();
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.url,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String url;
  final Future<void> Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final spacing = BitflowTokens.spacing;
    final hasUrl = url.trim().isNotEmpty;
    final planKey = ValueKey<String>('premium-plan-$title');

    return Container(
      padding: EdgeInsets.all(spacing.s12),
      decoration: BoxDecoration(
        color: t.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(BitflowTokens.radii.md),
        border: Border.all(color: t.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: t.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: spacing.s4),
          Text(
            subtitle,
            style: t.text.bodySmall?.copyWith(color: t.colors.textSecondary),
          ),
          SizedBox(height: spacing.s12),
          AppButton(
            key: planKey,
            label: hasUrl ? 'Ir al pago' : 'Link no configurado',
            icon: Icons.open_in_new_rounded,
            size: AppButtonSize.lg,
            variant: AppButtonVariant.primary,
            fullWidth: true,
            onPressed: hasUrl ? () => onTap(url) : null,
          ),
        ],
      ),
    );
  }
}

class _BenefitLine extends StatelessWidget {
  const _BenefitLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: t.colors.textPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: t.text.bodyMedium?.copyWith(
                color: t.colors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
