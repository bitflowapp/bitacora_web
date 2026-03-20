part of '../editor_screen.dart';

class _ExportFlowResultBanner extends StatelessWidget {
  const _ExportFlowResultBanner({
    required this.palette,
    required this.result,
    required this.title,
    required this.formatLabel,
    required this.icon,
    required this.actionLabelBuilder,
    required this.onAction,
    required this.onDismiss,
    this.busy = false,
  });

  final _SheetPalette palette;
  final _ExportFlowResult result;
  final String title;
  final String formatLabel;
  final IconData icon;
  final String Function(_ExportFlowResultAction action) actionLabelBuilder;
  final ValueChanged<_ExportFlowResultAction> onAction;
  final VoidCallback onDismiss;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError = result.isError;
    final bg = isError
        ? scheme.errorContainer.withValues(alpha: palette.isLight ? 0.74 : 0.3)
        : palette.menuBg.withValues(alpha: palette.isLight ? 0.96 : 0.82);
    final border = isError
        ? scheme.error.withValues(alpha: palette.isLight ? 0.3 : 0.5)
        : palette.borderStrong;
    final accent = isError ? scheme.error : palette.fg;
    final labelColor = isError ? scheme.onErrorContainer : palette.fgMuted;
    final detailColor = isError ? scheme.onErrorContainer : palette.fg;
    final location = (result.savedPath ?? '').trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: AppleCard(
        key: const ValueKey('export-flow-result-banner'),
        radius: 16,
        color: bg,
        borderColor: border,
        shadows: const <BoxShadow>[],
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color:
                        accent.withValues(alpha: palette.isLight ? 0.1 : 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: detailColor,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(
                                alpha: palette.isLight ? 0.09 : 0.16,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              formatLabel,
                              style: TextStyle(
                                color: accent,
                                fontSize: 11.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Tooltip(
                        message: result.fileName,
                        child: Text(
                          result.fileName,
                          key: const ValueKey('export-flow-result-file'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: detailColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.8,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('export-flow-result-dismiss'),
                  tooltip: 'Descartar resultado',
                  onPressed: onDismiss,
                  icon: Icon(
                    Icons.close_rounded,
                    color: labelColor,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              result.message,
              key: const ValueKey('export-flow-result-message'),
              style: TextStyle(
                color: labelColor,
                fontSize: 12.2,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 6),
              Tooltip(
                message: location,
                child: Text(
                  'Ubicacion: $location',
                  key: const ValueKey('export-flow-result-location'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 11.6,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (result.actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in result.actions)
                    TextButton(
                      key: ValueKey(
                        'export-flow-result-action-${action.name}',
                      ),
                      onPressed: busy ? null : () => onAction(action),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        foregroundColor: detailColor,
                        backgroundColor: accent.withValues(
                          alpha: palette.isLight ? 0.09 : 0.16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        actionLabelBuilder(action),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
