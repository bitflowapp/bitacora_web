import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_config.dart';
import '../services/auth_service.dart';
import '../services/premium_config.dart';
import '../services/premium_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  Future<void> _openCheckout(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Link no configurado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final opened =
        await launchUrl(parsed, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el link de pago.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copyCbu(String cbu) async {
    await Clipboard.setData(ClipboardData(text: cbu));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CBU copiado.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<Uri?> _buildPaymentNoticeUri() async {
    final cfg = await AppConfig.load();
    final email = cfg.contactEmail.trim();
    final whatsapp = cfg.contactWhatsApp.trim();
    if (whatsapp.isNotEmpty) {
      final digits = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        return Uri.parse(
          'https://wa.me/$digits?text=${Uri.encodeComponent('Hola, realicé un pago por suscripción Premium y quiero reportarlo para acreditación manual.')}',
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
    final messenger = ScaffoldMessenger.of(context);
    final uri = await _buildPaymentNoticeUri();
    if (uri == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No hay canal de aviso configurado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el canal de aviso de pago.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatCbu(String raw) {
    final digits = raw.replaceAll(RegExp(r'\s+'), '');
    if (digits.length == 22) {
      return '${digits.substring(0, 8)} ${digits.substring(8)}';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium'),
      ),
      body: StreamBuilder<PremiumState>(
        stream: PremiumService.I.watchCurrentUserPremium(),
        builder: (context, snapshot) {
          final state = snapshot.data ?? PremiumState.signedOut();
          final trialEndsAt = state.trialEndsAt?.toLocal();
          final statusText = state.premiumActive
              ? (state.isPremium
                  ? 'Premium activo'
                  : 'Te quedan ${state.remainingTrialDays} día(s) de prueba')
              : 'Prueba finalizada';
          final user = AuthService.I.currentUser;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                statusText,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                trialEndsAt == null
                    ? 'No hay fecha de finalización de prueba registrada.'
                    : 'Fin de prueba: ${trialEndsAt.day.toString().padLeft(2, '0')}/${trialEndsAt.month.toString().padLeft(2, '0')}/${trialEndsAt.year}',
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 4),
              if (user != null)
                Text(
                  'Usuario: ${user.email ?? user.id}',
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
                ),
              const SizedBox(height: 22),
              const _SectionTitle(text: 'Mercado Pago'),
              const SizedBox(height: 10),
              _PayButton(
                label: 'Pro mensual',
                url: PremiumConfig.proMonthlyUrl,
                onTap: _openCheckout,
              ),
              const SizedBox(height: 10),
              _PayButton(
                label: 'Equipos mensual',
                url: PremiumConfig.teamsMonthlyUrl,
                onTap: _openCheckout,
              ),
              const SizedBox(height: 10),
              _PayButton(
                label: 'Pro anual',
                url: PremiumConfig.proAnnualUrl,
                onTap: _openCheckout,
              ),
              const SizedBox(height: 10),
              _PayButton(
                label: 'Equipos anual',
                url: PremiumConfig.teamsAnnualUrl,
                onTap: _openCheckout,
              ),
              if (PremiumConfig.hasTransferCbu) ...[
                const SizedBox(height: 24),
                const _SectionTitle(text: 'Transferencia'),
                const SizedBox(height: 8),
                Text(
                  'CBU: ${_formatCbu(PremiumConfig.transferCbu)}',
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _copyCbu(PremiumConfig.transferCbu),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar CBU'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Acreditación manual (no automática).',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _openPaymentNotice,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Avisar pago'),
                ),
              ],
              const SizedBox(height: 18),
              TextButton.icon(
                onPressed: () async {
                  await AuthService.I.signOut();
                  if (!mounted) return;
                  Navigator.of(context).maybePop();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Cerrar sesión'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  const _PayButton({
    required this.label,
    required this.url,
    required this.onTap,
  });

  final String label;
  final String url;
  final Future<void> Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url.trim().isNotEmpty;
    return FilledButton(
      onPressed: hasUrl ? () => onTap(url) : null,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      child: Text(
        hasUrl ? 'Pagar $label' : '$label - Link no configurado',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      )
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w700, fontSize: 19),
    );
  }
}
