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
    final heroAction = quickActions.isNotEmpty ? quickActions.first : null;
    final secondaryActions = quickActions.length > 1
        ? quickActions.sublist(1)
        : const <_StartQuickActionSpec>[];
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
            'Una acci\u00f3n principal para empezar y accesos directos claros para retomar sin ruido.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          if (heroAction != null) ...[
            _StartQuickActionTile(
              action: heroAction,
              colors: colors,
              prominent: true,
            ),
            if (secondaryActions.isNotEmpty) const SizedBox(height: 14),
          ],
          if (secondaryActions.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 520
                    ? 1
                    : (constraints.maxWidth < 920 ? 2 : 3);
                const gap = 12.0;
                final totalGap = gap * (columns - 1);
                final tileWidth = (constraints.maxWidth - totalGap) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final action in secondaryActions)
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
          const SizedBox(height: 14),
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
