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
    required this.onRename,
    required this.onToggleFavorite,
    required this.onTogglePinned,
    required this.onMore,
    required this.onOpenHistory,
  });

  final _ApplePalette colors;
  final _StartBucketSpec primaryBucket;
  final List<_StartBucketSpec> secondaryBuckets;
  final String Function(String sheetId) noteForSheet;
  final bool Function(String sheetId) isFavorite;
  final bool Function(String sheetId) isPinned;
  final String Function(DateTime date) fmt;
  final Future<void> Function(SheetMeta meta) onOpen;
  final Future<void> Function(SheetMeta meta) onRename;
  final Future<void> Function(SheetMeta meta) onToggleFavorite;
  final Future<void> Function(SheetMeta meta) onTogglePinned;
  final Future<void> Function(SheetMeta meta) onMore;
  final Future<void> Function() onOpenHistory;

  @override
  Widget build(BuildContext context) {
    return _StartSectionShell(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Trabajo reciente',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              CupertinoButton(
                key: const ValueKey('start-history-open-all'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                onPressed: () => unawaited(onOpenHistory()),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colors.separator),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.collections,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ver todas',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Mantene visibles tus ultimos archivos, con favoritas y fijadas a mano cuando importan.',
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
                        onRename: onRename,
                        onToggleFavorite: onToggleFavorite,
                        onTogglePinned: onTogglePinned,
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
                              onRename: onRename,
                              onToggleFavorite: onToggleFavorite,
                              onTogglePinned: onTogglePinned,
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
                        onRename: onRename,
                        onToggleFavorite: onToggleFavorite,
                        onTogglePinned: onTogglePinned,
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
