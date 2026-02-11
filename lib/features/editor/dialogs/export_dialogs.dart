part of '../editor_screen.dart';

extension _EditorExportDialogs on _EditorScreenState {
  String _exportPresetLabel(String preset) {
    switch (preset) {
      case 'xlsx':
        return 'Planilla XLSX';
      case 'zip':
        return 'Paquete ZIP';
      case 'pdf':
      default:
        return 'Reporte PDF';
    }
  }

  Future<void> _openExportMenu() async {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    var preset =
        _isValidExportPreset(_lastExportPreset) ? _lastExportPreset : 'pdf';
    var format = preset == 'xlsx' ? 'xlsx' : 'pdf';
    var includeAttachments = true;

    await showAppModal<void>(
      context: context,
      title: 'Exportar planilla',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final fileName = _buildCommercialExportFileName(format);
          final isZipPreset = preset == 'zip';
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preset',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ultimo usado: ${_exportPresetLabel(_lastExportPreset)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Reporte PDF'),
                    selected: preset == 'pdf',
                    onSelected: (_) => setModalState(() {
                      preset = 'pdf';
                      format = 'pdf';
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Planilla XLSX'),
                    selected: preset == 'xlsx',
                    onSelected: (_) => setModalState(() {
                      preset = 'xlsx';
                      format = 'xlsx';
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Paquete ZIP'),
                    selected: preset == 'zip',
                    onSelected: (_) => setModalState(() {
                      preset = 'zip';
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!isZipPreset) ...[
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
                      label: const Text('XLSX'),
                      selected: format == 'xlsx',
                      onSelected: (_) => setModalState(() {
                        format = 'xlsx';
                        preset = 'xlsx';
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('PDF'),
                      selected: format == 'pdf',
                      onSelected: (_) => setModalState(() {
                        format = 'pdf';
                        preset = 'pdf';
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
              ] else ...[
                const Text(
                  'Incluye estado completo + adjuntos para backup/restore.',
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 6),
              Text(
                isZipPreset
                    ? 'Archivo: ${_buildCommercialExportFileName('bitflow.zip')}'
                    : 'Archivo: $fileName',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Descargar',
                icon: Icons.download_rounded,
                variant: AppButtonVariant.primary,
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(_setExportPresetPref(preset));
                  if (isZipPreset) {
                    unawaited(_setExportPresetPref('zip'));
                    unawaited(_exportZipBundle(share: false));
                    return;
                  }
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
                  unawaited(_setExportPresetPref(preset));
                  if (isZipPreset) {
                    unawaited(_setExportPresetPref('zip'));
                    unawaited(_exportZipBundle(share: true));
                    return;
                  }
                  _triggerSheetExport(
                    format: format,
                    includeAttachments: includeAttachments,
                    share: true,
                  );
                },
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppButton(
                    label: AppStrings.editorExportZip,
                    icon: Icons.folder_zip_rounded,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.sm,
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(_setExportPresetPref('zip'));
                      unawaited(_exportZipBundle(share: false));
                    },
                  ),
                  AppButton(
                    label: AppStrings.editorShareZip,
                    icon: Icons.ios_share_rounded,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.sm,
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(_setExportPresetPref('zip'));
                      unawaited(_exportZipBundle(share: true));
                    },
                  ),
                  AppButton(
                    label: AppStrings.editorBackupZip,
                    icon: Icons.backup_rounded,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.sm,
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(_exportBackupZip());
                    },
                  ),
                  AppButton(
                    label: 'Importar paquete',
                    icon: Icons.file_open_rounded,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.sm,
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(_openImportPackageDialog());
                    },
                  ),
                  AppButton(
                    label: AppStrings.editorReportHtml,
                    icon: Icons.description_rounded,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.sm,
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(_exportHtmlReport());
                    },
                  ),
                ],
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
    unawaited(_setExportPresetPref(format == 'pdf' ? 'pdf' : 'xlsx'));
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
