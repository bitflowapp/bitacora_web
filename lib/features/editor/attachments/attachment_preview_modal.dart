part of '../editor_screen.dart';

class AttachmentPreviewModal extends StatelessWidget {
  const AttachmentPreviewModal({
    super.key,
    required this.preview,
  });

  final Widget preview;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) {
          final scale = Tween<double>(begin: 0.96, end: 1.0).animate(anim);
          return FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
        child: ClipRRect(
          key: ValueKey(preview.hashCode),
          borderRadius: BorderRadius.circular(14),
          child: preview,
        ),
      ),
    );
  }
}
