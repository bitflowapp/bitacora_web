import 'package:bitacora_web/core/i18n/app_strings.dart';

String sanitizeBitFlowSheetName(String sheetName) {
  final trimmed = sheetName.trim();
  final fallback = trimmed.isEmpty ? AppStrings.sheetDefaultName : trimmed;
  final noForbidden = fallback
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'[^A-Za-z0-9._\\-\\s]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .trim();
  if (noForbidden.isEmpty) return AppStrings.sheetDefaultName;
  return noForbidden;
}

String buildBitFlowExportFileName({
  required String sheetName,
  required String extension,
  DateTime? now,
}) {
  final at = (now ?? DateTime.now()).toLocal();
  final ext = extension.trim().toLowerCase().replaceAll('.', '');
  final safeSheet = sanitizeBitFlowSheetName(sheetName);
  final yyyy = at.year.toString().padLeft(4, '0');
  final mm = at.month.toString().padLeft(2, '0');
  final dd = at.day.toString().padLeft(2, '0');
  return 'BitFlow_$yyyy-$mm-${dd}_$safeSheet.$ext';
}
