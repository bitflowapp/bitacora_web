part of '../editor_screen.dart';

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.text,
    required this.bg,
    required this.fg,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final Color bg;
  final Color fg;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
          ),
          if (onAction != null && (actionLabel ?? '').trim().isNotEmpty) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                foregroundColor: fg,
                backgroundColor: fg.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ValidationErrorsPanel extends StatelessWidget {
  const _ValidationErrorsPanel({
    required this.palette,
    required this.issues,
    required this.onJump,
    required this.onClose,
  });

  final _SheetPalette palette;
  final List<_ValidationIssue> issues;
  final ValueChanged<_ValidationIssue> onJump;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: AppleCard(
        radius: 16,
        color: palette.menuBg.withValues(alpha: palette.isLight ? 0.95 : 0.84),
        borderColor: palette.borderStrong,
        shadows: const <BoxShadow>[],
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Errores (${issues.length})',
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _MobilePanelIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Cerrar',
                  onTap: onClose,
                  palette: palette,
                ),
              ],
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 170),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: issues.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final issue = issues[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onJump(issue),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: palette.hintBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: palette.border,
                          width: palette.hairline,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            issue.label,
                            style: TextStyle(
                              color: palette.fg,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              issue.message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.fgMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: palette.fgMuted,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorFirstRunTourBanner extends StatelessWidget {
  const _EditorFirstRunTourBanner({
    required this.palette,
    required this.onAcknowledge,
    required this.onDismissForever,
  });

  final _SheetPalette palette;
  final VoidCallback onAcknowledge;
  final VoidCallback onDismissForever;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.height < 920;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: AppleCard(
        key: const ValueKey('editor-micro-onboarding'),
        radius: 16,
        color: palette.menuBg.withValues(alpha: palette.isLight ? 0.96 : 0.82),
        borderColor: palette.borderStrong,
        shadows: const <BoxShadow>[],
        padding: compact
            ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
            : const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Micro onboarding (3 pasos)',
              style: TextStyle(
                color: palette.fg,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              compact
                  ? '30s: abre palette (Ctrl/Cmd+K o rayo), pega con preview+undo y exporta.'
                  : 'Guia 30s: palette (Ctrl/Cmd+K o rayo), smart paste con undo y exportar.',
              style: TextStyle(
                color: palette.fgMuted,
                fontSize: 12.2,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (compact)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.hintBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: palette.border,
                    width: palette.hairline,
                  ),
                ),
                child: Text(
                  'Paleta (Ctrl/Cmd+K / rayo) \u00B7 Pegado inteligente + Deshacer \u00B7 Exportar',
                  style: TextStyle(
                    color: palette.fgMuted,
                    fontSize: 11.3,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              )
            else ...const [
              _TourStepItem(
                icon: Icons.bolt_rounded,
                title: '1) Command palette',
                body:
                    'Abrela con Ctrl/Cmd+K en desktop o con el boton rayo en mobile.',
              ),
              SizedBox(height: 6),
              _TourStepItem(
                icon: Icons.table_chart_rounded,
                title: '2) Smart paste + Undo',
                body:
                    'Pega TSV/CSV, revisa preview y revierte con Undo si hace falta.',
              ),
              SizedBox(height: 6),
              _TourStepItem(
                icon: Icons.ios_share_rounded,
                title: '3) Exportar',
                body:
                    'Cuando cierres la carga, exporta en XLSX o PDF desde el menu.',
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Entendido',
                    icon: Icons.check_rounded,
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.secondary,
                    onPressed: onAcknowledge,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'No mostrar mas',
                    icon: Icons.visibility_off_outlined,
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.ghost,
                    onPressed: onDismissForever,
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

class _TourStepItem extends StatelessWidget {
  const _TourStepItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final pal = _SheetPalette.fromApp(
      AppTheme.of(context),
      hairline: math.max(0.5, 1 / MediaQuery.of(context).devicePixelRatio),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: pal.hintBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border, width: pal.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: pal.fgMuted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: pal.fg,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    color: pal.fgMuted,
                    fontSize: 11.3,
                    fontWeight: FontWeight.w600,
                    height: 1.22,
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

class _InlineSearchBar extends StatelessWidget {
  const _InlineSearchBar({
    required this.palette,
    required this.controller,
    required this.focusNode,
    required this.totalHits,
    required this.activeIndex,
    required this.onChanged,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });

  final _SheetPalette palette;
  final TextEditingController controller;
  final FocusNode focusNode;
  final int totalHits;
  final int activeIndex;
  final ValueChanged<String> onChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final counterText = totalHits <= 0 ? '0' : '${activeIndex + 1}/$totalHits';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: AppleCard(
        radius: t.radii.xl,
        color: t.colors.surfaceElevated.withValues(
          alpha: palette.isLight ? 0.95 : 0.84,
        ),
        borderColor: t.colors.borderStrong,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: palette.fgMuted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: false,
                onChanged: onChanged,
                onSubmitted: (_) => onNext(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: 'Buscar en celdas...',
                  hintStyle: TextStyle(color: palette.fgMuted),
                ),
                style: TextStyle(
                  color: palette.fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  height: 1.1,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: palette.hintBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: palette.border,
                  width: palette.hairline,
                ),
              ),
              child: Text(
                counterText,
                style: TextStyle(
                  color: palette.fgMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _MobilePanelIconButton(
              icon: Icons.keyboard_arrow_up_rounded,
              tooltip: 'Anterior',
              onTap: onPrev,
              palette: palette,
              iconSize: 20,
              splashRadius: 17,
            ),
            _MobilePanelIconButton(
              icon: Icons.keyboard_arrow_down_rounded,
              tooltip: 'Siguiente',
              onTap: onNext,
              palette: palette,
              iconSize: 20,
              splashRadius: 17,
            ),
            _MobilePanelIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Cerrar busqueda',
              onTap: onClose,
              palette: palette,
              iconSize: 18,
              splashRadius: 17,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionItem {
  const _QuickActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.variant = AppButtonVariant.secondary,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final AppButtonVariant variant;
}

class _SelectionQuickActionsBar extends StatefulWidget {
  const _SelectionQuickActionsBar({
    required this.palette,
    required this.selectionLabel,
    required this.selectedRowsCount,
    required this.canMarkStatus,
    required this.onApplyValue,
    required this.onFillDown,
    required this.onDuplicateRows,
    required this.onAttachPhoto,
    required this.onAttachGps,
    required this.onJumpTo,
    required this.onMarkStatus,
  });

  final _SheetPalette palette;
  final String selectionLabel;
  final int selectedRowsCount;
  final bool canMarkStatus;
  final VoidCallback onApplyValue;
  final VoidCallback onFillDown;
  final VoidCallback onDuplicateRows;
  final VoidCallback onAttachPhoto;
  final VoidCallback onAttachGps;
  final VoidCallback onJumpTo;
  final ValueChanged<String> onMarkStatus;

  @override
  State<_SelectionQuickActionsBar> createState() =>
      _SelectionQuickActionsBarState();
}

class _SelectionQuickActionsBarState extends State<_SelectionQuickActionsBar> {
  bool _expanded = false;

  List<_QuickActionItem> _buildActions() {
    return <_QuickActionItem>[
      _QuickActionItem(
        label: AppStrings.quickActionApplyValue,
        icon: Icons.format_color_text_rounded,
        onTap: widget.onApplyValue,
      ),
      _QuickActionItem(
        label: AppStrings.quickActionFillDown,
        icon: Icons.vertical_align_bottom_rounded,
        onTap: widget.onFillDown,
      ),
      _QuickActionItem(
        label: AppStrings.quickActionDuplicateRow,
        icon: Icons.copy_all_outlined,
        onTap: widget.onDuplicateRows,
      ),
      _QuickActionItem(
        label: AppStrings.quickActionAttachPhoto,
        icon: Icons.photo_camera_outlined,
        onTap: widget.onAttachPhoto,
      ),
      _QuickActionItem(
        label: AppStrings.quickActionAttachGps,
        icon: Icons.my_location_rounded,
        onTap: widget.onAttachGps,
      ),
      _QuickActionItem(
        label: AppStrings.quickActionGoTo,
        icon: Icons.pin_drop_outlined,
        variant: AppButtonVariant.ghost,
        onTap: widget.onJumpTo,
      ),
    ];
  }

  Future<void> _openMoreActionsSheet(List<_QuickActionItem> actions) async {
    if (actions.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: false,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    AppStrings.moreActions,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: actions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final action = actions[index];
                      return SizedBox(
                        height: 52,
                        child: ListTile(
                          leading: Icon(action.icon),
                          title: Text(
                            action.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            action.onTap();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickButton(_QuickActionItem action) {
    return AppButton(
      label: action.label,
      icon: action.icon,
      size: AppButtonSize.sm,
      variant: action.variant,
      onPressed: action.onTap,
    );
  }

  Widget _buildCompactQuickButton(_QuickActionItem action) {
    return Tooltip(
      message: action.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: action.onTap,
        child: Container(
          width: 58,
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: widget.palette.hintBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.palette.border,
              width: widget.palette.hairline,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 18, color: widget.palette.fg),
              const SizedBox(height: 4),
              Text(
                _compactLabelFor(action.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.palette.fgMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _compactLabelFor(String label) {
    if (label == AppStrings.quickActionApplyValue) return 'Pegar';
    if (label == AppStrings.quickActionFillDown) return 'Rellenar';
    if (label == AppStrings.quickActionDuplicateRow) return 'Duplicar';
    if (label == AppStrings.quickActionAttachPhoto) return 'Foto';
    if (label == AppStrings.quickActionAttachGps) return 'GPS';
    if (label == AppStrings.quickActionGoTo) return 'Ir a';
    if (label == AppStrings.more) return 'Mas';
    return label;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowsLabel = widget.selectedRowsCount <= 1
            ? '1 fila'
            : '${widget.selectedRowsCount} filas';
        final isCompact = constraints.maxWidth <= 420;
        final actions = _buildActions();
        final pinnedCount = isCompact ? 4 : 3;
        final pinnedActions = actions.take(pinnedCount).toList(growable: false);
        final moreActions = actions.skip(pinnedCount).toList(growable: false);
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding:
              EdgeInsets.fromLTRB(12, 0, 12, 8 + (bottomInset > 0 ? 6 : 0)),
          child: AppleCard(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            radius: 16,
            color: widget.palette.menuBg
                .withValues(alpha: widget.palette.isLight ? 0.94 : 0.82),
            borderColor: widget.palette.borderStrong,
            shadows: const <BoxShadow>[],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: isCompact
                      ? () => unawaited(
                            _openMoreActionsSheet(
                              _buildCompactMoreActions(actions),
                            ),
                          )
                      : () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppStrings.quickActions,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.palette.fgMuted,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.8,
                            ),
                          ),
                        ),
                        Icon(
                          isCompact
                              ? Icons.more_horiz_rounded
                              : (_expanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded),
                          size: 18,
                          color: widget.palette.fgMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isCompact || _expanded) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$rowsLabel \u00B7 ${widget.selectionLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.palette.fgMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.8,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (isCompact)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final action in pinnedActions)
                        _buildCompactQuickButton(action),
                      _buildCompactQuickButton(
                        _QuickActionItem(
                          label: AppStrings.more,
                          icon: Icons.more_horiz_rounded,
                          onTap: () => unawaited(
                            _openMoreActionsSheet(
                                _buildCompactMoreActions(actions)),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final action in pinnedActions)
                        _buildQuickButton(action),
                      AppButton(
                        label: AppStrings.more,
                        icon: Icons.more_horiz_rounded,
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.ghost,
                        onPressed: () =>
                            unawaited(_openMoreActionsSheet(moreActions)),
                      ),
                    ],
                  ),
                if (!isCompact && _expanded && widget.canMarkStatus) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final status in const <String>[
                        'OK',
                        'Obs',
                        'Urgente'
                      ])
                        AppButton(
                          label: status,
                          icon: Icons.flag_outlined,
                          size: AppButtonSize.sm,
                          variant: AppButtonVariant.ghost,
                          onPressed: () => widget.onMarkStatus(status),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<_QuickActionItem> _buildCompactMoreActions(
      List<_QuickActionItem> actions) {
    final out = <_QuickActionItem>[...actions];
    if (widget.canMarkStatus) {
      out.addAll(<_QuickActionItem>[
        _QuickActionItem(
          label: 'Marcar OK',
          icon: Icons.flag_outlined,
          onTap: () => widget.onMarkStatus('OK'),
        ),
        _QuickActionItem(
          label: 'Marcar Obs',
          icon: Icons.flag_outlined,
          onTap: () => widget.onMarkStatus('Obs'),
        ),
        _QuickActionItem(
          label: 'Marcar Urgente',
          icon: Icons.flag_outlined,
          onTap: () => widget.onMarkStatus('Urgente'),
        ),
      ]);
    }
    return out;
  }
}

class _EditorPremiumEmptyStatePanel extends StatelessWidget {
  const _EditorPremiumEmptyStatePanel({
    required this.palette,
    required this.onNewRecord,
    required this.onSmartPaste,
    required this.onUseTemplate,
  });

  final _SheetPalette palette;
  final VoidCallback onNewRecord;
  final VoidCallback onSmartPaste;
  final VoidCallback onUseTemplate;

  @override
  Widget build(BuildContext context) {
    return AppleCard(
      key: const ValueKey('editor-premium-empty-state'),
      radius: 16,
      color: palette.menuBg.withValues(alpha: palette.isLight ? 0.96 : 0.84),
      borderColor: palette.borderStrong,
      shadows: const <BoxShadow>[],
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hoja vacia',
            style: TextStyle(
              color: palette.fg,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Empieza en segundos: crea un registro, pega una tabla o importa cuando este habilitado.',
            style: TextStyle(
              color: palette.fgMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          AppButton(
            key: const ValueKey('empty-state-cta-new-record'),
            label: 'Nuevo registro',
            icon: Icons.add_box_outlined,
            variant: AppButtonVariant.primary,
            onPressed: onNewRecord,
          ),
          const SizedBox(height: 8),
          AppButton(
            key: const ValueKey('empty-state-cta-smart-paste'),
            label: 'Pegar tabla',
            icon: Icons.table_chart_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: onSmartPaste,
          ),
          const SizedBox(height: 4),
          Text(
            'Tip: pega TSV/CSV y aparece preview para confirmar.',
            style: TextStyle(
              color: palette.fgMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          AppButton(
            key: const ValueKey('empty-state-cta-template'),
            label: 'Usar plantilla',
            icon: Icons.grid_view_rounded,
            variant: AppButtonVariant.ghost,
            onPressed: onUseTemplate,
          ),
        ],
      ),
    );
  }
}

class _MobileFabAction {
  const _MobileFabAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _MobileExpandableFabMenu extends StatelessWidget {
  const _MobileExpandableFabMenu({
    required this.palette,
    required this.isOpen,
    required this.hidden,
    required this.bottomOffset,
    required this.onMainTap,
    required this.onDismiss,
    required this.actions,
    this.forceReducedMotion = false,
  });

  final _SheetPalette palette;
  final bool isOpen;
  final bool hidden;
  final double bottomOffset;
  final VoidCallback onMainTap;
  final VoidCallback onDismiss;
  final List<_MobileFabAction> actions;
  final bool forceReducedMotion;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        forceReducedMotion || MediaQuery.of(context).disableAnimations;
    final openDuration = reduceMotion ? Duration.zero : AppMotion.quick;
    return Stack(
      children: [
        if (isOpen)
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey('mobile-fab-scrim'),
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: const SizedBox.expand(),
            ),
          ),
        Positioned(
          right: 12,
          bottom: bottomOffset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: openDuration,
                switchInCurve: AppMotion.standardOut,
                switchOutCurve: AppMotion.standardIn,
                child: !isOpen
                    ? const SizedBox.shrink()
                    : Container(
                        key: const ValueKey('mobile-fab-panel'),
                        width: 210,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: palette.menuBg.withValues(
                            alpha: palette.isLight ? 0.96 : 0.86,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: palette.borderStrong,
                            width: palette.hairline,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final action in actions)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: AppButton(
                                  key: action.key,
                                  label: action.label,
                                  icon: action.icon,
                                  size: AppButtonSize.sm,
                                  variant: AppButtonVariant.secondary,
                                  onPressed: () {
                                    AppHaptics.light();
                                    onDismiss();
                                    action.onTap();
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              IgnorePointer(
                ignoring: hidden,
                child: AnimatedOpacity(
                  duration: openDuration,
                  opacity: hidden ? 0 : 1,
                  child: FloatingActionButton.small(
                    key: const ValueKey('mobile-fab-main'),
                    heroTag: 'mobile-fab-main',
                    tooltip: 'Acciones rápidas',
                    onPressed: onMainTap,
                    backgroundColor: palette.appBarBg,
                    foregroundColor: palette.fg,
                    child: Icon(
                      isOpen ? Icons.close_rounded : Icons.bolt_rounded,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileQuickActionsBar extends StatelessWidget {
  const _MobileQuickActionsBar({
    required this.palette,
    required this.sensorsEnabled,
    required this.onQuickCapture,
    required this.onForm,
    required this.onBatch,
    required this.onGps,
    required this.onPhoto,
    required this.onVideo,
    required this.onAudio,
    required this.onFile,
    required this.onExport,
    required this.onShare,
    required this.onDensity,
  });

  final _SheetPalette palette;
  final bool sensorsEnabled;
  final VoidCallback onQuickCapture;
  final VoidCallback onForm;
  final VoidCallback onBatch;
  final VoidCallback onGps;
  final VoidCallback onPhoto;
  final VoidCallback onVideo;
  final VoidCallback onAudio;
  final VoidCallback onFile;
  final VoidCallback onExport;
  final VoidCallback onShare;
  final VoidCallback onDensity;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final bg = t.colors.surfaceElevated.withValues(
      alpha: palette.isLight ? 0.94 : 0.8,
    );

    return AppleCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      radius: t.radii.xl,
      color: bg,
      borderColor: t.colors.borderStrong,
      shadows: t.shadows.soft,
      child: SizedBox(
        height: _kMobileQuickBarH + 2,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              AppleButton(
                icon: Icons.add_box_outlined,
                label: '+ Registro',
                dense: true,
                onPressed: onQuickCapture,
                variant: AppleButtonVariant.filled,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.description_outlined,
                label: 'Formulario',
                dense: true,
                onPressed: onForm,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.layers_outlined,
                label: 'Lote',
                dense: true,
                onPressed: onBatch,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.my_location_rounded,
                label: 'GPS',
                dense: true,
                onPressed: onGps,
                enabled: sensorsEnabled,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.photo_camera_outlined,
                label: 'Camara',
                dense: true,
                onPressed: onPhoto,
                enabled: sensorsEnabled,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.videocam_outlined,
                label: 'Video',
                dense: true,
                onPressed: onVideo,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.mic_none_rounded,
                label: 'Audio',
                dense: true,
                onPressed: onAudio,
                enabled: sensorsEnabled,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.attach_file_rounded,
                label: 'Archivo',
                dense: true,
                onPressed: onFile,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.format_line_spacing_rounded,
                label: 'Densidad',
                dense: true,
                onPressed: onDensity,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.download_rounded,
                label: 'Exportar',
                dense: true,
                onPressed: onExport,
                variant: AppleButtonVariant.tonal,
              ),
              const SizedBox(width: 8),
              AppleButton(
                icon: Icons.ios_share_rounded,
                label: 'Compartir',
                dense: true,
                onPressed: onShare,
                variant: AppleButtonVariant.tonal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ========================= Mobile inline editor bar ========================

class _MobileInlineEditorBar extends StatelessWidget {
  const _MobileInlineEditorBar({
    required this.palette,
    required this.density,
    required this.barKey,
    required this.fieldKey,
    required this.isOpen,
    required this.title,
    required this.validationHint,
    required this.controller,
    required this.focusNode,
    required this.actions,
    required this.keyboardInset,
    required this.panelHeight,
    required this.canCopyPaste,
    required this.onGpsRow,
    required this.onPrev,
    required this.onNext,
    required this.onCopy,
    required this.onPaste,
    required this.onOverflow,
    required this.onCancel,
    required this.onDone,
  });

  final _SheetPalette palette;
  final _GridDensity density;
  final Key barKey;
  final Key fieldKey;
  final bool isOpen;
  final String title;
  final String? validationHint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<_MobileAction> actions;

  // inset real de teclado (dp)
  final double keyboardInset;
  final double panelHeight;
  final bool canCopyPaste;
  final VoidCallback? onGpsRow;

  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onOverflow;

  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final bindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.escape): onCancel,
      const SingleActivator(LogicalKeyboardKey.enter, meta: true): onDone,
      const SingleActivator(LogicalKeyboardKey.enter, control: true): onDone,
      if (onNext != null)
        const SingleActivator(LogicalKeyboardKey.tab): onNext!,
      if (onPrev != null)
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): onPrev!,
    };

    // ??? iOS Web: 0 exacto puede hacer que Safari ???no considere??? el input visible.
    final opacity = isOpen ? 1.0 : 0.01;

    final label = title.trim().isEmpty ? 'Editar' : title.trim();
    final metrics = _gridMetricsFor(density);
    final editorFont = (metrics.cellFontSize + 2).clamp(13.0, 17.0);
    final hPad = math.max(10.0, metrics.cellPadding.horizontal / 2);
    final vPad = math.max(10.0, metrics.cellPadding.vertical / 2);
    final editorPadding = EdgeInsets.symmetric(
      horizontal: hPad,
      vertical: vPad,
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedPadding(
        duration: AppMotion.quick,
        curve: AppMotion.standardOut,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SafeArea(
          top: false,
          bottom: true,
          child: AbsorbPointer(
            absorbing: !isOpen,
            child: AnimatedOpacity(
              duration: AppMotion.quick,
              curve: AppMotion.standardOut,
              opacity: opacity,
              child: CallbackShortcuts(
                bindings: bindings,
                child: Container(
                  key: barKey,
                  height: panelHeight,
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: BoxDecoration(
                    color: palette.appBarBg,
                    border: Border(
                      top: BorderSide(
                        color: palette.borderStrong,
                        width: palette.hairline,
                      ),
                    ),
                  ),
                  child: RepaintBoundary(
                    child: Container(
                      key: const ValueKey('mobile-inline-editor-panel'),
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      decoration: BoxDecoration(
                        color: palette.editorBg.withValues(
                          alpha: palette.isLight ? 0.97 : 0.88,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: palette.borderStrong,
                          width: palette.hairline,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.fgMuted,
                                    fontWeight: FontWeight.w900,
                                    fontSize: metrics.headerFontSize,
                                    height: 1.05,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                              _MobilePanelIconButton(
                                icon: Icons.chevron_left_rounded,
                                tooltip: 'Anterior',
                                onTap: onPrev,
                                palette: palette,
                                iconSize: 18,
                                splashRadius: 16,
                                padding: const EdgeInsets.all(4),
                              ),
                              _MobilePanelIconButton(
                                icon: Icons.chevron_right_rounded,
                                tooltip: 'Siguiente',
                                onTap: onNext,
                                palette: palette,
                                iconSize: 18,
                                splashRadius: 16,
                                padding: const EdgeInsets.all(4),
                              ),
                              _MobilePanelIconButton(
                                icon: Icons.check_rounded,
                                tooltip: 'Done',
                                onTap: onDone,
                                palette: palette,
                                iconSize: 18,
                                splashRadius: 16,
                                padding: const EdgeInsets.all(4),
                              ),
                              _MobilePanelIconButton(
                                icon: Icons.more_horiz_rounded,
                                tooltip: 'Acciones',
                                onTap: onOverflow,
                                palette: palette,
                                iconSize: 18,
                                splashRadius: 16,
                                padding: const EdgeInsets.all(4),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 46,
                            child: KeyedSubtree(
                              key: fieldKey,
                              child: _MobileEditorField(
                                controller: controller,
                                focusNode: focusNode,
                                palette: palette,
                                onNext: onNext,
                                onDone: onDone,
                                fontSize: editorFont,
                                contentPadding: editorPadding,
                              ),
                            ),
                          ),
                          if (validationHint != null &&
                              validationHint!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              validationHint!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.fgMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          // Acciones solo via overflow sheet
                        ],
                      ),
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

class _MobilePanelIconButton extends StatelessWidget {
  const _MobilePanelIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.palette,
    this.iconSize = 20,
    this.splashRadius = 18,
    this.padding = const EdgeInsets.all(6),
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final _SheetPalette palette;
  final double iconSize;
  final double splashRadius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = enabled ? palette.fg : palette.fgMuted.withValues(alpha: 0.5);
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: fg, size: iconSize),
      padding: padding,
      splashRadius: splashRadius,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MobileEditorField extends StatelessWidget {
  const _MobileEditorField({
    required this.controller,
    required this.focusNode,
    required this.palette,
    required this.onNext,
    required this.onDone,
    required this.fontSize,
    required this.contentPadding,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final _SheetPalette palette;
  final VoidCallback? onNext;
  final VoidCallback onDone;
  final double fontSize;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: false,
      minLines: 1,
      maxLines: 2,
      enabled: true,
      textAlignVertical: TextAlignVertical.center,
      textInputAction:
          onNext == null ? TextInputAction.done : TextInputAction.next,
      keyboardAppearance: palette.isLight ? Brightness.light : Brightness.dark,
      scrollPadding: EdgeInsets.zero,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      style: TextStyle(
        color: palette.fg,
        fontSize: fontSize,
        height: 1.08,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.15,
      ),
      cursorColor: palette.accent,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        // Dark: mantener vidrio visible.
        fillColor: palette.mobileInputBg,
        contentPadding: contentPadding,
        hintText: 'Escribir',
        hintStyle: TextStyle(color: palette.fgMuted),
        border: InputBorder.none,
      ),
      onSubmitted: (_) => onNext == null ? onDone() : onNext!(),
    );
  }
}
