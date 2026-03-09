part of 'start_page_v2.dart';

class _StartHeaderSection extends StatelessWidget {
  const _StartHeaderSection({
    required this.colors,
    required this.cardBackground,
    required this.borderColor,
    required this.isShortViewport,
    required this.headerTitle,
    required this.headerDetail,
    required this.headerMetrics,
    required this.onToggleTheme,
    required this.onOpenMore,
  });

  final _ApplePalette colors;
  final Color cardBackground;
  final Color borderColor;
  final bool isShortViewport;
  final String headerTitle;
  final String headerDetail;
  final List<Widget> headerMetrics;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Container(
        key: const ValueKey('start-header-card'),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: borderColor),
          boxShadow: [colors.subtleShadow],
        ),
        padding: EdgeInsets.fromLTRB(
          22,
          isShortViewport ? 16 : 20,
          22,
          isShortViewport ? 18 : 22,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: isShortViewport ? 40 : 44,
                  height: isShortViewport ? 40 : 44,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.14),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    CupertinoIcons.square_grid_2x2_fill,
                    color: colors.textPrimary,
                    size: isShortViewport ? 20 : 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BitFlow',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Centro de productividad',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StartCircleIconButton(
                  key: const ValueKey('start-theme-toggle'),
                  icon: colors.isLight
                      ? CupertinoIcons.moon_stars
                      : CupertinoIcons.sun_max,
                  label: 'Cambiar tema',
                  colors: colors,
                  onPressed: onToggleTheme,
                ),
                const SizedBox(width: 8),
                _StartCircleIconButton(
                  key: const ValueKey('start-more-button'),
                  icon: CupertinoIcons.ellipsis,
                  label: 'M\u00e1s opciones',
                  colors: colors,
                  onPressed: onOpenMore,
                ),
              ],
            ),
            SizedBox(height: isShortViewport ? 16 : 20),
            Text(
              headerTitle,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: isShortViewport ? 28 : 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
                height: 0.95,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              headerDetail,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: isShortViewport
                  ? headerMetrics.take(2).toList(growable: false)
                  : headerMetrics,
            ),
          ],
        ),
      ),
    );
  }
}
