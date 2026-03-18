part of '../editor_screen.dart';

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.palette,
    required this.thumb,
    required this.typeIcon,
    required this.label,
    required this.dateLabel,
    required this.onPreview,
    required this.onRename,
    required this.onDelete,
    this.previewKey,
    this.uploadStatusLabel,
    this.uploadStatusIcon,
    this.uploadStatusColor,
    this.uploadError,
    this.onRetryUpload,
  });

  final _SheetPalette palette;
  final Widget thumb;
  final IconData typeIcon;
  final String label;
  final String dateLabel;
  final VoidCallback? onPreview;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final Key? previewKey;
  final String? uploadStatusLabel;
  final IconData? uploadStatusIcon;
  final Color? uploadStatusColor;
  final String? uploadError;
  final VoidCallback? onRetryUpload;

  @override
  Widget build(BuildContext context) {
    final safeLabel = label.trim().isEmpty ? 'Adjunto' : label.trim();
    final overlayBg =
        palette.bg.withValues(alpha: palette.isLight ? 0.86 : 0.62);
    final canPreview = onPreview != null;
    return Semantics(
      button: canPreview,
      enabled: canPreview,
      label: canPreview
          ? 'Abrir adjunto $safeLabel'
          : 'Adjunto no disponible $safeLabel',
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
                if ((uploadStatusLabel ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        uploadStatusIcon ?? Icons.schedule_rounded,
                        size: 13,
                        color: uploadStatusColor ?? palette.fgMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          uploadStatusLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: uploadStatusColor ?? palette.fgMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if ((uploadError ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    uploadError!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.fgMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Semantics(
                      button: canPreview,
                      enabled: canPreview,
                      label: canPreview
                          ? 'Ver adjunto'
                          : 'Adjunto sin vista previa disponible',
                      child: Tooltip(
                        message: canPreview ? 'Ver' : 'Sin vista previa',
                        child: _MiniActionButton(
                          buttonKey: previewKey,
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
                if (onRetryUpload != null) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: onRetryUpload,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reintentar'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                ],
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
    this.buttonKey,
    required this.icon,
    required this.onPressed,
    required this.palette,
  });

  final Key? buttonKey;
  final IconData icon;
  final VoidCallback? onPressed;
  final _SheetPalette palette;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: buttonKey,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Opacity(
          opacity: enabled ? 1 : 0.42,
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
      ),
    );
  }
}
