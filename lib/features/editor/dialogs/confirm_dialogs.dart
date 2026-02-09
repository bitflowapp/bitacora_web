part of '../editor_screen.dart';

extension _EditorConfirmDialogs on _EditorScreenState {
  Future<bool> _confirmDeleteEvidence(
    BuildContext context, {
    String? name,
    String? cellLabel,
  }) async {
    final safeName = name?.trim();
    final safeCell = cellLabel?.trim();
    final detail = [
      if (safeName != null && safeName.isNotEmpty) 'Adjunto: $safeName.',
      if (safeCell != null && safeCell.isNotEmpty) 'Celda: $safeCell.',
    ].join(' ');
    final message = detail.isEmpty
        ? 'Esta accion elimina la evidencia del proyecto.'
        : '$detail Esta accion elimina la evidencia del proyecto.';
    final ok = await showAppModal<bool>(
      context: context,
      title: 'Eliminar evidencia',
      child: Text(message),
      actions: [
        AppButton(
          label: AppStrings.cancel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: AppStrings.delete,
          variant: AppButtonVariant.destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
      barrierDismissible: true,
      showClose: false,
    );
    return ok == true;
  }
}
