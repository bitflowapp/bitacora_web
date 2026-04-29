import 'package:flutter/material.dart';

import '../services/bitflow_payment_service.dart';
import '../services/bitflow_product_models.dart';

Future<void> showBitFlowUpgradeModal(
  BuildContext context, {
  String? reason,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BitFlowUpgradeModal(reason: reason),
  );
}

class _BitFlowUpgradeModal extends StatelessWidget {
  const _BitFlowUpgradeModal({this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Upgrade to Pro',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'BitFlow Pro desbloquea el modo producto: mas hojas, templates, sharing y automatizaciones.',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if ((reason ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      reason!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.74),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: const [
                      Expanded(
                        child: _PlanCard(
                          title: 'Free',
                          accent: Color(0xFFE7DED2),
                          items: <String>[
                            'Hasta 5 hojas',
                            'Formulas basicas',
                            'Export XLSX',
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _PlanCard(
                          title: 'Pro',
                          accent: Color(0xFF111111),
                          highlighted: true,
                          items: <String>[
                            'Hojas ilimitadas',
                            'Templates',
                            'Automatizaciones',
                            'Formulas avanzadas',
                            'Sharing por link',
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Checkout',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ProviderButton(
                    provider: BitFlowPaymentProvider.stripe,
                    plan: BitFlowPaymentPlan.proMonthly,
                    label: 'Stripe - Pro mensual',
                  ),
                  const SizedBox(height: 10),
                  _ProviderButton(
                    provider: BitFlowPaymentProvider.stripe,
                    plan: BitFlowPaymentPlan.proAnnual,
                    label: 'Stripe - Pro anual',
                  ),
                  const SizedBox(height: 10),
                  _ProviderButton(
                    provider: BitFlowPaymentProvider.mercadoPago,
                    plan: BitFlowPaymentPlan.proMonthly,
                    label: 'Mercado Pago - Pro mensual',
                  ),
                  const SizedBox(height: 10),
                  _ProviderButton(
                    provider: BitFlowPaymentProvider.mercadoPago,
                    plan: BitFlowPaymentPlan.proAnnual,
                    label: 'Mercado Pago - Pro anual',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Los proveedores de pago abren checkout externo. El desbloqueo de Pro queda listo para webhook o actualizacion manual del perfil.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.items,
    required this.accent,
    this.highlighted = false,
  });

  final String title;
  final List<String> items;
  final Color accent;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onAccent = highlighted ? Colors.white : theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? accent : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              highlighted ? accent : theme.dividerColor.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: onAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_rounded, color: onAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onAccent.withValues(alpha: 0.92),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ProviderButton extends StatefulWidget {
  const _ProviderButton({
    required this.provider,
    required this.plan,
    required this.label,
  });

  final BitFlowPaymentProvider provider;
  final BitFlowPaymentPlan plan;
  final String label;

  @override
  State<_ProviderButton> createState() => _ProviderButtonState();
}

class _ProviderButtonState extends State<_ProviderButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final available = BitFlowPaymentService.I.hasCheckout(
      provider: widget.provider,
      plan: widget.plan,
    );
    return FilledButton(
      onPressed: !available || _busy
          ? null
          : () async {
              setState(() => _busy = true);
              await BitFlowPaymentService.I.launchCheckout(
                provider: widget.provider,
                plan: widget.plan,
              );
              if (mounted) {
                setState(() => _busy = false);
              }
            },
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      child: Text(
        available ? widget.label : '${widget.label} - Not configured',
      ),
    );
  }
}
