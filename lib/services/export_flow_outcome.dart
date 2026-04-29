enum ExportFlowOutcome {
  cancelled,
  unsupported,
  failed,
}

ExportFlowOutcome classifyExportFlowOutcome(Object error) {
  if (error is UnsupportedError) {
    return ExportFlowOutcome.unsupported;
  }
  final lower = error.toString().toLowerCase();
  if (_looksLikeCancelled(lower)) {
    return ExportFlowOutcome.cancelled;
  }
  if (_looksLikeUnsupported(lower)) {
    return ExportFlowOutcome.unsupported;
  }
  return ExportFlowOutcome.failed;
}

bool isExportFlowCancelled(Object error) {
  return classifyExportFlowOutcome(error) == ExportFlowOutcome.cancelled;
}

bool isExportFlowUnsupported(Object error) {
  return classifyExportFlowOutcome(error) == ExportFlowOutcome.unsupported;
}

bool _looksLikeCancelled(String lower) {
  return lower.contains('aborterror') ||
      lower.contains('user aborted') ||
      lower.contains('aborted by user') ||
      lower.contains('no image selected') ||
      lower.contains('image selection cancelled') ||
      lower.contains('user cancelled') ||
      lower.contains('user canceled') ||
      lower.contains('canceled by user') ||
      lower.contains('share canceled') ||
      lower.contains('share cancelled') ||
      lower.contains('cancelled') ||
      lower.contains('canceled') ||
      lower.contains('dismissed') ||
      lower.contains('did not share');
}

bool _looksLikeUnsupported(String lower) {
  return lower.contains('unsupported') ||
      lower.contains('not supported') ||
      lower.contains('notimplemented') ||
      lower.contains('missingpluginexception') ||
      lower.contains('xlsx_save_unsupported_platform');
}
