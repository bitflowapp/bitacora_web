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
    required this.onSearch,
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
    required this.onShare,
    required this.onPalette,
    required this.onGpsMode,
    required this.onDensity,
    required this.sensorsEnabled,
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
  final VoidCallback onSearch;

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
  final VoidCallback onShare;
  final VoidCallback onPalette;
  final VoidCallback onGpsMode;
  final VoidCallback onDensity;

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
        borderRadius: BorderRadius.circular(26),
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: palette.headerCardBg,
                gradient: glassGradient,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                    color: palette.headerCardBorder, width: palette.hairline),
                boxShadow: [
                  BoxShadow(
                    color: palette.cellText
                        .withValues(alpha: palette.isLight ? 0.10 : 0.46),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (ctx, cs) {
                  final compact = cs.maxWidth < 720;
                  final veryCompact = cs.maxWidth < 520;

                  final titleSize = veryCompact ? 30.0 : 34.0;
                  final pillGap = veryCompact ? 8.0 : 10.0;

                  final iconRow = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      _IconCircleButton(
                        palette: palette,
                        icon: palette.isLight
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        onTap: onToggleTheme,
                        tooltip: palette.isLight ? 'Modo oscuro' : 'Modo claro',
                      ),
                      _IconCircleButton(
                        palette: palette,
                        icon: Icons.undo_rounded,
                        onTap: onUndo,
                        tooltip: 'Deshacer',
                      ),
                      _IconCircleButton(
                        palette: palette,
                        icon: Icons.redo_rounded,
                        onTap: onRedo,
                        tooltip: 'Rehacer',
                      ),
                      _IconCircleButton(
                        palette: palette,
                        icon: Icons.add_rounded,
                        onTap: onAddRow,
                        tooltip: 'Nueva fila',
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
                      fontWeight: FontWeight.w900,
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

                  return Column(
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
                        Align(alignment: Alignment.centerRight, child: iconRow),
                      ],
                      const SizedBox(height: 2),
                      SaveStatusChip(
                        palette: palette,
                        status: controller.saveStatus,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: pillGap,
                        runSpacing: 10,
                        children: [
                          _PillButton(
                            palette: palette,
                            filled: true,
                            icon: Icons.add_box_outlined,
                            label: '+ Registro',
                            semanticsLabel: 'Crear registro rapido de campo',
                            onTap: onQuickCapture,
                          ),
                          _PillButton(
                            palette: palette,
                            filled: false,
                            icon: Icons.search_rounded,
                            label: AppStrings.editorSearch,
                            semanticsLabel: AppStrings.semEditorSearch,
                            onTap: onSearch,
                          ),
                          _PillButton(
                            palette: palette,
                            filled: false,
                            icon: Icons.ios_share_rounded,
                            label: AppStrings.editorExport,
                            semanticsLabel: AppStrings.semEditorExport,
                            onTap: onExport,
                          ),
                          _PillButton(
                            palette: palette,
                            filled: false,
                            icon: Icons.layers_outlined,
                            label: AppStrings.editorBatchActions,
                            semanticsLabel: 'Abrir acciones por lote',
                            onTap: onBatch,
                          ),
                          _PillButton(
                            palette: palette,
                            filled: false,
                            icon: Icons.check_circle_outline_rounded,
                            label: AppStrings.editorSave,
                            semanticsLabel: AppStrings.semEditorSave,
                            onTap: onSave,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppleToolbar(
                        items: [
                          AppleToolbarItem(
                            icon: Icons.add_box_outlined,
                            label: '+ Registro',
                            onTap: onQuickCapture,
                          ),
                          AppleToolbarItem(
                            icon: Icons.layers_outlined,
                            label: 'Acciones',
                            onTap: onBatch,
                          ),
                          AppleToolbarItem(
                            icon: Icons.search_rounded,
                            label: AppStrings.editorSearch,
                            shortcut: 'Ctrl/Cmd+F',
                            onTap: onSearch,
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
                            label: 'Video',
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
                            label: 'Archivo',
                            onTap: onFile,
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
                  );
                },
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        palette.cellText
                            .withValues(alpha: palette.isLight ? 0.06 : 0.10),
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

class _MobileCompactHeader extends StatelessWidget {
  const _MobileCompactHeader({
    required this.palette,
    required this.title,
    required this.controller,
    required this.pendingRequired,
    required this.onSave,
    required this.onExport,
    required this.onMenu,
  });

  final _SheetPalette palette;
  final String title;
  final EditorController controller;
  final int pendingRequired;
  final VoidCallback onSave;
  final VoidCallback onExport;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final label = title.trim().isEmpty ? 'Planilla' : title.trim();

    return ValueListenableBuilder<EditorSaveSnapshot>(
      valueListenable: controller.saveStatus,
      builder: (context, snap, _) {
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

        final pendingLabel =
            pendingRequired > 0 ? ' · Pendientes: $pendingRequired' : '';
        final modeLabel = palette.isLight ? 'Claro' : 'Oscuro';

        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: AppTopBar(
            title: label,
            subtitle: '$saveLabel$pendingLabel · $modeLabel',
            actions: [
              AppButton(
                label: AppStrings.editorSave,
                icon: Icons.check_circle_outline_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                onPressed: onSave,
              ),
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

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          scale: _hovered ? 1.05 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: widget.palette.cellText.withValues(
                            alpha: widget.palette.isLight ? 0.10 : 0.36),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const [],
            ),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(999),
              child: Semantics(
                button: true,
                label: widget.semanticsLabel,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.palette.pillBtnBg,
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

class _PillButton extends StatefulWidget {
  const _PillButton({
    required this.palette,
    required this.filled,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.semanticsLabel,
  });

  final _SheetPalette palette;
  final bool filled;
  final IconData icon;
  final String label;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;

    final bg =
        widget.filled ? widget.palette.cellText : widget.palette.pillBtnBg;

    final fg = widget.filled ? widget.palette.gridBg : widget.palette.fg;

    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: MouseRegion(
        onEnter: disabled ? null : (_) => _setHovered(true),
        onExit: disabled ? null : (_) => _setHovered(false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          scale: _hovered ? 1.03 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: widget.palette.cellText.withValues(
                            alpha: widget.palette.isLight ? 0.10 : 0.32),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: InkWell(
              onTap: disabled ? null : widget.onTap,
              borderRadius: BorderRadius.circular(999),
              child: Semantics(
                button: true,
                label: widget.semanticsLabel,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: widget.palette.pillBtnBorder,
                        width: widget.palette.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, size: 18, color: fg),
                      const SizedBox(width: 8),
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                    ],
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

// ============================== UI: Grid ==================================

typedef _SelectCell = void Function(int r, int c);
typedef _EditCell = void Function(int r, int c, double cellWidth);
typedef _EditHeader = void Function(int c, double headerWidth);
typedef _ContextMenu = void Function(Offset pos, int r, int c, bool isHeader);
