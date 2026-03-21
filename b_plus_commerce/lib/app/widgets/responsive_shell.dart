import 'package:flutter/material.dart';

import '../screens/expense_screen.dart';
import '../screens/home_screen.dart';
import '../screens/products_screen.dart';
import '../screens/barcode_scan_screen.dart';
import '../screens/sale_screen.dart';
import '../screens/summary_screen.dart';
import '../services/backup_service.dart';
import '../services/excel_export_service.dart';
import '../theme/bpc_colors.dart';
import 'caja_clara_brand.dart';
import 'commerce_scope.dart';
import 'operation_dialogs.dart';

enum CommerceTab { home, products, summary }

class ResponsiveShell extends StatefulWidget {
  const ResponsiveShell({super.key});

  @override
  State<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends State<ResponsiveShell> {
  CommerceTab _tab = CommerceTab.home;
  bool _exportingExcel = false;
  bool _exportingBackup = false;
  bool _restoringBackup = false;
  bool _undoingMovement = false;
  bool _savingCashEvent = false;

  void _openSale() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SaleScreen()));
  }

  void _openExpense() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ExpenseScreen()));
  }

  void _openBarcodeScan() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BarcodeScanScreen()));
  }

  void _openProducts() {
    setState(() => _tab = CommerceTab.products);
  }

  Future<void> _exportExcel() async {
    if (_exportingExcel) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);

    setState(() => _exportingExcel = true);
    try {
      final result = await ExcelExportService().export(store);
      if (!mounted) {
        return;
      }

      if (result.saved) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Excel guardado en ${result.path}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (result.downloaded) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Descarga de Excel iniciada'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo exportar Excel: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingExcel = false);
      }
    }
  }

  Future<void> _exportBackup() async {
    if (_exportingBackup) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);

    setState(() => _exportingBackup = true);
    try {
      final result = await BackupService().exportBackup(store);
      if (!mounted) {
        return;
      }
      if (result.saved) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Backup guardado en ${result.path}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (result.downloaded) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Descarga de backup iniciada'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo exportar el backup: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingBackup = false);
      }
    }
  }

  Future<void> _restoreBackup() async {
    if (_restoringBackup) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);
    final backupService = BackupService();

    setState(() => _restoringBackup = true);
    try {
      final importData = await backupService.pickBackupToImport();
      if (importData == null || !mounted) {
        return;
      }

      final confirmed = await showDangerConfirmationDialog(
        context,
        title: 'Restaurar backup',
        message:
            'Se reemplazara el estado actual por el contenido de ${importData.fileName}. Esta accion no se puede revertir.',
        confirmLabel: 'Restaurar',
      );
      if (!confirmed || !mounted) {
        return;
      }

      await store.restoreSnapshot(importData.snapshot);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Backup restaurado desde ${importData.fileName}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo restaurar el backup: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _restoringBackup = false);
      }
    }
  }

  Future<void> _undoLastMovement() async {
    if (_undoingMovement) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);
    final movement = store.lastMovement;
    if (movement == null) {
      return;
    }

    final confirmed = await showDangerConfirmationDialog(
      context,
      title: 'Deshacer ultimo movimiento',
      message:
          'Se va a deshacer "${movement.title}". Si fue una venta, tambien se repone el stock.',
      confirmLabel: 'Deshacer',
    );
    if (!confirmed) {
      return;
    }

    setState(() => _undoingMovement = true);
    try {
      await store.undoLastMovement();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Ultimo movimiento deshecho'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo deshacer: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _undoingMovement = false);
      }
    }
  }

  Future<void> _registerCashOpening() async {
    if (_savingCashEvent) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);
    final amount = await showAmountEntryDialog(
      context,
      title: store.hasCashOpeningToday
          ? 'Actualizar apertura'
          : 'Apertura de caja',
      label: 'Caja inicial',
      confirmLabel: store.hasCashOpeningToday ? 'Actualizar' : 'Guardar',
      helper: 'Ingresa el efectivo inicial del dia.',
      initialValue: store.todayOpeningCashPesos,
    );
    if (amount == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    var overwrite = false;
    if (store.hasCashOpeningToday) {
      overwrite = await showDangerConfirmationDialog(
        context,
        title: 'Reemplazar apertura',
        message:
            'Ya existe una apertura registrada hoy. Se reemplazara la apertura y se limpiara el cierre del dia.',
        confirmLabel: 'Reemplazar',
      );
      if (!overwrite) {
        return;
      }
      if (!mounted) {
        return;
      }
    }

    setState(() => _savingCashEvent = true);
    try {
      await store.registerCashOpening(
        openingBalancePesos: amount,
        overwrite: overwrite,
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Apertura de caja registrada'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo registrar la apertura: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingCashEvent = false);
      }
    }
  }

  Future<void> _registerCashClosing() async {
    if (_savingCashEvent) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final store = CommerceScope.of(context);
    final amount = await showAmountEntryDialog(
      context,
      title: store.hasCashClosingToday ? 'Actualizar cierre' : 'Cierre de caja',
      label: 'Caja contada',
      confirmLabel: store.hasCashClosingToday ? 'Actualizar' : 'Guardar',
      helper: 'Ingresa el monto contado al cierre.',
      initialValue: store.todayClosingCashPesos,
    );
    if (amount == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    var overwrite = false;
    if (store.hasCashClosingToday) {
      overwrite = await showDangerConfirmationDialog(
        context,
        title: 'Reemplazar cierre',
        message:
            'Ya existe un cierre registrado hoy. Se reemplazara por el nuevo valor.',
        confirmLabel: 'Reemplazar',
      );
      if (!overwrite) {
        return;
      }
      if (!mounted) {
        return;
      }
    }

    setState(() => _savingCashEvent = true);
    try {
      await store.registerCashClosing(
        closingBalancePesos: amount,
        overwrite: overwrite,
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Cierre de caja registrado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo registrar el cierre: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingCashEvent = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = CommerceScope.of(context);
    final pages = <CommerceTab, Widget>{
      CommerceTab.home: HomeScreen(
        onNewSale: _openSale,
        onNewExpense: _openExpense,
        onScanProduct: _openBarcodeScan,
        onOpenProducts: _openProducts,
        onExportExcel: _exportExcel,
        exportingExcel: _exportingExcel,
      ),
      CommerceTab.products: const ProductsScreen(),
      CommerceTab.summary: SummaryScreen(
        onExportExcel: _exportExcel,
        exportingExcel: _exportingExcel,
        onExportBackup: _exportBackup,
        exportingBackup: _exportingBackup,
        onRestoreBackup: _restoreBackup,
        restoringBackup: _restoringBackup,
        onUndoLastMovement: _undoLastMovement,
        undoingMovement: _undoingMovement,
        onRegisterCashOpening: _registerCashOpening,
        onRegisterCashClosing: _registerCashClosing,
        savingCashEvent: _savingCashEvent,
      ),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final page = pages[_tab]!;
        final lowStockCount = store.lowStockCount;

        if (wide) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  Container(
                    width: 238,
                    margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                    decoration: BoxDecoration(
                      color: BpcColors.surface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: BpcColors.line),
                      boxShadow: const [
                        BoxShadow(
                          color: BpcColors.shadow,
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(2, 4, 2, 6),
                            child: _RailBrand(),
                          ),
                        ),
                        Expanded(
                          child: NavigationRail(
                            selectedIndex: _tab.index,
                            onDestinationSelected: (index) {
                              setState(() => _tab = CommerceTab.values[index]);
                            },
                            labelType: NavigationRailLabelType.all,
                            leading: const SizedBox(height: 2),
                            groupAlignment: -0.88,
                            backgroundColor: Colors.transparent,
                            destinations: [
                              const NavigationRailDestination(
                                icon: Icon(Icons.home_outlined),
                                selectedIcon: Icon(Icons.home_rounded),
                                label: Text('Inicio'),
                              ),
                              NavigationRailDestination(
                                icon: _ProductsIconBadge(count: lowStockCount),
                                selectedIcon: _ProductsIconBadge(
                                  count: lowStockCount,
                                  selected: true,
                                ),
                                label: const Text('Productos'),
                              ),
                              const NavigationRailDestination(
                                icon: Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                                selectedIcon: Icon(
                                  Icons.account_balance_wallet_rounded,
                                ),
                                label: Text('Caja'),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: BoxDecoration(
                              color: BpcColors.surfaceStrong,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: BpcColors.income,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    store.isSaving
                                        ? 'Guardando'
                                        : 'Local listo',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: BpcColors.ink,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 18, 16),
                      child: page,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: page,
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab.index,
            onDestinationSelected: (index) {
              setState(() => _tab = CommerceTab.values[index]);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: _ProductsIconBadge(count: lowStockCount),
                selectedIcon: _ProductsIconBadge(
                  count: lowStockCount,
                  selected: true,
                ),
                label: 'Productos',
              ),
              const NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Caja',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductsIconBadge extends StatelessWidget {
  const _ProductsIconBadge({required this.count, this.selected = false});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = selected
        ? Icons.inventory_2_rounded
        : Icons.inventory_2_outlined;
    if (count <= 0) return Icon(icon);

    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -8,
          top: -6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: BpcColors.expense,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: scheme.surface, width: 1.8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                '$count',
                style: TextStyle(
                  color: scheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RailBrand extends StatelessWidget {
  const _RailBrand();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CajaClaraLogo(height: 52),
        const SizedBox(height: 10),
        Text(
          'Caja, ventas, stock y barcode',
          style: theme.textTheme.bodySmall?.copyWith(
            color: BpcColors.subtleInk,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
