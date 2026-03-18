part of '../editor_screen.dart';

// UI principal del panel de adjuntos.
class _AttachmentsSheetHeader extends StatelessWidget {
  const _AttachmentsSheetHeader({
    required this.palette,
    required this.title,
    required this.count,
    required this.onAdd,
    required this.onClose,
  });

  final _SheetPalette palette;
  final String title;
  final int count;
  final VoidCallback onAdd;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final countLabel = count == 1 ? '1 foto' : '$count fotos';
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.fg,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          countLabel,
          style: TextStyle(
            color: palette.fgMuted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 12),
        AppButton(
          label: 'Adjuntar foto',
          icon: Icons.add_photo_alternate_outlined,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.sm,
          onPressed: onAdd,
        ),
        Tooltip(
          message: 'Cerrar',
          child: IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: palette.fgMuted),
          ),
        ),
      ],
    );
  }
}
