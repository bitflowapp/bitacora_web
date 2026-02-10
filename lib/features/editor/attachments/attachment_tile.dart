part of '../editor_screen.dart';

class AttachmentTile extends StatelessWidget {
  const AttachmentTile({
    required this.palette,
    required this.thumb,
    required this.typeIcon,
    required this.label,
    required this.dateLabel,
    required this.onPreview,
    required this.onRename,
    required this.onDelete,
  });

  final _SheetPalette palette;
  final Widget thumb;
  final IconData typeIcon;
  final String label;
  final String dateLabel;
  final VoidCallback onPreview;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final safeLabel = label.trim().isEmpty ? 'Adjunto' : label.trim();
    final overlayBg =
        palette.bg.withValues(alpha: palette.isLight ? 0.86 : 0.62);
    return Semantics(
      button: true,
      label: 'Abrir adjunto $safeLabel',
      child: Material(
        color: palette.menuBg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPreview,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: thumb),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Tooltip(
                          message: 'Reordenar',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: overlayBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: palette.border,
                                width: palette.hairline,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.drag_indicator_rounded,
                                  size: 13,
                                  color: palette.fgMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Mover',
                                  style: TextStyle(
                                    color: palette.fgMuted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(typeIcon, size: 14, color: palette.fgMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Tooltip(
                        message: safeLabel,
                        child: Text(
                          safeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.fg,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.fgMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Ver adjunto',
                      child: Tooltip(
                        message: 'Ver',
                        child: _MiniActionButton(
                          icon: Icons.visibility_outlined,
                          onPressed: onPreview,
                          palette: palette,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'Renombrar adjunto',
                      child: Tooltip(
                        message: 'Renombrar',
                        child: _MiniActionButton(
                          icon: Icons.edit_rounded,
                          onPressed: onRename,
                          palette: palette,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'Eliminar adjunto',
                      child: Tooltip(
                        message: 'Eliminar',
                        child: _MiniActionButton(
                          icon: Icons.delete_outline_rounded,
                          onPressed: onDelete,
                          palette: palette,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.onPressed,
    required this.palette,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final _SheetPalette palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: palette.hintBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: palette.border,
              width: palette.hairline,
            ),
          ),
          child: Icon(icon, size: 16, color: palette.fgMuted),
        ),
      ),
    );
  }
}
