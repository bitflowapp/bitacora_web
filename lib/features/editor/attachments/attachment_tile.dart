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
    return Semantics(
      button: true,
      label: 'Abrir adjunto $safeLabel',
      child: Material(
        color: palette.headerBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPreview,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: thumb),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Tooltip(
                          message: 'Reordenar',
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: palette.bg
                                  .withOpacity(palette.isLight ? 0.85 : 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.drag_handle_rounded,
                              size: 14,
                              color: palette.fgMuted,
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Renombrar adjunto',
                      child: Tooltip(
                        message: 'Renombrar',
                        child: AppIconButton(
                          icon: Icons.edit_rounded,
                          onPressed: onRename,
                          tooltip: 'Renombrar',
                          size: AppIconButtonSize.sm,
                          variant: AppIconButtonVariant.ghost,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      button: true,
                      label: 'Eliminar adjunto',
                      child: Tooltip(
                        message: 'Eliminar',
                        child: AppIconButton(
                          icon: Icons.delete_outline_rounded,
                          onPressed: onDelete,
                          tooltip: 'Eliminar',
                          size: AppIconButtonSize.sm,
                          variant: AppIconButtonVariant.ghost,
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
