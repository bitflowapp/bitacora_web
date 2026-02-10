part of '../editor_screen.dart';

extension _EditorActions on _EditorScreenState {
  Future<void> _openCommandPalette() async {
    if (!mounted) return;
    await showCommandPalette(
      context,
      title: 'Comandos',
      actions: [
        CommandAction(
          id: 'create_row',
          label: 'Crear fila',
          shortcut: 'Ctrl/Cmd+N',
          icon: Icons.add_rounded,
          onSelected: () => _insertRow(_rows.length),
        ),
        CommandAction(
          id: 'batch_actions',
          label: 'Acciones por lote',
          icon: Icons.layers_outlined,
          onSelected: () => unawaited(_openBatchActionsSheet()),
        ),
        CommandAction(
          id: 'search',
          label: 'Buscar',
          shortcut: 'Ctrl/Cmd+F',
          icon: Icons.search_rounded,
          onSelected: () => unawaited(_openSearchDialog()),
        ),
        CommandAction(
          id: 'export',
          label: 'Exportar',
          shortcut: 'Ctrl/Cmd+E',
          icon: Icons.download_rounded,
          onSelected: () => unawaited(_openExportMenu()),
        ),
        CommandAction(
          id: 'attach_photo',
          label: 'Adjuntar foto',
          shortcut: 'P',
          icon: Icons.photo_camera_outlined,
          onSelected: () => unawaited(
            _startPhotoFlowForCell(_selRow, _selCol),
          ),
        ),
        CommandAction(
          id: 'attach_gps',
          label: 'Adjuntar GPS',
          shortcut: 'G',
          icon: Icons.my_location_rounded,
          onSelected: () => unawaited(
              _requestGpsForCell(_selRow, _selCol, forceWriteText: true)),
        ),
        CommandAction(
          id: 'save',
          label: 'Guardar',
          shortcut: 'Ctrl/Cmd+S',
          icon: Icons.check_circle_outline_rounded,
          onSelected: () => unawaited(_saveLocalNow()),
        ),
        CommandAction(
          id: 'gps',
          label: 'GPS en celda',
          shortcut: 'G',
          icon: Icons.my_location_rounded,
          onSelected: () => unawaited(
              _requestGpsForCell(_selRow, _selCol, forceWriteText: true)),
        ),
        CommandAction(
          id: 'gps_mode',
          label: 'Modo GPS',
          icon: Icons.tune_rounded,
          onSelected: () => unawaited(_showGpsModePicker()),
        ),
        CommandAction(
          id: 'photo',
          label: 'Foto en celda',
          shortcut: 'P',
          icon: Icons.photo_camera_outlined,
          onSelected: () => unawaited(
            _startPhotoFlowForCell(_selRow, _selCol),
          ),
        ),
        CommandAction(
          id: 'audio',
          label: 'Audio en celda',
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
          id: 'export_xlsx',
          label: 'Exportar XLSX',
          shortcut: 'Ctrl/Cmd+E',
          icon: Icons.download_rounded,
          onSelected: () => unawaited(_exportXlsxOnly()),
        ),
        CommandAction(
          id: 'export_zip',
          label: 'Exportar ZIP',
          shortcut: 'Ctrl/Cmd+Shift+E',
          icon: Icons.archive_outlined,
          onSelected: () => unawaited(_exportZipBundle(share: false)),
        ),
        CommandAction(
          id: 'share_zip',
          label: 'Compartir ZIP',
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
