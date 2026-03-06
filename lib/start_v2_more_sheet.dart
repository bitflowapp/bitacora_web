part of 'start_page_v2.dart';

class _MoreSheetItem {
  const _MoreSheetItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onSelected,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onSelected;
  final bool destructive;
}

class _StartMoreSheet extends StatelessWidget {
  const _StartMoreSheet({
    required this.colors,
    required this.items,
    required this.firstDangerousIndex,
    required this.onClose,
  });

  final _ApplePalette colors;
  final List<_MoreSheetItem> items;
  final int firstDangerousIndex;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.separator),
            boxShadow: [colors.subtleShadow],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.separator,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Mas',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 0),
                      borderRadius: BorderRadius.circular(999),
                      color: colors.group,
                      onPressed: onClose,
                      child: Text(
                        'Cerrar',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: items.length,
                  separatorBuilder: (_, index) {
                    if (firstDangerousIndex > 0 &&
                        index == firstDangerousIndex - 1) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Container(
                          height: 1,
                          color: colors.separator.withValues(alpha: 0.9),
                        ),
                      );
                    }
                    return Container(
                      height: 1,
                      color: colors.separator,
                    );
                  },
                  itemBuilder: (_, index) {
                    final item = items[index];
                    return _MoreSheetRow(
                      colors: colors,
                      item: item,
                      onTap: () async {
                        Navigator.of(context).pop();
                        await item.onSelected();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreSheetRow extends StatelessWidget {
  const _MoreSheetRow({
    required this.colors,
    required this.item,
    required this.onTap,
  });

  final _ApplePalette colors;
  final _MoreSheetItem item;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = item.destructive ? colors.accent : colors.textPrimary;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      onPressed: () => unawaited(onTap()),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: item.destructive
                  ? colors.accent.withValues(alpha: 0.10)
                  : colors.group,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: item.destructive
                    ? colors.accent.withValues(alpha: 0.16)
                    : colors.separator,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(item.icon, color: foreground, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.chevron_forward,
            color: colors.textSecondary,
            size: 16,
          ),
        ],
      ),
    );
  }
}
