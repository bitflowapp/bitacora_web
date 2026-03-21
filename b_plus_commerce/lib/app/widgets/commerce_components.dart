import 'package:flutter/material.dart';

import '../models/movement.dart';
import '../models/product.dart';
import '../theme/bpc_colors.dart';
import '../utils/formatters.dart';

class BpcPanel extends StatelessWidget {
  const BpcPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.34),
        ),
        boxShadow: const [
          BoxShadow(
            color: BpcColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: BpcColors.subtleInk,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.helper,
    this.accentColor,
    this.tight = false,
  });

  final String label;
  final String value;
  final String? helper;
  final Color? accentColor;
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(tight ? 14 : 16),
      decoration: BoxDecoration(
        color:
            accentColor ?? scheme.surfaceContainerLow.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: BpcColors.mutedInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: BpcColors.ink),
          ),
          if (helper != null) ...[
            const SizedBox(height: 6),
            Text(
              helper!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: BpcColors.subtleInk),
            ),
          ],
        ],
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.fillColor,
    this.contentColor,
    this.emphasized = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? fillColor;
  final Color? contentColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = contentColor ?? scheme.onSurface;
    final iconSurface = emphasized
        ? Colors.white.withValues(alpha: 0.16)
        : scheme.primary.withValues(alpha: 0.08);
    return Material(
      color: fillColor ?? scheme.surfaceContainerLow.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(emphasized ? 24 : 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(emphasized ? 24 : 20),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: emphasized ? 112 : 84),
          padding: EdgeInsets.all(emphasized ? 20 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(emphasized ? 24 : 20),
            border: Border.all(
              color: emphasized
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.transparent,
            ),
            boxShadow: emphasized
                ? const [
                    BoxShadow(
                      color: Color(0x22122520),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: emphasized ? 58 : 52,
                height: emphasized ? 58 : 52,
                decoration: BoxDecoration(
                  color: iconSurface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: emphasized ? Colors.white : scheme.primary,
                  size: emphasized ? 28 : 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: fg,
                        fontSize: emphasized ? 22 : 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.35,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: emphasized
                              ? Colors.white.withValues(alpha: 0.82)
                              : BpcColors.mutedInk,
                          fontWeight: emphasized
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MovementsListTile extends StatelessWidget {
  const MovementsListTile({
    super.key,
    required this.movement,
    this.productName,
    this.showDivider = true,
  });

  final Movement movement;
  final String? productName;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = movement.isNeutral
        ? BpcColors.mutedInk
        : (movement.isIncome ? scheme.primary : scheme.error);
    final label = movement.isNeutral
        ? formatMoney(0)
        : movement.isIncome
        ? formatMoney(movement.amountPesos)
        : '-${formatMoney(movement.amountPesos)}';
    final subtitle =
        movement.subtitle ??
        (movement.kind == MovementKind.sale
            ? '${movement.originLabel} / ${movement.quantityUnits ?? 0} u. / ${movement.paymentMethod ?? 'Caja'}'
            : movement.kind == MovementKind.expense
            ? '${movement.originLabel} / ${movement.category ?? 'Gasto'}'
            : movement.originLabel);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.44),
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              movement.isNeutral
                  ? Icons.sync_alt_rounded
                  : movement.isIncome
                  ? Icons.add_rounded
                  : Icons.remove_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: BpcColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$subtitle${productName == null ? '' : ' / $productName'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BpcColors.subtleInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                formatMovementDate(movement.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BpcColors.subtleInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BpcPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BpcColors.subtleInk),
          ),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final low = product.isLowStock;
    final color = low ? scheme.error : scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        low ? 'Stock bajo' : 'Stock ok',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
