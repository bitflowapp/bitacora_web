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
              'Guia rapida (3 pasos)',
              style: TextStyle(
                color: palette.fg,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              compact
                  ? '30s: abre el rayo, usa Foto + registro y exporta.'
                  : 'En menos de 30 segundos podes abrir acciones, cargar una fila con evidencia y cerrar una salida.',
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
                  'Rayo | Foto + registro | Exportar',
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
                title: '1) Acciones',
                body:
                    'Abre acciones con el boton rayo en mobile o con Ctrl/Cmd+K en desktop.',
              ),
              SizedBox(height: 6),
              _TourStepItem(
                icon: Icons.add_a_photo_outlined,
                title: '2) Foto + registro',
                body:
                    'Crea una fila nueva, adjunta evidencia y completa el estado sin salir del flujo.',
              ),
              SizedBox(height: 6),
              _TourStepItem(
                icon: Icons.ios_share_rounded,
                title: '3) Exportar',
                body:
                    'Cuando cierres la carga, exporta o comparte ZIP, Excel o PDF segun el cierre que necesites.',
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
    required this.scope,
    required this.onScopeChanged,
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
  final _InlineSearchScope scope;
  final ValueChanged<_InlineSearchScope> onScopeChanged;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _InlineSearchScopeChip(
                  palette: palette,
                  label: 'Todo',
                  selected: scope == _InlineSearchScope.allSheet,
                  onTap: () => onScopeChanged(_InlineSearchScope.allSheet),
                ),
                _InlineSearchScopeChip(
                  palette: palette,
                  label: 'Fila',
                  selected: scope == _InlineSearchScope.currentRow,
                  onTap: () => onScopeChanged(_InlineSearchScope.currentRow),
                ),
                _InlineSearchScopeChip(
                  palette: palette,
                  label: 'Columna',
                  selected: scope == _InlineSearchScope.currentColumn,
                  onTap: () => onScopeChanged(_InlineSearchScope.currentColumn),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineSearchScopeChip extends StatelessWidget {
  const _InlineSearchScopeChip({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final _SheetPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? palette.selectionBorder : palette.fgMuted;
    final bg = selected ? palette.selectionFill : palette.hintBg;
    final border = selected
        ? palette.selectionBorder.withValues(alpha: 0.4)
        : palette.border;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: palette.hairline),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
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

class _FlowBotInlineQuickBar extends StatelessWidget {
  const _FlowBotInlineQuickBar({
    required this.palette,
    required this.title,
    required this.actions,
    required this.onRun,
    this.detail,
  });

  final _SheetPalette palette;
  final String title;
  final String? detail;
  final List<_FlowBotInlineQuickActionView> actions;
  final ValueChanged<_FlowBotQuickActionSpec> onRun;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: GlassSurface(
        key: const ValueKey('flowbot-inline-bar'),
        radius: 16,
        blurSigma: palette.isLight ? 10 : 9,
        backgroundColor:
            palette.menuBg.withValues(alpha: palette.isLight ? 0.78 : 0.58),
        borderColor: palette.borderStrong
            .withValues(alpha: palette.isLight ? 0.52 : 0.82),
        shadowColor:
            Colors.black.withValues(alpha: palette.isLight ? 0.08 : 0.24),
        shadowBlur: 14,
        shadowOffset: const Offset(0, 7),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: palette.fgMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: palette.fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.8,
                    ),
                  ),
                ),
              ],
            ),
            if ((detail ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                detail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.fgMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.1,
                ),
              ),
            ],
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int index = 0; index < actions.length; index++) ...[
                    _FlowBotInlineActionChip(
                      key: ValueKey('flowbot-inline-action-$index'),
                      palette: palette,
                      action: actions[index],
                      onTap: () => onRun(actions[index].action),
                    ),
                    if (index < actions.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowBotInlineActionChip extends StatelessWidget {
  const _FlowBotInlineActionChip({
    super.key,
    required this.palette,
    required this.action,
    required this.onTap,
  });

  final _SheetPalette palette;
  final _FlowBotInlineQuickActionView action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = switch (action.source) {
      'user' => palette.accent.withValues(alpha: palette.isLight ? 0.12 : 0.18),
      'template' => palette.mobileInputBg,
      _ => palette.hintBg,
    };
    final borderColor = switch (action.source) {
      'user' => palette.accent.withValues(alpha: palette.isLight ? 0.24 : 0.32),
      _ => palette.border,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 116, maxWidth: 180),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: palette.hairline,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(action.icon, size: 16, color: palette.fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                action.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.6,
                  height: 1.1,
                ),
              ),
            ),
            if (action.source == 'user')
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 1),
                child: Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: palette.accent,
                ),
              )
            else if (action.source == 'template')
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 1),
                child: Icon(
                  Icons.auto_fix_high_rounded,
                  size: 14,
                  color: palette.fgMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
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
    if (label == AppStrings.quickActionApplyValue) return 'Valor';
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
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final keyboardVisible = bottomInset > 0.0;
        final compactLayout = isCompact || keyboardVisible;
        const safeSeparator = ' | ';
        final quickActionsHeader =
            '${AppStrings.quickActions}$safeSeparator$rowsLabel';
        final pinnedCount = 4;
        final pinnedActions = actions.take(pinnedCount).toList(growable: false);
        final moreActions = actions.skip(pinnedCount).toList(growable: false);
        final compactMoreActions = _buildCompactMoreActions(moreActions);

        return AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(12, 0, 12, keyboardVisible ? 6 : 8),
          child: GlassSurface(
            radius: keyboardVisible ? 14 : 18,
            blurSigma: widget.palette.isLight ? (keyboardVisible ? 10 : 12) : 9,
            backgroundColor: widget.palette.menuBg
                .withValues(alpha: widget.palette.isLight ? 0.78 : 0.58),
            borderColor: widget.palette.borderStrong
                .withValues(alpha: widget.palette.isLight ? 0.55 : 0.82),
            shadowColor: Colors.black
                .withValues(alpha: widget.palette.isLight ? 0.08 : 0.24),
            shadowBlur: 16,
            shadowOffset: const Offset(0, 8),
            padding: keyboardVisible
                ? const EdgeInsets.fromLTRB(8, 6, 8, 6)
                : const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: compactLayout
                      ? () => unawaited(
                            _openMoreActionsSheet(compactMoreActions),
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
                            quickActionsHeader,
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
                          compactLayout
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
                if (!keyboardVisible && (compactLayout || _expanded)) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.selectionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.palette.fgMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.8,
                    ),
                  ),
                ],
                SizedBox(height: keyboardVisible ? 4 : 8),
                if (compactLayout)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final action in pinnedActions) ...[
                          _buildCompactQuickButton(action),
                          const SizedBox(width: 8),
                        ],
                        if (compactMoreActions.isNotEmpty)
                          _buildCompactQuickButton(
                            _QuickActionItem(
                              label: AppStrings.more,
                              icon: Icons.more_horiz_rounded,
                              onTap: () => unawaited(
                                _openMoreActionsSheet(compactMoreActions),
                              ),
                            ),
                          ),
                      ],
                    ),
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
                        onPressed: moreActions.isEmpty
                            ? null
                            : () =>
                                unawaited(_openMoreActionsSheet(moreActions)),
                      ),
                    ],
                  ),
                if (!compactLayout && _expanded && widget.canMarkStatus) ...[
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
            'Hoja vac\u00eda',
            style: TextStyle(
              color: palette.fg,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Empieza en segundos: crea un registro, pega una tabla o importa cuando est\u00e9 habilitado.',
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
            'Tip: pega TSV/CSV y aparece una vista previa para confirmar.',
            style: TextStyle(
              color: palette.fgMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          AppButton(
            key: const ValueKey('empty-state-cta-template'),
            label: 'Usar una plantilla',
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
    final maxPanelHeight = math.min(
      320.0,
      MediaQuery.of(context).size.height * 0.5,
    );
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
                        child: SizedBox(
                          height: maxPanelHeight,
                          child: SingleChildScrollView(
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

// ========================= Mobile inline editor bar ========================

class _MobileInlineEditorBar extends StatelessWidget {
  const _MobileInlineEditorBar({
    required this.palette,
    required this.density,
    required this.barKey,
    required this.fieldKey,
    required this.keyboardInset,
    required this.bottomAnimationDuration,
    required this.isOpen,
    required this.title,
    required this.validationHint,
    required this.controller,
    required this.focusNode,
    required this.actions,
    required this.panelHeight,
    required this.isExpanded,
    required this.canCopyPaste,
    required this.onGpsRow,
    required this.onPrev,
    required this.onNext,
    required this.onCopy,
    required this.onPaste,
    required this.onOverflow,
    required this.onToggleExpanded,
    required this.onCancel,
    required this.onDone,
  });

  final _SheetPalette palette;
  final _GridDensity density;
  final Key barKey;
  final Key fieldKey;
  final double keyboardInset;
  final Duration bottomAnimationDuration;
  final bool isOpen;
  final String title;
  final String? validationHint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<_MobileAction> actions;

  final double panelHeight;
  final bool isExpanded;
  final bool canCopyPaste;
  final VoidCallback? onGpsRow;

  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onOverflow;
  final VoidCallback onToggleExpanded;

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

    // iOS Web: 0 exacto puede hacer que Safari no considere el input visible.
    final opacity = isOpen ? 1.0 : 0.01;

    final media = MediaQuery.of(context);
    final resolvedKeyboardInset = keyboardInset < 0 ? 0.0 : keyboardInset;
    final keyboardVisible = resolvedKeyboardInset > 0.0;
    final homeIndicatorInset = keyboardVisible ? 0.0 : media.viewPadding.bottom;
    final compactBar = keyboardVisible || !isExpanded;

    final label = title.trim().isEmpty ? 'Editar' : title.trim();
    final metrics = _gridMetricsFor(density);
    final editorFont = math.max(16.0, metrics.cellFontSize + 3).toDouble();
    final editorPadding = compactBar
        ? EdgeInsets.symmetric(
            horizontal: keyboardVisible ? 14 : 12,
            vertical: keyboardVisible ? 10 : 9,
          )
        : EdgeInsets.symmetric(
            horizontal: math.max(14.0, metrics.cellPadding.horizontal / 2),
            vertical: math.max(11.0, metrics.cellPadding.vertical / 2),
          );
    final barHeight = compactBar
        ? (keyboardVisible ? _kMobileInlineCompactBarH : 60.0)
        : panelHeight;
    final compactFieldHeight = keyboardVisible ? 48.0 : 46.0;

    final iconSize = compactBar ? 22.0 : 18.0;
    final iconPadding =
        compactBar ? const EdgeInsets.all(8) : const EdgeInsets.all(4);
    final iconSplash = compactBar ? 22.0 : 16.0;
    final iconConstraints = compactBar
        ? const BoxConstraints(minWidth: 46, minHeight: 46)
        : const BoxConstraints(minWidth: 34, minHeight: 34);

    return AnimatedPositioned(
      duration: bottomAnimationDuration,
      curve: Curves.easeOut,
      left: 0,
      right: 0,
      bottom: resolvedKeyboardInset,
      child: SafeArea(
        top: false,
        bottom: false,
        minimum: EdgeInsets.zero,
        child: AbsorbPointer(
          absorbing: !isOpen,
          child: AnimatedOpacity(
            duration: AppMotion.quick,
            curve: AppMotion.standardOut,
            opacity: opacity,
            child: CallbackShortcuts(
              bindings: bindings,
              child: Padding(
                padding: EdgeInsets.only(bottom: homeIndicatorInset),
                child: SizedBox(
                  key: barKey,
                  height: barHeight,
                  child: RepaintBoundary(
                    child: Padding(
                      padding: compactBar
                          ? const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            )
                          : const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: GlassSurface(
                        radius: compactBar ? 16 : 20,
                        blurSigma: 0,
                        backgroundColor: palette.editorBg.withValues(alpha: 1),
                        borderColor: palette.borderStrong.withValues(alpha: 1),
                        shadowColor: Colors.black.withValues(
                          alpha: palette.isLight ? 0.07 : 0.22,
                        ),
                        shadowBlur: compactBar ? 10 : 14,
                        shadowOffset: compactBar
                            ? const Offset(0, 4)
                            : const Offset(0, 7),
                        padding: compactBar
                            ? const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              )
                            : const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        child: compactBar
                            ? Row(
                                children: [
                                  _MobilePanelIconButton(
                                    icon: Icons.chevron_left_rounded,
                                    tooltip: 'Anterior',
                                    onTap: onPrev,
                                    palette: palette,
                                    iconSize: iconSize,
                                    splashRadius: iconSplash,
                                    padding: iconPadding,
                                    constraints: iconConstraints,
                                    subtle: true,
                                  ),
                                  _MobilePanelIconButton(
                                    icon: Icons.chevron_right_rounded,
                                    tooltip: 'Siguiente',
                                    onTap: onNext,
                                    palette: palette,
                                    iconSize: iconSize,
                                    splashRadius: iconSplash,
                                    padding: iconPadding,
                                    constraints: iconConstraints,
                                    subtle: true,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: SizedBox(
                                      height: compactFieldHeight,
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
                                          expanded: false,
                                          compactMode: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _MobilePanelIconButton(
                                    icon: Icons.check_circle_rounded,
                                    tooltip: 'Guardar y cerrar',
                                    onTap: onDone,
                                    palette: palette,
                                    iconSize: iconSize + 1,
                                    splashRadius: iconSplash,
                                    padding: iconPadding,
                                    constraints: const BoxConstraints(
                                      minWidth: 52,
                                      minHeight: 46,
                                    ),
                                    filled: true,
                                  ),
                                  if (!keyboardVisible)
                                    _MobilePanelIconButton(
                                      icon: isExpanded
                                          ? Icons.unfold_less_rounded
                                          : Icons.unfold_more_rounded,
                                      tooltip:
                                          isExpanded ? 'Compactar' : 'Expandir',
                                      onTap: onToggleExpanded,
                                      palette: palette,
                                      iconSize: iconSize,
                                      splashRadius: iconSplash,
                                      padding: iconPadding,
                                      constraints: iconConstraints,
                                      subtle: true,
                                    ),
                                  _MobilePanelIconButton(
                                    icon: Icons.more_horiz_rounded,
                                    tooltip: 'Mas acciones',
                                    onTap: onOverflow,
                                    palette: palette,
                                    iconSize: iconSize,
                                    splashRadius: iconSplash,
                                    padding: iconPadding,
                                    constraints: iconConstraints,
                                    subtle: true,
                                  ),
                                ],
                              )
                            : Column(
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
                                        subtle: true,
                                      ),
                                      _MobilePanelIconButton(
                                        icon: Icons.chevron_right_rounded,
                                        tooltip: 'Siguiente',
                                        onTap: onNext,
                                        palette: palette,
                                        iconSize: 18,
                                        splashRadius: 16,
                                        padding: const EdgeInsets.all(4),
                                        subtle: true,
                                      ),
                                      _MobilePanelIconButton(
                                        icon: isExpanded
                                            ? Icons.unfold_less_rounded
                                            : Icons.unfold_more_rounded,
                                        tooltip: isExpanded
                                            ? 'Compactar'
                                            : 'Expandir',
                                        onTap: onToggleExpanded,
                                        palette: palette,
                                        iconSize: 17,
                                        splashRadius: 16,
                                        padding: const EdgeInsets.all(4),
                                        subtle: true,
                                      ),
                                      _MobilePanelIconButton(
                                        icon: Icons.check_circle_rounded,
                                        tooltip: 'Guardar y cerrar',
                                        onTap: onDone,
                                        palette: palette,
                                        iconSize: 19,
                                        splashRadius: 16,
                                        padding: const EdgeInsets.all(4),
                                        filled: true,
                                      ),
                                      _MobilePanelIconButton(
                                        icon: Icons.more_horiz_rounded,
                                        tooltip: 'Mas acciones',
                                        onTap: onOverflow,
                                        palette: palette,
                                        iconSize: 18,
                                        splashRadius: 16,
                                        padding: const EdgeInsets.all(4),
                                        subtle: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: isExpanded ? 78 : 44,
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
                                        expanded: isExpanded,
                                        compactMode: false,
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
    this.constraints = const BoxConstraints(minWidth: 34, minHeight: 34),
    this.filled = false,
    this.subtle = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final _SheetPalette palette;
  final double iconSize;
  final double splashRadius;
  final EdgeInsets padding;
  final BoxConstraints constraints;
  final bool filled;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final secondaryFg = subtle
        ? palette.fgMuted.withValues(alpha: enabled ? 0.92 : 0.46)
        : (enabled ? palette.fg : palette.fgMuted.withValues(alpha: 0.5));
    final fg = filled ? palette.editorBg : secondaryFg;
    final bg = filled
        ? palette.accent.withValues(alpha: enabled ? 1 : 0.42)
        : (subtle
            ? palette.hintBg.withValues(
                alpha: enabled
                    ? (palette.isLight ? 0.78 : 0.54)
                    : (palette.isLight ? 0.45 : 0.32),
              )
            : Colors.transparent);
    final borderColor = subtle
        ? palette.border.withValues(alpha: enabled ? 0.62 : 0.36)
        : Colors.transparent;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: palette.hairline),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: fg, size: iconSize),
        padding: padding,
        splashRadius: splashRadius,
        constraints: constraints,
        visualDensity: VisualDensity.compact,
      ),
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
    required this.expanded,
    required this.compactMode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final _SheetPalette palette;
  final VoidCallback? onNext;
  final VoidCallback onDone;
  final double fontSize;
  final EdgeInsets contentPadding;
  final bool expanded;
  final bool compactMode;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compactMode ? 14 : 16);

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        final borderColor = focused
            ? palette.accent.withValues(alpha: 0.76)
            : palette.borderStrong.withValues(alpha: 0.52);

        return AnimatedContainer(
          duration: AppMotion.quick,
          curve: AppMotion.standardOut,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.mobileInputBg.withValues(alpha: 1),
                palette.mobileInputBg.withValues(
                  alpha: palette.isLight ? 0.92 : 0.86,
                ),
              ],
            ),
            border: Border.all(
              color: borderColor,
              width: focused
                  ? math.max(1.05, palette.hairline.toDouble())
                  : palette.hairline.toDouble(),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: palette.isLight ? 0.04 : 0.18,
                ),
                blurRadius: focused ? 12 : 8,
                offset: Offset(0, focused ? 5 : 3),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: false,
            minLines: compactMode ? 1 : (expanded ? 3 : 1),
            maxLines: compactMode ? 1 : (expanded ? 5 : 1),
            expands: false,
            enabled: true,
            textAlignVertical: compactMode
                ? TextAlignVertical.center
                : (expanded ? TextAlignVertical.top : TextAlignVertical.center),
            textInputAction:
                onNext == null ? TextInputAction.done : TextInputAction.next,
            keyboardAppearance:
                palette.isLight ? Brightness.light : Brightness.dark,
            scrollPadding: EdgeInsets.zero,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            style: TextStyle(
              color: palette.fg,
              fontSize: fontSize,
              height: compactMode ? 1.1 : 1.08,
              fontWeight: compactMode ? FontWeight.w700 : FontWeight.w800,
              letterSpacing: -0.15,
            ),
            cursorColor: palette.accent,
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              contentPadding: contentPadding,
              hintText: 'Escribe aqui',
              hintStyle: TextStyle(color: palette.fgMuted),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            onSubmitted: (_) => onNext == null ? onDone() : onNext!(),
          ),
        );
      },
    );
  }
}
