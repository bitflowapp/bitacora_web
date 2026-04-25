part of '../editor_screen.dart';

extension _EditorDialogs on _EditorScreenState {
  Future<void> _openEditorDefaultsDialog() async {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    var dateDefault = _defaultDateTodayEnabled;
    var statusDefault = _defaultStatusOkEnabled;
    var autoIncrement = _autoIncrementIdEnabled;
    var inlinePreviews = _cellInlinePreviewsEnabled;
    var mobileCompactMode = _mobileCompactModeEnabled;
    var zenMode = _zenModeEnabled;
    var mobileFocusCellMode = _mobileFocusCellModeEnabled;
    var flowBotUseLocalLlm = _flowBotUseLocalLlm;

    final result = await showAppModal<_EditorDefaultsConfig>(
      context: context,
      title: 'Preferencias de editor',
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: dateDefault,
                onChanged: (value) => setModalState(() => dateDefault = value),
                activeColor: _palette(ctx).accent,
                title: const Text('Fecha: completar con hoy al crear fila'),
                subtitle: const Text('Aplica en columnas Fecha/Hora'),
              ),
              SwitchListTile(
                value: statusDefault,
                onChanged: (value) =>
                    setModalState(() => statusDefault = value),
                activeColor: _palette(ctx).accent,
                title: const Text('Estado: default OK'),
                subtitle: const Text('Aplica en columnas Estado'),
              ),
              SwitchListTile(
                value: autoIncrement,
                onChanged: (value) =>
                    setModalState(() => autoIncrement = value),
                activeColor: _palette(ctx).accent,
                title: const Text('ID/Progresiva: autoincrement'),
                subtitle: const Text(
                  'Toma el ultimo valor numerico y suma +1',
                ),
              ),
              SwitchListTile(
                value: inlinePreviews,
                onChanged: (value) =>
                    setModalState(() => inlinePreviews = value),
                activeColor: _palette(ctx).accent,
                title: const Text('Previews en celdas'),
                subtitle: const Text(
                  'Muestra miniaturas inline (puede usar mas memoria en grillas grandes).',
                ),
              ),
              SwitchListTile(
                value: mobileCompactMode,
                onChanged: (value) =>
                    setModalState(() => mobileCompactMode = value),
                activeColor: _palette(ctx).accent,
                title: const Text('Modo compacto (mobile auto-hide)'),
                subtitle: const Text(
                  'Oculta header al hacer scroll para maximizar la grilla.',
                ),
              ),
              SwitchListTile(
                value: zenMode,
                onChanged: (value) => setModalState(() => zenMode = value),
                activeColor: _palette(ctx).accent,
                title: const Text('Modo Zen'),
                subtitle: const Text(
                  'Oculta la barra superior hasta salir de Zen.',
                ),
              ),
              SwitchListTile(
                value: mobileFocusCellMode,
                onChanged: (value) =>
                    setModalState(() => mobileFocusCellMode = value),
                activeColor: _palette(ctx).accent,
                title: const Text('Focus cell mode (mobile)'),
                subtitle: const Text(
                  'Al editar, centra la celda activa sin reflow pesado.',
                ),
              ),
              SwitchListTile(
                value: flowBotUseLocalLlm,
                onChanged: (value) =>
                    setModalState(() => flowBotUseLocalLlm = value),
                activeColor: _palette(ctx).accent,
                title: const Text('FlowBot Local LLM (sin API)'),
                subtitle: Text(
                  _flowBotLocalModelPath.trim().isEmpty
                      ? 'No hay modelo instalado. Usa motor offline deterministico.'
                      : 'Modelo local: ${_flowBotLocalModelPath.split(RegExp(r'[\\\\/]')).last}',
                ),
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
        AppButton(
          label: AppStrings.save,
          variant: AppButtonVariant.primary,
          onPressed: () {
            Navigator.of(context).pop(
              _EditorDefaultsConfig(
                dateDefault: dateDefault,
                statusDefault: statusDefault,
                autoIncrement: autoIncrement,
                inlinePreviews: inlinePreviews,
                mobileCompactMode: mobileCompactMode,
                zenMode: zenMode,
                mobileFocusCellMode: mobileFocusCellMode,
                flowBotUseLocalLlm: flowBotUseLocalLlm,
              ),
            );
          },
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
    if (result == null) return;
    await _setEditorDefaultRules(
      defaultDateTodayEnabled: result.dateDefault,
      defaultStatusOkEnabled: result.statusDefault,
      autoIncrementIdEnabled: result.autoIncrement,
      cellInlinePreviewsEnabled: result.inlinePreviews,
      mobileCompactModeEnabled: result.mobileCompactMode,
      zenModeEnabled: result.zenMode,
      mobileFocusCellModeEnabled: result.mobileFocusCellMode,
      flowBotUseLocalLlm: result.flowBotUseLocalLlm,
    );
    if (!mounted) return;
    _showActionSnack(
      'Preferencias de editor actualizadas.',
      isError: false,
      icon: Icons.tune_rounded,
    );
  }

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
          _ShortcutLine(shortcut: 'Ctrl/Cmd+J', label: 'Ir a fila/ID'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+Z', label: 'Deshacer'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+Y', label: 'Rehacer'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+Shift+Z', label: 'Toggle modo Zen'),
          SizedBox(height: 10),
          Text(
            'Productividad',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+N', label: 'Crear fila'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+Shift+B', label: 'Aplicar valor'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+Shift+R', label: 'FlowBot'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+E', label: 'Centrar celda activa'),
          _ShortcutLine(
              shortcut: 'Ctrl/Cmd+Shift+L', label: 'Wrap 1/2/3 lineas'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+Alt+C', label: 'Centrar columna'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+Shift+E', label: 'Exportar XLSX'),
          _ShortcutLine(shortcut: 'Ctrl/Cmd+Alt+E', label: 'Exportar paquete'),
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

class _EditorDefaultsConfig {
  const _EditorDefaultsConfig({
    required this.dateDefault,
    required this.statusDefault,
    required this.autoIncrement,
    required this.inlinePreviews,
    required this.mobileCompactMode,
    required this.zenMode,
    required this.mobileFocusCellMode,
    required this.flowBotUseLocalLlm,
  });

  final bool dateDefault;
  final bool statusDefault;
  final bool autoIncrement;
  final bool inlinePreviews;
  final bool mobileCompactMode;
  final bool zenMode;
  final bool mobileFocusCellMode;
  final bool flowBotUseLocalLlm;
}
