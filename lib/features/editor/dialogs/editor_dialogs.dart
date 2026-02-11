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
          Text(
            'Atajos clave',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+K', label: 'Paleta de comandos'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+S', label: 'Guardar'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+F', label: 'Buscar inline'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+J', label: 'Jump to fila/ID'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+Z', label: 'Deshacer'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+Y', label: 'Rehacer'),
          SizedBox(height: 10),
          Text(
            'Productividad',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+N', label: 'Crear fila'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+Shift+B', label: 'Aplicar valor'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+Shift+L', label: 'Cola offline'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+E', label: 'Exportar XLSX'),
          _ShortcutLine(
              shortcut: 'Ctrl/Cmd+Shift+E', label: 'Exportar paquete'),
          _ShortcutLine(
              shortcut: 'Ctrl/Cmd+Shift+I', label: 'Importar paquete'),
          SizedBox(height: 10),
          Text(
            'Campo',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+G', label: 'Adjuntar GPS'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+P', label: 'Adjuntar foto'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+Shift+A', label: 'Audio en celda'),
          _ShortcutLine(shortcut: 'Enter', label: 'Editar o confirmar'),
          _ShortcutLine(shortcut: 'Esc', label: 'Cerrar/Cancelar'),
          SizedBox(height: 10),
          Text(
            'Tip: usa Ctrl/Cmd+K para ejecutar acciones sin mover la mano del teclado.',
            style: TextStyle(fontSize: 12),
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

class _ShortcutLine extends StatelessWidget {
  const _ShortcutLine({
    required this.shortcut,
    required this.label,
  });

  final String shortcut;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.of(context).colors.border),
              color: AppTheme.of(context).colors.surfaceMuted,
            ),
            child: Text(
              shortcut,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.of(context).colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
