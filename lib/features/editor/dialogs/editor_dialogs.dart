part of '../editor_screen.dart';

extension _EditorDialogs on _EditorScreenState {
  Future<void> _openShortcutsHelp() async {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await showAppModal<void>(
      context: context,
      title: AppStrings.editorShortcuts,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Ctrl/Cmd+S - Guardar'),
          Text('Ctrl/Cmd+F - Buscar'),
          Text('Ctrl/Cmd+J - Jump to fila/ID'),
          Text('Ctrl/Cmd+K - Paleta de comandos'),
          Text('Ctrl/Cmd+Z - Deshacer'),
          Text('Ctrl/Cmd+Y - Rehacer'),
          Text('Ctrl/Cmd+E - Exportar XLSX'),
          Text('Ctrl/Cmd+Shift+E - Exportar paquete'),
          Text('Ctrl/Cmd+Shift+I - Importar paquete'),
          Text('Ctrl/Cmd+Shift+B - Aplicar valor a seleccion'),
          Text('Ctrl/Cmd+Shift+L - Abrir cola offline'),
          Text('Ctrl/Cmd+N - Crear fila'),
          Text('Ctrl/Cmd+G - GPS en celda'),
          Text('Ctrl/Cmd+Shift+A - Audio en celda'),
          Text('Ctrl/Cmd+P - Foto en celda'),
          Text('Enter - Editar/confirmar'),
          Text('Esc - Cancelar'),
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

  Future<void> _showDensityPicker() async {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showAppModal<_GridDensity>(
      context: context,
      title: AppStrings.editorDensity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in _GridDensity.values)
            RadioListTile<_GridDensity>(
              value: d,
              groupValue: _gridDensity,
              onChanged: (v) => Navigator.of(context).pop(v),
              activeColor: _palette(context).accent,
              title: Text(
                _densityLabel(d),
                style: TextStyle(
                  color: _palette(context).fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
    if (picked != null) {
      await _setGridDensity(picked);
    }
  }

  Future<void> _showGpsModePicker() async {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showAppModal<_GpsWriteMode>(
      context: context,
      title: AppStrings.editorGpsMode,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in _GpsWriteMode.values)
            RadioListTile<_GpsWriteMode>(
              dense: true,
              value: mode,
              groupValue: _gpsWriteMode,
              onChanged: (v) => Navigator.of(context).pop(v),
              title: Text(
                _gpsModeLabel(mode),
                style: TextStyle(
                  color: _palette(context).fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                _gpsModeDesc(mode),
                style:
                    TextStyle(color: _palette(context).fgMuted, fontSize: 12),
              ),
              activeColor: _palette(context).accent,
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
    if (!mounted) return;
    if (picked != null) {
      await _setGpsMode(picked);
    }
  }
}
