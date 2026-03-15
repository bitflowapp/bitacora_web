part of '../editor_screen.dart';

extension _EditorExportDialogs on _EditorScreenState {
  Future<void> _openExportMenu() async {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    var format = _lastExportPreset == 'xlsx'
        ? 'xlsx'
        : (_lastExportPreset == 'zip' ? 'zip' : 'pdf');
    var includeAttachments = true;

    await showAppModal<void>(
      context: context,
      title: 'Exportar',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final fileName = _buildCommercialExportFileName(format);
          return Column(
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
                    onSelected: (_) => setModalState(() {
                      format = 'xlsx';
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Reporte PDF (.pdf)'),
                    selected: format == 'pdf',
                    onSelected: (_) => setModalState(() {
                      format = 'pdf';
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Paquete completo (.zip)'),
                    selected: format == 'zip',
                    onSelected: (_) => setModalState(() {
                      format = 'zip';
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Incluir adjuntos'),
                subtitle: const Text('Fotos, audio y GPS en el export.'),
                value: includeAttachments,
                onChanged: (value) {
                  setModalState(() => includeAttachments = value);
                },
              ),
              const SizedBox(height: 6),
              Text(
                'Archivo estimado: $fileName',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Descargar',
                icon: Icons.download_rounded,
                variant: AppButtonVariant.primary,
                onPressed: () {
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
                label: 'Compartir',
                icon: Icons.ios_share_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: () {
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
    unawaited(
      _setExportPresetPref(
        format == 'pdf' ? 'pdf' : (format == 'zip' ? 'zip' : 'xlsx'),
      ),
    );
    if (format == 'pdf') {
      unawaited(
        _exportPdf(
          includeAttachments: includeAttachments,
          share: share,
        ),
      );
      return;
    }
    if (format == 'zip') {
      unawaited(_exportZipBundle(share: share));
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
