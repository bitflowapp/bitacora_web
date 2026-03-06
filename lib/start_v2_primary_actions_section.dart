part of 'start_page_v2.dart';

class _StartPrimaryActionsSection extends StatelessWidget {
  const _StartPrimaryActionsSection({
    required this.colors,
    required this.quickActions,
  });

  final _ApplePalette colors;
  final List<_StartQuickActionSpec> quickActions;

  @override
  Widget build(BuildContext context) {
    return _StartSectionShell(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Acciones principales',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Solo las cuatro acciones mas utiles para empezar, abrir y avanzar rapido.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final columns = compact ? 2 : 4;
              const gap = 12.0;
              final totalGap = gap * (columns - 1);
              final tileWidth = (constraints.maxWidth - totalGap) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final action in quickActions)
                    SizedBox(
                      width: tileWidth,
                      child: _StartQuickActionTile(
                        action: action,
                        colors: colors,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StartShortcutChip(
                combo: 'Ctrl/Cmd + K',
                label: 'Paleta de comandos',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
