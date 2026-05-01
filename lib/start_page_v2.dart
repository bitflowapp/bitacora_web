import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/editor/editor_screen.dart';
import 'screens/about_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/terms_screen.dart';
import 'services/build_info.dart';
import 'services/demo_templates.dart';
import 'services/sheet_store.dart';
import 'ui/ui.dart';

class StartPageV2 extends StatefulWidget {
  const StartPageV2({
    super.key,
    required this.isLight,
    required this.onToggleTheme,
  });

  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<StartPageV2> createState() => _StartPageV2State();
}

class _StartPageV2State extends State<StartPageV2> {
  static const String _kPrefOnboardingDone = 'bitflow.onboarding_done.v1';

  final FocusNode _focusNode = FocusNode(debugLabel: 'StartPageV2Focus');
  bool _onboardingDone = true;
  bool _loadedPrefs = false;
  bool _hideOnboardingNextTime = false;
  bool _busy = false;
  bool _busyCanCancel = false;
  bool _busyCancelRequested = false;
  String _busyMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _onboardingDone = prefs.getBool(_kPrefOnboardingDone) ?? false;
      _loadedPrefs = true;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefOnboardingDone, true);
    if (!mounted) return;
    setState(() => _onboardingDone = true);
  }

  Future<void> _dismissOnboarding() async {
    if (_hideOnboardingNextTime) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefOnboardingDone, true);
    }
    if (!mounted) return;
    setState(() => _onboardingDone = true);
  }

  void debugShowBusyOverlay({
    required String message,
    bool canCancel = false,
  }) {
    setState(() {
      _busy = true;
      _busyMessage = message;
      _busyCanCancel = canCancel;
      _busyCancelRequested = false;
    });
  }

  void debugClearBusyOverlay() {
    setState(() {
      _busy = false;
      _busyMessage = '';
      _busyCanCancel = false;
      _busyCancelRequested = false;
    });
  }

  bool debugBusyCancelRequested() => _busyCancelRequested;

  Future<void> _openBlankSheet() async {
    final sheetName = SheetStore.defaultNewSheetName();
    final id = SheetStore.createNew(nameOverride: sheetName);
    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => EditorScreen(
          sheetId: id,
          initialName: sheetName,
          isLight: widget.isLight,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
  }

  Future<void> _showCreateSheetChoices() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('create-sheet-choice-blank'),
              leading: const Icon(Icons.add_rounded),
              title: const Text('Planilla vacía'),
              subtitle: const Text('Relevamiento con nombre automático'),
              onTap: () => Navigator.of(context).pop('blank'),
            ),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Plantilla técnica'),
              subtitle:
                  const Text('Relevamiento con evidencias listo para usar'),
              onTap: () => Navigator.of(context).pop('demo'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'demo') {
      await _openTechnicalDemo();
    } else if (choice == 'blank') {
      await _openBlankSheet();
    }
  }

  Future<void> _openTechnicalDemo() async {
    final template = resolveDemoTemplateFromSlug('relevamiento-evidencias');
    if (template == null) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => EditorScreen(
          sheetId:
              'demo_${template.slug}_${DateTime.now().millisecondsSinceEpoch}',
          initialName: template.sheetName,
          initialHeaders: template.headers,
          initialRows: template.rows,
          isLight: widget.isLight,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
  }

  Future<void> _openMostRecentSheet() async {
    final sheets = SheetStore.list();
    if (sheets.isEmpty) {
      await _openBlankSheet();
      return;
    }
    final meta = sheets.first;
    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => EditorScreen(
          sheetId: meta.id,
          initialName: meta.title,
          isLight: widget.isLight,
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
  }

  Future<void> _openQuickSwitcher() async {
    final sheets = SheetStore.list();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            Navigator.of(dialogContext).pop();
          },
          const SingleActivator(LogicalKeyboardKey.enter): () {
            Navigator.of(dialogContext).pop();
            _openMostRecentSheet();
          },
        },
        child: Focus(
          autofocus: true,
          child: AlertDialog(
            key: const ValueKey('command_palette_dialog'),
            title: const Text('Quick Switcher'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sheets.isEmpty)
                    const Text('No hay planillas todavía.')
                  else
                    for (final sheet in sheets.take(5))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          sheet.title.trim().isEmpty
                              ? 'Planilla sin título'
                              : sheet.title,
                        ),
                        subtitle: Text('${sheet.rows} filas'),
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          _openMostRecentSheet();
                        },
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openStaticPage(Widget page) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => page),
    );
  }

  Future<void> _openLicenses() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LicensePage(
          applicationName: 'BitFlow',
          applicationVersion: BuildInfo.stamp,
        ),
      ),
    );
  }

  Future<void> _openMoreMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuTile(
              icon: Icons.info_outline_rounded,
              title: 'Acerca de BitFlow',
              onTap: () {
                Navigator.of(context).pop();
                _openStaticPage(const AboutScreen());
              },
            ),
            _MenuTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacidad',
              onTap: () {
                Navigator.of(context).pop();
                _openStaticPage(const PrivacyScreen());
              },
            ),
            _MenuTile(
              icon: Icons.description_outlined,
              title: 'Términos',
              onTap: () {
                Navigator.of(context).pop();
                _openStaticPage(const TermsScreen());
              },
            ),
            _MenuTile(
              icon: Icons.monitor_heart_outlined,
              title: 'Diagnóstico',
              onTap: () {
                Navigator.of(context).pop();
                _openStaticPage(DiagnosticsScreen());
              },
            ),
            _MenuTile(
              icon: Icons.code_rounded,
              title: 'Licencias',
              onTap: () {
                Navigator.of(context).pop();
                _openLicenses();
              },
            ),
          ],
        ),
      ),
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isModifierPressed = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (isModifierPressed && event.logicalKey == LogicalKeyboardKey.keyK) {
      _openQuickSwitcher();
      return KeyEventResult.handled;
    }
    if (isModifierPressed && event.logicalKey == LogicalKeyboardKey.keyN) {
      _showCreateSheetChoices();
      return KeyEventResult.handled;
    }
    if (isModifierPressed && event.logicalKey == LogicalKeyboardKey.keyO) {
      _openMostRecentSheet();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final sheets = SheetStore.list();
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 720;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Material(
        color: tokens.colors.bg,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  key: const ValueKey('start-base-fill'),
                  color: tokens.colors.bg,
                ),
              ),
            ),
            SafeArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  wide ? 28 : 18,
                  wide ? 28 : 22,
                  wide ? 28 : 18,
                  32,
                ),
                children: [
                  _BrandRow(
                    onMore: _openMoreMenu,
                    onToggleTheme: widget.onToggleTheme,
                    isLight: widget.isLight,
                  ),
                  const SizedBox(height: 22),
                  if (_loadedPrefs && !_onboardingDone) ...[
                    _OnboardingCard(
                      hideNextTime: _hideOnboardingNextTime,
                      onHideNextTimeChanged: (value) {
                        setState(() => _hideOnboardingNextTime = value);
                      },
                      onNext: _completeOnboarding,
                      onDismiss: _dismissOnboarding,
                      onCreate: _showCreateSheetChoices,
                    ),
                    const SizedBox(height: 22),
                  ],
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Hero(wide: wide),
                          const SizedBox(height: 24),
                          _ActionGrid(
                            sheets: sheets,
                            wide: wide,
                            onNew: _openBlankSheet,
                            onRecent: _openMostRecentSheet,
                            onSearch: _openQuickSwitcher,
                            onTemplate: _openTechnicalDemo,
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _showCreateSheetChoices,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Crear hoja'),
                          ),
                          const SizedBox(height: 32),
                          _DemoPanel(),
                          const SizedBox(height: 32),
                          SectionHeader(
                            title: 'Continuar trabajo',
                            subtitle: sheets.isEmpty
                                ? 'Tus relevamientos recientes aparecerán acá.'
                                : '${sheets.length} planillas guardadas en este dispositivo.',
                          ),
                          const SizedBox(height: 12),
                          _RecentSheetsPanel(
                            sheets: sheets,
                            onOpen: (id) async {
                              if (!mounted) return;
                              final meta = sheets.firstWhere(
                                (s) => s.id == id,
                                orElse: () => sheets.first,
                              );
                              await Navigator.of(context).push(
                                CupertinoPageRoute<void>(
                                  builder: (_) => EditorScreen(
                                    sheetId: meta.id,
                                    initialName: meta.title,
                                    isLight: widget.isLight,
                                    onToggleTheme: widget.onToggleTheme,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                          _AutomationPanel(
                            key: const ValueKey('start-automation-zone'),
                            onDemo: _openTechnicalDemo,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.18),
                  child: Center(
                    child: LoadingState(
                      message: _busyMessage,
                      onCancel: _busyCanCancel
                          ? () {
                              setState(() => _busyCancelRequested = true);
                            }
                          : null,
                      cancelLabel: AppStrings.cancel,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _sheetTitle(SheetMeta sheet) {
    final title = sheet.title.trim();
    return title.isEmpty ? 'Planilla sin título' : title;
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({
    required this.onMore,
    required this.onToggleTheme,
    required this.isLight,
  });

  final VoidCallback onMore;
  final VoidCallback onToggleTheme;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: t.colors.surfaceMuted,
            borderRadius: BorderRadius.circular(t.radii.sm),
            border: Border.all(color: t.colors.border),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.grid_view_rounded,
            size: 18,
            color: t.colors.textPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Bit Flow',
            style: t.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('start-more-button'),
          onPressed: onMore,
          icon: const Icon(CupertinoIcons.ellipsis),
          color: t.colors.textPrimary,
          tooltip: 'Más opciones',
        ),
        IconButton(
          onPressed: onToggleTheme,
          icon: Icon(
            isLight ? CupertinoIcons.moon : CupertinoIcons.sun_max,
          ),
          color: t.colors.textPrimary,
          tooltip: isLight ? 'Modo oscuro' : 'Modo claro',
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final titleStyle =
        (wide ? t.text.displaySmall : t.text.headlineMedium)?.copyWith(
      color: t.colors.textPrimary,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.6,
      height: 1.05,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: t.colors.surfaceMuted,
            borderRadius: BorderRadius.circular(t.radii.pill),
            border: Border.all(color: t.colors.border),
          ),
          child: Text(
            'Local · Sin servidores · Listo para campo',
            style: t.text.labelSmall?.copyWith(
              color: t.colors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Planillas técnicas con\nevidencias en campo.',
          style: titleStyle,
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            'Bit Flow organiza relevamientos, registros técnicos y adjuntos en una tabla rápida, local y lista para exportar.',
            style: t.text.bodyLarge?.copyWith(
              color: t.colors.textSecondary,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.sheets,
    required this.wide,
    required this.onNew,
    required this.onRecent,
    required this.onSearch,
    required this.onTemplate,
  });

  final List<SheetMeta> sheets;
  final bool wide;
  final VoidCallback onNew;
  final VoidCallback onRecent;
  final VoidCallback onSearch;
  final VoidCallback onTemplate;

  @override
  Widget build(BuildContext context) {
    final recentTitle = sheets.isEmpty
        ? 'Tu relevamiento reciente aparecerá acá'
        : _StartPageV2State._sheetTitle(sheets.first);
    final tiles = <Widget>[
      _ActionTile(
        valueKey: const ValueKey('start-primary-new'),
        icon: Icons.add_rounded,
        title: 'Nuevo relevamiento',
        subtitle: 'Crea una hoja con nombre único',
        accent: true,
        onTap: onNew,
      ),
      _ActionTile(
        valueKey: const ValueKey('start-primary-open-recent'),
        icon: Icons.history_rounded,
        title: 'Continuar último',
        subtitle: recentTitle,
        onTap: onRecent,
      ),
      _ActionTile(
        valueKey: const ValueKey('start-primary-search'),
        icon: Icons.search_rounded,
        title: 'Buscar planillas',
        subtitle: 'Saltar rápido a un trabajo',
        onTap: onSearch,
      ),
      _ActionTile(
        valueKey: const ValueKey('start-primary-automate'),
        icon: Icons.auto_awesome_rounded,
        title: 'Plantilla técnica',
        subtitle: 'Operadora Norte · evidencias',
        onTap: onTemplate,
      ),
    ];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cols = wide && constraints.maxWidth > 720 ? 2 : 1;
        final spacing = 14.0;
        final tileWidth = cols == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.valueKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final ValueKey<String> valueKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return KeyedSubtree(
      key: valueKey,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        borderColor: accent ? t.colors.borderStrong : t.colors.border,
        shadows: accent ? t.shadows.card : t.shadows.soft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent ? t.colors.accent : t.colors.surfaceMuted,
                borderRadius: BorderRadius.circular(t.radii.md),
                border: Border.all(
                  color: accent ? t.colors.accent : t.colors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 20,
                color: accent
                    ? (t.colors.isLight
                        ? Colors.white
                        : const Color(0xFF0D0D0F))
                    : t.colors.textPrimary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.bodySmall?.copyWith(
                      color: t.colors.textSecondary,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: t.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.hideNextTime,
    required this.onHideNextTimeChanged,
    required this.onNext,
    required this.onDismiss,
    required this.onCreate,
  });

  final bool hideNextTime;
  final ValueChanged<bool> onHideNextTimeChanged;
  final VoidCallback onNext;
  final VoidCallback onDismiss;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      padding: const EdgeInsets.all(20),
      shadows: t.shadows.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: t.colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(t.radii.sm),
                  border: Border.all(color: t.colors.border),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: t.colors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Primeros pasos',
                  style: t.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Crea una planilla, carga evidencias y exporta cuando termines.',
            style: t.text.bodyMedium?.copyWith(
              color: t.colors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Switch.adaptive(
                value: hideNextTime,
                onChanged: onHideNextTimeChanged,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'No volver a mostrar',
                  style: t.text.bodySmall?.copyWith(
                    color: t.colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: onNext,
                child: const Text('Siguiente'),
              ),
              TextButton(
                onPressed: onDismiss,
                child: const Text('Ahora no'),
              ),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crear hoja'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentSheetsPanel extends StatelessWidget {
  const _RecentSheetsPanel({
    required this.sheets,
    required this.onOpen,
  });

  final List<SheetMeta> sheets;
  final Future<void> Function(String) onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (sheets.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: t.colors.surfaceMuted,
                borderRadius: BorderRadius.circular(t.radii.md),
                border: Border.all(color: t.colors.border),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.history_rounded,
                size: 20,
                color: t.colors.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Cuando abras una planilla, aparecerá acá para retomarla rápido.',
                style: t.text.bodyMedium?.copyWith(
                  color: t.colors.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < sheets.take(4).length; i++) ...[
            _RecentRow(
              meta: sheets[i],
              onTap: () => onOpen(sheets[i].id),
            ),
            if (i < sheets.take(4).length - 1)
              Divider(height: 1, color: t.colors.border),
          ],
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.meta, required this.onTap});

  final SheetMeta meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final title = _StartPageV2State._sheetTitle(meta);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: t.colors.surfaceMuted,
                borderRadius: BorderRadius.circular(t.radii.sm),
                border: Border.all(color: t.colors.border),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.table_chart_outlined,
                size: 18,
                color: t.colors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${meta.rows} filas',
                    style: t.text.bodySmall?.copyWith(
                      color: t.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: t.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _AutomationPanel extends StatelessWidget {
  const _AutomationPanel({
    super.key,
    required this.onDemo,
  });

  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: t.colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(t.radii.sm),
                  border: Border.all(color: t.colors.border),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: t.colors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Automatizaciones',
                  style: t.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Acciones listas para relevamientos técnicos.',
            style: t.text.bodyMedium?.copyWith(
              color: t.colors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: 'Plantilla técnica',
            icon: Icons.science_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: onDemo,
          ),
        ],
      ),
    );
  }
}

class _DemoPanel extends StatelessWidget {
  const _DemoPanel();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rows = const [
      ['Operadora Norte', 'Manifold 3', 'Inspección visual', 'OK'],
      ['Operadora Norte', 'Línea 6"', 'Vibración en soporte', 'Revisar'],
      ['Operadora Norte', 'Caseta RTU', 'Foto y GPS cargados', 'Completo'],
    ];

    return AppCard(
      padding: EdgeInsets.zero,
      shadows: t.shadows.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: t.colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(t.radii.sm),
                    border: Border.all(color: t.colors.border),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.table_chart_outlined,
                    size: 18,
                    color: t.colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Relevamiento técnico con evidencias',
                        style: t.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Local · Guardado en este dispositivo',
                        style: t.text.bodySmall?.copyWith(
                          color: t.colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: t.colors.border),
          Semantics(
            label:
                'Vista previa de relevamiento técnico con cliente, activo, hallazgo y estado.',
            child: ExcludeSemantics(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(
                    t.colors.surfaceMuted,
                  ),
                  dividerThickness: 0,
                  columns: const [
                    DataColumn(label: Text('Cliente')),
                    DataColumn(label: Text('Activo')),
                    DataColumn(label: Text('Hallazgo')),
                    DataColumn(label: Text('Estado')),
                  ],
                  rows: [
                    for (final row in rows)
                      DataRow(
                        cells: [
                          for (final cell in row) DataCell(Text(cell)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
