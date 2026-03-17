part of '../editor_screen.dart';

extension _EditorExportDialogs on _EditorScreenState {
  Future<void> _openExportMenu() async {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    var format =
        _isValidExportPreset(_lastExportPreset) ? _lastExportPreset : 'pdf';
    var includeAttachments = true;

    await showAppModal<void>(
      context: context,
      title: 'Exportar',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final exportBusy = _longOperation != null || _saving;
          final fileName = format == 'zip'
              ? buildBitFlowBundleExportFileName(sheetName: _sheetName)
              : _buildCommercialExportFileName(format);
          final exportLabel = switch (format) {
            'zip' => 'Exportar paquete ZIP',
            'xlsx' => 'Exportar Excel (.xlsx)',
            _ => 'Exportar reporte PDF',
          };
          final shareLabel = switch (format) {
            'zip' => 'Compartir paquete ZIP',
            'xlsx' => 'Compartir Excel (.xlsx)',
            _ => 'Compartir reporte PDF',
          };
          final maxBodyHeight = MediaQuery.of(context).size.height * 0.62;
          return SizedBox(
            width: double.infinity,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxBodyHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Formato',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Excel (.xlsx)'),
                          selected: format == 'xlsx',
                          onSelected: exportBusy
                              ? null
                              : (_) => setModalState(() {
                                    format = 'xlsx';
                                  }),
                        ),
                        ChoiceChip(
                          label: const Text('Reporte PDF (.pdf)'),
                          selected: format == 'pdf',
                          onSelected: exportBusy
                              ? null
                              : (_) => setModalState(() {
                                    format = 'pdf';
                                  }),
                        ),
                        ChoiceChip(
                          label: const Text('Paquete completo (.ZIP)'),
                          selected: format == 'zip',
                          onSelected: exportBusy
                              ? null
                              : (_) => setModalState(() {
                                    format = 'zip';
                                    includeAttachments = true;
                                  }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Incluir adjuntos'),
                      subtitle: Text(
                        switch (format) {
                          'zip' =>
                            'Incluye Excel, reporte PDF, manifiesto y carpetas de evidencias.',
                          'pdf' =>
                            'Incluye resumen, tabla principal y evidencias con fotos cuando existan.',
                          _ =>
                            'Incluye planilla editable y hoja de evidencias/adjuntos.',
                        },
                      ),
                      value: format == 'zip' ? true : includeAttachments,
                      onChanged: exportBusy || format == 'zip'
                          ? null
                          : (value) {
                              setModalState(() => includeAttachments = value);
                            },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Archivo: $fileName',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      switch (format) {
                        'zip' =>
                          'Paquete completo (.zip): planilla + evidencias en una estructura portable.',
                        'pdf' =>
                          'Reporte PDF (.pdf): listo para presentar o compartir con clientes y supervisión.',
                        _ =>
                          'Excel (.xlsx): ideal para seguir editando y hacer seguimiento interno.',
                      },
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_rows.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'La planilla no tiene filas. Exportaremos la estructura actual.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (exportBusy) ...[
                      const SizedBox(height: 8),
                      Text(
                        _saving
                            ? 'Hay un guardado en curso. Espera a que termine para exportar.'
                            : 'Ya hay una operaci\u00f3n en curso. Espera a que termine para exportar o compartir.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 12),
                    AppButton(
                      key: const ValueKey('editor-export-submit'),
                      label: exportLabel,
                      icon: Icons.download_rounded,
                      variant: AppButtonVariant.primary,
                      onPressed: exportBusy
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              unawaited(_setExportPresetPref(format));
                              _triggerSheetExport(
                                format: format,
                                includeAttachments: includeAttachments,
                                share: false,
                              );
                            },
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      key: const ValueKey('editor-export-share'),
                      label: shareLabel,
                      icon: Icons.ios_share_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: exportBusy
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              unawaited(_setExportPresetPref(format));
                              _triggerSheetExport(
                                format: format,
                                includeAttachments: includeAttachments,
                                share: true,
                              );
                            },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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

  void _triggerSheetExport({
    required String format,
    required bool includeAttachments,
    required bool share,
  }) {
    unawaited(_setExportPresetPref(format));
    if (format == 'zip') {
      unawaited(_exportZipBundle(share: share));
      return;
    }
    if (format == 'pdf') {
      unawaited(
        _exportPdf(
          includeAttachments: includeAttachments,
          share: share,
        ),
      );
      return;
    }
    unawaited(
      _exportXlsxOnly(
        includeAttachments: includeAttachments,
        share: share,
      ),
    );
  }
}
