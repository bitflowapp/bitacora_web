part of '../editor_screen.dart';

extension _EditorActions on _EditorScreenState {
  Future<void> _openCommandPalette() async {
    if (!mounted) return;
    final activeCell = (_selRow >= 0 && _selCol >= 0)
        ? 'Fila ${_selRow + 1}, Col ${_selCol + 1}'
        : 'Sin seleccion';
    await showCommandPalette(
      context,
      title: 'Comandos',
      actions: [
        CommandAction(
          id: 'save',
          label: 'Guardar',
          subtitle: 'Persistir cambios locales y sincronizacion',
          shortcut: 'Ctrl/Cmd+S',
          icon: Icons.check_circle_outline_rounded,
          onSelected: () => unawaited(_saveLocalNow()),
        ),
        CommandAction(
          id: 'search',
          label: 'Buscar',
          subtitle: 'Busqueda inline con resaltado',
          shortcut: 'Ctrl/Cmd+F',
          icon: Icons.search_rounded,
          onSelected: () => unawaited(_openSearchDialog()),
        ),
        CommandAction(
          id: 'search_everywhere',
          label: 'Busqueda global',
          subtitle: 'Buscar en esta planilla o en todas',
          shortcut: 'Ctrl/Cmd+Shift+F',
          icon: Icons.travel_explore_rounded,
          onSelected: () => unawaited(_openSearchEverywhereDialog()),
        ),
        CommandAction(
          id: 'jump_to',
          label: 'Jump to...',
          subtitle: 'Ir rapido por fila o ID',
          shortcut: 'Ctrl/Cmd+J',
          icon: Icons.pin_drop_outlined,
          onSelected: () => unawaited(_openJumpToDialog()),
        ),
        CommandAction(
          id: 'columns_panel',
          label: 'Panel de columnas',
          subtitle: 'Tipo, visibilidad, orden y fijada',
          icon: Icons.view_column_rounded,
          onSelected: () => unawaited(_openColumnPanel()),
        ),
        CommandAction(
          id: 'center_column',
          label: 'Centrar columna activa',
          subtitle: activeCell,
          icon: Icons.format_align_center_rounded,
          onSelected: () => _setColumnPresentationForIndex(
            _selCol,
            textAlign: _GridTextAlignX.center,
            verticalAlign: _GridTextAlignY.middle,
          ),
        ),
        CommandAction(
          id: 'history_log',
          label: 'Historial',
          subtitle: 'Auditoria de cambios por planilla',
          icon: Icons.history_rounded,
          onSelected: () => unawaited(_openHistoryPanel()),
        ),
        CommandAction(
          id: 'quick_capture',
          label: 'Modo campo (+Registro)',
          subtitle: 'Alta rapida para relevamiento',
          icon: Icons.add_box_outlined,
          onSelected: () => unawaited(_startQuickCaptureFlow()),
        ),
        CommandAction(
          id: 'flowbot',
          label: 'FlowBot',
          subtitle: 'Comandos por voz o texto para editar celdas',
          icon: Icons.auto_awesome_rounded,
          onSelected: () => unawaited(_openFlowBotSheet()),
        ),
        CommandAction(
          id: 'form_mode',
          label: 'Formulario de fila',
          subtitle: 'Editar fila activa con inputs por tipo',
          shortcut: 'Ctrl/Cmd+Shift+M',
          icon: Icons.description_outlined,
          onSelected: () => unawaited(
            _openRowFormMode(
              rowIndex: _selRow,
              createNew: false,
            ),
          ),
        ),
        CommandAction(
          id: 'create_row',
          label: 'Crear fila',
          subtitle: 'Inserta una nueva fila al final',
          shortcut: 'Ctrl/Cmd+N',
          icon: Icons.add_rounded,
          onSelected: () => _insertRow(_rows.length),
        ),
        CommandAction(
          id: 'duplicate_row',
          label: 'Duplicar fila activa',
          subtitle: activeCell,
          icon: Icons.copy_all_outlined,
          onSelected: () => _duplicateRow(_selRow),
        ),
        CommandAction(
          id: 'duplicate_last_row',
          label: 'Duplicar ultima fila',
          subtitle: 'Replica la fila final en un toque',
          icon: Icons.copy_all_rounded,
          onSelected: _duplicateLastRowQuick,
        ),
        CommandAction(
          id: 'mark_reviewed',
          label: 'Marcar revisado',
          subtitle: 'Workflow de revision para seleccion',
          icon: Icons.verified_rounded,
          onSelected: () => unawaited(_markSelectedRowsReviewed()),
        ),
        CommandAction(
          id: 'goto_errors',
          label: 'Ir a errores',
          subtitle: 'Salta a la primera celda invalida',
          icon: Icons.rule_rounded,
          onSelected: _jumpToFirstValidationIssue,
        ),
        CommandAction(
          id: 'view_urgent',
          label: 'Vista Urgentes',
          subtitle: 'Aplica vista guardada o crea atajo urgente',
          icon: Icons.priority_high_rounded,
          onSelected: () => unawaited(_activateUrgentViewShortcut()),
        ),
        CommandAction(
          id: 'pending_review',
          label: 'Pendientes de revision',
          subtitle: 'Filtrar filas no revisadas',
          icon: Icons.pending_actions_rounded,
          onSelected: _togglePendingReviewView,
        ),
        CommandAction(
          id: 'auto_id',
          label: 'Auto-ID',
          subtitle: 'Completa IDs faltantes en seleccion',
          icon: Icons.tag_rounded,
          onSelected: _applyAutoIdQuick,
        ),
        CommandAction(
          id: 'last_value',
          label: 'Usar ultimo valor',
          subtitle: 'Aplica sugerencia reciente de la columna',
          icon: Icons.history_rounded,
          onSelected: _useLastValueForSelectedCell,
        ),
        CommandAction(
          id: 'batch_actions',
          label: 'Acciones por lote',
          subtitle: 'Aplicar a seleccion actual',
          icon: Icons.layers_outlined,
          onSelected: () => unawaited(_openBatchActionsSheet()),
        ),
        CommandAction(
          id: 'apply_value_to_selection',
          label: 'Aplicar valor a seleccion',
          subtitle: 'Carga rapida por columna activa',
          icon: Icons.format_color_text_rounded,
          onSelected: () => unawaited(_promptBatchApplyValue()),
        ),
        CommandAction(
          id: 'fill_down',
          label: 'Rellenar hacia abajo',
          subtitle: 'Repetir valor de la celda activa',
          shortcut: 'Ctrl/Cmd+D',
          icon: Icons.vertical_align_bottom_rounded,
          onSelected: () =>
              unawaited(_promptFillDown(context, _selRow, _selCol)),
        ),
        CommandAction(
          id: 'open_attachments',
          label: 'Abrir adjuntos de celda activa',
          subtitle: activeCell,
          icon: Icons.attach_file_rounded,
          onSelected: () =>
              unawaited(_openAttachmentPanelForCell(_selRow, _selCol)),
        ),
        CommandAction(
          id: 'attach_photo',
          label: 'Adjuntar foto',
          subtitle: activeCell,
          shortcut: 'P',
          icon: Icons.photo_camera_outlined,
          onSelected: () => unawaited(
            _startPhotoFlowForCell(_selRow, _selCol),
          ),
        ),
        CommandAction(
          id: 'attach_gps',
          label: 'Adjuntar GPS',
          subtitle: activeCell,
          shortcut: 'G',
          icon: Icons.my_location_rounded,
          onSelected: () => unawaited(
              _requestGpsForCell(_selRow, _selCol, forceWriteText: true)),
        ),
        CommandAction(
          id: 'audio',
          label: 'Audio en celda',
          subtitle: activeCell,
          shortcut: 'A',
          icon: Icons.mic_none_rounded,
          onSelected: () {
            if (_audioRecording) {
              unawaited(_stopAudioRecording());
            } else {
              unawaited(_startAudioRecordingForCell(_selRow, _selCol));
            }
          },
        ),
        CommandAction(
          id: 'open_queue',
          label: 'Abrir cola offline',
          subtitle: 'Ver pendientes y reintentar sync',
          shortcut: 'Ctrl/Cmd+Shift+L',
          icon: Icons.sync_alt_rounded,
          onSelected: () => unawaited(_openOfflineQueueDialog()),
        ),
        CommandAction(
          id: 'gps_mode',
          label: 'Modo GPS',
          icon: Icons.tune_rounded,
          onSelected: () => unawaited(_showGpsModePicker()),
        ),
        CommandAction(
          id: 'density',
          label: 'Densidad de grilla',
          icon: Icons.format_line_spacing_rounded,
          onSelected: () => unawaited(_showDensityPicker()),
        ),
        CommandAction(
          id: 'toggle_zen',
          label: _zenModeEnabled ? 'Salir modo Zen' : 'Activar modo Zen',
          subtitle: 'Oculta o restaura la barra superior',
          shortcut: 'Ctrl/Cmd+Shift+Z',
          icon: _zenModeEnabled
              ? Icons.visibility_rounded
              : Icons.visibility_off_rounded,
          onSelected: () => unawaited(_toggleZenMode()),
        ),
        CommandAction(
          id: 'editor_defaults',
          label: 'Preferencias de editor',
          icon: Icons.tune_rounded,
          onSelected: () => unawaited(_openEditorDefaultsDialog()),
        ),
        CommandAction(
          id: 'export_pdf',
          label: 'Reporte PDF premium',
          subtitle: 'Resumen comercial + evidencias',
          shortcut: 'Ctrl/Cmd+Shift+P',
          icon: Icons.picture_as_pdf_outlined,
          onSelected: () => unawaited(
            _exportPdf(
              includeAttachments: true,
              share: false,
            ),
          ),
        ),
        CommandAction(
          id: 'export_xlsx',
          label: 'Exportar XLSX',
          shortcut: 'Ctrl/Cmd+E',
          icon: Icons.download_rounded,
          onSelected: () => unawaited(_exportXlsxOnly()),
        ),
        CommandAction(
          id: 'export_zip',
          label: 'Exportar paquete',
          shortcut: 'Ctrl/Cmd+Shift+E',
          icon: Icons.archive_outlined,
          onSelected: () => unawaited(_exportZipBundle(share: false)),
        ),
        CommandAction(
          id: 'import_package',
          label: 'Importar paquete',
          shortcut: 'Ctrl/Cmd+Shift+I',
          icon: Icons.file_open_rounded,
          onSelected: () => unawaited(_openImportPackageDialog()),
        ),
        CommandAction(
          id: 'collaborate',
          label: 'Colaborar',
          subtitle: 'Exportar/importar paquete y merge asincronico',
          icon: Icons.group_work_outlined,
          onSelected: () => unawaited(_openCollaborateFlowDialog()),
        ),
        CommandAction(
          id: 'export_menu',
          label: 'Menu de exportacion',
          subtitle: 'Exportar, compartir o imprimir',
          icon: Icons.ios_share_rounded,
          onSelected: () => unawaited(_openExportMenu()),
        ),
        CommandAction(
          id: 'share_zip',
          label: 'Compartir paquete',
          icon: Icons.ios_share_rounded,
          onSelected: () => unawaited(_exportZipBundle(share: true)),
        ),
        CommandAction(
          id: 'export_backup',
          label: 'Backup ZIP',
          icon: Icons.backup_rounded,
          onSelected: () => unawaited(_exportBackupZip()),
        ),
        CommandAction(
          id: 'export_report',
          label: 'Reporte HTML',
          icon: Icons.description_rounded,
          onSelected: () => unawaited(_exportHtmlReport()),
        ),
        if (!_engineBusy)
          CommandAction(
            id: 'compute',
            label: 'Calcular',
            icon: Icons.functions_rounded,
            onSelected: () => unawaited(_computeEngine()),
          ),
        CommandAction(
          id: 'shortcuts',
          label: 'Ver atajos',
          shortcut: 'Ctrl/Cmd+K',
          icon: Icons.keyboard,
          onSelected: () => unawaited(_openShortcutsHelp()),
        ),
        CommandAction(
          id: 'tour',
          label: 'Ver tour rapido',
          icon: Icons.explore_outlined,
          onSelected: _reopenEditorTour,
        ),
      ],
    );
  }

  Future<void> _openCollaborateFlowDialog() async {
    if (!mounted) return;
    await showAppModal<void>(
      context: context,
      title: 'Colaborar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Intercambia paquetes de planilla sin backend y mergea cambios al importar.',
            style: TextStyle(color: _palette(context).fg),
          ),
          const SizedBox(height: 10),
          Text(
            'Formato actual: snapshot completo con metadata colaborativa.',
            style: TextStyle(color: _palette(context).fgMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: 'Exportar paquete',
            icon: Icons.archive_outlined,
            variant: AppButtonVariant.primary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_exportZipBundle(share: false));
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Compartir paquete',
            icon: Icons.ios_share_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_exportZipBundle(share: true));
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Importar y mergear',
            icon: Icons.file_open_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_openImportPackageDialog());
            },
          ),
        ],
      ),
      actions: [
        AppButton(
          label: AppStrings.close,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
  }
}
