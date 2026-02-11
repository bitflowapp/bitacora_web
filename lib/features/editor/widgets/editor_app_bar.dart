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

  String _formatLocalSaved(DateTime? value) {
    if (value == null) return 'Ultimo guardado local: --:--';
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return 'Ultimo guardado local: $hh:$mm';
  }

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
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InlineMetaChip(
                              palette: palette,
                              icon: Icons.table_view_rounded,
                              label: 'Vista base',
                              onTap: () => onSelectView(null),
                            ),
                            for (final view in savedViews.take(5))
                              _InlineMetaChip(
                                palette: palette,
                                icon: view.id == activeViewId
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_outlined,
                                label: view.name,
                                onTap: () => onSelectView(view.id),
                              ),
                            _InlineMetaChip(
                              palette: palette,
                              icon: Icons.bookmark_add_outlined,
                              label: 'Guardar vista',
                              onTap: onSaveView,
                            ),
                            if (savedViews.isNotEmpty)
                              _InlineMetaChip(
                                palette: palette,
                                icon: Icons.more_horiz_rounded,
                                label: 'Gestionar vistas',
                                onTap: onManageViews,
                              ),
                            _InlineMetaChip(
                              palette: palette,
                              icon: pendingReviewViewActive
                                  ? Icons.pending_actions_rounded
                                  : Icons.fact_check_outlined,
                              label: pendingReviewViewActive
                                  ? 'Pendientes'
                                  : 'Ver pendientes',
                              onTap: onTogglePendingReviewView,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatLocalSaved(lastLocalSavedAt),
                          style: TextStyle(
                            color: palette.fgMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: pillGap,
                          runSpacing: 10,
                          children: [
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(1.0),
                              child: _PillButton(
                                palette: palette,
                                filled: false,
                                icon: Icons.check_circle_outline_rounded,
                                label: AppStrings.editorSave,
                                semanticsLabel: AppStrings.semEditorSave,
                                tooltip: 'Guardar cambios locales',
                                onTap: onSave,
                              ),
                            ),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(1.1),
                              child: _PillButton(
                                palette: palette,
                                filled: true,
                                icon: Icons.add_box_outlined,
                                label: '+ Registro',
                                semanticsLabel:
                                    'Crear registro rapido de campo',
                                tooltip: 'Crear un registro en modo campo',
                                onTap: onQuickCapture,
                              ),
                            ),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(1.2),
                              child: _PillButton(
                                palette: palette,
                                filled: false,
                                icon: Icons.description_outlined,
                                label: 'Formulario',
                                semanticsLabel: 'Abrir modo formulario',
                                tooltip: 'Editar fila en modo formulario',
                                onTap: onForm,
                              ),
                            ),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(1.25),
                              child: _PillButton(
                                palette: palette,
                                filled: false,
                                icon: Icons.search_rounded,
                                label: AppStrings.editorSearch,
                                semanticsLabel: AppStrings.semEditorSearch,
                                tooltip: 'Buscar en todas las celdas',
                                onTap: onSearch,
                              ),
                            ),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(1.3),
                              child: _PillButton(
                                palette: palette,
                                filled: false,
                                icon: Icons.pin_drop_outlined,
                                label: 'Jump to...',
                                semanticsLabel: 'Ir rapido por fila o ID',
                                tooltip: 'Ir a fila o ID rapidamente',
                                onTap: onJumpTo,
                              ),
                            ),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(1.4),
                              child: _PillButton(
                                palette: palette,
                                filled: false,
                                icon: Icons.view_column_rounded,
                                label: 'Columnas',
                                semanticsLabel:
                                    'Abrir panel de configuracion de columnas',
                                tooltip: 'Tipos, orden, visibilidad y fijar',
                                onTap: onColumns,
                              ),
                            ),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(1.45),
                              child: _PillButton(
                                palette: palette,
                                filled: false,
                                icon: Icons.attach_file_rounded,
                                label: 'Adjuntos',
                                semanticsLabel:
                                    'Abrir adjuntos de celda activa',
                                tooltip: 'Abrir panel de adjuntos',
                                onTap: onAttachments,
                              ),
                            ),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(1.47),
                              child: _PillButton(
                                palette: palette,
                                filled: false,
                                icon: Icons.history_rounded,
                                label: 'Historial',
                                semanticsLabel: 'Abrir historial de cambios',
                                tooltip: 'Auditoria de cambios',
                                onTap: onHistory,
                              ),
                            ),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(1.5),
                              child: _PillButton(
                                palette: palette,
                                filled: false,
                                icon: Icons.ios_share_rounded,
                                label: AppStrings.editorExport,
                                semanticsLabel: AppStrings.semEditorExport,
                                tooltip: 'Exportar o compartir planilla',
                                onTap: onExport,
                              ),
                            ),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(1.6),
                              child: _PillButton(
                                palette: palette,
                                filled: false,
                                icon: Icons.layers_outlined,
                                label: AppStrings.editorBatchActions,
                                semanticsLabel: 'Abrir acciones por lote',
                                tooltip:
                                    'Acciones rapidas para filas seleccionadas',
                                onTap: onBatch,
                              ),
                            ),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(1.65),
                              child: _PillButton(
                                palette: palette,
                                filled: false,
                                icon: Icons.verified_rounded,
                                label: 'Marcar revisado',
                                semanticsLabel:
                                    'Marcar filas seleccionadas como revisadas',
                                tooltip: 'Workflow de revision',
                                onTap: onMarkReviewed,
                              ),
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
                              icon: Icons.pin_drop_outlined,
                              label: 'Jump to...',
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
                              label: 'Adjuntos',
                              onTap: onAttachments,
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
                    ),
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

  String _formatLocalSaved(DateTime? value) {
    if (value == null) return 'Ultimo guardado local: --:--';
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return 'Ultimo guardado local: $hh:$mm';
  }

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

            final pendingLabel =
                pendingRequired > 0 ? ' | Errores: $pendingRequired' : '';
            final queueLabel =
                pendingOfflineCount > 0 ? ' | Cola: $pendingOfflineCount' : '';
            final offlineLabel = offline.message?.trim().isNotEmpty == true
                ? offline.message!.trim()
                : 'Sincronizado';
            final modeLabel = palette.isLight ? 'Claro' : 'Oscuro';
            final localLabel =
                _formatLocalSaved(lastLocalSavedAt ?? snap.savedAt)
                    .replaceFirst('Ultimo guardado local: ', 'Local: ');
            final activeCell = (selectedRow >= 0 && selectedCol >= 0)
                ? '${_columnLabel(selectedCol)}${selectedRow + 1}'
                : '--';

            return Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: AppTopBar(
                title: label,
                subtitle:
                    '$saveLabel$pendingLabel$queueLabel | Celda: $activeCell | $localLabel | Sync: $offlineLabel | $modeLabel',
                actions: [
                  AppButton(
                    label: AppStrings.editorSave,
                    icon: Icons.check_circle_outline_rounded,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.sm,
                    onPressed: onSave,
                  ),
                  AppButton(
                    label: 'Cola',
                    icon: Icons.sync_alt_rounded,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.sm,
                    onPressed: onOpenOfflineQueue,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.hintBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border, width: palette.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: palette.fgMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: palette.fgMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
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
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          scale: _pressed ? 0.97 : (_hovered ? 1.05 : 1.0),
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

class _PillButton extends StatefulWidget {
  const _PillButton({
    required this.palette,
    required this.filled,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.semanticsLabel,
    this.tooltip,
  });

  final _SheetPalette palette;
  final bool filled;
  final IconData icon;
  final String label;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
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
    final disabled = widget.onTap == null;

    final baseBg =
        widget.filled ? widget.palette.cellText : widget.palette.pillBtnBg;
    final bg = _pressed
        ? baseBg.withValues(alpha: widget.filled ? 0.85 : 0.72)
        : (_hovered
            ? baseBg.withValues(alpha: widget.filled ? 0.94 : 0.9)
            : baseBg);

    final fg = widget.filled ? widget.palette.gridBg : widget.palette.fg;

    final button = Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: MouseRegion(
        onEnter: disabled ? null : (_) => _setHovered(true),
        onExit: disabled ? null : (_) => _setHovered(false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          scale: _pressed ? 0.985 : (_hovered ? 1.03 : 1.0),
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
              onHighlightChanged: disabled ? null : _setPressed,
              borderRadius: BorderRadius.circular(999),
              child: Semantics(
                button: true,
                label: widget.semanticsLabel,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
                          fontSize: 13,
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
    final tip = widget.tooltip?.trim() ?? '';
    if (tip.isEmpty) return button;
    return Tooltip(message: tip, child: button);
  }
}

// ============================== UI: Grid ==================================

typedef _SelectCell = void Function(int r, int c);
typedef _EditCell = void Function(int r, int c, double cellWidth);
typedef _EditHeader = void Function(int c, double headerWidth);
typedef _ContextMenu = void Function(Offset pos, int r, int c, bool isHeader);
