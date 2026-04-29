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
import 'ui/app_strings.dart';
import 'ui/loading_state.dart';

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
                              ? 'Planilla sin titulo'
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
    final brightness = widget.isLight ? Brightness.light : Brightness.dark;
    final bg =
        widget.isLight ? const Color(0xFFF6F4EF) : const Color(0xFF111316);
    final panel = widget.isLight ? Colors.white : const Color(0xFF1A1D22);
    final ink =
        widget.isLight ? const Color(0xFF121418) : const Color(0xFFF4F7FB);
    final muted =
        widget.isLight ? const Color(0xFF5D6470) : const Color(0xFFAEB7C4);
    final accent =
        widget.isLight ? const Color(0xFF1455D9) : const Color(0xFF7FB4FF);
    final border =
        widget.isLight ? const Color(0xFFE2E6EE) : const Color(0xFF303743);
    final sheets = SheetStore.list();

    return Theme(
      data: ThemeData(
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ),
        useMaterial3: true,
      ),
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Material(
          color: bg,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    key: const ValueKey('start-base-fill'),
                    color: bg,
                  ),
                ),
              ),
              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Bit Flow',
                            style: TextStyle(
                              color: ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('start-more-button'),
                          onPressed: _openMoreMenu,
                          icon: Icon(CupertinoIcons.ellipsis, color: ink),
                        ),
                        IconButton(
                          onPressed: widget.onToggleTheme,
                          icon: Icon(
                            widget.isLight
                                ? CupertinoIcons.moon
                                : CupertinoIcons.sun_max,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_loadedPrefs && !_onboardingDone)
                      _OnboardingCard(
                        panel: panel,
                        border: border,
                        ink: ink,
                        muted: muted,
                        hideNextTime: _hideOnboardingNextTime,
                        onHideNextTimeChanged: (value) {
                          setState(() => _hideOnboardingNextTime = value);
                        },
                        onNext: _completeOnboarding,
                        onDismiss: _dismissOnboarding,
                        onCreate: _showCreateSheetChoices,
                      ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Planillas técnicas con evidencias en campo.',
                            style: TextStyle(
                              color: ink,
                              fontSize: 38,
                              height: 1.02,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Bit Flow organiza relevamientos, registros técnicos y adjuntos en una tabla rápida, local y lista para exportar.',
                            style: TextStyle(
                              color: muted,
                              fontSize: 16,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _HomeActionButton(
                                key: const ValueKey('start-primary-new'),
                                icon: Icons.add_rounded,
                                title: 'Nuevo relevamiento',
                                subtitle: 'Crea una hoja con nombre único',
                                onTap: _openBlankSheet,
                              ),
                              _HomeActionButton(
                                key:
                                    const ValueKey('start-primary-open-recent'),
                                icon: Icons.history_rounded,
                                title: 'Abrir reciente',
                                subtitle: sheets.isEmpty
                                    ? 'Aparecerá tu último trabajo'
                                    : _sheetTitle(sheets.first),
                                onTap: _openMostRecentSheet,
                              ),
                              _HomeActionButton(
                                key: const ValueKey('start-primary-search'),
                                icon: Icons.search_rounded,
                                title: 'Buscar archivos',
                                subtitle: 'Quick Search',
                                onTap: _openQuickSwitcher,
                              ),
                              _HomeActionButton(
                                key: const ValueKey('start-primary-automate'),
                                icon: Icons.auto_awesome_rounded,
                                title: 'Plantilla técnica',
                                subtitle: 'Operadora Norte · evidencias',
                                onTap: _openTechnicalDemo,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _showCreateSheetChoices,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Crear hoja'),
                          ),
                          const SizedBox(height: 28),
                          _DemoPanel(
                            panel: panel,
                            border: border,
                            ink: ink,
                            muted: muted,
                            accent: accent,
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Continuar trabajo',
                            style: TextStyle(
                              color: ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _RecentSheetsPanel(
                            panel: panel,
                            border: border,
                            muted: muted,
                            sheets: sheets,
                          ),
                          const SizedBox(height: 28),
                          _AutomationPanel(
                            key: const ValueKey('start-automation-zone'),
                            panel: panel,
                            border: border,
                            ink: ink,
                            muted: muted,
                            onDemo: _openTechnicalDemo,
                          ),
                        ],
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
      ),
    );
  }

  static String _sheetTitle(SheetMeta sheet) {
    final title = sheet.title.trim();
    return title.isEmpty ? 'Planilla sin titulo' : title;
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

class _HomeActionButton extends StatelessWidget {
  const _HomeActionButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.panel,
    required this.border,
    required this.ink,
    required this.muted,
    required this.hideNextTime,
    required this.onHideNextTimeChanged,
    required this.onNext,
    required this.onDismiss,
    required this.onCreate,
  });

  final Color panel;
  final Color border;
  final Color ink;
  final Color muted;
  final bool hideNextTime;
  final ValueChanged<bool> onHideNextTimeChanged;
  final VoidCallback onNext;
  final VoidCallback onDismiss;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Primeros pasos',
            style: TextStyle(
              color: ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Crea una planilla, carga evidencias y exporta cuando termines.',
            style: TextStyle(color: muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Switch(
                value: hideNextTime,
                onChanged: onHideNextTimeChanged,
              ),
              Text(
                'No volver a mostrar',
                style: TextStyle(color: muted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(onPressed: onNext, child: const Text('Siguiente')),
              TextButton(onPressed: onDismiss, child: const Text('Ahora no')),
              FilledButton(
                onPressed: onCreate,
                child: const Text('Crear hoja'),
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
    required this.panel,
    required this.border,
    required this.muted,
    required this.sheets,
  });

  final Color panel;
  final Color border;
  final Color muted;
  final List<SheetMeta> sheets;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sheets.isEmpty)
            Text(
              'Abre una planilla para verla aqui.',
              style: TextStyle(color: muted),
            )
          else
            for (final sheet in sheets.take(4))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _StartPageV2State._sheetTitle(sheet),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        ],
      ),
    );
  }
}

class _AutomationPanel extends StatelessWidget {
  const _AutomationPanel({
    super.key,
    required this.panel,
    required this.border,
    required this.ink,
    required this.muted,
    required this.onDemo,
  });

  final Color panel;
  final Color border;
  final Color ink;
  final Color muted;
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Automatizaciones',
            style: TextStyle(
              color: ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Acciones listas para relevamientos técnicos.',
            style: TextStyle(color: muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onDemo,
            icon: const Icon(Icons.science_outlined),
            label: const Text('Plantilla técnica'),
          ),
        ],
      ),
    );
  }
}

class _DemoPanel extends StatelessWidget {
  const _DemoPanel({
    required this.panel,
    required this.border,
    required this.ink,
    required this.muted,
    required this.accent,
  });

  final Color panel;
  final Color border;
  final Color ink;
  final Color muted;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final rows = const [
      ['Operadora Norte', 'Manifold 3', 'Inspección visual', 'OK'],
      ['Operadora Norte', 'Línea 6"', 'Vibración en soporte', 'Revisar'],
      ['Operadora Norte', 'Caseta RTU', 'Foto y GPS cargados', 'Completo'],
    ];

    return Container(
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.table_chart_outlined, color: accent),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    'Relevamiento técnico con evidencias',
                    style: TextStyle(
                      color: ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  'Local · Guardado en este dispositivo',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: border),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                accent.withValues(alpha: 0.08),
              ),
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
        ],
      ),
    );
  }
}
