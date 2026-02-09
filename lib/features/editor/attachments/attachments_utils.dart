part of '../editor_screen.dart';

// Helpers puros de adjuntos.
String _photoCaptionFor(PhotoAttachment p) {
  final caption = p.caption.trim();
  if (caption.isNotEmpty) return caption;
  final name = p.filename.trim();
  return name.isNotEmpty ? name : 'Adjunto';
}
