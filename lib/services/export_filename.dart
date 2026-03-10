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

String buildBitFlowBundleExportFileName({
  required String sheetName,
  DateTime? now,
}) {
  final at = (now ?? DateTime.now()).toLocal();
  final safeSheet = sanitizeBitFlowSheetName(sheetName);
  final yyyy = at.year.toString().padLeft(4, '0');
  final mm = at.month.toString().padLeft(2, '0');
  final dd = at.day.toString().padLeft(2, '0');
  final hh = at.hour.toString().padLeft(2, '0');
  final min = at.minute.toString().padLeft(2, '0');
  return 'BitFlow_${safeSheet}_$yyyy-$mm-$dd' '_$hh-$min.zip';
}

String buildBitFlowPackageWorkbookFileName({required String sheetName}) {
  final safeSheet = sanitizeBitFlowSheetName(sheetName);
  return 'BitFlow_$safeSheet.xlsx';
}

String buildBitFlowEvidenceFileName({
  required String kind,
  required String sheetName,
  required String reference,
  required DateTime timestamp,
  required String extension,
}) {
  final safeKind = sanitizeBitFlowSheetName(kind).toLowerCase();
  final safeSheet = sanitizeBitFlowSheetName(sheetName);
  final safeRef = sanitizeBitFlowSheetName(reference).replaceAll('_', '-');
  final yyyy = timestamp.year.toString().padLeft(4, '0');
  final mm = timestamp.month.toString().padLeft(2, '0');
  final dd = timestamp.day.toString().padLeft(2, '0');
  final hh = timestamp.hour.toString().padLeft(2, '0');
  final min = timestamp.minute.toString().padLeft(2, '0');
  final ext = extension.startsWith('.')
      ? extension.toLowerCase()
      : '.${extension.toLowerCase()}';
  return '${safeKind}_${safeSheet}_${safeRef}_$yyyy-$mm-$dd' '_$hh-$min$ext';
}
