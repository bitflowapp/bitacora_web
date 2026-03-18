part of 'start_page_v2.dart';

class _StartRecentWorkSection extends StatelessWidget {
  const _StartRecentWorkSection({
    required this.colors,
    required this.primaryBucket,
    required this.secondaryBuckets,
    required this.noteForSheet,
    required this.isFavorite,
    required this.isPinned,
    required this.fmt,
    required this.onOpen,
    required this.onMore,
  });

  final _ApplePalette colors;
  final _StartBucketSpec primaryBucket;
  final List<_StartBucketSpec> secondaryBuckets;
  final String Function(String sheetId) noteForSheet;
  final bool Function(String sheetId) isFavorite;
  final bool Function(String sheetId) isPinned;
  final String Function(DateTime date) fmt;
  final Future<void> Function(SheetMeta meta) onOpen;
  final Future<void> Function(SheetMeta meta) onMore;

  @override
  Widget build(BuildContext context) {
    return _StartSectionShell(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trabajo reciente',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Retoma tus ultimos archivos sin ruido visual ni capas de organizacion antes de abrir.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              const gap = 14.0;
              if (maxWidth >= 980 && secondaryBuckets.isNotEmpty) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _StartFileBucket(
                        colors: colors,
                        bucket: primaryBucket,
                        noteForSheet: noteForSheet,
                        isFavorite: isFavorite,
                        isPinned: isPinned,
                        fmt: fmt,
                        onOpen: onOpen,
                        onMore: onMore,
                      ),
                    ),
                    const SizedBox(width: gap),
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          for (int i = 0; i < secondaryBuckets.length; i++) ...[
                            _StartFileBucket(
                              colors: colors,
                              bucket: secondaryBuckets[i],
                              noteForSheet: noteForSheet,
                              isFavorite: isFavorite,
                              isPinned: isPinned,
                              fmt: fmt,
                              onOpen: onOpen,
                              onMore: onMore,
                            ),
                            if (i != secondaryBuckets.length - 1)
                              const SizedBox(height: gap),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              }

              final buckets = <_StartBucketSpec>[
                primaryBucket,
                ...secondaryBuckets,
              ];
              final columns = maxWidth >= 1080 && buckets.length > 1 ? 2 : 1;
              final totalGap = gap * (columns - 1);
              final bucketWidth = (maxWidth - totalGap) / columns;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final bucket in buckets)
                    SizedBox(
                      width: bucketWidth,
                      child: _StartFileBucket(
                        colors: colors,
                        bucket: bucket,
                        noteForSheet: noteForSheet,
                        isFavorite: isFavorite,
                        isPinned: isPinned,
                        fmt: fmt,
                        onOpen: onOpen,
                        onMore: onMore,
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
