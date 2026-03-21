import 'package:flutter/material.dart';

import '../utils/formatters.dart';
import '../widgets/commerce_components.dart';
import '../widgets/commerce_scope.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({
    super.key,
    required this.onExportExcel,
    required this.exportingExcel,
    required this.onExportBackup,
    required this.exportingBackup,
    required this.onRestoreBackup,
    required this.restoringBackup,
    required this.onUndoLastMovement,
    required this.undoingMovement,
    required this.onRegisterCashOpening,
    required this.onRegisterCashClosing,
    required this.savingCashEvent,
  });

  final VoidCallback onExportExcel;
  final bool exportingExcel;
  final VoidCallback onExportBackup;
  final bool exportingBackup;
  final VoidCallback onRestoreBackup;
  final bool restoringBackup;
  final VoidCallback onUndoLastMovement;
  final bool undoingMovement;
  final VoidCallback onRegisterCashOpening;
  final VoidCallback onRegisterCashClosing;
  final bool savingCashEvent;

  @override
  Widget build(BuildContext context) {
    final store = CommerceScope.of(context);
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final recent = store.recentMovements(10);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Caja / Resumen',
                subtitle: 'Operacion basica, caja y respaldo local',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: exportingExcel ? null : onExportExcel,
                    icon: exportingExcel
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_download_rounded),
                    label: Text(
                      exportingExcel ? 'Exportando Excel' : 'Exportar Excel',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: exportingBackup ? null : onExportBackup,
                    icon: exportingBackup
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt_rounded),
                    label: Text(
                      exportingBackup ? 'Exportando backup' : 'Exportar backup',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: restoringBackup ? null : onRestoreBackup,
                    icon: restoringBackup
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.restore_page_rounded),
                    label: Text(
                      restoringBackup ? 'Restaurando' : 'Restaurar backup',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: undoingMovement || !store.canUndoLastMovement
                        ? null
                        : onUndoLastMovement,
                    icon: undoingMovement
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.undo_rounded),
                    label: Text(
                      undoingMovement ? 'Deshaciendo' : 'Deshacer ultimo',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: savingCashEvent ? null : onRegisterCashOpening,
                    icon: const Icon(Icons.login_rounded),
                    label: Text(
                      store.hasCashOpeningToday
                          ? 'Editar apertura'
                          : 'Apertura de caja',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: savingCashEvent ? null : onRegisterCashClosing,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(
                      store.hasCashClosingToday
                          ? 'Editar cierre'
                          : 'Cierre de caja',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              BpcPanel(
                padding: const EdgeInsets.all(16),
                color: Colors.white.withValues(alpha: 0.78),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final width = wide
                        ? (constraints.maxWidth - 20) / 3
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: width,
                          child: MetricCard(
                            label: 'Caja actual',
                            value: formatMoney(store.cashBalancePesos),
                            helper: 'Saldo total',
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: MetricCard(
                            label: 'Apertura del dia',
                            value: store.todayOpeningCashPesos == null
                                ? 'Sin abrir'
                                : formatMoney(store.todayOpeningCashPesos!),
                            helper: 'Caja inicial del dia',
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: MetricCard(
                            label: 'Ventas del dia',
                            value: formatMoney(store.todaySalesPesos),
                            helper: 'Ingresos hoy',
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: MetricCard(
                            label: 'Gastos del dia',
                            value: formatMoney(store.todayExpensesPesos),
                            helper: 'Egresos hoy',
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: MetricCard(
                            label: 'Caja esperada',
                            value: store.todayExpectedCashPesos == null
                                ? 'Sin apertura'
                                : formatMoney(store.todayExpectedCashPesos!),
                            helper: 'Apertura + ventas - gastos',
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: MetricCard(
                            label: 'Cierre registrado',
                            value: store.todayClosingCashPesos == null
                                ? 'Sin cierre'
                                : formatMoney(store.todayClosingCashPesos!),
                            helper: store.todayClosingDifferencePesos == null
                                ? 'Caja contada al cierre'
                                : 'Diferencia: ${formatMoney(store.todayClosingDifferencePesos!)}',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              const SectionHeader(
                title: 'Movimientos recientes',
                subtitle: 'Venta, gasto, apertura, cierre o restauracion',
              ),
              const SizedBox(height: 10),
              if (recent.isEmpty)
                const EmptyCard(
                  title: 'Sin movimientos',
                  message: 'Cuando registres ventas o gastos, aparecen aca.',
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
