part of 'editor_screen.dart';

class EditorController {
  const EditorController({
    required this.saveStatus,
    required this.openAttachments,
    required this.closeAttachments,
    required this.addAttachment,
    required this.removeAttachment,
    required this.previewAttachment,
  });

  final ValueListenable<EditorSaveSnapshot> saveStatus;
  final void Function(CellRef ref) openAttachments;
  final VoidCallback closeAttachments;
  final Future<void> Function(CellRef ref) addAttachment;
  final Future<void> Function(CellRef ref, int index) removeAttachment;
  final Future<void> Function(BuildContext context, PhotoAttachment attachment)
      previewAttachment;
}
