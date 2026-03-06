part of 'start_page_v2.dart';

class _StartQuickActionSpec {
  const _StartQuickActionSpec({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.shortcut,
    required this.onPressed,
  });

  final Key key;
  final IconData icon;
  final String title;
  final String subtitle;
  final String shortcut;
  final Future<void> Function() onPressed;
}

class _StartBucketSpec {
  const _StartBucketSpec({
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    required this.items,
  });

  final String title;
  final String subtitle;
  final String emptyMessage;
  final List<SheetMeta> items;
}

class _StartAutomationAction {
  const _StartAutomationAction({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.contextLabel,
    required this.onSelected,
  });

  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final String contextLabel;
  final Future<void> Function() onSelected;
}

class _StartSectionShell extends StatelessWidget {
  const _StartSectionShell({
    required this.colors,
    required this.child,
  });

  final _ApplePalette colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.separator),
        boxShadow: [colors.subtleShadow],
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }
}

class _StartMetricPill extends StatelessWidget {
  const _StartMetricPill({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final _ApplePalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.group,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.separator),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartShortcutChip extends StatelessWidget {
  const _StartShortcutChip({
    required this.combo,
    required this.label,
  });

  final String combo;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _ApplePalette(
      isLight: theme.brightness == Brightness.light,
      colorScheme: theme.colorScheme,
      scaffold: theme.scaffoldBackgroundColor,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.group,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.separator),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            combo,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartCircleIconButton extends StatelessWidget {
  const _StartCircleIconButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final _ApplePalette colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colors.group,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.separator),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: colors.textPrimary,
          size: 18,
          semanticLabel: label,
        ),
      ),
    );
  }
}

class _StartQuickActionTile extends StatefulWidget {
  const _StartQuickActionTile({
    required this.action,
    required this.colors,
  });

  final _StartQuickActionSpec action;
  final _ApplePalette colors;

  @override
  State<_StartQuickActionTile> createState() => _StartQuickActionTileState();
}

class _StartQuickActionTileState extends State<_StartQuickActionTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final compact = MediaQuery.of(context).size.height < 760;
    final tilePadding = compact ? 14.0 : 16.0;
    final iconBox = compact ? 38.0 : 42.0;
    final titleFont = compact ? 15.0 : 17.0;
    final subtitleFont = compact ? 11.0 : 12.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.01 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: CupertinoButton(
          key: widget.action.key,
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => unawaited(widget.action.onPressed()),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.all(tilePadding),
            decoration: BoxDecoration(
              color: _hovering ? colors.group : colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.separator),
              boxShadow: _hovering ? [colors.subtleShadow] : const [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.14),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    widget.action.icon,
                    color: colors.textPrimary,
                    size: compact ? 18 : 20,
                  ),
                ),
                SizedBox(height: compact ? 14 : 18),
                Text(
                  widget.action.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: titleFont,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: compact ? 4 : 6),
                Text(
                  widget.action.subtitle,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: subtitleFont,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: compact ? 10 : 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: colors.group,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colors.separator),
                  ),
                  child: Text(
                    widget.action.shortcut,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartFileBucket extends StatelessWidget {
  const _StartFileBucket({
    required this.colors,
    required this.bucket,
    required this.noteForSheet,
    required this.isFavorite,
    required this.isPinned,
    required this.fmt,
    required this.onOpen,
    required this.onRename,
    required this.onToggleFavorite,
    required this.onTogglePinned,
    required this.onMore,
  });

  final _ApplePalette colors;
  final _StartBucketSpec bucket;
  final String Function(String sheetId) noteForSheet;
  final bool Function(String sheetId) isFavorite;
  final bool Function(String sheetId) isPinned;
  final String Function(DateTime date) fmt;
  final Future<void> Function(SheetMeta meta) onOpen;
  final Future<void> Function(SheetMeta meta) onRename;
  final Future<void> Function(SheetMeta meta) onToggleFavorite;
  final Future<void> Function(SheetMeta meta) onTogglePinned;
  final Future<void> Function(SheetMeta meta) onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.group.withValues(alpha: colors.isLight ? 0.54 : 0.46),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.separator),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bucket.title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bucket.subtitle,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (bucket.items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.separator),
              ),
              child: Text(
                bucket.emptyMessage,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            )
          else
            for (int i = 0; i < bucket.items.length; i++) ...[
              _StartFileItemTile(
                colors: colors,
                sheet: bucket.items[i],
                note: noteForSheet(bucket.items[i].id),
                favorite: isFavorite(bucket.items[i].id),
                pinned: isPinned(bucket.items[i].id),
                fmt: fmt,
                onOpen: () => onOpen(bucket.items[i]),
                onRename: () => onRename(bucket.items[i]),
                onToggleFavorite: () => onToggleFavorite(bucket.items[i]),
                onTogglePinned: () => onTogglePinned(bucket.items[i]),
                onMore: () => onMore(bucket.items[i]),
              ),
              if (i != bucket.items.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _StartFileItemTile extends StatelessWidget {
  const _StartFileItemTile({
    required this.colors,
    required this.sheet,
    required this.note,
    required this.favorite,
    required this.pinned,
    required this.fmt,
    required this.onOpen,
    required this.onRename,
    required this.onToggleFavorite,
    required this.onTogglePinned,
    required this.onMore,
  });

  final _ApplePalette colors;
  final SheetMeta sheet;
  final String note;
  final bool favorite;
  final bool pinned;
  final String Function(DateTime date) fmt;
  final Future<void> Function() onOpen;
  final Future<void> Function() onRename;
  final Future<void> Function() onToggleFavorite;
  final Future<void> Function() onTogglePinned;
  final Future<void> Function() onMore;

  String get _title {
    final title = sheet.title.trim();
    return title.isEmpty ? 'Planilla sin titulo' : title;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.separator),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${fmt(sheet.updatedAt)} - ${sheet.rows} filas',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  _StartTinyIconButton(
                    icon: pinned ? CupertinoIcons.pin_fill : CupertinoIcons.pin,
                    colors: colors,
                    onPressed: () => unawaited(onTogglePinned()),
                  ),
                  const SizedBox(height: 6),
                  _StartTinyIconButton(
                    buttonKey: ValueKey('start-sheet-more-${sheet.id}'),
                    icon: CupertinoIcons.ellipsis,
                    colors: colors,
                    onPressed: () => unawaited(onMore()),
                  ),
                ],
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSecondary.withValues(alpha: 0.92),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StartFileActionChip(
                icon: CupertinoIcons.arrow_up_right_square,
                label: 'Abrir',
                colors: colors,
                emphasis: true,
                onPressed: () => unawaited(onOpen()),
              ),
              _StartFileActionChip(
                icon: CupertinoIcons.pencil,
                label: 'Renombrar',
                colors: colors,
                onPressed: () => unawaited(onRename()),
              ),
              _StartFileActionChip(
                icon: favorite ? CupertinoIcons.star_fill : CupertinoIcons.star,
                label: 'Favorita',
                colors: colors,
                onPressed: () => unawaited(onToggleFavorite()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StartTinyIconButton extends StatelessWidget {
  const _StartTinyIconButton({
    this.buttonKey,
    required this.icon,
    required this.colors,
    required this.onPressed,
  });

  final Key? buttonKey;
  final IconData icon;
  final _ApplePalette colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      key: buttonKey,
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: colors.group,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.separator),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: colors.textSecondary,
          size: 14,
        ),
      ),
    );
  }
}

class _StartFileActionChip extends StatelessWidget {
  const _StartFileActionChip({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onPressed,
    this.emphasis = false,
  });

  final IconData icon;
  final String label;
  final _ApplePalette colors;
  final VoidCallback onPressed;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final fillColor = emphasis ? colors.group : colors.surface;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.separator),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: colors.textPrimary,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartAutomationTile extends StatelessWidget {
  const _StartAutomationTile({
    required this.action,
    required this.colors,
    required this.onPressed,
  });

  final _StartAutomationAction action;
  final _ApplePalette colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.separator),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                action.icon,
                color: colors.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (action.contextLabel.trim().isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      action.contextLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: colors.textSecondary,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}
