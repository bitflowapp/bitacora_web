part of '../editor_screen.dart';

extension _EditorExportDialogs on _EditorScreenState {
  Future<void> _openExportMenu() async {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _recomputeValidation();
    final quality = _sheetQuality;
    final evidenceCount = _sheetEvidenceCount();
    var format = _fieldModeEnabled
        ? 'zip'
        : (_isValidExportPreset(_lastExportPreset) ? _lastExportPreset : 'pdf');
    var includeAttachments = true;

    await showAppModal<void>(
      context: context,
      title: 'Exportar o compartir',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final exportBusy = _longOperation != null || _saving;
          final pendingSyncCount = _pendingOfflineCount + _outboxQueuedCount;
          final fileName = format == 'zip'
              ? buildBitFlowBundleExportFileName(sheetName: _sheetName)
              : _buildCommercialExportFileName(format);
          final exportBaseLabel = switch (format) {
            'zip' => 'Exportar paquete ZIP',
            'xlsx' => 'Exportar Excel (.xlsx)',
            _ => 'Exportar reporte PDF',
          };
          final shareBaseLabel = switch (format) {
            'zip' => 'Compartir paquete ZIP',
            'xlsx' => 'Compartir Excel (.xlsx)',
            _ => 'Compartir reporte PDF',
          };
          final exportLabel =
              quality.hasIssues ? '$exportBaseLabel igual' : exportBaseLabel;
          final shareLabel =
              quality.hasIssues ? '$shareBaseLabel igual' : shareBaseLabel;
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
                      title: const Text('Incluir evidencias y adjuntos'),
                      subtitle: Text(
                        switch (format) {
                          'zip' =>
                            'Incluye Excel, PDF y todas las evidencias en un solo paquete.',
                          'pdf' =>
                            'Incluye tabla principal y fotos cuando existan.',
                          _ =>
                            'Incluye planilla editable y una hoja de evidencias.',
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
                      'Vas a generar: $fileName',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      switch (format) {
                        'zip' =>
                          'Paquete ZIP (.zip): cierre recomendado para campo. Lleva planilla, reporte y evidencias en un solo archivo.',
                        'pdf' =>
                          'Reporte PDF (.pdf): listo para presentar o mandar por mail o mensajeria.',
                        _ =>
                          'Excel (.xlsx): ideal para seguir trabajando o consolidar datos.',
                      },
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (pendingSyncCount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Hay $pendingSyncCount cambio(s) en cola. Esta salida se genera con el estado actual de la planilla.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      key: const ValueKey('editor-export-quality-card'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: quality.hasIssues
                            ? Theme.of(context)
                                .colorScheme
                                .errorContainer
                                .withValues(alpha: 0.7)
                            : Theme.of(context)
                                .colorScheme
                                .secondaryContainer
                                .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: quality.hasIssues
                              ? Theme.of(context)
                                  .colorScheme
                                  .error
                                  .withValues(alpha: 0.25)
                              : Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estado de la planilla',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _sheetQualityHeadline(quality),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ExportQualityChip(
                                label:
                                    'Completitud ${quality.requiredCompletionPercent}%',
                              ),
                              _ExportQualityChip(
                                label:
                                    'Filas listas ${quality.rowsReady}/${math.max(quality.rowsWithData, quality.rowsTotal)}',
                              ),
                              _ExportQualityChip(
                                label: 'Errores ${quality.invalidCells}',
                              ),
                              _ExportQualityChip(
                                label: 'Evidencias $evidenceCount',
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _sheetQualityDetail(
                              quality,
                              evidenceCount: evidenceCount,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (quality.hasIssues) ...[
                            const SizedBox(height: 8),
                            AppButton(
                              label: 'Ver primer error',
                              icon: Icons.rule_rounded,
                              size: AppButtonSize.sm,
                              variant: AppButtonVariant.ghost,
                              onPressed: () {
                                Navigator.of(context).pop();
                                _setEditorState(() => _errorsPanelOpen = true);
                                _jumpToFirstValidationIssue();
                              },
                            ),
                          ],
                        ],
                      ),
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
                            ? 'Estamos guardando cambios. Espera a que termine para cerrar la salida.'
                            : 'Estamos terminando otra salida. Espera un momento para exportar o compartir.',
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

class _ExportQualityChip extends StatelessWidget {
  const _ExportQualityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
