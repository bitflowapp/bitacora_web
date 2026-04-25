part of '../editor_screen.dart';

class _PremiumAppleHeader extends StatelessWidget {
  const _PremiumAppleHeader({
    required this.palette,
    required this.titleController,
    required this.titleFocus,
    required this.controller,
    required this.onTitleChanged,
    required this.onToggleTheme,
    required this.onUndo,
    required this.onRedo,
    required this.onAddRow,
    required this.onQuickCapture,
    required this.onForm,
    required this.onSearch,
    required this.onSearchEverywhere,
    required this.onJumpTo,
    required this.onColumns,
    required this.onHistory,
    required this.onSaveView,
    required this.onSelectView,
    required this.onManageViews,
    required this.onMarkReviewed,
    required this.onTogglePendingReviewView,
    required this.onSave,
    required this.onExport,
    required this.onSmokeTest,
    required this.onCompute,
    required this.onBatch,
    required this.onGps,
    required this.onPhoto,
    required this.onVideo,
    required this.onAudio,
    required this.onFile,
    required this.onAttachments,
    required this.onShare,
    required this.onCollaborate,
    required this.onPalette,
    required this.onGpsMode,
    required this.onDensity,
    required this.onOpenOfflineQueue,
    required this.lastLocalSavedAt,
    required this.sensorsEnabled,
    required this.selectedRow,
    required this.selectedCol,
    required this.selectedRowsCount,
    required this.pendingOfflineCount,
    required this.errorsCount,
    required this.savedViews,
    required this.activeViewId,
    required this.pendingReviewViewActive,
  });

  final _SheetPalette palette;
  final bool sensorsEnabled;

  final TextEditingController titleController;
  final FocusNode titleFocus;
  final EditorController controller;

  final ValueChanged<String> onTitleChanged;

  final VoidCallback onToggleTheme;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onAddRow;
  final VoidCallback onQuickCapture;
  final VoidCallback onForm;
  final VoidCallback onSearch;
  final VoidCallback onSearchEverywhere;
  final VoidCallback onJumpTo;
  final VoidCallback onColumns;
  final VoidCallback onHistory;
  final VoidCallback onSaveView;
  final ValueChanged<String?> onSelectView;
  final VoidCallback onManageViews;
  final VoidCallback onMarkReviewed;
  final VoidCallback onTogglePendingReviewView;

  final VoidCallback onSave;
  final VoidCallback onExport;
  final VoidCallback onSmokeTest;
  final VoidCallback? onCompute;
  final VoidCallback onBatch;

  final VoidCallback onGps;
  final VoidCallback onPhoto;
  final VoidCallback onVideo;
  final VoidCallback onAudio;
  final VoidCallback onFile;
  final VoidCallback onAttachments;
  final VoidCallback onShare;
  final VoidCallback onCollaborate;
  final VoidCallback onPalette;
  final VoidCallback onGpsMode;
  final VoidCallback onDensity;
  final VoidCallback onOpenOfflineQueue;
  final DateTime? lastLocalSavedAt;
  final int selectedRow;
  final int selectedCol;
  final int selectedRowsCount;
  final int pendingOfflineCount;
  final int errorsCount;
  final List<_SavedView> savedViews;
  final String? activeViewId;
  final bool pendingReviewViewActive;

  static String _columnLabel(int col) {
    var value = col + 1;
    final out = StringBuffer();
    while (value > 0) {
      final rem = (value - 1) % 26;
      out.writeCharCode(65 + rem);
      value = (value - 1) ~/ 26;
    }
    return out.toString().split('').reversed.join();
  }

  String _selectionLabel() {
    if (selectedRow < 0 || selectedCol < 0) return 'Sin seleccion';
    return 'Celda ${_columnLabel(selectedCol)}${selectedRow + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final top = math.max(10.0, pad.top);

    final sigma = palette.isLight ? 14.0 : 12.0;

    final glassGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        palette.gridBg.withValues(alpha: palette.isLight ? 0.94 : 0.78),
        palette.headerBg.withValues(alpha: palette.isLight ? 0.84 : 0.64),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(14, top + 8, 14, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
                child: const SizedBox(),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: BoxDecoration(
                color: palette.headerCardBg,
                gradient: glassGradient,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: palette.headerCardBorder, width: palette.hairline),
                boxShadow: [
                  BoxShadow(
                    color: palette.cellText
                        .withValues(alpha: palette.isLight ? 0.07 : 0.32),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (ctx, cs) {
                  final compact = cs.maxWidth < 720;
                  final veryCompact = cs.maxWidth < 520;

                  final titleSize = veryCompact ? 30.0 : 34.0;
                  final iconRow = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(0.1),
                        child: _IconCircleButton(
                          palette: palette,
                          icon: palette.isLight
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                          onTap: onToggleTheme,
                          tooltip:
                              palette.isLight ? 'Modo oscuro' : 'Modo claro',
                        ),
                      ),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(0.2),
                        child: _IconCircleButton(
                          palette: palette,
                          icon: Icons.undo_rounded,
                          onTap: onUndo,
                          tooltip: 'Deshacer',
                        ),
                      ),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(0.3),
                        child: _IconCircleButton(
                          palette: palette,
                          icon: Icons.redo_rounded,
                          onTap: onRedo,
                          tooltip: 'Rehacer',
                        ),
                      ),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(0.4),
                        child: _IconCircleButton(
                          palette: palette,
                          icon: Icons.add_rounded,
                          onTap: onAddRow,
                          tooltip: 'Nueva fila',
                        ),
                      ),
                    ],
                  );

                  final titleField = TextField(
                    controller: titleController,
                    focusNode: titleFocus,
                    onChanged: onTitleChanged,
                    maxLines: 1,
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      height: 1.02,
                      letterSpacing: -0.6,
                    ),
                    cursorColor: palette.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: AppStrings.editorSheetNameHint,
                      hintStyle: TextStyle(color: palette.fgMuted),
                    ),
                  );

                  return FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!compact)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: titleField),
                              const SizedBox(width: 10),
                              iconRow,
                            ],
                          )
                        else ...[
                          titleField,
                          const SizedBox(height: 10),
                          Align(
                              alignment: Alignment.centerRight, child: iconRow),
                        ],
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SaveStatusChip(
                              palette: palette,
                              status: controller.saveStatus,
                            ),
                            SyncStatusChip(
                              palette: palette,
                              status: controller.offlineStatus,
                              onTap: onOpenOfflineQueue,
                            ),
                            _InlineMetaChip(
                              palette: palette,
                              icon: Icons.grid_3x3_rounded,
                              label: _selectionLabel(),
                            ),
                            if (selectedRowsCount > 1)
                              _InlineMetaChip(
                                palette: palette,
                                icon: Icons.checklist_rounded,
                                label: '$selectedRowsCount filas',
                              ),
                            if (pendingOfflineCount > 0)
                              _InlineMetaChip(
                                palette: palette,
                                icon: Icons.cloud_upload_outlined,
                                label: '$pendingOfflineCount en cola',
                                onTap: onOpenOfflineQueue,
                              ),
                            if (errorsCount > 0)
                              _InlineMetaChip(
                                palette: palette,
                                icon: Icons.rule_rounded,
                                label: '$errorsCount errores',
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AppleToolbar(
                          items: [
                            AppleToolbarItem(
                              icon: Icons.add_box_outlined,
                              label: '+ Registro',
                              onTap: onQuickCapture,
                            ),
                            AppleToolbarItem(
                              icon: Icons.description_outlined,
                              label: 'Formulario',
                              onTap: onForm,
                            ),
                            AppleToolbarItem(
                              icon: Icons.layers_outlined,
                              label: 'Acciones',
                              onTap: onBatch,
                            ),
                            AppleToolbarItem(
                              icon: Icons.verified_rounded,
                              label: 'Revisado',
                              onTap: onMarkReviewed,
                            ),
                            AppleToolbarItem(
                              icon: pendingReviewViewActive
                                  ? Icons.pending_actions_rounded
                                  : Icons.fact_check_outlined,
                              label: pendingReviewViewActive
                                  ? 'Pendientes'
                                  : 'Ver pendientes',
                              onTap: onTogglePendingReviewView,
                            ),
                            AppleToolbarItem(
                              icon: Icons.search_rounded,
                              label: AppStrings.editorSearch,
                              shortcut: 'Ctrl/Cmd+F',
                              onTap: onSearch,
                            ),
                            AppleToolbarItem(
                              icon: Icons.travel_explore_rounded,
                              label: 'Buscar global',
                              shortcut: 'Ctrl/Cmd+Shift+F',
                              onTap: onSearchEverywhere,
                            ),
                            AppleToolbarItem(
                              icon: Icons.pin_drop_outlined,
                              label: 'Ir a...',
                              shortcut: 'Ctrl/Cmd+J',
                              onTap: onJumpTo,
                            ),
                            AppleToolbarItem(
                              icon: Icons.view_column_rounded,
                              label: 'Columnas',
                              onTap: onColumns,
                            ),
                            AppleToolbarItem(
                              icon: Icons.history_rounded,
                              label: 'Historial',
                              onTap: onHistory,
                            ),
                            AppleToolbarItem(
                              icon: Icons.my_location_rounded,
                              label: 'GPS',
                              shortcut: 'G',
                              onTap: onGps,
                              enabled: sensorsEnabled,
                              onDisabledTap: onGps,
                            ),
                            AppleToolbarItem(
                              icon: Icons.tune_rounded,
                              label: 'Modo GPS',
                              onTap: onGpsMode,
                            ),
                            AppleToolbarItem(
                              icon: Icons.format_line_spacing_rounded,
                              label: 'Densidad',
                              onTap: onDensity,
                            ),
                            AppleToolbarItem(
                              icon: Icons.photo_camera_outlined,
                              label: 'Camara',
                              shortcut: 'P',
                              onTap: onPhoto,
                              enabled: sensorsEnabled,
                              onDisabledTap: onPhoto,
                            ),
                            AppleToolbarItem(
                              icon: Icons.videocam_outlined,
                              label: 'Grabar video',
                              onTap: onVideo,
                            ),
                            AppleToolbarItem(
                              icon: Icons.mic_none_rounded,
                              label: 'Audio',
                              shortcut: 'A',
                              onTap: onAudio,
                              enabled: sensorsEnabled,
                              onDisabledTap: onAudio,
                            ),
                            AppleToolbarItem(
                              icon: Icons.attach_file_rounded,
                              label: 'Adjuntos',
                              onTap: onAttachments,
                            ),
                            AppleToolbarItem(
                              icon: Icons.attach_file_rounded,
                              label: 'Archivo',
                              onTap: onFile,
                            ),
                            AppleToolbarItem(
                              icon: Icons.group_work_outlined,
                              label: 'Colaborar',
                              onTap: onCollaborate,
                            ),
                            AppleToolbarItem(
                              icon: Icons.download_rounded,
                              label: 'Exportar',
                              shortcut: 'Ctrl/Cmd+E',
                              onTap: onExport,
                            ),
                            AppleToolbarItem(
                              icon: Icons.science_outlined,
                              label: AppStrings.editorDiagnostics,
                              onTap: onSmokeTest,
                            ),
                            AppleToolbarItem(
                              icon: Icons.functions_rounded,
                              label: AppStrings.editorCompute,
                              onTap: onCompute ?? () {},
                              enabled: onCompute != null,
                            ),
                            AppleToolbarItem(
                              icon: Icons.ios_share_rounded,
                              label: 'Compartir',
                              shortcut: 'Ctrl/Cmd+Shift+E',
                              onTap: onShare,
                            ),
                            AppleToolbarItem(
                              icon: Icons.keyboard,
                              label: 'Atajos',
                              shortcut: 'Ctrl/Cmd+K',
                              onTap: onPalette,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        palette.cellText
                            .withValues(alpha: palette.isLight ? 0.04 : 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.35],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopBottomToolbar extends StatelessWidget {
  const _DesktopBottomToolbar({
    required this.palette,
    required this.selectionLabel,
    required this.selectedRowsCount,
    required this.pendingOfflineCount,
    required this.errorsCount,
    required this.lastLocalSavedAt,
    required this.onNewRecord,
    required this.onSmartPaste,
    required this.onSearch,
    required this.onPhoto,
    required this.onGps,
    required this.onExport,
    required this.onPalette,
    required this.onToggleTrace,
    required this.traceModeActive,
  });

  final _SheetPalette palette;
  final String selectionLabel;
  final int selectedRowsCount;
  final int pendingOfflineCount;
  final int errorsCount;
  final DateTime? lastLocalSavedAt;
  final VoidCallback onNewRecord;
  final VoidCallback onSmartPaste;
  final VoidCallback onSearch;
  final VoidCallback onPhoto;
  final VoidCallback onGps;
  final VoidCallback onExport;
  final VoidCallback onPalette;
  final VoidCallback onToggleTrace;
  final bool traceModeActive;

  String _savedText() {
    final value = lastLocalSavedAt;
    if (value == null) return '--';
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return 'Guardado $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final status = <String>[
      selectionLabel,
      if (selectedRowsCount > 1) '$selectedRowsCount filas',
      _savedText(),
      if (pendingOfflineCount > 0) '$pendingOfflineCount en cola',
      if (errorsCount > 0) '$errorsCount errores',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: palette.isLight ? 16 : 12,
            sigmaY: palette.isLight ? 16 : 12,
            tileMode: TileMode.decal,
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.headerCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: palette.headerCardBorder,
                width: palette.hairline,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: palette.isLight ? 0.05 : 0.25,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.cellTextMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  flex: 2,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DesktopToolbarButton(
                          palette: palette,
                          icon: Icons.add_rounded,
                          label: 'Registro',
                          onTap: onNewRecord,
                        ),
                        _DesktopToolbarButton(
                          palette: palette,
                          icon: Icons.table_chart_rounded,
                          label: 'Pegar',
                          onTap: onSmartPaste,
                        ),
                        _DesktopToolbarButton(
                          palette: palette,
                          icon: Icons.search_rounded,
                          label: 'Buscar',
                          onTap: onSearch,
                        ),
                        _DesktopToolbarButton(
                          palette: palette,
                          icon: Icons.gesture_rounded,
                          label: traceModeActive ? 'Trazo on' : 'Trazo',
                          onTap: onToggleTrace,
                          isPrimary: traceModeActive,
                        ),
                        _DesktopToolbarButton(
                          palette: palette,
                          icon: Icons.photo_camera_rounded,
                          label: 'Foto',
                          onTap: onPhoto,
                        ),
                        _DesktopToolbarButton(
                          palette: palette,
                          icon: Icons.my_location_rounded,
                          label: 'GPS',
                          onTap: onGps,
                        ),
                        _DesktopToolbarButton(
                          palette: palette,
                          icon: Icons.ios_share_rounded,
                          label: 'Exportar',
                          onTap: onExport,
                        ),
                        _DesktopToolbarButton(
                          palette: palette,
                          icon: Icons.bolt_rounded,
                          label: 'Comandos',
                          isPrimary: true,
                          onTap: onPalette,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopToolbarButton extends StatelessWidget {
  const _DesktopToolbarButton({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final _SheetPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary ? palette.accent : palette.pillBtnBg;
    final fg = isPrimary
        ? (palette.isLight ? Colors.white : Colors.black)
        : palette.fg;
    final border = isPrimary
        ? palette.accent.withValues(alpha: 0.36)
        : palette.pillBtnBorder;

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: palette.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileCompactHeader extends StatelessWidget {
  const _MobileCompactHeader({
    required this.palette,
    required this.title,
    required this.controller,
    required this.pendingRequired,
    required this.pendingOfflineCount,
    required this.selectedRow,
    required this.selectedCol,
    required this.onSave,
    required this.onExport,
    required this.onMenu,
    required this.onOpenOfflineQueue,
    required this.lastLocalSavedAt,
  });

  final _SheetPalette palette;
  final String title;
  final EditorController controller;
  final int pendingRequired;
  final int pendingOfflineCount;
  final int selectedRow;
  final int selectedCol;
  final VoidCallback onSave;
  final VoidCallback onExport;
  final VoidCallback onMenu;
  final VoidCallback onOpenOfflineQueue;
  final DateTime? lastLocalSavedAt;

  @override
  Widget build(BuildContext context) {
    final label = title.trim().isEmpty ? 'Planilla' : title.trim();

    return ValueListenableBuilder<EditorSaveSnapshot>(
      valueListenable: controller.saveStatus,
      builder: (context, snap, _) {
        return ValueListenableBuilder<OfflineSyncSnapshot>(
          valueListenable: controller.offlineStatus,
          builder: (context, offline, __) {
            String saveLabel;
            switch (snap.state) {
              case EditorSaveState.saving:
                saveLabel = 'Guardando';
                break;
              case EditorSaveState.dirty:
                saveLabel = 'Sin guardar';
                break;
              case EditorSaveState.saved:
                saveLabel = 'Guardado';
                break;
              case EditorSaveState.idle:
                saveLabel = 'Listo';
                break;
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 4),
              child: AppTopBar(
                title: label,
                subtitle:
                    '$saveLabel${pendingRequired > 0 ? " · $pendingRequired err." : ""}${pendingOfflineCount > 0 ? " · $pendingOfflineCount cola" : ""}',
                actions: [
                  AppButton(
                    label: AppStrings.editorExport,
                    icon: Icons.ios_share_rounded,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.sm,
                    onPressed: onExport,
                  ),
                  AppButton(
                    label: AppStrings.editorOptions,
                    icon: Icons.more_horiz_rounded,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.sm,
                    onPressed: onMenu,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _InlineMetaChip extends StatelessWidget {
  const _InlineMetaChip({
    required this.palette,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final _SheetPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.hintBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border, width: palette.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: palette.fgMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: palette.fgMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              height: 1.05,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }
}

class _IconCircleButton extends StatefulWidget {
  const _IconCircleButton({
    required this.palette,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    String? semanticsLabel,
  }) : semanticsLabel = semanticsLabel ?? tooltip;

  final _SheetPalette palette;
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final String semanticsLabel;

  @override
  State<_IconCircleButton> createState() => _IconCircleButtonState();
}

class _IconCircleButtonState extends State<_IconCircleButton> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final surface = _pressed
        ? widget.palette.pillBtnBg.withValues(alpha: 0.7)
        : (_hovered
            ? widget.palette.pillBtnBg.withValues(alpha: 0.92)
            : widget.palette.pillBtnBg);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: AnimatedScale(
          duration: AppMotion.quick,
          curve: AppMotion.standardOut,
          scale: _pressed ? 0.96 : 1.0,
          child: AnimatedContainer(
            duration: AppMotion.quick,
            curve: AppMotion.standardOut,
            decoration: BoxDecoration(
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: widget.palette.cellText.withValues(
                            alpha: widget.palette.isLight ? 0.06 : 0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : const [],
            ),
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: _setPressed,
              borderRadius: BorderRadius.circular(999),
              child: Semantics(
                button: true,
                label: widget.semanticsLabel,
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: widget.palette.pillBtnBorder,
                        width: widget.palette.hairline),
                  ),
                  child: Icon(widget.icon, size: 18, color: widget.palette.fg),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================== UI: Grid ==================================

typedef _SelectCell = void Function(int r, int c);
typedef _EditCell = void Function(int r, int c, double cellWidth);
typedef _EditHeader = void Function(int c, double headerWidth);
typedef _ContextMenu = void Function(Offset pos, int r, int c, bool isHeader);
