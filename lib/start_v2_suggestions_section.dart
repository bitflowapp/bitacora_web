part of 'start_page_v2.dart';

class _StartSuggestionsSection extends StatelessWidget {
  const _StartSuggestionsSection({
    required this.colors,
    required this.automationActions,
  });

  final _ApplePalette colors;
  final List<_StartAutomationAction> automationActions;

  @override
  Widget build(BuildContext context) {
    return _StartSectionShell(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sugerencias',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Atajos y sugerencias pequenas para decidir el siguiente paso util sin ruido.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 760 ? 1 : 2;
              const gap = 12.0;
              final totalGap = gap * (columns - 1);
              final tileWidth = (constraints.maxWidth - totalGap) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final action in automationActions)
                    SizedBox(
                      width: tileWidth,
                      child: _StartAutomationTile(
                        action: action,
                        colors: colors,
                        onPressed: () => unawaited(action.onSelected()),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
