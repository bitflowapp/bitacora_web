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
                  ? '3 atajos para arrancar rapido: pegar tabla, nuevo registro y deshacer.'
                  : 'Guia corta para pegar tablas sin jank, crear registros rapidos y deshacer en un toque.',
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
                  'Smart paste preview · Nuevo registro · Undo rapido',
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
                icon: Icons.table_chart_rounded,
                title: '1) Smart paste premium',
                body:
                    'Pega TSV/CSV y aparece preview con opciones (insertar o reemplazar).',
              ),
              SizedBox(height: 6),
              _TourStepItem(
                icon: Icons.add_box_outlined,
                title: '2) Nuevo registro',
                body:
                    'Usa +Registro o Ctrl/Cmd+N para crear fila con defaults y foco listo.',
              ),
              SizedBox(height: 6),
              _TourStepItem(
                icon: Icons.undo_rounded,
                title: '3) Undo inmediato',
                body:
                    'Si algo no cierra, usa Deshacer en snackbar para revertir sin perder ritmo.',
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
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: AppleCard(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        radius: 16,
        color: palette.menuBg.withValues(alpha: palette.isLight ? 0.94 : 0.82),
        borderColor: palette.borderStrong,
        shadows: const <BoxShadow>[],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acciones rapidas · $rowsLabel · $selectionLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.fgMuted,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton(
                  label: 'Pegar valor',
                  icon: Icons.format_color_text_rounded,
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: onApplyValue,
                ),
                AppButton(
                  label: 'Rellenar',
                  icon: Icons.vertical_align_bottom_rounded,
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: onFillDown,
                ),
                AppButton(
                  label: 'Duplicar fila',
                  icon: Icons.copy_all_outlined,
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: onDuplicateRows,
                ),
                AppButton(
                  label: 'Adjuntar foto',
                  icon: Icons.photo_camera_outlined,
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: onAttachPhoto,
                ),
                AppButton(
                  label: 'Adjuntar GPS',
                  icon: Icons.my_location_rounded,
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: onAttachGps,
                ),
                AppButton(
                  label: 'Jump to...',
                  icon: Icons.pin_drop_outlined,
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.ghost,
                  onPressed: onJumpTo,
                ),
              ],
            ),
            if (canMarkStatus) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final status in const <String>['OK', 'Obs', 'Urgente'])
                    AppButton(
                      label: status,
                      icon: Icons.flag_outlined,
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.ghost,
                      onPressed: () => onMarkStatus(status),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
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
