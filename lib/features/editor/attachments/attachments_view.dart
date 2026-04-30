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

  String get _countLabel {
    if (count == 0) return 'Sin evidencias';
    if (count == 1) return '1 evidencia';
    return '$count evidencias';
  }

  @override
  Widget build(BuildContext context) {
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
          _countLabel,
          style: TextStyle(
            color: palette.fgMuted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 12),
        AppButton(
          label: 'Agregar',
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
