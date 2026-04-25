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
                fontWeight: FontWeight.w600,
                height: 1.05,
                fontSize: 13,
              ),
            ),
          ),
          if (onAction != null && (actionLabel ?? '').trim().isNotEmpty) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 28),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                foregroundColor: fg,
                backgroundColor: fg.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
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
                      fontWeight: FontWeight.w700,
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
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
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
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
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
              'Primeros pasos',
              style: TextStyle(
                color: palette.fg,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              compact
                  ? 'Abre el menú, pega tu tabla y exporta en segundos.'
                  : 'Usa el menú de comandos, pega una tabla y exporta con un toque.',
              style: TextStyle(
                color: palette.fgMuted,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            if (compact)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: palette.hintBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: palette.border,
                    width: palette.hairline,
                  ),
                ),
                child: Text(
                  'Menú · Pegar tabla · Exportar',
                  style: TextStyle(
                    color: palette.fgMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                    letterSpacing: 0.2,
                  ),
                ),
              )
            else ...const [
              _TourStepItem(
                icon: Icons.bolt_rounded,
                title: 'Menú de comandos',
                body: 'Abre todas las acciones con Ctrl/Cmd+K.',
              ),
              SizedBox(height: 6),
              _TourStepItem(
                icon: Icons.table_chart_rounded,
                title: 'Pegar desde Excel',
                body: 'Copia tu tabla y pégala. Revisa el preview y confirma.',
              ),
              SizedBox(height: 6),
              _TourStepItem(
                icon: Icons.ios_share_rounded,
                title: 'Exportar PDF o Excel',
                body: 'Un toque para generar el reporte profesional.',
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Listo',
                    icon: Icons.check_rounded,
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.primary,
                    onPressed: onAcknowledge,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'Ocultar',
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: pal.hintBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pal.border, width: pal.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 15, color: pal.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: pal.fg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    color: pal.fgMuted,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
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
                  hintText: 'Buscar...',
                  hintStyle: TextStyle(color: palette.fgMuted),
                ),
                style: TextStyle(
                  color: palette.fg,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  height: 1.1,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: palette.hintBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: palette.border,
                  width: palette.hairline,
                ),
              ),
              child: Text(
                counterText,
                style: TextStyle(
                  color: palette.fgMuted,
                  fontWeight: FontWeight.w500,
                  fontSize: 11.5,
                  letterSpacing: 0.2,
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

class _SelectionQuickActionsBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final rowsLabel =
        selectedRowsCount <= 1 ? '1 fila' : '$selectedRowsCount filas';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Container(
        decoration: BoxDecoration(
          color:
              palette.menuBg.withValues(alpha: palette.isLight ? 0.92 : 0.78),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border, width: palette.hairline),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            Flexible(
              flex: 0,
              child: Text(
                '$rowsLabel · $selectionLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.fgMuted,
                  fontWeight: FontWeight.w500,
                  fontSize: 11.5,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _QuickChip(
                      palette: palette,
                      icon: Icons.format_color_text_rounded,
                      label: 'Pegar',
                      onTap: onApplyValue,
                    ),
                    _QuickChip(
                      palette: palette,
                      icon: Icons.vertical_align_bottom_rounded,
                      label: 'Rellenar',
                      onTap: onFillDown,
                    ),
                    _QuickChip(
                      palette: palette,
                      icon: Icons.copy_all_outlined,
                      label: 'Duplicar',
                      onTap: onDuplicateRows,
                    ),
                    _QuickChip(
                      palette: palette,
                      icon: Icons.photo_camera_outlined,
                      label: 'Foto',
                      onTap: onAttachPhoto,
                    ),
                    _QuickChip(
                      palette: palette,
                      icon: Icons.my_location_rounded,
                      label: 'GPS',
                      onTap: onAttachGps,
                    ),
                    if (canMarkStatus) ...[
                      for (final status in const <String>[
                        'OK',
                        'Obs',
                        'Urgente'
                      ])
                        _QuickChip(
                          palette: palette,
                          icon: Icons.flag_outlined,
                          label: status,
                          onTap: () => onMarkStatus(status),
                        ),
                    ],
                    _QuickChipMore(
                      palette: palette,
                      onJumpTo: onJumpTo,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final _SheetPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 5),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: palette.pillBtnBg,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: palette.pillBtnBorder, width: palette.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: palette.fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: palette.fg,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChipMore extends StatelessWidget {
  const _QuickChipMore({
    required this.palette,
    required this.onJumpTo,
  });

  final _SheetPalette palette;
  final VoidCallback onJumpTo;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'jump') onJumpTo();
      },
      tooltip: '',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: palette.menuBg,
      elevation: 4,
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          value: 'jump',
          child: Row(
            children: [
              Icon(Icons.pin_drop_outlined, size: 16, color: palette.fg),
              const SizedBox(width: 8),
              Text(
                'Ir a...',
                style: TextStyle(
                  color: palette.fg,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: palette.pillBtnBg,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: palette.pillBtnBorder, width: palette.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz_rounded, size: 13, color: palette.fgMuted),
            const SizedBox(width: 4),
            Text(
              'Más',
              style: TextStyle(
                color: palette.fgMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
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
            'Tu planilla está vacía',
            style: TextStyle(
              color: palette.fg,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Agrega un registro o pega una tabla desde Excel para empezar.',
            style: TextStyle(
              color: palette.fgMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          AppButton(
            key: const ValueKey('empty-state-cta-new-record'),
            label: 'Agregar registro',
            icon: Icons.add_rounded,
            variant: AppButtonVariant.primary,
            onPressed: onNewRecord,
          ),
          const SizedBox(height: 8),
          AppButton(
            key: const ValueKey('empty-state-cta-smart-paste'),
            label: 'Pegar desde Excel',
            icon: Icons.table_chart_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: onSmartPaste,
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
                        width: 220,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: palette.menuBg.withValues(
                            alpha: palette.isLight ? 0.98 : 0.90,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: palette.border,
                            width: palette.hairline,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: palette.isLight ? 0.08 : 0.40,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
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
                  child: FloatingActionButton(
                    key: const ValueKey('mobile-fab-main'),
                    heroTag: 'mobile-fab-main',
                    tooltip: 'Agregar',
                    onPressed: onMainTap,
                    backgroundColor: palette.accent,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    highlightElevation: 4,
                    shape: const CircleBorder(),
                    child: Icon(
                      isOpen ? Icons.close_rounded : Icons.add_rounded,
                      size: 26,
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
                label: 'Grabar video',
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
    required this.onDictate,
    required this.dictationActive,
    required this.dictationStatus,
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

  /// Toggle de dictado en la celda activa.
  final VoidCallback onDictate;
  final bool dictationActive;
  final String? dictationStatus;

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

    // iOS Web: 0 exacto puede hacer que Safari no considere visible el input.
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
                          alpha: palette.isLight ? 0.98 : 0.90,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: palette.border,
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
                                    fontWeight: FontWeight.w600,
                                    fontSize: metrics.headerFontSize,
                                    height: 1.05,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              _MobilePanelIconButton(
                                icon: Icons.close_rounded,
                                tooltip: 'Cancelar',
                                onTap: onCancel,
                                palette: palette,
                                iconSize: 18,
                                splashRadius: 16,
                                padding: const EdgeInsets.all(4),
                              ),
                              _MobileDictateButton(
                                palette: palette,
                                active: dictationActive,
                                onTap: onDictate,
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
                                tooltip: 'Guardar',
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
                          if (dictationActive ||
                              (dictationStatus != null &&
                                  dictationStatus!.trim().isNotEmpty)) ...[
                            const SizedBox(height: 6),
                            _MobileDictationStatus(
                              palette: palette,
                              active: dictationActive,
                              status: dictationStatus,
                            ),
                          ],
                          if (validationHint != null &&
                              validationHint!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              constraints: const BoxConstraints(minHeight: 24),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: palette.accent.withValues(
                                  alpha: palette.isLight ? 0.10 : 0.18,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: palette.accent.withValues(alpha: 0.28),
                                  width: palette.hairline,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 13,
                                    color: palette.accent,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      validationHint!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.fg,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
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
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
      keyboardType: TextInputType.text,
      keyboardAppearance: palette.isLight ? Brightness.light : Brightness.dark,
      scrollPadding: EdgeInsets.zero,
      autocorrect: false,
      enableSuggestions: false,
      enableInteractiveSelection: true,
      textCapitalization: TextCapitalization.none,
      style: TextStyle(
        color: palette.fg,
        fontSize: fontSize,
        height: 1.08,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1,
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

class _MobileDictateButton extends StatefulWidget {
  const _MobileDictateButton({
    required this.palette,
    required this.active,
    required this.onTap,
  });

  final _SheetPalette palette;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_MobileDictateButton> createState() => _MobileDictateButtonState();
}

class _MobileDictateButtonState extends State<_MobileDictateButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_MobileDictateButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _pulse.repeat(reverse: true);
    } else if (!widget.active && oldWidget.active) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = widget.palette;
    return Tooltip(
      message: widget.active ? 'Detener dictado' : 'Dictar',
      child: SizedBox(
        width: 44,
        height: 44,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_pulse.value);
            return InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: widget.onTap,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: 30 + (widget.active ? 4 * t : 0),
                  height: 30 + (widget.active ? 4 * t : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.active
                        ? pal.accent
                        : pal.accent.withValues(alpha: 0.10),
                    boxShadow: widget.active
                        ? [
                            BoxShadow(
                              color:
                                  pal.accent.withValues(alpha: 0.35 + 0.20 * t),
                              blurRadius: 14 + 6 * t,
                              spreadRadius: 1,
                            ),
                          ]
                        : const [],
                  ),
                  child: Icon(
                    widget.active
                        ? Icons.mic_rounded
                        : Icons.record_voice_over_rounded,
                    size: 16,
                    color: widget.active
                        ? (pal.isLight ? Colors.white : Colors.black)
                        : pal.accent,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MobileDictationStatus extends StatelessWidget {
  const _MobileDictationStatus({
    required this.palette,
    required this.active,
    required this.status,
  });

  final _SheetPalette palette;
  final bool active;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final pal = palette;
    final hasStatus = status != null && status!.trim().isNotEmpty;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Container(
        key: ValueKey<String>('${active ? 1 : 0}|${status ?? ''}'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: pal.accent.withValues(alpha: pal.isLight ? 0.08 : 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: pal.accent.withValues(alpha: 0.30),
            width: pal.hairline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              active ? Icons.graphic_eq_rounded : Icons.check_rounded,
              size: 13,
              color: pal.accent,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                hasStatus
                    ? status!
                    : (active ? 'Escuchando…' : 'Dictado finalizado'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: pal.fg,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
