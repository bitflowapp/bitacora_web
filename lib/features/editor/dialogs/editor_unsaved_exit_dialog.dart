part of '../editor_screen.dart';

extension _EditorUnsavedExitDialog on _EditorScreenState {
  Future<_UnsavedExitAction> _askUnsavedExitAction() async {
    if (!mounted) return _UnsavedExitAction.cancel;
    final result = await showDialog<_UnsavedExitAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cambios sin guardar'),
          content: Text(
            _saving
                ? 'BitFlow esta guardando cambios en este momento. Si sales ahora, el guardado podria quedar incompleto.'
                : 'Hay cambios sin guardar. Guarda antes de salir para no perder ediciones recientes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                _UnsavedExitAction.cancel,
              ),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                _UnsavedExitAction.discard,
              ),
              child: const Text('Salir sin guardar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                _UnsavedExitAction.save,
              ),
              child: const Text('Guardar y salir'),
            ),
          ],
        );
      },
    );
    return result ?? _UnsavedExitAction.cancel;
  }
}
