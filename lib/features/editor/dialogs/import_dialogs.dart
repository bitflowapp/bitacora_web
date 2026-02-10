part of '../editor_screen.dart';

extension _EditorImportDialogs on _EditorScreenState {
  Future<void> _openImportPackageDialog() async {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final typeGroup = const XTypeGroup(
      label: 'BitFlow package',
      extensions: ['zip'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      _reportFlowErrorMessage(
        'import_empty_file',
        flow: AppErrorFlow.importData,
        operation: 'import_package_read_bytes',
        fallbackMessage: 'Archivo vacio.',
        icon: Icons.file_open_rounded,
      );
      return;
    }

    _PackageImportBundle bundle;
    try {
      bundle = await _readPackageImportBundle(bytes);
    } catch (e, st) {
      _reportFlowError(
        e,
        flow: AppErrorFlow.importData,
        operation: 'import_package_parse_archive',
        stackTrace: st,
        fallbackMessage: 'No se pudo leer el paquete ZIP.',
        icon: Icons.file_open_rounded,
      );
      return;
    }
    if (!mounted) return;

    final mode = await showAppModal<_PackageImportMode>(
      context: context,
      title: 'Importar paquete',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Formato: ${bundle.preview.formatLabel}',
            style: TextStyle(
              color: _palette(context).fg,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Filas: ${bundle.preview.rows} | Adjuntos: ${bundle.preview.attachments}',
            style: TextStyle(color: _palette(context).fgMuted),
          ),
          const SizedBox(height: 4),
          Text(
            'Fotos: ${bundle.preview.photos} | Audios: ${bundle.preview.audios}',
            style: TextStyle(color: _palette(context).fgMuted),
          ),
          if (bundle.preview.exportedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Exportado: ${_formatDateTimeShort(bundle.preview.exportedAt!.toLocal())}',
              style: TextStyle(color: _palette(context).fgMuted),
            ),
          ],
          if ((bundle.preview.appVersion ?? '').trim().isNotEmpty ||
              (bundle.preview.buildId ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Version: ${bundle.preview.appVersion ?? '-'}'
              ' | Build: ${bundle.preview.buildId ?? '-'}',
              style: TextStyle(color: _palette(context).fgMuted),
            ),
          ],
          const SizedBox(height: 14),
          AppButton(
            label: 'Crear nueva (recomendado)',
            icon: Icons.add_box_outlined,
            variant: AppButtonVariant.primary,
            onPressed: () =>
                Navigator.of(context).pop(_PackageImportMode.createNew),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Reemplazar actual',
            icon: Icons.system_update_alt_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () =>
                Navigator.of(context).pop(_PackageImportMode.replaceCurrent),
          ),
          const SizedBox(height: 8),
          Text(
            'Restauracion atomica: adjuntos primero, luego planilla.',
            style: TextStyle(
              color: _palette(context).fgMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        AppButton(
          label: AppStrings.cancel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
    if (!mounted || mode == null) return;

    if (mode == _PackageImportMode.replaceCurrent) {
      final confirm = await showAppModal<bool>(
        context: context,
        title: 'Reemplazar planilla actual?',
        child: Text(
          'Se sobrescribira la planilla abierta y su cola offline local. '
          'Recomendado: exportar paquete antes de continuar.',
          style: TextStyle(color: _palette(context).fg),
        ),
        actions: [
          AppButton(
            label: AppStrings.cancel,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButton(
            label: 'Reemplazar',
            variant: AppButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
        showClose: false,
        barrierDismissible: true,
      );
      if (confirm != true || !mounted) return;
    }

    await _importPackageBundle(
      bundle,
      replaceCurrent: mode == _PackageImportMode.replaceCurrent,
    );
  }
}
