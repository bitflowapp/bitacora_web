part of '../editor_screen.dart';

// UI principal del panel de adjuntos.
class AttachmentsSheetHeader extends StatelessWidget {
  const AttachmentsSheetHeader({
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
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.fg,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Text(
          '$count',
          style: TextStyle(
            color: palette.fgMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        AppButton(
          label: 'Agregar',
          icon: Icons.add_photo_alternate_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: onAdd,
        ),
        AppIconButton(
          icon: Icons.close_rounded,
          onPressed: onClose,
          tooltip: 'Cerrar',
          variant: AppIconButtonVariant.ghost,
        ),
      ],
    );
  }
}
