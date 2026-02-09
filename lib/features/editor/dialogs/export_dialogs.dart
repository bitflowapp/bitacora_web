part of '../editor_screen.dart';

extension _EditorExportDialogs on _EditorScreenState {
  Future<void> _openExportMenu() async {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await showAppModal<void>(
      context: context,
      title: AppStrings.editorExportShare,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: AppStrings.editorExportXlsx,
            icon: Icons.table_view_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_exportXlsxOnly());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: AppStrings.editorExportZip,
            icon: Icons.folder_zip_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_exportZipBundle(share: false));
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: AppStrings.editorShareZip,
            icon: Icons.ios_share_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_exportZipBundle(share: true));
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: AppStrings.editorBackupZip,
            icon: Icons.backup_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_exportBackupZip());
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: AppStrings.editorReportHtml,
            icon: Icons.description_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_exportHtmlReport());
            },
          ),
        ],
      ),
      actions: [
        AppButton(
          label: AppStrings.close,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      showClose: false,
      barrierDismissible: true,
    );
  }
}
