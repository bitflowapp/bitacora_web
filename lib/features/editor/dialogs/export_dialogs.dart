part of '../editor_screen.dart';

extension _EditorExportDialogs on _EditorScreenState {
  Future<void> _openExportMenu() async {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    var format = 'xlsx';
    var includeAttachments = true;

    await showAppModal<void>(
      context: context,
      title: 'Exportar planilla',
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
                    label: const Text('XLSX'),
                    selected: format == 'xlsx',
                    onSelected: (_) => setModalState(() => format = 'xlsx'),
                  ),
                  ChoiceChip(
                    label: const Text('PDF'),
                    selected: format == 'pdf',
                    onSelected: (_) => setModalState(() => format = 'pdf'),
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
                'Archivo: $fileName',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Descargar',
                icon: Icons.download_rounded,
                variant: AppButtonVariant.primary,
                onPressed: () {
                  Navigator.of(context).pop();
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
