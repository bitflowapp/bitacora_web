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
          subtitle: 'Buscar texto en la planilla',
          shortcut: 'Ctrl/Cmd+F',
          icon: Icons.search_rounded,
          onSelected: () => unawaited(_openSearchDialog()),
        ),
        CommandAction(
          id: 'quick_capture',
          label: 'Modo campo (+Registro)',
          subtitle: 'Alta rapida para relevamiento',
          icon: Icons.add_box_outlined,
          onSelected: () => unawaited(_startQuickCaptureFlow()),
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
      ],
    );
  }
}
