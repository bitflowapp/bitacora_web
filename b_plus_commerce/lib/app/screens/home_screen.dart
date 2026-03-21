import 'package:flutter/material.dart';

import '../services/commerce_store.dart';
import '../theme/bpc_colors.dart';
import '../utils/formatters.dart';
import '../widgets/caja_clara_brand.dart';
import '../widgets/commerce_components.dart';
import '../widgets/commerce_scope.dart';
import '../widgets/product_form_dialog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onNewSale,
    required this.onNewExpense,
    required this.onScanProduct,
    required this.onOpenProducts,
    required this.onExportExcel,
    required this.exportingExcel,
  });

  final VoidCallback onNewSale;
  final VoidCallback onNewExpense;
  final VoidCallback onScanProduct;
  final VoidCallback onOpenProducts;
  final VoidCallback onExportExcel;
  final bool exportingExcel;

  @override
  Widget build(BuildContext context) {
    final store = CommerceScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final now = DateTime.now();
        final recent = store.recentMovements();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderStrip(now: now, store: store),
              const SizedBox(height: 14),
              _PrimaryActions(
                onNewSale: onNewSale,
                onNewExpense: onNewExpense,
                onScanProduct: onScanProduct,
              ),
              const SizedBox(height: 12),
              _SecondaryActions(
                lowStockCount: store.lowStockCount,
                onAddProduct: () => showProductEditor(context, store),
                onOpenLowStock: onOpenProducts,
                onExportExcel: onExportExcel,
                exportingExcel: exportingExcel,
              ),
              const SizedBox(height: 16),
              const SectionHeader(
                title: 'Ultimos movimientos',
                subtitle: 'Lo ultimo en caja, sin ruido.',
              ),
              const SizedBox(height: 10),
              if (recent.isEmpty)
                EmptyCard(
                  title: 'Sin movimientos todavia',
                  message:
                      'Registra una venta o un gasto. Queda guardado offline.',
                  action: FilledButton(
                    onPressed: onNewSale,
                    child: const Text('Nueva venta'),
                  ),
                )
              else
                BpcPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < recent.length; index++)
                        MovementsListTile(
                          movement: recent[index],
                          productName: store
                              .productById(recent[index].productId ?? '')
                              ?.name,
                          showDivider: index != recent.length - 1,
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderStrip extends StatelessWidget {
  const _HeaderStrip({required this.now, required this.store});

  final DateTime now;
  final CommerceStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BpcPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: Colors.white.withValues(alpha: 0.82),
      child: Wrap(
        spacing: 18,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: BpcColors.greenDeep,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const CajaClaraSymbol(size: 28),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Caja Clara',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.66),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hoy',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatShortDate(now),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _HeaderMetric(
            label: 'Ventas del dia',
            value: formatMoney(store.todaySalesPesos),
          ),
          _HeaderMetric(
            label: 'Caja actual',
            value: formatMoney(store.cashBalancePesos),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 148),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: BpcColors.mutedInk,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: BpcColors.ink,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.onNewSale,
    required this.onNewExpense,
    required this.onScanProduct,
  });

  final VoidCallback onNewSale;
  final VoidCallback onNewExpense;
  final VoidCallback onScanProduct;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ActionCard(
          title: 'Nueva venta',
          subtitle: 'Vende y actualiza caja',
          icon: Icons.shopping_bag_rounded,
          onTap: onNewSale,
          fillColor: Theme.of(context).colorScheme.primary,
          contentColor: Theme.of(context).colorScheme.onPrimary,
          emphasized: true,
        ),
        const SizedBox(height: 12),
        BpcPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: Colors.white.withValues(alpha: 0.76),
          child: Column(
            children: [
              _InlineActionRow(
                title: 'Registrar gasto',
                subtitle: 'Resta de caja',
                icon: Icons.receipt_long_rounded,
                onTap: onNewExpense,
              ),
              const Divider(height: 1),
              _InlineActionRow(
                title: 'Escanear producto',
                subtitle: 'Camara, scanner o codigo',
                icon: Icons.qr_code_scanner_rounded,
                onTap: onScanProduct,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({
    required this.lowStockCount,
    required this.onAddProduct,
    required this.onOpenLowStock,
    required this.onExportExcel,
    required this.exportingExcel,
  });

  final int lowStockCount;
  final VoidCallback onAddProduct;
  final VoidCallback onOpenLowStock;
  final VoidCallback onExportExcel;
  final bool exportingExcel;

  @override
  Widget build(BuildContext context) {
    return BpcPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.white.withValues(alpha: 0.74),
      child: Column(
        children: [
          _InlineActionRow(
            title: 'Agregar producto',
            subtitle: 'Nombre, barcode, stock, costo y precio',
            icon: Icons.add_box_rounded,
            onTap: onAddProduct,
          ),
          const Divider(height: 1),
          _InlineActionRow(
            title: 'Ver stock bajo',
            subtitle: lowStockCount == 0
                ? 'Sin alertas'
                : '$lowStockCount productos a reponer',
            icon: Icons.warning_amber_rounded,
            onTap: onOpenLowStock,
          ),
          const Divider(height: 1),
          _InlineActionRow(
            title: 'Exportar Excel',
            subtitle: exportingExcel
                ? 'Generando archivo'
                : 'Resumen, productos, ventas, gastos y movimientos',
            icon: Icons.file_download_rounded,
            onTap: onExportExcel,
          ),
        ],
      ),
    );
  }
}

class _InlineActionRow extends StatelessWidget {
  const _InlineActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: BpcColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: BpcColors.subtleInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded, color: BpcColors.mutedInk),
          ],
        ),
      ),
    );
  }
}
