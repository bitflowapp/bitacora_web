import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_config.dart';
import '../services/auth_service.dart';
import '../services/premium_config.dart';
import '../services/premium_service.dart';
import '../services/runtime_flags.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  late final Future<AppConfig> _appConfigFuture;

  bool _checkoutInFlight = false;
  bool _copyInFlight = false;
  bool _paymentNoticeInFlight = false;
  bool _signOutInFlight = false;

  @override
  void initState() {
    super.initState();
    _appConfigFuture = AppConfig.load();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    final text = message.trim();
    if (text.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _openExternalUri(
    Uri uri, {
    required String errorMessage,
  }) async {
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        _showSnack(errorMessage);
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('PremiumScreen._openExternalUri error: $e');
      _showSnack(errorMessage);
      return false;
    }
  }

  Future<void> _openCheckout(String url) async {
    if (_checkoutInFlight) return;

    final raw = url.trim();
    final parsed = Uri.tryParse(raw);
    final isValid =
        parsed != null && (parsed.scheme == 'https' || parsed.scheme == 'http');

    if (!isValid) {
      _showSnack('Link de pago no configurado.');
      return;
    }

    setState(() => _checkoutInFlight = true);
    try {
      await _openExternalUri(
        parsed,
        errorMessage: 'No se pudo abrir el link de pago.',
      );
    } finally {
      if (mounted) {
        setState(() => _checkoutInFlight = false);
      }
    }
  }

  Future<void> _copyCbu(String cbu) async {
    if (_copyInFlight) return;

    final normalized = cbu.replaceAll(RegExp(r'\s+'), '').trim();
    if (normalized.isEmpty) {
      _showSnack('CBU no configurado.');
      return;
    }

    setState(() => _copyInFlight = true);
    try {
      await Clipboard.setData(ClipboardData(text: normalized));
      _showSnack('CBU copiado.');
    } catch (e) {
      debugPrint('PremiumScreen._copyCbu error: $e');
      _showSnack('No se pudo copiar el CBU.');
    } finally {
      if (mounted) {
        setState(() => _copyInFlight = false);
      }
    }
  }

  Future<Uri?> _buildPaymentNoticeUri() async {
    AppConfig cfg;
    try {
      cfg = await _appConfigFuture;
    } catch (e) {
      debugPrint('PremiumScreen._buildPaymentNoticeUri config error: $e');
      cfg = AppConfig.defaults();
    }

    final email = cfg.contactEmail.trim();
    final whatsapp = cfg.contactWhatsApp.trim();

    if (whatsapp.isNotEmpty) {
      final digits = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        return Uri.parse(
          'https://wa.me/$digits?text=${Uri.encodeComponent('Hola, realice un pago por suscripcion Premium y quiero reportarlo para acreditacion manual.')}',
        );
      }
    }

    if (email.isNotEmpty) {
      return Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: <String, String>{
          'subject': 'Aviso de pago Premium',
          'body':
              'Hola, realice un pago por transferencia y necesito acreditacion manual.',
        },
      );
    }

    return null;
  }

  Future<void> _openPaymentNotice() async {
    if (_paymentNoticeInFlight) return;

    setState(() => _paymentNoticeInFlight = true);
    try {
      final uri = await _buildPaymentNoticeUri();
      if (uri == null) {
        _showSnack('No hay canal de aviso configurado.');
        return;
      }

      await _openExternalUri(
        uri,
        errorMessage: 'No se pudo abrir el canal de aviso de pago.',
      );
    } finally {
      if (mounted) {
        setState(() => _paymentNoticeInFlight = false);
      }
    }
  }

  Future<void> _signOut() async {
    if (_signOutInFlight) return;

    final navigator = Navigator.of(context);

    setState(() => _signOutInFlight = true);
    try {
      await AuthService.I.signOut();
      if (!mounted) return;
      await navigator.maybePop();
    } catch (e) {
      debugPrint('PremiumScreen._signOut error: $e');
      _showSnack('No se pudo cerrar sesion.');
    } finally {
      if (mounted) {
        setState(() => _signOutInFlight = false);
      }
    }
  }

  String _formatCbu(String raw) {
    final digits = raw.replaceAll(RegExp(r'\s+'), '');
    if (digits.length == 22) {
      return '${digits.substring(0, 8)} ${digits.substring(8)}';
    }
    return raw.trim();
  }

  List<Widget> _buildPaymentOptions(ThemeData theme) {
    return [
      const _SectionTitle(text: 'Mercado Pago'),
      const SizedBox(height: 10),
      _PayButton(
        label: 'Pro mensual',
        url: PremiumConfig.proMonthlyUrl,
        busy: _checkoutInFlight,
        onTap: _openCheckout,
      ),
      const SizedBox(height: 10),
      _PayButton(
        label: 'Equipos mensual',
        url: PremiumConfig.teamsMonthlyUrl,
        busy: _checkoutInFlight,
        onTap: _openCheckout,
      ),
      const SizedBox(height: 10),
      _PayButton(
        label: 'Pro anual',
        url: PremiumConfig.proAnnualUrl,
        busy: _checkoutInFlight,
        onTap: _openCheckout,
      ),
      const SizedBox(height: 10),
      _PayButton(
        label: 'Equipos anual',
        url: PremiumConfig.teamsAnnualUrl,
        busy: _checkoutInFlight,
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
          onPressed:
              _copyInFlight ? null : () => _copyCbu(PremiumConfig.transferCbu),
          icon: const Icon(Icons.copy_rounded),
          label: Text(_copyInFlight ? 'Copiando...' : 'Copiar CBU'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'AcreditaciÃ³n manual (no automÃ¡tica).',
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _paymentNoticeInFlight ? null : _openPaymentNotice,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: Text(
            _paymentNoticeInFlight ? 'Abriendo...' : 'Avisar pago',
          ),
        ),
      ],
    ];
  }

  Widget _buildSignedInBody(
    BuildContext context,
    ThemeData theme,
    PremiumState state,
  ) {
    final trialEndsAt = state.trialEndsAt?.toLocal();
    final user = AuthService.I.currentUser;
    final signedIn = user != null;

    final String statusText;
    if (!signedIn) {
      statusText = 'IniciÃ¡ sesiÃ³n para ver tu estado Premium';
    } else if (state.isPremium) {
      statusText = 'Premium activo';
    } else if (state.premiumActive) {
      statusText = 'Te quedan ${state.remainingTrialDays} dÃ­a(s) de prueba';
    } else {
      statusText = 'Prueba finalizada';
    }

    final String secondaryText;
    if (!signedIn) {
      secondaryText =
          'NecesitÃ¡s una sesiÃ³n activa para consultar tu prueba o suscripciÃ³n.';
    } else if (trialEndsAt == null) {
      secondaryText = 'No hay fecha de finalizaciÃ³n de prueba registrada.';
    } else {
      secondaryText =
          'Fin de prueba: ${trialEndsAt.day.toString().padLeft(2, '0')}/${trialEndsAt.month.toString().padLeft(2, '0')}/${trialEndsAt.year}';
    }

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
          secondaryText,
          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 4),
        if (signedIn)
          Text(
            'Usuario: ${user.email ?? user.id}',
            style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
          ),
        const SizedBox(height: 22),
        ..._buildPaymentOptions(theme),
        if (signedIn) ...[
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: _signOutInFlight ? null : _signOut,
            icon: const Icon(Icons.logout_rounded),
            label: Text(
              _signOutInFlight ? 'Cerrando sesiÃ³n...' : 'Cerrar sesiÃ³n',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDemoBody(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Modo demo',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'La autenticaciÃ³n estÃ¡ desactivada temporalmente. El estado Premium por usuario no se evalÃºa en este modo.',
          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 22),
        ..._buildPaymentOptions(theme),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium'),
      ),
      body: RuntimeFlags.isAuthRequired
          ? StreamBuilder<PremiumState>(
              stream: PremiumService.I.watchCurrentUserPremium(),
              builder: (context, snapshot) {
                final state = snapshot.data ?? PremiumState.signedOut();

                if (snapshot.hasError) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'No se pudo cargar el estado Premium',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aun asÃ­ podÃ©s usar los enlaces de pago o avisar una transferencia manual.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 22),
                      ..._buildPaymentOptions(theme),
                    ],
                  );
                }

                return _buildSignedInBody(context, theme, state);
              },
            )
          : _buildDemoBody(theme),
    );
  }
}

class _PayButton extends StatelessWidget {
  const _PayButton({
    required this.label,
    required this.url,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final String url;
  final Future<void> Function(String) onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url.trim().isNotEmpty;

    return FilledButton(
      onPressed: hasUrl && !busy ? () => onTap(url) : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
      child: Text(
        !hasUrl
            ? '$label Â· Link no configurado'
            : busy
                ? 'Abriendo...'
                : 'Pagar $label',
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
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 19,
          ),
    );
  }
}
